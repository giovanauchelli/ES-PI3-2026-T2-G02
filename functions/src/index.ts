import { createHash } from "node:crypto";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

admin.initializeApp();

const db = admin.firestore();
const usuariosCollection = db.collection("usuarios");

type RegistrarUsuarioPayload = {
  cpf?: unknown;
  fullName?: unknown;
  dataNascimento?: unknown;
  email?: unknown;
  senha?: unknown;
  telefone?: unknown;
  mfaHabilitado?: unknown;
  userActive?: unknown;
  userloggedIn?: unknown;
};

export const registrarUsuario = functions.https.onCall(
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

    await usuariosCollection.doc(userId).set(
      {
        ...payload,
        uid: userId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      uid: userId,
    };
  }
);

export const excluirPerfilAoExcluirAuth = functions.auth
  .user()
  .onDelete(async (user) => {
    await usuariosCollection.doc(user.uid).delete().catch(() => undefined);
  });

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

function normalizarPayload(
  data: RegistrarUsuarioPayload,
  emailAutenticado?: string | null
) {
  const cpf = sanitizeDigits(data.cpf, "CPF");
  const fullName = sanitizeRequiredString(data.fullName, "Nome completo");
  const telefone = sanitizeDigits(data.telefone, "Telefone");
  const senha = hashPassword(sanitizeRequiredString(data.senha, "Senha"));
  const email = sanitizeEmail(data.email ?? emailAutenticado);
  const dataNascimento = sanitizeBirthDate(data.dataNascimento);
  const mfaHabilitado = Boolean(data.mfaHabilitado);
  const userActive = data.userActive === undefined ? true : Boolean(data.userActive);
  const userloggedIn =
    data.userloggedIn === undefined ? true : Boolean(data.userloggedIn);

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
    senha,
    telefone,
    mfaHabilitado,
    userActive,
    userloggedIn,
  };
}

function hashPassword(password: string): string {
  if (password.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A senha deve ter pelo menos 6 caracteres."
    );
  }

  return createHash("sha256").update(password).digest("hex");
}

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

function sanitizeDigits(value: unknown, fieldName: string): string {
  const raw = sanitizeRequiredString(value, fieldName);
  return raw.replace(/\D/g, "");
}

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
