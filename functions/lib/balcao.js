"use strict";
// ============================================================
// ARQUIVO: balcao.js
//
// O que é esse arquivo?
// É o coração financeiro da plataforma. Implementa um
// "balcão de negociações" — um mini mercado de ações onde
// usuários podem comprar e vender TOKENS de startups,
// parecido com uma bolsa de valores simplificada.
//
// Conceitos importantes para entender este arquivo:
//
// TOKEN → representação digital de uma fração de uma startup.
//         Comprar tokens = investir na startup.
//
// ORDEM → intenção de compra ou venda. Ex: "quero comprar
//         100 tokens pelo preço de R$ 10,00 cada".
//
// ORDEM LIMIT (limite) → você define o preço máximo que aceita
//         pagar (compra) ou mínimo que aceita receber (venda).
//         Fica esperando alguém aceitar seu preço.
//
// ORDEM MARKET (mercado) → você aceita qualquer preço atual.
//         Executada imediatamente ao melhor preço disponível.
//
// ORDER BOOK (livro de ordens) → lista de todas as ordens
//         abertas de compra e venda. É o "painel" do mercado.
//
// MATCHING ENGINE → motor de casamento. Lógica que encontra
//         um comprador e um vendedor com preços compatíveis
//         e executa a negociação entre eles.
//
// TRADE → negociação concluída. Quando comprador e vendedor
//         concordaram no preço e a troca foi feita.
//
// LOCKUP → período de bloqueio. Tokens comprados ficam
//         travados por X dias e não podem ser vendidos antes.
//         Protege contra especulação imediata.
//
// BID → melhor preço de compra disponível no mercado.
// ASK → melhor preço de venda disponível no mercado.
// SPREAD → diferença entre ASK e BID. Ex: BID=9, ASK=11, spread=2.
// ============================================================


// ------------------------------------------------------------
// BOILERPLATE DO TYPESCRIPT (gerado automaticamente)
// Explicado em detalhes no arquivo index.comentado.js.
// Resumo: garante compatibilidade entre módulos.
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

// Declara antecipadamente as 4 funções que serão exportadas.
// Começa como "void 0" (undefined) e é preenchido mais abaixo.
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTrades = exports.getOrderbook = exports.ordersCancel = exports.ordersCreate = void 0;

// firebase-admin → SDK do servidor com acesso total ao Firebase
const admin = __importStar(require("firebase-admin"));
// firebase-functions → permite criar Cloud Functions (funções de nuvem)
const functions = __importStar(require("firebase-functions/v1"));

// Atalho para o banco de dados Firestore
const db = admin.firestore();


// ============================================================
// SEÇÃO: HELPERS GENÉRICOS
// Pequenas funções utilitárias usadas em todo o arquivo.
// ============================================================

// ------------------------------------------------------------
// throwHttp
// O que faz: lança um erro padronizado do Firebase.
// É um atalho para não repetir "new functions.https.HttpsError"
// em todo o código.
//
// Parâmetros:
//   code → código do tipo de erro (ex: "unauthenticated",
//           "invalid-argument", "not-found")
//   msg  → mensagem legível descrevendo o problema
// ------------------------------------------------------------
function throwHttp(code, msg) {
    throw new functions.https.HttpsError(code, msg);
}

// ------------------------------------------------------------
// requireString
// O que faz: valida que um campo é uma string não vazia.
// Se não for, lança erro imediatamente (interrompe a função).
// Retorna a string sem espaços nas bordas (trim).
//
// Exemplo: requireString("  abc  ", "nome") → "abc"
//          requireString(123, "nome") → erro: "nome obrigatorio."
// ------------------------------------------------------------
function requireString(value, field) {
    if (typeof value !== "string" || !value.trim()) {
        throwHttp("invalid-argument", `${field} obrigatorio.`);
    }
    return value.trim();
}

// ------------------------------------------------------------
// requirePositiveInteger
// O que faz: valida que um campo é um número inteiro positivo.
// Rejeita: decimais (1.5), zero, negativos, strings, etc.
//
// Exemplo: requirePositiveInteger(100, "qty") → 100
//          requirePositiveInteger(0, "qty")   → erro
//          requirePositiveInteger(1.5, "qty") → erro
// ------------------------------------------------------------
function requirePositiveInteger(value, field) {
    if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
        throwHttp("invalid-argument", `${field} deve ser um inteiro positivo.`);
    }
    return value;
}


// ============================================================
// SEÇÃO: REFERÊNCIAS DO FIRESTORE
// Funções que retornam "endereços" de documentos/coleções
// no banco de dados. Centralizar aqui evita escrever o
// mesmo caminho repetidamente em todo o código.
// ============================================================

// Coleção de ordens de uma startup específica.
// Caminho: startups/{startupId}/orders
function startupOrdersRef(startupId) {
    return db.collection("startups").doc(startupId).collection("orders");
}

// Coleção de trades (negociações concluídas) de uma startup.
// Caminho: startups/{startupId}/trades
function startupTradesRef(startupId) {
    return db.collection("startups").doc(startupId).collection("trades");
}

// Coleção do balcão de uma startup (contém config e state).
// Caminho: startups/{startupId}/balcao
function startupBalcaoRef(startupId) {
    return db.collection("startups").doc(startupId).collection("balcao");
}

// Documento principal da carteira de um usuário.
// Caminho: usuarios/{uid}/wallet/main
// Contém: saldo_brl (saldo em reais), saldo_brl_reservado, etc.
function userWalletRef(uid) {
    return db.collection("usuarios").doc(uid).collection("wallet").doc("main");
}

// Documento da posição do usuário em uma startup específica.
// Caminho: usuarios/{uid}/positions/{startupId}
// Contém: tokens_livres, tokens_reservados, investidor_ativo
function userPositionRef(uid, startupId) {
    return db.collection("usuarios").doc(uid).collection("positions").doc(startupId);
}

// Documento com o histórico de compras de tokens do usuário em uma startup.
// Caminho: usuarios/{uid}/token_purchases/{startupId}
// Contém: lista de compras com data (usado para validar lockup de tempo).
function userPurchasesRef(uid, startupId) {
    return db.collection("usuarios").doc(uid).collection("token_purchases").doc(startupId);
}

