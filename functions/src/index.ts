import { createHash, randomInt } from "node:crypto";
import * as net from "node:net";
import * as tls from "node:tls";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

admin.initializeApp();

const db = admin.firestore();
const usuariosCollection = db.collection("usuarios");
const passwordRecoveryCollection = db.collection("passwordRecoveryCodes");
const recoveryCodeTtlMinutes = 10;
const recoveryCodeLength = 6;

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

type SolicitarCodigoRecuperacaoPayload = {
  email?: unknown;
};

type RedefinirSenhaPayload = {
  email?: unknown;
  code?: unknown;
  newPassword?: unknown;
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

export const solicitarCodigoRecuperacaoSenha = functions.https.onCall(
  async (data: SolicitarCodigoRecuperacaoPayload) => {
    const email = sanitizeEmail(data.email);
    const response = {
      success: true,
      message:
        "Se existir uma conta com este e-mail, um codigo de recuperacao foi enviado.",
    };

    let user: admin.auth.UserRecord;

    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (isAuthUserNotFound(error)) {
        return response;
      }

      throw toHttpsError(error, "Nao foi possivel iniciar a recuperacao de senha.");
    }

    const code = generateNumericCode(recoveryCodeLength);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + recoveryCodeTtlMinutes * 60 * 1000)
    );

    await passwordRecoveryCollection.doc(buildRecoveryDocId(email)).set(
      {
        uid: user.uid,
        email,
        codeHash: hashRecoveryCode(email, code),
        attempts: 0,
        usedAt: null,
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await sendRecoveryCodeEmail({
      to: email,
      code,
      expiresInMinutes: recoveryCodeTtlMinutes,
    });

    return response;
  }
);

export const redefinirSenhaComCodigo = functions.https.onCall(
  async (data: RedefinirSenhaPayload) => {
    const email = sanitizeEmail(data.email);
    const code = sanitizeRecoveryCode(data.code);
    const newPassword = sanitizeNewPassword(data.newPassword);
    const recoveryRef = passwordRecoveryCollection.doc(buildRecoveryDocId(email));
    const recoverySnapshot = await recoveryRef.get();

    if (!recoverySnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Nenhum codigo de recuperacao foi solicitado para este e-mail."
      );
    }

    const recoveryData = recoverySnapshot.data();
    const expiresAt = recoveryData?.expiresAt as admin.firestore.Timestamp | undefined;
    const usedAt = recoveryData?.usedAt;
    const storedHash = recoveryData?.codeHash;

    if (!expiresAt || typeof storedHash !== "string") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "O codigo de recuperacao armazenado esta invalido."
      );
    }

    if (usedAt) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Este codigo ja foi utilizado."
      );
    }

    if (expiresAt.toDate().getTime() < Date.now()) {
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "O codigo informado expirou. Solicite um novo envio."
      );
    }

    if (storedHash !== hashRecoveryCode(email, code)) {
      await recoveryRef.set(
        {
          attempts: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      throw new functions.https.HttpsError(
        "permission-denied",
        "O codigo informado esta incorreto."
      );
    }

    let user: admin.auth.UserRecord;

    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      throw toHttpsError(error, "Nao foi possivel localizar a conta do usuario.");
    }

    await admin.auth().updateUser(user.uid, { password: newPassword });
    await recoveryRef.set(
      {
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      message: "Senha redefinida com sucesso.",
    };
  }
);

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

function sanitizeRecoveryCode(value: unknown): string {
  const raw = sanitizeRequiredString(value, "Codigo");
  const digits = raw.replace(/\D/g, "");

  if (digits.length !== recoveryCodeLength) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `O codigo deve conter ${recoveryCodeLength} digitos.`
    );
  }

  return digits;
}

function sanitizeNewPassword(value: unknown): string {
  const password = sanitizeRequiredString(value, "Nova senha");

  if (password.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A nova senha deve ter pelo menos 6 caracteres."
    );
  }

  return password;
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

function buildRecoveryDocId(email: string): string {
  return createHash("sha256").update(email).digest("hex");
}

function hashRecoveryCode(email: string, code: string): string {
  return createHash("sha256").update(`${email}:${code}`).digest("hex");
}

function generateNumericCode(length: number): string {
  return Array.from({ length }, () => randomInt(0, 10)).join("");
}

function isAuthUserNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "auth/user-not-found"
  );
}

function toHttpsError(error: unknown, fallbackMessage: string): functions.https.HttpsError {
  if (error instanceof functions.https.HttpsError) {
    return error;
  }

  const message =
    error instanceof Error && error.message.trim().length > 0
      ? error.message
      : fallbackMessage;

  return new functions.https.HttpsError("internal", message);
}

type SmtpConfig = {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  pass: string;
  fromEmail: string;
  fromName: string;
};

type RecoveryEmailPayload = {
  to: string;
  code: string;
  expiresInMinutes: number;
};

