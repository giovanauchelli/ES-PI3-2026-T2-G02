"use strict";
// ============================================================
// "use strict" → ativa o modo estrito do JavaScript.
// Isso faz o JS ser mais rigoroso: proíbe variáveis não declaradas,
// evita erros silenciosos e facilita a detecção de bugs.
// ============================================================


// ------------------------------------------------------------
// BLOCO DE IMPORTAÇÕES (boilerplate gerado automaticamente)
// Esse bloco enorme no início é código gerado pelo TypeScript
// (compilador que transforma TypeScript → JavaScript).
// Você não precisa entender cada linha — ele só garante que
// os módulos importados funcionem corretamente em qualquer
// ambiente Node.js antigo ou novo.
// Em resumo: ele cria funções auxiliares para "copiar" e
// "exportar" partes de outros arquivos/módulos.
// ------------------------------------------------------------
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
// ------------------------------------------------------------
// FIM DO BLOCO DE BOILERPLATE
// ------------------------------------------------------------


// ------------------------------------------------------------
// EXPORTAÇÕES: torna funções deste arquivo visíveis para outros
// arquivos que o importarem.
// Começa como "undefined" e é preenchido mais abaixo.
// ------------------------------------------------------------

//A propriedade __esModule: true é uma marca que diz: "este arquivo foi originalmente escrito no sistema moderno", para que outros arquivos saibam como importá-lo corretamente
Object.defineProperty(exports, "__esModule", { value: true });
exports.listarStartups = exports.creditarSaldoSimulado = exports.excluirPerfilAoExcluirAuth = exports.registrarUsuario = void 0;


// ------------------------------------------------------------
// IMPORTAÇÕES DAS BIBLIOTECAS USADAS
// ------------------------------------------------------------

// "firebase-admin" → SDK do servidor do Firebase.
// Permite acessar banco de dados (Firestore), autenticação (Auth)
// e outros serviços do Firebase com permissão total (como administrador).
const admin = __importStar(require("firebase-admin"));

// "firebase-functions/v1" → permite criar funções de nuvem (Cloud Functions).
// São funções que rodam no servidor do Google quando chamadas pelo app.
const functions = __importStar(require("firebase-functions/v1"));

// Importa e re-exporta tudo que estiver no arquivo "./balcao"
// (provavelmente outras funções relacionadas ao "balcão de negociação").
__exportStar(require("./balcao"), exports);


// ------------------------------------------------------------
// INICIALIZAÇÃO DO FIREBASE
// Sempre necessário antes de usar qualquer serviço do Firebase no servidor.
// ------------------------------------------------------------
admin.initializeApp();

// "db" → referência ao banco de dados Firestore.
// Firestore é um banco NoSQL (não relacional) da Google, baseado em documentos.
const db = admin.firestore();

// "usuariosCollection" → atalho para a coleção "usuarios" no Firestore.
// Uma coleção é como uma "tabela" no banco; cada item dentro é um "documento".
const usuariosCollection = db.collection("usuarios");