// Documento de histórico de uma ordem específica do usuário.
// Caminho: usuarios/{uid}/order_history/{orderId}
// Contém: resumo da ordem e histórico de mudanças de status.
function userOrderHistoryRef(uid, orderId) {
    return db.collection("usuarios").doc(uid).collection("order_history").doc(orderId);
}


// ============================================================
// SEÇÃO: LEITURA DE DADOS DO BALCÃO (com fallback)
//
// O balcão pode ter seus dados em dois lugares:
//   1. Subcoleção: startups/{id}/balcao/config  (preferido)
//   2. Campo embutido no documento da startup    (fallback/legado)
//
// As funções abaixo tentam o lugar 1 primeiro.
// Se não encontrar, tentam o lugar 2.
// Isso garante compatibilidade com dados mais antigos.
// ============================================================

// ------------------------------------------------------------
// readConfig
// O que faz: lê as configurações fixas do balcão de uma startup.
// Configurações raramente mudam (definidas pela startup).
//
// Campos retornados:
//   tokens_emitidos           → total de tokens que a startup criou
//   preco_emissao             → preço original de lançamento do token
//   lockup_quantidade_tipo    → "percentual" ou "absoluto"
//   lockup_quantidade_valor   → % ou quantidade mínima a ser vendida
//                               antes de permitir re-venda
//   lockup_dias_minimo        → dias mínimos que o token deve ficar
//                               com o comprador antes de poder vender
//   limite_preco_percentual   → variação máxima de preço permitida
//                               (ex: 0.1 = ±10% do último preço)
//   qty_maxima_por_ordem      → limite de tokens por ordem
//   max_ordens_abertas_por_usuario → limite de ordens simultâneas
// ------------------------------------------------------------
async function readConfig(startupId) {
    // Tenta ler da subcoleção (lugar preferido)
    const subSnap = await startupBalcaoRef(startupId).doc("config").get();
    if (subSnap.exists)
        return subSnap.data(); // encontrou, retorna direto

    // Fallback: lê do documento principal da startup
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    const data = startupSnap.data();

    // data.balcao?.config → acessa "balcao" e depois "config" com segurança
    // ?? {} → se não existir, usa objeto vazio
    const cfg = (data.balcao?.config ?? {});

    // Retorna os campos com valores padrão caso não existam (?? = "ou, se não tiver")
    return {
        tokens_emitidos: cfg.tokens_emitidos ?? 0,
        preco_emissao: cfg.preco_emissao ?? 0,
        lockup_quantidade_tipo: cfg.lockup_quantidade_tipo ?? "percentual",
        lockup_quantidade_valor: cfg.lockup_quantidade_valor ?? 0.5, // 50% padrão
        lockup_dias_minimo: cfg.lockup_dias_minimo ?? 30,            // 30 dias padrão
        limite_preco_percentual: cfg.limite_preco_percentual ?? null, // null = sem limite
        qty_maxima_por_ordem: cfg.qty_maxima_por_ordem ?? 100000,
        max_ordens_abertas_por_usuario: cfg.max_ordens_abertas_por_usuario ?? 100,
    };
}

// ------------------------------------------------------------
// readState
// O que faz: lê o estado atual (dinâmico) do balcão.
// Diferente da config, o state muda a cada negociação.
//
// Campos retornados:
//   last_price                 → preço do último trade executado
//   tokens_vendidos_startup    → total de tokens já vendidos pela startup
//   tokens_disponiveis_startup → tokens ainda disponíveis para venda
//   best_bid                   → melhor preço de compra no livro
//   best_ask                   → melhor preço de venda no livro
//   spread                     → diferença entre best_ask e best_bid
//   total_trades               → total de negociações já realizadas
// ------------------------------------------------------------
async function readState(startupId) {
    const subSnap = await startupBalcaoRef(startupId).doc("state").get();
    if (subSnap.exists)
        return subSnap.data();

    // Fallback para dados embutidos
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    const data = startupSnap.data();
    const s = (data.balcao?.state ?? {});

    return {
        last_price: s.last_price ?? null,
        tokens_vendidos_startup: s.tokens_vendidos_startup ?? 0,
        tokens_disponiveis_startup: s.tokens_disponiveis_startup ?? 0,
        best_bid: null,   // recalculado dinamicamente, não lido do fallback
        best_ask: null,
        spread: null,
        total_trades: s.total_trades ?? 0,
    };
}

// ------------------------------------------------------------
// readStateInTx
// O que faz: mesma coisa que readState, MAS feita DENTRO de
// uma transação do Firestore.
//
// Por que precisa ser diferente?
// Dentro de uma transação, todas as leituras devem usar
// "t.get()" (o objeto da transação), não "await ref.get()" direto.
// Isso garante que o Firestore "trava" os dados lidos e evita
// que outra operação simultânea altere os dados no meio do caminho.
//
// Retorna também "stateRef" (a referência do documento),
// para que a transação possa atualizar o mesmo documento depois.
// ------------------------------------------------------------
async function readStateInTx(t, startupId) {
    const stateRef = startupBalcaoRef(startupId).doc("state");
    const stateSnap = await t.get(stateRef); // leitura dentro da transação

    if (stateSnap.exists)
        return { state: stateSnap.data(), stateRef };

    // Fallback: lê do documento da startup (também dentro da transação)
    const startupRef = db.collection("startups").doc(startupId);
    const startupSnap = await t.get(startupRef);
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    const data = startupSnap.data();
    const s = (data.balcao?.state ?? {});
    const state = {
        last_price: s.last_price ?? null,
        tokens_vendidos_startup: s.tokens_vendidos_startup ?? 0,
        tokens_disponiveis_startup: s.tokens_disponiveis_startup ?? 0,
        best_bid: null,
        best_ask: null,
        spread: null,
        total_trades: s.total_trades ?? 0,
    };

    return { state, stateRef };
}


// ============================================================
// SEÇÃO: VALIDAÇÕES DE LOCKUP
//
// Lockup = "período de bloqueio". Protege a startup de
// investidores que compram tokens só para revender rápido.
// Existem dois tipos de lockup:
//   1. Lockup de Quantidade → exige que a startup tenha vendido
//      uma quantidade mínima de tokens antes de permitir re-venda
//   2. Lockup de Tempo → exige que o investidor segure seus
//      tokens por X dias antes de poder vender
// ============================================================

