// =============================================================================
// ARQUIVO: balcao_service.dart
// PROPÓSITO: Este arquivo é o "serviço de balcão" — ele é responsável por toda
// a comunicação entre o aplicativo Flutter e o banco de dados Firebase.
// Pense nele como um intermediário: a tela pede algo, e este serviço vai buscar
// ou enviar os dados no Firebase.
// =============================================================================

// "import" significa: "traga funcionalidades de outro arquivo/biblioteca"
// Abaixo estamos importando bibliotecas externas que o projeto usa:

import 'dart:convert'; // Biblioteca do Dart para converter JSON (texto) em Map (objeto) e vice-versa

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
// cloud_firestore: banco de dados em nuvem do Firebase (tipo de banco NoSQL em tempo real)
// "hide Order" significa: ignore a classe "Order" que vem desta biblioteca,
// porque temos nossa própria classe "Order" definida em outro arquivo.

import 'package:cloud_functions/cloud_functions.dart';
// cloud_functions: permite chamar funções backend hospedadas no Firebase
// (código que roda no servidor, não no celular do usuário)

import 'package:firebase_auth/firebase_auth.dart';
// firebase_auth: gerencia autenticação de usuários (login, logout, usuário atual)

import '../models/orderbook_models.dart';
// Importa os "modelos" do projeto — classes que representam os dados:
// Startup, Order, Trade, Wallet, etc. O "../" significa "pasta acima da atual".

// =============================================================================
// CLASSE PRINCIPAL: BalcaoService
// Uma "classe" em Dart é como uma planta de uma casa: define as propriedades
// e as ações disponíveis. Esta classe agrupa tudo relacionado ao balcão de negócios.
// =============================================================================
class BalcaoService {

  // ── PROPRIEDADES DA CLASSE (as "ferramentas" que o serviço usa) ──────────

  // "_db" é a instância do Firestore — a conexão com o banco de dados.
  // O "_" na frente indica que é privado: só esta classe pode usar.
  // "final" significa que depois de atribuído, o valor não muda mais.
  final _db = FirebaseFirestore.instance;

  // "_auth" é a instância de autenticação — usada para saber quem está logado.
  final _auth = FirebaseAuth.instance;

  // "_fn" é a instância para chamar Cloud Functions.
  // "instanceFor(region: ...)" especifica em qual região do mundo as funções estão hospedadas.
  // 'southamerica-east1' = São Paulo, Brasil (menor latência para usuários brasileiros).
  final _fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  // ── PROPRIEDADE COMPUTADA ────────────────────────────────────────────────

  // "String?" significa: uma String que pode ser nula (pode não ter valor).
  // "get _uid" é um "getter" — toda vez que alguém chamar "_uid", ele executa
  // o código abaixo e retorna o resultado.
  // "_auth.currentUser?.uid" usa "?." (safe call): se currentUser for nulo,
  // retorna nulo em vez de dar erro. Se não for nulo, retorna o ID do usuário.
  String? get _uid => _auth.currentUser?.uid;

  // ==========================================================================
  // SEÇÃO: STARTUPS
  // Métodos relacionados a buscar dados das startups cadastradas.
  // ==========================================================================