// ============================================================
// FUNÇÃO: registrarUsuario
// ============================================================
// O que faz: recebe os dados de cadastro de um usuário (nome, CPF, etc.)
// e salva no banco de dados Firestore.
//
// Tipo: "Callable Function" → é chamada diretamente pelo app mobile/web
// usando o SDK do Firebase (não é uma URL HTTP comum).
//
// Região: southamerica-east1 → roda em servidores em São Paulo,
// mais próximo dos usuários brasileiros (menor latência).
// ============================================================
exports.registrarUsuario = functions
    .region('southamerica-east1')
    .https.onCall(async (data, context) => {
    // "data" → dados enviados pelo app (nome, CPF, telefone, etc.)
    // "context" → informações sobre quem está chamando (usuário logado, etc.)

    // VERIFICAÇÃO DE AUTENTICAÇÃO:
    // context.auth?.uid → o "?" é optional chaining: se "auth" for null/undefined,
    // não dá erro, apenas retorna undefined.
    // Se não houver UID (usuário não está logado), lança um erro e para tudo.
    if (!context.auth?.uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
        // HttpsError → erro padronizado do Firebase que o app consegue ler.
        // "unauthenticated" → código do erro (tipo do problema).
    }

    // Normaliza e valida os dados recebidos (limpa CPF, valida e-mail, etc.)
    const payload = normalizarPayload(data, context.auth.token.email);
    // context.auth.token.email → e-mail confirmado pelo Firebase Auth
    // (mais confiável que o e-mail enviado pelo app, pois vem do token JWT).

    const userId = context.auth.uid;
    // UID → identificador único do usuário no Firebase Auth.

    // Verifica se já existe outro usuário cadastrado com o mesmo CPF.
    await validarCpfDisponivel(payload.cpf, userId);

    // Busca o documento atual do usuário no Firestore (se já existir).
    const existingSnapshot = await usuariosCollection.doc(userId).get();
    // .doc(userId) → acessa o documento com o ID igual ao UID do usuário.
    // .get() → lê o documento do banco. Retorna um "snapshot" (foto do dado).

    const existingData = existingSnapshot.data() ?? {};
    // .data() → extrai os campos do documento como um objeto JS.
    // ?? {} → se for null/undefined, usa um objeto vazio como padrão.

    // Preserva o "role" (papel/permissão) anterior do usuário, se existir.
    // Isso evita que um re-cadastro apague permissões de admin, por exemplo.
    //role -> qual tipo de usuário essa pessoa é dentro do sistema
    const existingRole = typeof existingData.role === "string" && existingData.role.trim().length > 0
        ? existingData.role
        : "user"; // se não tiver role definido, assume "user" (usuário comum)

    // Preserva o campo isAdmin anterior, se existir.
    const existingIsAdmin = typeof existingData.isAdmin === "boolean" ? existingData.isAdmin : false;

    // Salva (ou atualiza) o documento do usuário no Firestore.
    await usuariosCollection.doc(userId).set({
        ...payload,          // espalha todos os campos de payload (CPF, nome, etc.)
        uid: userId,         // adiciona o UID
        role: existingRole,  // mantém o role anterior
        isAdmin: existingIsAdmin, // mantém o isAdmin anterior

        // createdAt → data de criação. Se o documento já existia, preserva a data original.
        // Se é novo, usa o timestamp do servidor (momento exato no servidor Google).
        createdAt: existingSnapshot.exists && existingData.createdAt
            ? existingData.createdAt
            : admin.firestore.FieldValue.serverTimestamp(),

        // updatedAt → sempre atualiza para o momento atual.
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // { merge: true } → não apaga campos que já existem no documento;
    // apenas atualiza/adiciona os campos enviados.

    // Retorna sucesso para o app.
    return {
        success: true,
        uid: userId,
    };
});


// ============================================================
// FUNÇÃO: excluirPerfilAoExcluirAuth
// ============================================================
// O que faz: quando um usuário é deletado do Firebase Auth
// (sistema de login), esta função automaticamente apaga
// também o perfil dele no Firestore (banco de dados).
//
// Tipo: "Auth Trigger" → é disparado automaticamente pelo Firebase
// quando um evento de autenticação ocorre (neste caso, deleção).
// ============================================================
exports.excluirPerfilAoExcluirAuth = functions
    .region('southamerica-east1')
    .auth
    .user()
    .onDelete(async (user) => {
    // "user" → objeto com dados do usuário que foi deletado (uid, email, etc.)

    // Tenta apagar o documento do Firestore com o mesmo UID.
    // .catch(() => undefined) → se der erro (ex: documento não existe), ignora silenciosamente.
    await usuariosCollection.doc(user.uid).delete().catch(() => undefined);
});


// ============================================================
// FUNÇÃO: creditarSaldoSimulado
// ============================================================
// O que faz: adiciona saldo simulado (dinheiro fictício para testes)
// na carteira (wallet) do usuário no Firestore.
// Também registra essa operação como uma transação no histórico.
//
// Por que usar Cloud Function aqui?
// As regras de segurança do Firestore no cliente poderiam bloquear
// escritas diretas na carteira. Usando o Admin SDK no servidor,
// essas regras são ignoradas (o servidor tem permissão total).
// ============================================================
exports.creditarSaldoSimulado = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
    }

    // Valida que o valor enviado é um número positivo e finito.
    const valor = sanitizePositiveNumber(data.valor, "Valor");

    // Referências aos documentos que serão escritos:
    //pegue o documento do usuário com esse UID
    const usuarioRef = usuariosCollection.doc(uid);

    // Subcoleção "transacoes" dentro do documento do usuário.
    // .doc() sem argumento → gera um ID aleatório único para a nova transação.
    // transacaoRef é o ponteiro para nova transação futura
    const transacaoRef = usuarioRef.collection("transacoes").doc();

    // Documento "main" dentro da subcoleção "wallet" do usuário.
    const walletMainRef = usuarioRef.collection("wallet").doc("main");

    // "batch" → operação em lote. Agrupa múltiplas escritas para executar
    // todas de uma vez, de forma atômica (ou tudo funciona, ou nada é salvo).
    // Isso evita inconsistências: ex, creditar o saldo mas falhar ao salvar a transação.
    const batch = db.batch();

    // Atualiza o saldo: incrementa o campo "saldo_brl" pelo valor recebido.
    // FieldValue.increment() → soma ao valor existente sem precisar ler antes.
    batch.set(walletMainRef, {
        saldo_brl: admin.firestore.FieldValue.increment(valor),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Salva o registro da transação no histórico.
    batch.set(transacaoRef, {
        tipo: "deposito",
        titulo: "Credito Simulado",
        subtitulo: formatTransactionDate(new Date()), // data/hora formatada
        valor,
        positivo: true,    // indica que é uma entrada (crédito), não débito
        fonte: "Externo",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Executa todas as operações do lote de uma vez.
    await batch.commit();

    return {
        success: true,
        valor,
    };
});


// ============================================================
// FUNÇÃO AUXILIAR: normalizeStage
// ============================================================
// O que faz: recebe um valor "bruto" (que pode ser string, número ou nulo)
// representando o estágio de uma startup, e retorna um valor padronizado
// em um dos três formatos aceitos: "nova", "emOperacao" ou "emExpansao".
//
// Por que é necessário?
// Dados vindos do Firestore podem ter sido salvos de formas diferentes
// por pessoas diferentes. Esta função unifica tudo.
// ============================================================
function normalizeStage(raw) {
    // Se vier null ou undefined, assume "nova".
    if (raw === null || raw === undefined)
        return "nova";

    if (typeof raw === "string") {
        const normalized = raw
            .trim()                          // remove espaços no início/fim
            .toLowerCase()                   // torna tudo minúsculo
            .normalize("NFD")                // separa letras de acentos (ex: "á" → "a" + acento)
            .replace(/[\u0300-\u036f]/g, ""); // remove os acentos isolados
        // Agora "normalized" é algo como "emoperacao", "nova", "emexpansao"

        if (normalized === "nova") return "nova";
        if (normalized === "emoperacao" || normalized === "em-operacao") return "emOperacao";
        if (normalized === "emexpansao" || normalized === "em-expansao") return "emExpansao";

        // Se contém a palavra parcialmente (ex: "nova startup"):
        if (normalized.includes("nova")) return "nova";
        if (normalized.includes("operacao")) return "emOperacao";
        if (normalized.includes("expansao")) return "emExpansao";
    }

    // Se for número:
    if (typeof raw === "number") {
        if (raw === 0) return "nova";
        if (raw === 1) return "emOperacao";
        if (raw === 2) return "emExpansao";
    }

    // Qualquer outro caso não reconhecido → "nova"
    return "nova";
}


// ============================================================
// FUNÇÃO AUXILIAR: stageLabel
// ============================================================
// O que faz: converte o estágio normalizado em um texto legível
// para mostrar na interface do usuário (UI).
// Exemplo: "emOperacao" → "Em operação"
// ============================================================
function stageLabel(raw) {
    const stage = normalizeStage(raw); // primeiro normaliza
    switch (stage) {
        case "emOperacao":  return "Em operação";
        case "emExpansao":  return "Em expansão";
        case "nova":
        default:            return "Nova";
    }
}


// ============================================================
// FUNÇÃO AUXILIAR: toNumber
// ============================================================
// O que faz: tenta converter qualquer valor (string ou número)
// para um número JavaScript válido e finito.
// Retorna null se a conversão falhar.
//
// Exemplo: "1.500,75" → remove pontos e troca vírgula por ponto → 1500.75
// ============================================================
function toNumber(raw) {
    // Se já é número finito, retorna direto.
    if (typeof raw === "number" && Number.isFinite(raw))
        return raw;

    if (typeof raw === "string") {
        const cleaned = raw
            .replace(/\s/g, "")   // remove espaços
            .replace(/\./g, "")   // remove pontos de milhar (ex: "1.500" → "1500")
            .replace(",", ".");    // troca vírgula decimal por ponto (padrão JS)
        const parsed = Number(cleaned);
        return Number.isFinite(parsed) ? parsed : null;
    }

    return null; // tipo não suportado
}


// ============================================================
// FUNÇÃO AUXILIAR: formatCompactNumberBR
// ============================================================
// O que faz: formata números grandes de forma curta.
// Exemplos:
//   1500000 → "1M" (um milhão)
//   3500    → "3k" (três mil, "k" = kilo)
//   450     → "450"
// ============================================================
function formatCompactNumberBR(value) {
    const abs = Math.abs(value); // valor absoluto (ignora sinal negativo para comparar)
    if (abs >= 1000000) return `${Math.round(value / 1000000)}M`;
    if (abs >= 1000)    return `${Math.round(value / 1000)}k`;
    return `${Math.round(value)}`;
}


// ============================================================
// FUNÇÃO AUXILIAR: formatCapital
// ============================================================
// O que faz: formata um valor monetário em Real Brasileiro de forma compacta.
// Exemplo: 2500000 → "R$ 2M"
// ============================================================
function formatCapital(value) {
    return `R$ ${formatCompactNumberBR(value)}`;
}


// ============================================================
// FUNÇÃO AUXILIAR: formatTokens
// ============================================================
// O que faz: formata a quantidade de tokens de forma compacta.
// Usa a mesma lógica de absRoundToCompact (inclui bilhões).
// Exemplo: 1200000000 → "1B"
// ============================================================
function formatTokens(value) {
    return absRoundToCompact(value);
}


// ============================================================
// FUNÇÃO AUXILIAR: absRoundToCompact
// ============================================================
// Similar a formatCompactNumberBR, mas também suporta bilhões (B).
// Exemplos:
//   5000000000 → "5B"
//   2000000    → "2M"
//   1500       → "1k" (arredondado de 1500 para 1000 = 2k? não: Math.round(1500/1000) = 2... na verdade "2k")
//   800        → "800"
// ============================================================
function absRoundToCompact(value) {
    const abs = Math.abs(value);
    if (abs >= 1000000000) return `${Math.round(value / 1000000000)}B`;
    if (abs >= 1000000)    return `${Math.round(value / 1000000)}M`;
    if (abs >= 1000)       return `${Math.round(value / 1000)}k`;
    return `${Math.round(value)}`;
}


// ============================================================
// FUNÇÃO AUXILIAR: formatPrecoBRL
// ============================================================
// O que faz: formata um número como preço em Reais com 2 casas decimais,
// usando vírgula como separador decimal (padrão brasileiro).
// Exemplo: 25.5 → "R$ 25,50"
// ============================================================
function formatPrecoBRL(value) {
    const fixed = value.toFixed(2);       // ex: "25.50"
    const withComma = fixed.replace(".", ","); // ex: "25,50"
    return `R$ ${withComma}`;             // ex: "R$ 25,50"
}


// ============================================================
// FUNÇÃO: listarStartups
// ============================================================
// O que faz: busca todas as startups cadastradas no Firestore e
// retorna uma lista formatada com nome, descrição, status e
// dados financeiros (capital, tokens, preço do token).
//
// É chamada pelo app para montar o catálogo/listagem de startups.
// ============================================================
exports.listarStartups = functions
    .region('southamerica-east1')
    .https.onCall(async (_data, _context) => {
    // Nomes de coleção possíveis (diferentes pessoas podem ter criado com nomes diferentes).
    // Tenta cada uma até encontrar uma que tenha documentos.
    const collectionsToTry = ["startups", "Startups", "startup"];
    let snapshot = null;

    for (const collectionName of collectionsToTry) {
        const snap = await db.collection(collectionName).get();
        if (!snap.empty) {   // .empty → true se não tiver nenhum documento
            snapshot = snap;
            break; // encontrou dados, para o loop
        }
    }

    // Se nenhuma coleção tiver dados, "docs" será um array vazio.
    const docs = snapshot?.docs ?? [];

    // Para cada documento (startup), monta um objeto formatado.
    // Promise.all() → executa todas as operações em paralelo (mais rápido que uma por uma).
    const startups = await Promise.all(docs.map(async (doc) => {
        const data = doc.data(); // lê os campos do documento

        // Nome da startup (garante que é string; se não, usa string vazia).
        const nome = typeof data.nome === "string" ? data.nome : "";

        // Descrição: tenta "descricao", depois "bio", depois string vazia.
        const descricao = typeof data.descricao === "string"
            ? data.descricao
            : typeof data.bio === "string" ? data.bio : "";

        // Estágio de desenvolvimento: tenta vários nomes de campo possíveis.
        // O operador "??" retorna o primeiro valor que NÃO seja null/undefined.
        const estagio = data.estagioDesenvolvimento ?? data.estagio ?? data.stage ?? data.status;
        const status = stageLabel(estagio); // converte para texto legível

        // Dados do "balcão" (sistema de negociação dos tokens da startup).
        // Podem estar salvos como subcampo do documento OU em subcoleções separadas.
        const balcao = (typeof data.balcao === 'object' && data.balcao !== null)
            ? data.balcao : {};

        // Configuração e estado embutidos no documento principal (se existirem).
        const embCfg = (typeof balcao.config === 'object' && balcao.config !== null)
            ? balcao.config : {};
        const embSt = (typeof balcao.state === 'object' && balcao.state !== null)
            ? balcao.state : {};

        // Tenta buscar config e state também nas subcoleções "balcao/config" e "balcao/state".
        // Busca as duas em paralelo para economizar tempo.
        const [cfgSnap, stSnap] = await Promise.all([
            doc.ref.collection("balcao").doc("config").get(),
            doc.ref.collection("balcao").doc("state").get(),
        ]);

        // Prefere os dados da subcoleção; se não existir, usa os embutidos no doc principal.
        const balcaoCfg = (cfgSnap.exists ? cfgSnap.data() : embCfg);
        const balcaoSt  = (stSnap.exists  ? stSnap.data()  : embSt);

        // Total de tokens emitidos pela startup.
        const totalTokens = toNumber(balcaoCfg.tokens_emitidos) ?? 0;

        // Capital total já aportado (investido) pelos usuários.
        const cptAportado = toNumber(balcaoSt.cptAportado) ?? 0;

        // Preço do token: tenta usar o último preço negociado.
        // Se não existir ou for inválido, usa o preço de emissão original.
        let preco = toNumber(balcaoSt.last_price) ?? 0;
        if (!Number.isFinite(preco) || preco <= 0)
            preco = toNumber(balcaoCfg.preco_emissao) ?? 0;

        // Retorna o objeto formatado para essa startup.
        return {
            uid: doc.id,                   // ID único do documento no Firestore
            nome,
            descricao,
            status,
            tokens: formatTokens(totalTokens),  // ex: "500k"
            capital: formatCapital(cptAportado), // ex: "R$ 2M"
            preco: formatPrecoBRL(preco),        // ex: "R$ 25,00"
        };
    }));

    return { startups }; // retorna a lista para o app
});


// ============================================================
// FUNÇÃO AUXILIAR: validarCpfDisponivel
// ============================================================
// O que faz: verifica no Firestore se outro usuário já está
// cadastrado com o mesmo CPF. Se sim, lança um erro.
//
// Por que verificar isso?
// CPF é único por pessoa, então dois usuários diferentes
// não podem compartilhar o mesmo CPF.
// ============================================================
async function validarCpfDisponivel(cpf, userId) {
    // Busca documentos onde o campo "cpf" é igual ao CPF recebido.
    // .limit(1) → para na primeira ocorrência (otimização: não precisa buscar todos).
    const snapshot = await usuariosCollection
        .where("cpf", "==", cpf)
        .limit(1)
        .get();

    // Se encontrou um documento E não é o próprio usuário atual:
    if (!snapshot.empty && snapshot.docs[0]?.id !== userId) {
        throw new functions.https.HttpsError(
            "already-exists",
            "Ja existe um usuario cadastrado com este CPF."
        );
    }
    // Se não encontrou nada, ou encontrou o próprio usuário (re-cadastro): tudo OK.
}


// ============================================================
// FUNÇÃO AUXILIAR: normalizarPayload
// ============================================================
// O que faz: recebe os dados brutos enviados pelo app e os
// sanitiza (limpa, valida e formata) antes de salvar no banco.
// Retorna um objeto limpo e padronizado.
// ============================================================
function normalizarPayload(data, emailAutenticado) {
    // sanitizeDigits → remove tudo que não for dígito (ex: "123.456.789-09" → "12345678909")
    const cpf = sanitizeDigits(data.cpf, "CPF");

    // sanitizeRequiredString → garante que é uma string não vazia
    const fullName = sanitizeRequiredString(data.fullName, "Nome completo");

    const telefone = sanitizeDigits(data.telefone, "Telefone");

    // sanitizeEmail → valida formato e converte para minúsculo
    // Se não vier e-mail nos dados, usa o e-mail do token de autenticação.
    const email = sanitizeEmail(data.email ?? emailAutenticado);

    // sanitizeBirthDate → converte a string de data para Timestamp do Firestore
    const dataNascimento = sanitizeBirthDate(data.dataNascimento);

    // Se não vier "userActive", assume true (ativo por padrão).
    const userActive = data.userActive === undefined ? true : Boolean(data.userActive);

    // Validações de negócio:
    if (cpf.length !== 11) {
        // CPF brasileiro tem sempre 11 dígitos.
        throw new functions.https.HttpsError("invalid-argument", "CPF invalido.");
    }
    if (telefone.length < 10 || telefone.length > 11) {
        // Telefone brasileiro: 10 dígitos (fixo) ou 11 (celular com 9 na frente).
        throw new functions.https.HttpsError("invalid-argument", "Telefone invalido.");
    }

    // Garante que o e-mail enviado no formulário seja igual ao do token de autenticação.
    // Isso impede que o usuário tente cadastrar com um e-mail diferente do que ele usa para logar.
    if (
        typeof emailAutenticado === "string" &&
        emailAutenticado.trim().toLowerCase() !== email
    ) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "O e-mail autenticado difere do payload enviado."
        );
    }

    // Retorna os dados validados e limpos.
    return {
        cpf,
        fullName,
        dataNascimento,
        email,
        telefone,
        userActive,
    };
}


// ============================================================
// FUNÇÃO AUXILIAR: sanitizeRequiredString
// ============================================================
// O que faz: garante que um campo é uma string não vazia.
// Lança erro se for de outro tipo ou estiver vazio.
// ============================================================
function sanitizeRequiredString(value, fieldName) {
    if (typeof value != "string") {
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} obrigatorio.`);
    }
    const normalized = value.trim(); // remove espaços nas bordas
    if (!normalized) {
        // String só com espaços também é inválida.
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} obrigatorio.`);
    }
    return normalized;
}