// ------------------------------------------------------------
// validateLockupQuantidade
// O que faz: verifica se a startup já vendeu tokens suficientes
// para "desbloquear" o mercado secundário (re-venda entre usuários).
//
// Exemplo prático:
//   Startup emitiu 1.000 tokens.
//   lockup_quantidade_valor = 0.5 (50%)
//   Só permite re-venda quando pelo menos 500 tokens tiverem
//   sido vendidos pela startup para investidores.
//
// Dois modos:
//   "percentual" → trava até vender X% do total
//   "absoluto"   → trava até vender X tokens (número fixo)
// ------------------------------------------------------------
function validateLockupQuantidade(config, state) {
    const { lockup_quantidade_tipo, lockup_quantidade_valor, tokens_emitidos } = config;
    const { tokens_vendidos_startup } = state;

    if (lockup_quantidade_tipo === "percentual") {
        // Calcula a porcentagem já vendida
        // Evita divisão por zero com o "tokens_emitidos > 0 ? ... : 0"
        const pct = tokens_emitidos > 0 ? tokens_vendidos_startup / tokens_emitidos : 0;

        if (pct < lockup_quantidade_valor) {
            // Calcula quantos tokens ainda faltam para desbloquear
            //Math ceil -> arredonda para cima
            const needed = Math.ceil(lockup_quantidade_valor * tokens_emitidos - tokens_vendidos_startup);

            // Lança erro com JSON detalhado para o app poder mostrar mensagem útil
            throwHttp("failed-precondition", JSON.stringify({
                code: "LOCKUP_QUANTITY_VIOLATION",
                lockup_type: "percentual",
                tokens_sold_percentage: Math.round(pct * 100),           // ex: 35 (35%)
                required_percentage: Math.round(lockup_quantidade_valor * 100), // ex: 50 (50%)
                tokens_needed_to_unlock: needed,                          // ex: 150
            }));
        }
    } else {
        // Modo absoluto: compara direto com o número de tokens vendidos
        if (tokens_vendidos_startup < lockup_quantidade_valor) {
            throwHttp("failed-precondition", JSON.stringify({
                code: "LOCKUP_QUANTITY_VIOLATION",
                lockup_type: "absoluto",
                tokens_sold: tokens_vendidos_startup,
                required_tokens: lockup_quantidade_valor,
                tokens_needed_to_unlock: lockup_quantidade_valor - tokens_vendidos_startup,
            }));
        }
    }
}

// ------------------------------------------------------------
// validateLockupTempo
// O que faz: verifica se os tokens que o usuário quer vender
// já passaram pelo período mínimo de lockup (ex: 30 dias).
//
// Como funciona:
// Cada vez que o usuário compra tokens, salva-se uma "entrada"
// com a data da compra (acquired_at). Esta função percorre
// todas as entradas e verifica quais já "desbloquearam"
// (data_compra + dias_lockup <= hoje).
//
// Parâmetros:
//   uid          → ID do usuário
//   startupId    → ID da startup
//   qtyRequested → quantidade que o usuário quer vender
//   lockupDias   → dias mínimos de lockup (ex: 30)
// ------------------------------------------------------------
async function validateLockupTempo(uid, startupId, qtyRequested, lockupDias) {
    // Busca o histórico de compras do usuário nessa startup
    const snap = await userPurchasesRef(uid, startupId).get();

    if (!snap.exists) {
        // Se não há histórico de compras, não tem nada disponível para vender
        throwHttp("failed-precondition", JSON.stringify({
            code: "LOCKUP_TIME_VIOLATION",
            available_to_sell: 0,
            locked_qty: 0,
        }));
    }

    // "entries" → array de compras. Ex: [{qty: 100, acquired_at: Timestamp}, ...]
    const entries = snap.data()?.entries ?? [];

    const now = Date.now(); // momento atual em milissegundos
    const lockupMs = lockupDias * 86400000;
    // 86400000 = 24h * 60min * 60s * 1000ms = 1 dia em milissegundos

    let available = 0; // tokens desbloqueados (podem ser vendidos)
    let locked = 0;    // tokens ainda no lockup
    const breakdown = []; // detalhes de cada lote bloqueado

    for (const entry of entries) {
        // Calcula o momento exato em que esse lote desbloqueia
        const unlockMs = entry.acquired_at.toMillis() + lockupMs;
        // .toMillis() converte Timestamp do Firestore para milissegundos

        if (now >= unlockMs) {
            // Já passou o período de lockup → disponível para venda
            available += entry.qty;
        } else {
            // Ainda no lockup
            locked += entry.qty;
            breakdown.push({
                qty: entry.qty,
                unlock_at: new Date(unlockMs).toISOString(), // data de desbloqueio em formato legível
                days_remaining: Math.ceil((unlockMs - now) / 86400000), // dias restantes
            });
        }
    }

    if (available <= 0) {
        // Nenhum token disponível (todos ainda no lockup)
        throwHttp("failed-precondition", JSON.stringify({
            code: "LOCKUP_TIME_VIOLATION",
            locked_tokens_breakdown: breakdown, // mostra quando cada lote desbloqueia
            available_to_sell: 0,
        }));
    }

    if (available < qtyRequested) {
        // Tem alguns disponíveis, mas não o suficiente para a quantidade solicitada
        throwHttp("failed-precondition", JSON.stringify({
            code: "LOCKUP_PARTIAL_VIOLATION",
            available_to_sell: available,
            locked_qty: locked,
            requested_qty: qtyRequested,
        }));
    }

    // Se chegou aqui: o usuário tem tokens suficientes desbloqueados. Tudo OK.
}