  // "Future<List<Startup>>" significa: esta função vai retornar uma Lista de
  // objetos Startup, mas de forma assíncrona (vai buscar na internet, então
  // precisamos esperar — por isso "Future", como uma "promessa" de que os dados vêm).
  // "async" marca a função como assíncrona.
  Future<List<Startup>> fetchStartups() async {
    // "await" = espere este resultado antes de continuar.
    // Estamos buscando TODOS os documentos da coleção 'startups' no Firestore.
    // No Firebase, dados ficam em "coleções" (como pastas) e "documentos" (como arquivos).
    final snap = await _db.collection('startups').get();

    // ".map()" transforma cada item de uma lista em outra coisa.
    // Aqui: para cada documento do banco, criamos um objeto Startup.
    // "(doc)" é cada documento individual.
    return snap.docs.map((doc) {
      // "doc.data()" retorna os dados do documento como um Map<String, dynamic>
      // Map é como um dicionário: {'chave': valor, 'outra_chave': outro_valor}
      final d = doc.data();

      // Aqui fazemos uma verificação de segurança:
      // Se d['balcao'] for um Map, usamos ele. Se não for (ou for nulo),
      // usamos um Map vazio "<String, dynamic>{}".
      // Isso evita erros quando o campo não existe no banco.
      final balcao = d['balcao'] is Map
          ? Map<String, dynamic>.from(d['balcao'] as Map)
          : <String, dynamic>{};

      // Mesma lógica: busca o sub-mapa 'config' dentro de 'balcao'
      final cfg = balcao['config'] is Map
          ? Map<String, dynamic>.from(balcao['config'] as Map)
          : <String, dynamic>{};

      // E o sub-mapa 'state' (estado atual do balcão)
      final st = balcao['state'] is Map
          ? Map<String, dynamic>.from(balcao['state'] as Map)
          : <String, dynamic>{};

      // Busca o nome da startup. "as String?" tenta converter para String.
      // Se der null, o operador "??" define um valor padrão: o ID do documento.
      final nome = (d['nome'] as String?) ?? doc.id;

      // Busca a sigla (ex: "ACME" para "Acme Tecnologia")
      final siglaRaw = d['sigla'] as String?;

      // Se a sigla existir e não estiver vazia, usa ela.
      // Caso contrário, gera uma sigla automaticamente a partir do nome:
      // remove espaços, pega os primeiros 4 caracteres, converte para maiúsculas.
      final sigla = (siglaRaw != null && siglaRaw.isNotEmpty)
          ? siglaRaw
          : nome
              .replaceAll(' ', '')       // Remove todos os espaços
              .substring(0, nome.replaceAll(' ', '').length.clamp(0, 4)) // Pega até 4 chars
              .toUpperCase();            // Converte para maiúsculas

      // Cria e retorna o objeto Startup com os dados extraídos.
      // "as num?" tenta converter para número. ".toDouble()" converte para decimal.
      // "??" define valor padrão caso seja nulo.
      return Startup(
        id: doc.id,
        nome: nome,
        sigla: sigla,
        precoEmissao: (cfg['preco_emissao'] as num?)?.toDouble() ?? 0,
        tokensEmitidos: (cfg['tokens_emitidos'] as num?)?.toInt() ?? 0,
        lastPrice: (st['last_price'] as num?)?.toDouble(), // Pode ser nulo (nullable)
      );
    }).toList(); // ".toList()" converte o resultado do .map() em uma List
  }

  // ==========================================================================
  // SEÇÃO: STREAMS (dados em tempo real)
  // "Stream" é como uma torneira de dados: fica aberta e envia novos dados
  // toda vez que algo muda no banco. Diferente de Future que busca uma vez só.
  // ==========================================================================

  // Retorna um Stream com as ordens de compra e venda abertas de uma startup.
  // O tipo de retorno "(List<Order> buys, List<Order> sells)" é um "Record" do Dart —
  // uma tupla que agrupa dois valores: lista de compras e lista de vendas.
  Stream<(List<Order> buys, List<Order> sells)> watchOrders(String startupId) {
    // Salva o uid do usuário atual para usar dentro do .map() abaixo.
    // (Dentro do .map() o "this" pode ter contexto diferente)
    final uid = _uid;

    // Monta a query no Firestore:
    // collection('startups') → coleção de startups
    // .doc(startupId)         → documento específico de uma startup
    // .collection('orders')   → sub-coleção de ordens desta startup
    // .where(...)             → filtra: só ordens com status aberta ou parcialmente executada
    // .snapshots()            → transforma em Stream (atualiza em tempo real)
    return _db
        .collection('startups')
        .doc(startupId)
        .collection('orders')
        .where('status', whereIn: ['aberta', 'parcialmente_executada'])
        .snapshots()
        .map((snap) {
          // Para cada nova lista de documentos recebida:
          final buys = <Order>[];   // Lista vazia para ordens de compra
          final sells = <Order>[];  // Lista vazia para ordens de venda

          for (final doc in snap.docs) {
            // Converte o documento em um objeto Order (usando método privado abaixo)
            //Transforma documento Firestore em objeto Dart.
            final o = _orderFromDoc(doc, uid);

            // Separa nas listas corretas conforme o lado da ordem
            if (o.side == 'buy') {
              buys.add(o);
            } else {
              sells.add(o);
            }
          }

          // Retorna as duas listas juntas como um Record (tupla)
          return (buys, sells);
        });
  }

  // Stream dos últimos trades (negócios realizados) de uma startup.
  Stream<List<Trade>> watchTrades(String startupId) {
    return _db
        .collection('startups')
        .doc(startupId)
        .collection('trades')
        .orderBy('executed_at', descending: true) // Mais recentes primeiro
        .limit(30)                                  // Máximo 30 trades
        .snapshots()
        // Converte cada documento em um objeto Trade usando o método _tradeFromDoc
        .map((snap) => snap.docs.map(_tradeFromDoc).toList());
  }