// ============================================================
// FUNÇÃO AUXILIAR: sanitizeDigits
// ============================================================
// O que faz: valida que o valor é uma string não vazia,
// depois remove todos os caracteres que não são dígitos.
// Útil para CPF ("123.456.789-09" → "12345678909")
// e Telefone ("(11) 99999-9999" → "11999999999").
// ============================================================
function sanitizeDigits(value, fieldName) {
    const raw = sanitizeRequiredString(value, fieldName); // primeiro valida como string
    return raw.replace(/\D/g, ""); // \D = qualquer coisa que NÃO seja dígito
}


// ============================================================
// FUNÇÃO AUXILIAR: sanitizeEmail
// ============================================================
// O que faz: valida que o e-mail tem formato válido (contém "@" e ".").
// Converte para minúsculo antes de salvar.
// ============================================================
function sanitizeEmail(value) {
    const email = sanitizeRequiredString(value, "E-mail").toLowerCase();

    // Regex = expressão regular (padrão de texto para validação).
    // Este padrão verifica: "alguma coisa @ alguma coisa . alguma coisa"
    // ^ = início da string
    // [^\s@]+ = um ou mais caracteres que não sejam espaço ou @
    // $ = fim da string
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailPattern.test(email)) {
        throw new functions.https.HttpsError("invalid-argument", "E-mail invalido.");
    }
    return email;
}