// ============================================================
// FUNÇÃO: runMatchingEngine (Motor de Casamento)
//
// Esta é a função mais complexa do arquivo.
// O que faz: percorre as ordens abertas de compra e venda
// e "casa" (combina) pares compatíveis, gerando trades.
//
// Regras de casamento (quando uma compra "encontra" uma venda):
//   - Ordem market sempre casa (aceita qualquer preço)
//   - Ordem limit casa quando: preço_compra >= preço_venda
//
// Prioridade de execução:
//   - Ordens market têm prioridade máxima
//   - Depois, compras: maior preço primeiro (bid alto = mais agressivo)
//   - Depois, vendas: menor preço primeiro (ask baixo = mais agressivo)
//   - Em caso de empate de preço: a ordem mais antiga primeiro
//
// Determinação do preço do trade:
//   - Se compra é market: usa o preço da venda (limit)
//   - Se venda é market: usa o preço da compra (limit)
//   - Se ambas market: usa o último preço negociado
//   - Se ambas limit: usa o preço da venda (ask)
//     (convenção: o price-taker paga o preço do book)
//
// Parâmetros:
//   t            → objeto da transação do Firestore
//   startupId    → ID da startup
//   currentState → estado atual do balcão (último preço, etc.)
// ============================================================
async function runMatchingEngine(t, startupId, currentState) {
    const ordersRef = startupOrdersRef(startupId);

    // Busca todas as ordens abertas de compra (bids) e venda (asks) em paralelo
    const [bidsSnap, asksSnap] = await Promise.all([
        t.get(ordersRef
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "buy")),
        t.get(ordersRef
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "sell")),
    ]);

    // Converte os documentos do Firestore em objetos JS simples
    // e ordena por prioridade de execução:

    // BIDS (compras) → maior preço primeiro; market antes de limit
    const bids = bidsSnap.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => {
            // Ordens market têm prioridade máxima
            if (a.order_type === "market" && b.order_type !== "market") return -1; // a vem antes
            if (b.order_type === "market" && a.order_type !== "market") return 1;  // b vem antes
            // Entre limits: maior preço primeiro (b.price - a.price = decrescente)
            // Em caso de empate de preço: mais antiga primeiro (a - b = crescente por tempo)
            return b.price - a.price || a.created_at.toMillis() - b.created_at.toMillis();
        });

    // ASKS (vendas) → menor preço primeiro; market antes de limit
    const asks = asksSnap.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => {
            if (a.order_type === "market" && b.order_type !== "market") return -1;
            if (b.order_type === "market" && a.order_type !== "market") return 1;
            // Entre limits: menor preço primeiro (a.price - b.price = crescente)
            return a.price - b.price || a.created_at.toMillis() - b.created_at.toMillis();
        });

    // Estrutura que acumula os resultados do matching
    const result = {
        trades: [],              // lista de trades gerados
        orderUpdates: new Map(), // Map: orderId → campos atualizados
        // Map é como um objeto, mas aceita qualquer tipo como chave
        lastPrice: currentState.last_price,     // último preço (atualizado a cada trade)
        startupTokensSoldDelta: 0, // quantos tokens a STARTUP vendeu neste round
    };

    // Cria cópias mutáveis das ordens (não altera os originais durante o loop)
    const mBids = bids.map(o => ({ ...o }));
    const mAsks = asks.map(o => ({ ...o }));

    // Índices para percorrer as duas listas simultaneamente
    let bi = 0; // índice atual nos bids
    let ai = 0; // índice atual nos asks

    // Loop principal do matching: tenta casar o melhor bid com o melhor ask
    while (bi < mBids.length && ai < mAsks.length) {
        const bid = mBids[bi]; // melhor compra disponível
        const ask = mAsks[ai]; // melhor venda disponível

        // Pula ordens que já foram totalmente executadas neste round
        if (bid.qty_restante <= 0) { bi++; continue; }
        if (ask.qty_restante <= 0) { ai++; continue; }

        const bidIsMarket = bid.order_type === "market";
        const askIsMarket = ask.order_type === "market";

        // Verifica se há cruzamento (condição para executar o trade):
        // - Qualquer ordem market cruza automaticamente
        // - Limit cruza quando o preço de compra >= preço de venda
        const crosses = bidIsMarket || askIsMarket || bid.price >= ask.price;

        if (!crosses)
            break; // O melhor bid e o melhor ask não se encontram → nenhum outro par vai cruzar

        // Determina o preço do trade (quem é "tomador" paga o preço do "fazedor"):
        let tradePrice;
        if (bidIsMarket && !askIsMarket)
            tradePrice = ask.price;         // comprador aceita o preço da venda
        else if (askIsMarket && !bidIsMarket)
            tradePrice = bid.price;         // vendedor aceita o preço da compra
        else if (bidIsMarket && askIsMarket)
            tradePrice = currentState.last_price ?? ask.price; // ambos market: usa último preço
        else
            tradePrice = ask.price;         // ambos limit: usa o preço da venda (convenção)

        // Quantidade negociada: o menor entre o que o comprador quer e o que o vendedor tem
        const tradeQty = Math.min(bid.qty_restante, ask.qty_restante);

        const now = admin.firestore.Timestamp.now();

        // Gera um ID único para este trade usando o Firestore
        const tradeId = startupTradesRef(startupId).doc().id;

        // Registra o trade na lista de resultados
        result.trades.push({
            id: tradeId,
            buy_order_id: bid.id,
            sell_order_id: ask.id,
            buyer_id: bid.user_id,
            seller_id: ask.user_id,
            seller_type: ask.seller_type,    // "investor" ou "startup"
            price: tradePrice,
            qty: tradeQty,
            executed_at: now,
            spread_at_execution: currentState.spread, // spread no momento da execução
            impact_price: tradePrice,
        });

        // Atualiza as quantidades nas cópias locais das ordens
        bid.qty_executada += tradeQty;
        bid.qty_restante  -= tradeQty;
        ask.qty_executada += tradeQty;
        ask.qty_restante  -= tradeQty;

        // Define o novo status de cada ordem:
        // "executada" se qty_restante chegou a zero, senão "parcialmente_executada"
        const newBidStatus = bid.qty_restante === 0 ? "executada" : "parcialmente_executada";
        const newAskStatus = ask.qty_restante === 0 ? "executada" : "parcialmente_executada";

        // Guarda as atualizações das ordens no Map (serão escritas no Firestore depois)
        result.orderUpdates.set(bid.id, {
            qty_executada: bid.qty_executada,
            qty_restante:  bid.qty_restante,
            status:        newBidStatus,
            updated_at:    now,
        });
        result.orderUpdates.set(ask.id, {
            qty_executada: ask.qty_executada,
            qty_restante:  ask.qty_restante,
            status:        newAskStatus,
            updated_at:    now,
        });

        // Se a startup foi a vendedora, acumula os tokens que ela vendeu
        if (ask.seller_type === "startup")
            result.startupTokensSoldDelta += tradeQty;

        // Atualiza o último preço
        result.lastPrice = tradePrice;

        // Avança o ponteiro da ordem que foi totalmente executada
        if (bid.qty_restante === 0) bi++;
        if (ask.qty_restante === 0) ai++;
    }

    return result;
}