  // Stream com o estado atual do balcão: último preço, tokens vendidos, tokens emitidos.
  // O tipo de retorno usa um "Record nomeado" — como um objeto anônimo com campos nomeados.
  Stream<({double? lastPrice, int tokensVendidos, int tokensEmitidos})>
      watchBalcaoState(String startupId) {

    // Tenta ler o estado de uma sub-coleção separada ('balcao/state').
    // Se não existir, cai no fallback e lê do documento principal da startup.
    return _db
        .collection('startups')
        .doc(startupId)
        .collection('balcao')
        .doc('state')
        .snapshots()
        // "asyncMap" é como .map() mas permite operações assíncronas dentro
        .asyncMap((subSnap) async {
      if (subSnap.exists) {
        // Sub-coleção existe: lê os dados dela
        final d = subSnap.data()!; // "!" = garante que não é nulo (afirmação do desenvolvedor)

        // Busca também o documento de configuração para saber quantos tokens foram emitidos
        final cfg = await _db
            .collection('startups')
            .doc(startupId)
            .collection('balcao')
            .doc('config')
            .get();

        final emitted = (cfg.data()?['tokens_emitidos'] as num?)?.toInt() ?? 0;

        // Retorna um Record nomeado com os três valores
        return (
          lastPrice: (d['last_price'] as num?)?.toDouble(),
          tokensVendidos: (d['tokens_vendidos_startup'] as num?)?.toInt() ?? 0,
          tokensEmitidos: emitted,
        );
      }

      // FALLBACK: sub-coleção não existe, lê do documento principal da startup
      final startupSnap = await _db.collection('startups').doc(startupId).get();

      // "?? {}" = se for nulo, usa mapa vazio. Evita NullPointerException.
      final balcao =
          startupSnap.data()?['balcao'] as Map<String, dynamic>? ?? {};
      final st = balcao['state'] as Map<String, dynamic>? ?? {};
      final cfg = balcao['config'] as Map<String, dynamic>? ?? {};

      return (
        lastPrice: (st['last_price'] as num?)?.toDouble(),
        tokensVendidos: (st['tokens_vendidos_startup'] as num?)?.toInt() ?? 0,
        tokensEmitidos: (cfg['tokens_emitidos'] as num?)?.toInt() ?? 0,
      );
    });
  }

  // Stream da carteira (wallet) do usuário logado: saldo em reais e tokens.
  Stream<Wallet> watchWallet() {
    final uid = _uid;

    // Se o usuário não estiver logado (uid nulo), retorna uma carteira zerada
    // "Stream.value()" cria um Stream que emite um único valor e fecha.
    if (uid == null)
      return Stream.value(Wallet(brl: 0, tokens: 0, tokensReserved: 0));

    return _db
        .collection('usuarios')
        .doc(uid)            // Documento do usuário logado
        .collection('wallet')
        .doc('main')         // Documento principal da carteira
        .snapshots()
        .map((snap) {
      // "?? const <String, dynamic>{}" = se snap.data() for nulo, usa mapa vazio
      final d = snap.data() ?? const <String, dynamic>{};
      return Wallet(
        brl: (d['saldo_brl'] as num?)?.toDouble() ?? 0,
        tokens: 0, // Tokens são zerados aqui (talvez sejam calculados de outra forma)
        tokensReserved: (d['saldo_brl_reservado'] as num?)?.toInt() ?? 0,
      );
    });
  }