// ============================================================
// FUNÇÃO AUXILIAR: sanitizeBirthDate
// ============================================================
// O que faz: converte uma string de data (ex: "1990-05-15") para
// um objeto Timestamp do Firestore (formato que o banco entende).
// Rejeita datas inválidas e datas no futuro (impossível nascer no futuro).
// ============================================================
function sanitizeBirthDate(value) {
    const raw = sanitizeRequiredString(value, "Data de nascimento");

    // new Date(raw) → tenta criar um objeto Date a partir da string.
    const parsedDate = new Date(raw);

    // isNaN(parsedDate.getTime()) → se a data for inválida (ex: "abc"),
    // getTime() retorna NaN (Not a Number).
    // parsedDate > new Date() → data no futuro é inválida.
    if (Number.isNaN(parsedDate.getTime()) || parsedDate > new Date()) {
        throw new functions.https.HttpsError("invalid-argument", "Data de nascimento invalida.");
    }

    // Converte para o tipo Timestamp do Firestore.
    return admin.firestore.Timestamp.fromDate(parsedDate);
}


// ============================================================
// FUNÇÃO AUXILIAR: sanitizePositiveNumber
// ============================================================
// O que faz: valida que um valor é um número positivo e finito.
// Lança erro se for zero, negativo, infinito ou não-numérico.
// ============================================================
function sanitizePositiveNumber(value, fieldName) {
    if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} invalido.`);
    }
    return value;
}


// ============================================================
// FUNÇÃO AUXILIAR: formatTransactionDate
// ============================================================
// O que faz: formata um objeto Date em uma string legível no estilo
// brasileiro para usar como subtítulo de transação.
// Exemplo: new Date("2025-06-15T14:30:00") → "15 jun 2025 - 14:30"
// ============================================================
function formatTransactionDate(data) {
    // Array de meses em português abreviado. Índice 0 é vazio porque
    // getMonth() retorna 0 para janeiro, então usamos [mês + 1].
    const meses = ["", "jan", "fev", "mar", "abr", "mai", "jun",
                       "jul", "ago", "set", "out", "nov", "dez"];

    // padStart(2, "0") → garante 2 dígitos, ex: "9" → "09"
    const hora   = data.getHours().toString().padStart(2, "0");
    const minuto = data.getMinutes().toString().padStart(2, "0");

    // Monta a string final: "dia mês ano - hora:minuto"
    return `${data.getDate()} ${meses[data.getMonth() + 1]} ${data.getFullYear()} - ${hora}:${minuto}`;
}