// ============================================================
// FUNÇÃO AUXILIAR: clearInvestidorAtivoIfEmpty
// O que faz: verifica se um investidor ficou sem tokens em uma
// startup e, se sim, marca seu perfil como investidor inativo
// (investidor_ativo = false).
//
// Por que isso importa?
// O campo investidor_ativo é usado para mostrar se o usuário
// ainda tem participação na startup. Se vendeu tudo, não é
// mais investidor ativo.
// ============================================================
async function clearInvestidorAtivoIfEmpty(uid, startupId) {
    const posRef = userPositionRef(uid, startupId);
    const snap = await posRef.get();
    const pos = (snap.data() ?? {});

    // Soma tokens livres (disponíveis) + tokens reservados (em ordens abertas)
    const total = (pos.tokens_livres ?? 0) + (pos.tokens_reservados ?? 0);

    if (total <= 0) {
        // Sem tokens: marca como inativo
        await posRef.set(
            { investidor_ativo: false, updated_at: admin.firestore.Timestamp.now() },
            { merge: true }
        );
    }
}


// ============================================================
// CLOUD FUNCTION: ordersCreate
// ============================================================
// O que faz: cria uma nova ordem de compra ou venda de tokens.
// É a função principal do balcão — o fluxo completo é:
//
//   1. Valida autenticação e parâmetros básicos
//   2. Valida regras de lockup (para vendas)
//   3. Verifica limite de ordens abertas
//   4. Verifica saldo (compra) ou tokens disponíveis (venda)
//   5. Verifica limite de variação de preço
//   6. Abre uma transação atômica no Firestore:
//      a. Re-verifica saldo/tokens dentro da transação
//      b. Insere a nova ordem
//      c. Reserva saldo (compra) ou tokens (venda)
//      d. Roda o matching engine
//      e. Processa os trades (transfere BRL e tokens)
//      f. Atualiza status das ordens casadas
//      g. Atualiza o estado do balcão
//   7. Salva histórico da ordem
//   8. Atualiza best_bid/best_ask de forma assíncrona
// ============================================================
exports.ordersCreate = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {

    // ── 1. Autenticação e validação dos parâmetros ──────────────

    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");

    const startupId = requireString(data.startup_id, "startup_id");
    const side      = requireString(data.side, "side");       // "buy" ou "sell"
    const orderType = requireString(data.order_type, "order_type"); // "market" ou "limit"
    const qty       = requirePositiveInteger(data.qty, "qty");

    // Valida valores aceitos para "side"
    if (side !== "buy" && side !== "sell")
        throwHttp("invalid-argument", "side deve ser 'buy' ou 'sell'.");

    // Valida valores aceitos para "order_type"
    if (orderType !== "market" && orderType !== "limit")
        throwHttp("invalid-argument", "order_type deve ser 'market' ou 'limit'.");

    // Limite absoluto de segurança (1 milhão de tokens por ordem)
    if (qty > 1000000)
        throwHttp("invalid-argument", "Quantidade excede o limite de 1.000.000.");

    // Para ordens limit, o preço é obrigatório e deve ser positivo
    let limitPrice = 0;
    if (orderType === "limit") {
        if (typeof data.price !== "number" || data.price <= 0) {
            throwHttp("invalid-argument", "price obrigatorio e deve ser positivo para limit order.");
        }
        limitPrice = data.price;
    }

    // Verifica se a startup existe
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    // Carrega configuração e estado do balcão em paralelo
    const [config, state] = await Promise.all([
        readConfig(startupId),
        readState(startupId),
    ]);

    // Verifica limite de quantidade configurado pela startup
    if (qty > config.qty_maxima_por_ordem) {
        throwHttp("invalid-argument", `Quantidade excede o máximo de ${config.qty_maxima_por_ordem} por ordem.`);
    }

    // ── 2. Validações de lockup (apenas para ordens de venda) ──

    if (side === "sell") {
        // Verifica lockup de quantidade (startup vendeu tokens suficientes?)
        validateLockupQuantidade(config, state);

        // Verifica lockup de tempo (o usuário tem tokens desbloqueados suficientes?)
        await validateLockupTempo(uid, startupId, qty, config.lockup_dias_minimo);
    }

    // ── 3. Limite de ordens abertas por usuário ─────────────────

    const openOrdersSnap = await startupOrdersRef(startupId)
        .where("user_id", "==", uid)
        .where("status", "in", ["aberta", "parcialmente_executada"])
        .get();

    if (openOrdersSnap.size >= config.max_ordens_abertas_por_usuario) {
        throwHttp("resource-exhausted",
            `Limite de ${config.max_ordens_abertas_por_usuario} ordens abertas atingido.`
        );
    }

    // ── 4. Verificação prévia de saldo e tokens ──────────────────
    // (pré-validação fora da transação para resposta rápida;
    //  será re-validado dentro da transação para garantia)

    const [walletSnap, positionSnap] = await Promise.all([
        userWalletRef(uid).get(),
        userPositionRef(uid, startupId).get(),
    ]);

    const walletData   = (walletSnap.data() ?? {});
    const saldoBrl          = walletData.saldo_brl ?? 0;
    const saldoBrlReservado = walletData.saldo_brl_reservado ?? 0;
    // saldo disponível = saldo total - saldo já reservado em outras ordens abertas
    const saldoDisponivel   = saldoBrl - saldoBrlReservado;

    const positionData = (positionSnap.data() ?? {});
    const tokensLivres = positionData.tokens_livres ?? 0;

    // Para market orders, usa o preço de emissão como estimativa do custo
    const orderPrice    = orderType === "limit" ? limitPrice : config.preco_emissao;
    const estimatedCost = Number((orderPrice * qty).toFixed(2));
    // .toFixed(2) → arredonda para 2 casas decimais
    // Number(...) → converte string (resultado do toFixed) de volta para número

    // Verifica saldo para compra limit
    if (side === "buy" && orderType === "limit" && saldoDisponivel < estimatedCost) {
        throwHttp("failed-precondition", JSON.stringify({
            code: "INSUFFICIENT_BALANCE",
            available: saldoDisponivel,
            required: estimatedCost,
        }));
    }

    // Verifica tokens disponíveis para venda limit
    if (side === "sell" && orderType === "limit" && tokensLivres < qty) {
        throwHttp("failed-precondition", JSON.stringify({
            code: "INSUFFICIENT_TOKENS",
            tokens_livres: tokensLivres,
            requested: qty,
        }));
    }

    // ── 5. Proteção de preço (circuit breaker) ──────────────────
    // Se a startup configurou um limite de variação de preço,
    // rejeita ordens que desviem demais do último preço negociado.

    if (
        config.limite_preco_percentual !== null &&
        orderType === "limit" &&
        state.last_price !== null
    ) {
        const maxDev  = config.limite_preco_percentual;
        const maxPrice = state.last_price * (1 + maxDev); // teto (ex: +10%)
        const minPrice = state.last_price * (1 - maxDev); // piso (ex: -10%)

        if (limitPrice > maxPrice || limitPrice < minPrice) {
            throwHttp("invalid-argument", JSON.stringify({
                code: "PRICE_OUT_OF_RANGE",
                last_price: state.last_price,
                min_allowed: minPrice,
                max_allowed: maxPrice,
            }));
        }
    }

    // ── 6. Transação atômica ────────────────────────────────────
    // Tudo abaixo acontece "de uma vez" no banco de dados.
    // Se qualquer passo falhar, NADA é salvo. Isso evita
    // inconsistências como: ordem criada mas saldo não reservado.

    const now         = admin.firestore.Timestamp.now();
    const newOrderRef = startupOrdersRef(startupId).doc(); // gera ID único antecipadamente

    const newOrderData = {
        user_id:      uid,
        seller_type:  "investor",  // distingue do vendedor "startup"
        side,
        order_type:   orderType,
        price:        orderType === "limit" ? limitPrice : 0,
        // market orders não têm preço fixo (0 = será definido no matching)
        qty_original: qty,   // quantidade total solicitada
        qty_executada: 0,    // quantidade já executada (começa em zero)
        qty_restante:  qty,  // quantidade ainda em aberto
        status:        "aberta",
        version:       1,    // versão para controle de concorrência (incrementada a cada update)
        created_at:    now,
        updated_at:    now,
    };

    let executedTrades = []; // será preenchido dentro da transação

    await db.runTransaction(async (t) => {
        // t → objeto da transação. Todas as leituras e escritas aqui
        // são agrupadas e executadas atomicamente.

        // Relê o estado do balcão DENTRO da transação (dados mais frescos)
        const { state: txState, stateRef } = await readStateInTx(t, startupId);

        // Relê carteira e posição DENTRO da transação para garantia
        const txWalletSnap   = await t.get(userWalletRef(uid));
        const txPositionSnap = await t.get(userPositionRef(uid, startupId));
        const txWallet   = (txWalletSnap.data() ?? {});
        const txPosition = (txPositionSnap.data() ?? {});

        const txSaldoDisponivel = (txWallet.saldo_brl ?? 0) - (txWallet.saldo_brl_reservado ?? 0);
        const txTokensLivres    = txPosition.tokens_livres ?? 0;

        // Re-validação dentro da transação (dados podem ter mudado desde a pré-validação)
        if (side === "buy" && orderType === "limit" && txSaldoDisponivel < estimatedCost)
            throwHttp("failed-precondition", JSON.stringify({ code: "INSUFFICIENT_BALANCE" }));

        if (side === "sell" && orderType === "limit" && txTokensLivres < qty)
            throwHttp("failed-precondition", JSON.stringify({ code: "INSUFFICIENT_TOKENS" }));

        // Insere a nova ordem no Firestore
        t.set(newOrderRef, newOrderData);

        // Reserva saldo ou tokens para ordens limit
        // (market orders não reservam; são executadas imediatamente ou ignoradas)
        if (orderType === "limit") {
            if (side === "buy") {
                // Reserva o saldo em BRL para não ser usado em outra ordem
                t.set(userWalletRef(uid), {
                    saldo_brl_reservado: admin.firestore.FieldValue.increment(estimatedCost),
                    updated_at: now,
                }, { merge: true });
            } else {
                // Reserva os tokens para não serem vendidos em outra ordem
                t.set(userPositionRef(uid, startupId), {
                    tokens_reservados: admin.firestore.FieldValue.increment(qty),
                    tokens_livres:     admin.firestore.FieldValue.increment(-qty), // remove dos livres
                    updated_at: now,
                }, { merge: true });
            }
        }

        // Roda o motor de casamento (pode gerar zero ou vários trades)
        const matchResult = await runMatchingEngine(t, startupId, txState);
        executedTrades = matchResult.trades;

        // Processa cada trade gerado pelo matching engine
        for (const trade of matchResult.trades) {
            const tradeCost = Number((trade.price * trade.qty).toFixed(2));

            // Salva o registro do trade no banco
            t.set(startupTradesRef(startupId).doc(trade.id), trade);

            // ── COMPRADOR: paga BRL e recebe tokens ──

            // Desconta o custo do saldo (o "reservado" também vai a zero porque foi usado)
            t.set(userWalletRef(trade.buyer_id), {
                saldo_brl:          admin.firestore.FieldValue.increment(-tradeCost),
                saldo_brl_reservado: admin.firestore.FieldValue.increment(-tradeCost),
                updated_at: now,
            }, { merge: true });

            // Adiciona os tokens na posição do comprador e marca como investidor ativo
            t.set(userPositionRef(trade.buyer_id, startupId), {
                tokens_livres:   admin.firestore.FieldValue.increment(trade.qty),
                investidor_ativo: true,
                updated_at: now,
            }, { merge: true });

            // Registra a compra no histórico (necessário para validar lockup futuro)
            t.set(userPurchasesRef(trade.buyer_id, startupId), {
                qty_total: admin.firestore.FieldValue.increment(trade.qty),
                entries: admin.firestore.FieldValue.arrayUnion({
                    // arrayUnion → adiciona ao array sem duplicar
                    qty: trade.qty,
                    acquired_at: trade.executed_at,
                    source:   "buy_order",
                    order_id: trade.buy_order_id,
                }),
                updated_at: now,
            }, { merge: true });

            // ── VENDEDOR (apenas se for investidor, não startup): recebe BRL ──
            // Quando a startup vende, o dinheiro vai para outro lugar (fora do escopo aqui)
            if (trade.seller_type === "investor") {
                // Credita o BRL na carteira do vendedor
                t.set(userWalletRef(trade.seller_id), {
                    saldo_brl: admin.firestore.FieldValue.increment(tradeCost),
                    updated_at: now,
                }, { merge: true });

                // Libera os tokens reservados (foram vendidos, não estão mais na posição)
                t.set(userPositionRef(trade.seller_id, startupId), {
                    tokens_reservados: admin.firestore.FieldValue.increment(-trade.qty),
                    updated_at: now,
                }, { merge: true });
            }
        }

        // Atualiza o status de todas as ordens que foram (parcialmente) executadas
        // matchResult.orderUpdates é um Map: orderId → {qty_executada, qty_restante, status}
        for (const [orderId, updates] of matchResult.orderUpdates) {
            t.update(startupOrdersRef(startupId).doc(orderId), {
                ...updates, // espalha os campos de atualização
                version: admin.firestore.FieldValue.increment(1), // incrementa a versão
            });
        }

        // Calcula os novos totais de tokens vendidos pela startup
        const newTokensVendidos = txState.tokens_vendidos_startup + matchResult.startupTokensSoldDelta;
        const newLastPrice      = matchResult.lastPrice ?? txState.last_price;

        // Atualiza o estado do balcão com os novos dados
        t.set(stateRef, {
            last_price:                newLastPrice,
            tokens_vendidos_startup:   newTokensVendidos,
            tokens_disponiveis_startup: Math.max(0, config.tokens_emitidos - newTokensVendidos),
            // Math.max(0, ...) → garante que nunca fique negativo
            total_trades: admin.firestore.FieldValue.increment(matchResult.trades.length),
            updated_at: now,
        }, { merge: true });
    });
    // ── Fim da transação ────────────────────────────────────────

    // ── 7. Histórico da ordem (fora da transação, "best-effort") ──
    // "best-effort" = tenta, mas se falhar não é crítico
    await userOrderHistoryRef(uid, newOrderRef.id).set({
        startup_id: startupId,
        side,
        order_type: orderType,
        price:      orderType === "limit" ? limitPrice : config.preco_emissao,
        qty_original: qty,
        status_changes: [{ status: "aberta", at: now }],
        created_at: now,
    });

    // ── 8. Atualiza best_bid/best_ask de forma assíncrona ────────
    // .catch(() => undefined) → ignora erros silenciosamente
    // (não bloqueia a resposta ao usuário)
    updateBestPrices(startupId).catch(() => undefined);

    // ── 9. Verifica investidores que venderam tudo ───────────────
    // Coleta IDs únicos de investidores que venderam nesta rodada
    const investorSellerIds = [
        ...new Set( // Set = conjunto sem duplicatas; spread (...) converte de volta para array
            executedTrades
                .filter(tr => tr.seller_type === "investor")
                .map(tr => tr.seller_id)
        )
    ];

    if (investorSellerIds.length > 0) {
        // Para cada vendedor, verifica se ficou sem tokens (assíncrono, não bloqueia)
        Promise.all(investorSellerIds.map(sid => clearInvestidorAtivoIfEmpty(sid, startupId)))
            .catch(() => undefined);
    }

    // Retorna a ordem criada e os trades executados para o app
    return {
        success: true,
        order:  { id: newOrderRef.id, ...newOrderData },
        trades: executedTrades,
    };
});