  // Stream do histórico de ordens do usuário.
  // "int limit = 50" é um parâmetro com valor padrão: se não passar nada, usa 50.
  Stream<List<OrderHistoryEntry>> watchOrderHistory({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []); // Lista vazia se não logado

    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('order_history')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      // "cache" é um dicionário temporário para guardar nomes de startups já buscados.
      // Assim evitamos buscar o mesmo nome várias vezes (otimização de performance).
      final cache = <String, String>{};

      final entries = <OrderHistoryEntry>[];

      for (final doc in snap.docs) {
        final d = doc.data();
        final startupId = (d['startup_id'] as String?) ?? '';

        // Tenta pegar o nome do cache. Se não tiver, busca no banco.
        String startupNome = cache[startupId] ?? '';
        if (startupNome.isEmpty && startupId.isNotEmpty) {
          try {
            final s = await _db.collection('startups').doc(startupId).get();
            startupNome = (s.data()?['nome'] as String?) ?? startupId;
            cache[startupId] = startupNome; // Salva no cache para próximas ordens
          } catch (_) {
            // Se der qualquer erro ao buscar o nome, usa o ID como fallback.
            // O "_" descarta a exceção (não precisamos saber o tipo do erro aqui).
            startupNome = startupId;
          }
        }

        // Busca o histórico de mudanças de status da ordem.
        // "??" garante que se for nulo, usa uma lista vazia.
        final changes = (d['status_changes'] as List?) ?? const [];

        // Pega o status mais recente (último item da lista de mudanças).
        // Se a lista estiver vazia, assume 'aberta' como padrão.
        final lastStatus = changes.isNotEmpty
            ? ((changes.last as Map?)?['status'] as String?) ?? 'aberta'
            : 'aberta';

        entries.add(OrderHistoryEntry(
          id: doc.id,
          startupId: startupId,
          startupNome: startupNome,
          side: (d['side'] as String?) ?? 'buy',
          orderType: (d['order_type'] as String?) ?? 'market',
          price: (d['price'] as num?)?.toDouble() ?? 0,
          qtyOriginal: (d['qty_original'] as num?)?.toInt() ?? 0,
          status: lastStatus,
          // "Timestamp" é o tipo do Firebase para datas.
          // ".toDate()" converte para o tipo DateTime do Dart.
          createdAt:
              (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
      return entries;
    });
  }

  // Stream da posição do usuário em uma startup específica:
  // quantos tokens ele tem livre (pode vender) e reservados (em ordens abertas).
  Stream<({int tokensLivres, int tokensReservados})> watchPosition(
      String startupId) {
    final uid = _uid;
    if (uid == null) {
      // Se não logado, retorna um Stream com valores zerados
      return Stream.value((tokensLivres: 0, tokensReservados: 0));
    }

    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('positions')
        .doc(startupId) // Um documento por startup: posição do usuário nessa startup
        .snapshots()
        .map((snap) {
      // Se o documento não existir (usuário não tem posição nessa startup), retorna zeros
      if (!snap.exists) return (tokensLivres: 0, tokensReservados: 0);
      final d = snap.data()!;
      return (
        tokensLivres: (d['tokens_livres'] as num?)?.toInt() ?? 0,
        tokensReservados: (d['tokens_reservados'] as num?)?.toInt() ?? 0,
      );
    });
  }

  // ==========================================================================
  // SEÇÃO: AÇÕES DE ORDEM
  // Métodos que criam ou cancelam ordens de compra/venda.
  // ==========================================================================

  // Cria uma nova ordem de compra ou venda.
  // "required" = parâmetro obrigatório (não tem valor padrão).
  // "double? price" = o preço é opcional (ordens a mercado não precisam de preço).
  Future<OrderCreateResult> createOrder({
    required String startupId,
    required String side,        // 'buy' ou 'sell'
    required String orderType,   // 'market' (mercado) ou 'limit' (limitada)
    required int qty,            // Quantidade de tokens
    double? price,               // Preço unitário (só para ordens limit)
  }) async {
    try {
      // Chama a Cloud Function 'ordersCreate' no Firebase.
      // Passamos os dados como um Map (dicionário).
      // "if (price != null) 'price': price" = só inclui o preço no Map se ele não for nulo.
      final res = await _fn.httpsCallable('ordersCreate').call({
        'startup_id': startupId,
        'side': side,
        'order_type': orderType,
        'qty': qty,
        if (price != null) 'price': price,
      });

      // Conta quantos trades foram gerados (a ordem pode ter executado imediatamente)
      final trades = (res.data['trades'] as List?)?.length ?? 0;

      // Retorna resultado de sucesso
      return OrderCreateResult(success: true, tradesExecuted: trades);

    } on FirebaseFunctionsException catch (e) {
      // "on TipoEspecifico catch (e)" captura apenas erros daquele tipo.
      // FirebaseFunctionsException = erro vindo da Cloud Function (ex: saldo insuficiente).
      return OrderCreateResult(
        success: false,
        errorCode: _parseErrorCode(e.message),      // Extrai o código do erro do JSON
        errorMessage: _humanizeError(e.message),    // Traduz para mensagem legível
      );
    } catch (e) {
      // "catch (e)" genérico captura qualquer outro tipo de erro (ex: sem internet).
      return OrderCreateResult(
        success: false,
        errorMessage: 'Erro ao processar ordem. Tente novamente.',
      );
    }
  }

  // Cancela uma ordem que ainda está aberta.
  Future<CancelResult> cancelOrder({
    required String startupId,
    required String orderId,
  }) async {
    try {
      // Chama a Cloud Function 'ordersCancel' com os identificadores necessários
      await _fn.httpsCallable('ordersCancel').call({
        'startup_id': startupId,
        'order_id': orderId,
      });
      return CancelResult(success: true);

    } on FirebaseFunctionsException catch (e) {
      return CancelResult(
        success: false,
        errorMessage: _humanizeError(e.message),
      );
    } catch (e) {
      return CancelResult(
          success: false, errorMessage: 'Erro ao cancelar ordem.');
    }
  }

  // ==========================================================================
  // SEÇÃO: CONVERSORES (MAPPERS)
  // Métodos privados que convertem documentos do Firebase em objetos Dart.
  // Eles centralizam a lógica de conversão para não repetir código.
  // ==========================================================================

  // Converte um DocumentSnapshot (documento bruto do Firestore) em um objeto Order.
  // "currentUid" é o ID do usuário logado, para marcar se a ordem é dele.
  Order _orderFromDoc(DocumentSnapshot doc, String? currentUid) {
    // "as Map<String, dynamic>?" tenta fazer cast. "?? {}" usa mapa vazio se falhar.
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Order(
      id: doc.id,
      side: (d['side'] as String?) ?? 'buy',
      type: (d['order_type'] as String?) ?? 'limit',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      qtyOriginal: (d['qty_original'] as num?)?.toInt() ?? 0,
      qty: (d['qty_restante'] as num?)?.toInt() ?? 0, // Quantidade restante (não executada ainda)
      mine: d['user_id'] == currentUid,          // true se a ordem pertence ao usuário logado
      isStartup: d['seller_type'] == 'startup',  // true se o vendedor é a própria startup
      status: (d['status'] as String?) ?? 'aberta',
    );
  }

  // Converte um DocumentSnapshot em um objeto Trade (negócio realizado).
  Trade _tradeFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    // Converte o Timestamp do Firebase em um DateTime do Dart
    final ts = d['executed_at'] as Timestamp?;
    final dt = ts?.toDate() ?? DateTime.now(); // Se nulo, usa a hora atual

    // Formata a hora como HH:MM:SS usando padLeft para garantir dois dígitos
    // Ex: hora 9 → "09", minuto 5 → "05"
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');

    return Trade(
      time: '$h:$m:$s', // String interpolation: monta "09:05:03"
      side: 'compra',   // Trades sempre representam uma compra casando com uma venda
      price: (d['price'] as num?)?.toDouble() ?? 0,
      qty: (d['qty'] as num?)?.toInt() ?? 0,
    );
  }

  // ==========================================================================
  // SEÇÃO: TRATAMENTO DE ERROS
  // Métodos privados para interpretar as mensagens de erro das Cloud Functions.
  // As funções retornam erros em JSON, então precisamos decodificar e traduzir.
  // ==========================================================================

  // Extrai o código do erro a partir da mensagem JSON.
  // Exemplo: message = '{"code": "INSUFFICIENT_BALANCE", "details": ...}'
  // Retorna: "INSUFFICIENT_BALANCE"
  String? _parseErrorCode(String? message) {
    try {
      // jsonDecode transforma a string JSON em um Map Dart
      final m = jsonDecode(message ?? '{}') as Map<String, dynamic>;
      return m['code'] as String?;
    } catch (_) {
      // Se a mensagem não for um JSON válido, retorna nulo
      return null;
    }
  }

  // Converte o código de erro técnico em uma mensagem amigável para o usuário.
  String _humanizeError(String? message) {
    try {
      final m = jsonDecode(message ?? '{}') as Map<String, dynamic>;
      final code = m['code'] as String?;

      // "switch" é como uma série de "if" para comparar um valor com vários casos
      switch (code) {
        case 'INSUFFICIENT_BALANCE':
          // Usuário não tem saldo em reais suficiente
          return 'Saldo insuficiente para esta operação.';

        case 'INSUFFICIENT_TOKENS':
          // Usuário não tem tokens suficientes para vender
          return 'Tokens insuficientes em carteira.';

        case 'LOCKUP_QUANTITY_VIOLATION':
          // Violação de regra de lockup por quantidade:
          // A startup precisa ter vendido uma quantidade mínima de tokens
          // antes de seus investidores poderem revender.
          final tipo = m['lockup_type'] as String?;
          if (tipo == 'percentual') {
            // Lockup baseado em porcentagem
            final sold = m['tokens_sold_percentage'];
            final req = m['required_percentage'];
            final needed = m['tokens_needed_to_unlock'];
            return 'Vendas bloqueadas: startup vendeu $sold% dos tokens (mínimo $req%). Faltam $needed tokens.';
          } else {
            // Lockup baseado em quantidade absoluta
            final sold = m['tokens_sold'];
            final req = m['required_tokens'];
            final needed = m['tokens_needed_to_unlock'];
            return 'Vendas bloqueadas: startup vendeu $sold tokens (mínimo $req). Faltam $needed tokens.';
          }

        case 'LOCKUP_TIME_VIOLATION':
          // Violação de lockup temporal (vesting): os tokens ainda estão
          // bloqueados por um período de tempo mínimo após a emissão.
          final avail = m['available_to_sell'] ?? 0;
          if (avail == 0) {
            // Nenhum token disponível ainda
            final breakdown =
                m['locked_tokens_breakdown'] as List<dynamic>? ?? [];
            if (breakdown.isNotEmpty) {
              final first = breakdown.first as Map<String, dynamic>;
              final days = first['days_remaining'];
              return 'Tokens bloqueados por vesting. Disponíveis em $days dia(s).';
            }
            return 'Tokens ainda sob período de vesting (lock-up temporal).';
          }
          // Alguns tokens já estão disponíveis
          return 'Apenas $avail tokens desbloqueados disponíveis para venda.';

        case 'LOCKUP_PARTIAL_VIOLATION':
          // Apenas parte dos tokens está disponível (mix de bloqueados e livres)
          final avail = m['available_to_sell'] ?? 0;
          return 'Apenas $avail tokens estão desbloqueados. Deseja vender $avail?';

        case 'PRICE_OUT_OF_RANGE':
          // O preço informado está fora dos limites permitidos pelo sistema
          final min = m['min_allowed'];
          final max = m['max_allowed'];
          // "R\$" = o "\" serve para escapar o "$" (que normalmente inicia interpolação)
          return 'Preço fora do limite permitido (R\$ $min – R\$ $max).';

        default:
          // Caso o código não seja nenhum dos acima, retorna a mensagem bruta
          return message ?? 'Erro ao processar ordem.';
      }
    } catch (_) {
      // Se qualquer coisa der errado ao processar o erro, retorna mensagem genérica
      return message ?? 'Erro ao processar ordem.';
    }
  }
}

// =============================================================================
// CLASSES DE RESULTADO
// Classes simples que encapsulam o resultado de uma operação.
// Usadas para retornar tanto o sucesso/falha quanto detalhes sobre o que aconteceu.
// =============================================================================

// Resultado da criação de uma ordem.
class OrderCreateResult {
  final bool success;             // true = ordem criada com sucesso
  final int tradesExecuted;       // Quantos trades foram gerados imediatamente
  final String? errorCode;        // Código do erro (ex: 'INSUFFICIENT_BALANCE'), se houver
  final String? errorMessage;     // Mensagem legível do erro, se houver