async function sendRecoveryCodeEmail({
  to,
  code,
  expiresInMinutes,
}: RecoveryEmailPayload): Promise<void> {
  const smtp = getSmtpConfig();
  const socket = await connectSmtp(smtp);

  try {
    await expectResponse(socket, 220);
    await sendCommand(socket, `EHLO ${smtp.host}`, 250);
    await sendCommand(
      socket,
      `AUTH LOGIN`,
      334
    );
    await sendCommand(
      socket,
      Buffer.from(smtp.user, "utf8").toString("base64"),
      334
    );
    await sendCommand(
      socket,
      Buffer.from(smtp.pass, "utf8").toString("base64"),
      235
    );
    await sendCommand(socket, `MAIL FROM:<${smtp.fromEmail}>`, 250);
    await sendCommand(socket, `RCPT TO:<${to}>`, 250);
    await sendCommand(socket, "DATA", 354);

    const message = buildRawEmail({
      fromEmail: smtp.fromEmail,
      fromName: smtp.fromName,
      to,
      subject: "Codigo de recuperacao de senha",
      text: [
        "Voce solicitou a recuperacao da sua senha.",
        `Seu codigo de verificacao e: ${code}`,
        `Este codigo expira em ${expiresInMinutes} minutos.`,
        "Se voce nao solicitou esta alteracao, ignore este e-mail.",
      ].join("\n"),
      html: [
        "<p>Voce solicitou a recuperacao da sua senha.</p>",
        `<p><strong>Seu codigo de verificacao e: ${code}</strong></p>`,
        `<p>Este codigo expira em ${expiresInMinutes} minutos.</p>`,
        "<p>Se voce nao solicitou esta alteracao, ignore este e-mail.</p>",
      ].join(""),
    });

    socket.write(`${escapeSmtpData(message)}\r\n.\r\n`);
    await expectResponse(socket, 250);
    await sendCommand(socket, "QUIT", 221);
  } finally {
    socket.end();
  }
}

function getSmtpConfig(): SmtpConfig {
  const smtp = functions.config().smtp;

  if (!smtp?.host || !smtp?.user || !smtp?.pass || !smtp?.from_email) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "As credenciais SMTP nao foram configuradas nas Cloud Functions."
    );
  }

  return {
    host: String(smtp.host),
    port: Number(smtp.port ?? 465),
    secure: smtp.secure === undefined ? true : String(smtp.secure) === "true",
    user: String(smtp.user),
    pass: String(smtp.pass),
    fromEmail: String(smtp.from_email),
    fromName: String(smtp.from_name ?? "Mescla Invest"),
  };
}

async function connectSmtp(smtp: SmtpConfig): Promise<tls.TLSSocket | net.Socket> {
  return await new Promise((resolve, reject) => {
    const onError = (error: Error) => reject(error);

    if (smtp.secure) {
      const socket = tls.connect(
        {
          host: smtp.host,
          port: smtp.port,
          servername: smtp.host,
        },
        () => resolve(socket)
      );

      socket.on("error", onError);
      return;
    }

    const socket = net.connect(
      {
        host: smtp.host,
        port: smtp.port,
      },
      () => resolve(socket)
    );

    socket.on("error", onError);
  });
}

async function sendCommand(
  socket: tls.TLSSocket | net.Socket,
  command: string,
  expectedCode: number
): Promise<void> {
  socket.write(`${command}\r\n`);
  await expectResponse(socket, expectedCode);
}

async function expectResponse(
  socket: tls.TLSSocket | net.Socket,
  expectedCode: number
): Promise<void> {
  const response = await readSmtpResponse(socket);

  if (response.code !== expectedCode) {
    throw new Error(
      `SMTP respondeu com ${response.code} quando ${expectedCode} era esperado: ${response.message}`
    );
  }
}

async function readSmtpResponse(
  socket: tls.TLSSocket | net.Socket
): Promise<{ code: number; message: string }> {
  return await new Promise((resolve, reject) => {
    let buffer = "";

    const cleanup = () => {
      socket.off("data", onData);
      socket.off("error", onError);
      socket.off("close", onClose);
    };

    const onError = (error: Error) => {
      cleanup();
      reject(error);
    };

    const onClose = () => {
      cleanup();
      reject(new Error("Conexao SMTP encerrada inesperadamente."));
    };

    const onData = (chunk: Buffer | string) => {
      buffer += chunk.toString();
      const lines = buffer.split(/\r?\n/).filter(Boolean);

      if (lines.length === 0) {
        return;
      }

      const lastLine = lines[lines.length - 1];
      const match = lastLine.match(/^(\d{3})([ -])(.*)$/);

      if (!match || match[2] !== " ") {
        return;
      }

      cleanup();
      resolve({
        code: Number(match[1]),
        message: lines.join("\n"),
      });
    };

    socket.on("data", onData);
    socket.on("error", onError);
    socket.on("close", onClose);
  });
}

function buildRawEmail({
  fromEmail,
  fromName,
  to,
  subject,
  text,
  html,
}: {
  fromEmail: string;
  fromName: string;
  to: string;
  subject: string;
  text: string;
  html: string;
}): string {
  const boundary = `mescla-${Date.now()}`;

  return [
    `From: ${fromName} <${fromEmail}>`,
    `To: <${to}>`,
    `Subject: ${subject}`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: 8bit",
    "",
    text,
    `--${boundary}`,
    "Content-Type: text/html; charset=UTF-8",
    "Content-Transfer-Encoding: 8bit",
    "",
    html,
    `--${boundary}--`,
  ].join("\r\n");
}

function escapeSmtpData(message: string): string {
  return message
    .replace(/\r?\n/g, "\r\n")
    .replace(/^\./gm, "..");
}