// ============================================================
// CLOUD FUNCTION: ordersCancel
// ============================================================
// O que faz: cancela uma ordem aberta do usuário.
//
// Ao cancelar:
//   - Status da ordem vira "cancelada"
//   - Se era compra limit: devolve o saldo BRL reservado
//   - Se era venda limit: devolve os tokens reservados
//   - Atualiza best_bid/best_ask após o cancelamento
// ============================================================
exports.ordersCancel = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {

    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");

    const startupId = requireString(data.startup_id, "startup_id");
    const orderId   = requireString(data.order_id, "order_id");

    // Busca a ordem no banco
    const orderRef  = startupOrdersRef(startupId).doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists)
        throwHttp("not-found", "Ordem não encontrada.");

    const order = { id: orderId, ...orderSnap.data() };

    // Verifica se a ordem pertence ao usuário autenticado
    if (order.user_id !== uid)
        throwHttp("permission-denied", "Sem permissão para cancelar esta ordem.");

    // Não é possível cancelar ordens já finalizadas
    if (order.status === "executada" || order.status === "cancelada") {
        throwHttp("failed-precondition", "Ordem já executada ou cancelada.");
    }

    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (t) => {
        // Marca a ordem como cancelada e incrementa a versão
        t.update(orderRef, {
            status:     "cancelada",
            updated_at: now,
            version:    admin.firestore.FieldValue.increment(1),
        });

        // Devolve saldo reservado para ordens de COMPRA limit
        if (order.side === "buy" && order.order_type === "limit") {
            // Calcula quanto foi reservado para a quantidade RESTANTE
            // (a quantidade já executada já foi debitada, não precisa devolver)
            const refund = Number((order.price * order.qty_restante).toFixed(2));
            t.set(userWalletRef(uid), {
                saldo_brl_reservado: admin.firestore.FieldValue.increment(-refund),
                updated_at: now,
            }, { merge: true });
        }

        // Devolve tokens reservados para ordens de VENDA limit
        if (order.side === "sell" && order.order_type === "limit") {
            t.set(userPositionRef(uid, startupId), {
                tokens_reservados: admin.firestore.FieldValue.increment(-order.qty_restante),
                tokens_livres:     admin.firestore.FieldValue.increment(order.qty_restante),
                updated_at: now,
            }, { merge: true });
        }
    });

    // Registra o cancelamento no histórico da ordem
    await userOrderHistoryRef(uid, orderId).set({
        status_changes: admin.firestore.FieldValue.arrayUnion({ status: "cancelada", at: now }),
    }, { merge: true });

    // Atualiza best_bid/best_ask (assíncrono, não bloqueia a resposta)
    updateBestPrices(startupId).catch(() => undefined);

    return { success: true };
});