  // "const" construtor = pode ser criado em tempo de compilação (mais eficiente).
  // Parâmetros com "{}" são nomeados. "this.tradesExecuted = 0" define valor padrão.
  const OrderCreateResult({
    required this.success,
    this.tradesExecuted = 0,
    this.errorCode,
    this.errorMessage,
  });
}

// Resultado do cancelamento de uma ordem.
class CancelResult {
  final bool success;
  final String? errorMessage;

  const CancelResult({required this.success, this.errorMessage});
}

// Representa uma entrada no histórico de ordens do usuário.
class OrderHistoryEntry {
  final String id;              // ID único da ordem no Firestore
  final String startupId;       // ID da startup relacionada
  final String startupNome;     // Nome legível da startup (ex: "Acme Tecnologia")
  final String side;            // 'buy' (compra) ou 'sell' (venda)
  final String orderType;       // 'market' (a mercado) ou 'limit' (limitada)
  final double price;           // Preço da ordem (0 para ordens a mercado)
  final int qtyOriginal;        // Quantidade original da ordem
  final String status;          // Último status: 'aberta', 'executada', 'cancelada', etc.
  final DateTime createdAt;     // Data e hora em que a ordem foi criada

  const OrderHistoryEntry({
    required this.id,
    required this.startupId,
    required this.startupNome,
    required this.side,
    required this.orderType,
    required this.price,
    required this.qtyOriginal,
    required this.status,
    required this.createdAt,
  });
}