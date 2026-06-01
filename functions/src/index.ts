import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
export * from "./balcao";
import { enforceRateLimit } from "./rate_limit";

// Inicializa o SDK do Firebase Admin (requisito para acesso ao Auth/Firestore).
// Guard idempotente: o módulo balcao (re-exportado acima) pode já ter inicializado.
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const usuariosCollection = db.collection("usuarios");

// Payload esperado para registrar usuário (todos os campos são recebidos como unknown e sanitizados/validados).
type RegistrarUsuarioPayload = {
  cpf?: unknown;
  fullName?: unknown;
  dataNascimento?: unknown;
  email?: unknown;
  telefone?: unknown;
  mfaHabilitado?: unknown;
  userActive?: unknown;
};

type CreditarSaldoPayload = {
  valor?: unknown;
};

// Função Callable: registra um usuário (valida autenticação, sanitiza payload, evita CPF duplicado e salva/merge no Firestore).
export const registrarUsuario = functions
  .region('southamerica-east1')
  .https.onCall(
  async (data: RegistrarUsuarioPayload, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }

    const payload = normalizarPayload(data, context.auth.token.email);
    const userId = context.auth.uid;

    await validarCpfDisponivel(payload.cpf, userId);

    const existingSnapshot = await usuariosCollection.doc(userId).get();
    const existingData = existingSnapshot.data() ?? {};
    const existingRole =
      typeof existingData.role === "string" && existingData.role.trim().length > 0
        ? existingData.role
        : "user";
    const existingIsAdmin =
      typeof existingData.isAdmin === "boolean" ? existingData.isAdmin : false;

    await usuariosCollection.doc(userId).set(
      {
        ...payload,
        uid: userId,
        role: existingRole,
        isAdmin: existingIsAdmin,
        createdAt:
          existingSnapshot.exists && existingData.createdAt
            ? existingData.createdAt
            : admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Garante wallet/main desde o signup. Idempotente: não sobrescreve saldo existente.
    const walletRef = usuariosCollection.doc(userId).collection("wallet").doc("main");
    const walletSnap = await walletRef.get();
    if (!walletSnap.exists) {
      await walletRef.set({
        saldo_brl: 0,
        saldo_brl_reservado: 0,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      success: true,
      uid: userId,
    };
  }
);

// Trigger Auth: ao remover usuário no Firebase Auth, tenta remover o perfil correspondente no Firestore.
export const excluirPerfilAoExcluirAuth = functions
  .region('southamerica-east1')
  .auth
  .user()
  .onDelete(async (user) => {
    await usuariosCollection.doc(user.uid).delete().catch(() => undefined);
  });

// Funcao Callable: credita saldo simulado com privilegios de Admin SDK para evitar bloqueios das regras do cliente.
export const creditarSaldoSimulado = functions
  .region("southamerica-east1")
  .https.onCall(async (data: CreditarSaldoPayload, context) => {
    const uid = context.auth?.uid;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }

    const valor = sanitizePositiveNumber(data.valor, "Valor");

    const VALOR_MAX_POR_DEPOSITO = 100_000;
    const VALOR_MAX_DIARIO = 500_000;

    if (valor > VALOR_MAX_POR_DEPOSITO) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Valor maximo por deposito: R$ ${VALOR_MAX_POR_DEPOSITO}.`
      );
    }

    const usuarioRef = usuariosCollection.doc(uid);
    const transacaoRef = usuarioRef.collection("transacoes").doc();
    const walletMainRef = usuarioRef.collection("wallet").doc("main");
    const todayKey = new Date().toISOString().slice(0, 10);
    const dailyLimitRef = usuarioRef.collection("deposit_limits").doc(todayKey);

    await db.runTransaction(async (tx) => {
      const limitSnap = await tx.get(dailyLimitRef);
      const totalHoje = (limitSnap.data()?.total as number | undefined) ?? 0;
      if (totalHoje + valor > VALOR_MAX_DIARIO) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          `Limite diario de R$ ${VALOR_MAX_DIARIO} excedido. Ja depositado hoje: R$ ${totalHoje}.`
        );
      }

      tx.set(
        walletMainRef,
        {
          saldo_brl: admin.firestore.FieldValue.increment(valor),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(transacaoRef, {
        tipo: "deposito",
        titulo: "Credito Simulado",
        subtitulo: formatTransactionDate(new Date()),
        valor,
        positivo: true,
        fonte: "Externo",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        dailyLimitRef,
        {
          total: admin.firestore.FieldValue.increment(valor),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return {
      success: true,
      valor,
    };
  });

// Funcao Callable: atualiza o flag mfaHabilitado no perfil do usuario.
// Cliente nao pode escrever esse campo diretamente (protegido pelas rules).
export const atualizarMfaStatus = functions
  .region("southamerica-east1")
  .https.onCall(async (data: { habilitado?: unknown }, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }
    if (typeof data.habilitado !== "boolean") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "habilitado deve ser boolean."
      );
    }

    await enforceRateLimit({
      key: uid,
      action: "atualizarMfaStatus",
      maxPerWindow: 5,
      windowSeconds: 600,
    });

    await usuariosCollection.doc(uid).set(
      {
        mfaHabilitado: data.habilitado,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { success: true, habilitado: data.habilitado };
  });

// Valida se um CPF já está disponível para cadastro; se existir outro usuário com o mesmo CPF, lança erro.
async function validarCpfDisponivel(cpf: string, userId: string): Promise<void> {
  const snapshot = await usuariosCollection
    .where("cpf", "==", cpf)
    .limit(1)
    .get();

  if (!snapshot.empty && snapshot.docs[0]?.id !== userId) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Ja existe um usuario cadastrado com este CPF."
    );
  }
}

// Sanitiza e normaliza o payload de registro (CPF/telefone/e-mail/senha/data) para um objeto consistente.
function normalizarPayload(
  data: RegistrarUsuarioPayload,
  emailAutenticado?: string | null
) {
  const cpf = sanitizeDigits(data.cpf, "CPF");
  const fullName = sanitizeRequiredString(data.fullName, "Nome completo");
  const telefone = sanitizeDigits(data.telefone, "Telefone");
  const email = sanitizeEmail(data.email ?? emailAutenticado);
  const dataNascimento = sanitizeBirthDate(data.dataNascimento);
  const mfaHabilitado = Boolean(data.mfaHabilitado);
  const userActive = data.userActive === undefined ? true : Boolean(data.userActive);

  if (cpf.length !== 11) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "CPF invalido."
    );
  }

  if (telefone.length < 10 || telefone.length > 11) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Telefone invalido."
    );
  }

  if (
    typeof emailAutenticado === "string" &&
    emailAutenticado.trim().toLowerCase() !== email
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "O e-mail autenticado difere do payload enviado."
    );
  }

  return {
    cpf,
    fullName,
    dataNascimento,
    email,
    telefone,
    mfaHabilitado,
    userActive,
  };
}

// Garante que um campo seja string não vazia (trim), senão lança HttpsError.
function sanitizeRequiredString(value: unknown, fieldName: string): string {
  if (typeof value != "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} obrigatorio.`
    );
  }

  const normalized = value.trim();
  if (!normalized) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} obrigatorio.`
    );
  }

  return normalized;
}

// Sanitiza campos numéricos representados como texto (mantém apenas dígitos), usando sanitizeRequiredString.
function sanitizeDigits(value: unknown, fieldName: string): string {
  const raw = sanitizeRequiredString(value, fieldName);
  return raw.replace(/\D/g, "");
}

// Sanitiza e valida e-mail por regex, convertendo para lowercase.
function sanitizeEmail(value: unknown): string {
  const email = sanitizeRequiredString(value, "E-mail").toLowerCase();
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!emailPattern.test(email)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "E-mail invalido."
    );
  }

  return email;
}

// Converte string de data em Timestamp do Firestore; rejeita datas inválidas e datas no futuro.
function sanitizeBirthDate(value: unknown): admin.firestore.Timestamp {
  const raw = sanitizeRequiredString(value, "Data de nascimento");
  const parsedDate = new Date(raw);

  if (Number.isNaN(parsedDate.getTime()) || parsedDate > new Date()) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Data de nascimento invalida."
    );
  }

  return admin.firestore.Timestamp.fromDate(parsedDate);
}

function sanitizePositiveNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} invalido.`
    );
  }

  return value;
}

function formatTransactionDate(data: Date): string {
  const meses = [
    "",
    "jan",
    "fev",
    "mar",
    "abr",
    "mai",
    "jun",
    "jul",
    "ago",
    "set",
    "out",
    "nov",
    "dez",
  ];

  const hora = data.getHours().toString().padStart(2, "0");
  const minuto = data.getMinutes().toString().padStart(2, "0");

  return `${data.getDate()} ${meses[data.getMonth() + 1]} ${data.getFullYear()} - ${hora}:${minuto}`;
}