// ============================================================
// CLOUD FUNCTION: getOrderbook
// ============================================================
// O que faz: retorna o livro de ordens atual da startup.
// É o "painel do mercado" — mostra as ordens abertas de
// compra e venda para o usuário visualizar no app.
//
// Retorna:
//   buy_orders  → até 20 melhores ordens de compra (maior preço primeiro)
//   sell_orders → até 20 melhores ordens de venda (menor preço primeiro)
//   last_price  → preço do último trade
//   preco_emissao → preço original de lançamento
//   best_bid, best_ask, spread → resumo do mercado
//   tokens_vendidos_startup, tokens_emitidos → progresso da venda
// ============================================================
exports.getOrderbook = functions
    .region("southamerica-east1")
    .https.onCall(async (data, _context) => {
    // _context → convenção: underscore no início indica que o parâmetro existe
    // mas não é usado nesta função (autenticação não é exigida aqui)

    const startupId = requireString(data.startup_id, "startup_id");

    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    // Busca tudo em paralelo para economizar tempo
    const [openOrdersSnap, config, state] = await Promise.all([
        startupOrdersRef(startupId)
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .get(),
        readConfig(startupId),
        readState(startupId),
    ]);

    const orders = openOrdersSnap.docs.map(d => ({ id: d.id, ...d.data() }));

    // Filtra e ordena as ordens de compra: maior preço primeiro, mostra só as top 20
    const buyOrders = orders
        .filter(o => o.side === "buy")
        .sort((a, b) => b.price - a.price) // decrescente
        .slice(0, 20); // pega só as 20 primeiras

    // Filtra e ordena as ordens de venda: menor preço primeiro, mostra só as top 20
    const sellOrders = orders
        .filter(o => o.side === "sell")
        .sort((a, b) => a.price - b.price) // crescente
        .slice(0, 20);

    return {
        success: true,
        buy_orders:  buyOrders,
        sell_orders: sellOrders,
        last_price:  state.last_price,
        preco_emissao: config.preco_emissao,
        best_bid:    state.best_bid,
        best_ask:    state.best_ask,
        spread:      state.spread,
        tokens_vendidos_startup: state.tokens_vendidos_startup,
        tokens_emitidos:         config.tokens_emitidos,
    };
});


// ============================================================
// CLOUD FUNCTION: getTrades
// ============================================================
// O que faz: retorna o histórico de negociações (trades)
// já executados em uma startup, do mais recente para o mais antigo.
//
// Suporta paginação:
//   data.limit → quantos trades retornar (entre 1 e 50, padrão 20)
//   data.after → ID do último trade visto; retorna os próximos
//                (como um "próxima página")
// ============================================================
exports.getTrades = functions
    .region("southamerica-east1")
    .https.onCall(async (data, _context) => {

    const startupId = requireString(data.startup_id, "startup_id");

    // Limita o valor de "limit" entre 1 e 50; usa 20 como padrão
    // Math.min e Math.max garantem os limites
    const limitVal = typeof data.limit === "number"
        ? Math.min(Math.max(data.limit, 1), 50)
        : 20;

    // Monta a query: ordena por data de execução (mais recente primeiro) e limita a quantidade
    let query = startupTradesRef(startupId)
        .orderBy("executed_at", "desc")
        .limit(limitVal);

    // Se veio um "after" (ID do cursor de paginação), busca a partir dali
    if (typeof data.after === "string" && data.after) {
        const afterSnap = await startupTradesRef(startupId).doc(data.after).get();
        if (afterSnap.exists) {
            query = query.startAfter(afterSnap);
            // startAfter → paginação do Firestore: "começa DEPOIS deste documento"
        }
    }

    const snap = await query.get();

    return {
        success: true,
        trades: snap.docs.map(d => ({ id: d.id, ...d.data() })),
    };
});


// ============================================================
// FUNÇÃO INTERNA: updateBestPrices
// ============================================================
// O que faz: recalcula e salva os melhores preços de compra (best_bid)
// e venda (best_ask) do mercado, além do spread.
//
// É chamada de forma assíncrona (sem esperar) após criar ou
// cancelar ordens, para manter o estado do balcão atualizado.
//
// best_bid  → maior preço de compra aberto no livro
// best_ask  → menor preço de venda aberto no livro
// spread    → best_ask - best_bid (quanto custa "cruzar" o mercado)
//
// Por que é separado da transação principal?
// Calcular best_bid/best_ask exige queries extras que não precisam
// ser atômicas. Fazer isso fora da transação é mais eficiente.
// ============================================================
async function updateBestPrices(startupId) {
    // Busca o melhor bid e o melhor ask em paralelo
    const [bidsSnap, asksSnap] = await Promise.all([
        // Melhor bid = maior preço de compra aberta → orderBy desc, limit 1
        startupOrdersRef(startupId)
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "buy")
            .orderBy("price", "desc") // maior preço primeiro
            .limit(1)
            .get(),

        // Melhor ask = menor preço de venda aberta → orderBy asc, limit 1
        startupOrdersRef(startupId)
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "sell")
            .orderBy("price", "asc") // menor preço primeiro
            .limit(1)
            .get(),
    ]);

    // Se não houver nenhuma ordem do tipo, o valor é null
    const bestBid = bidsSnap.empty ? null : bidsSnap.docs[0].data().price;
    const bestAsk = asksSnap.empty ? null : asksSnap.docs[0].data().price;

    // Calcula o spread apenas se ambos existirem
    const spread = bestBid !== null && bestAsk !== null
        ? Number((bestAsk - bestBid).toFixed(2))
        : null;

    // Salva no estado do balcão
    await startupBalcaoRef(startupId).doc("state").set({
        best_bid:   bestBid,
        best_ask:   bestAsk,
        spread,
        updated_at: admin.firestore.Timestamp.now(),
    }, { merge: true });
}