// =============================================================================
// ARQUIVO: orderbook_models.dart
// PROPÓSITO: Define todos os "modelos de dados" e o "estado global" do aplicativo.
//
// Um modelo é uma classe que representa uma entidade do mundo real em código.
// Ex: Order representa uma ordem de compra/venda, Startup representa uma empresa.
//
// O "estado global" (OrderbookState) guarda todos os dados da tela atual e
// notifica os widgets quando algo muda, para que eles se redesenhem.
// =============================================================================

// "foundation.dart" traz utilitários base do Flutter.
// Importamos especificamente para usar "ChangeNotifier" (explicado abaixo).
import 'package:flutter/foundation.dart';

// =============================================================================
// MODELO: Order (Ordem de compra ou venda)
// Representa uma oferta no livro de ordens (orderbook):
// alguém quer comprar ou vender X tokens a Y reais.
// =============================================================================
class Order {
  // "final" = imutável após criação. O ID nunca muda.
  final String id;

  final String side; // 'buy' (compra) ou 'sell' (venda)
  final String type; // 'market' (a mercado) ou 'limit' (preço fixo)

  // Estes NÃO são "final" — podem mudar durante a vida da ordem.
  // Ex: quando parte da ordem é executada, qty diminui.
  double price;       // Preço por token em R$
  int qtyOriginal;    // Quantidade original quando a ordem foi criada
  int qty;            // Quantidade RESTANTE (ainda não executada)
  bool mine;          // true se esta ordem pertence ao usuário logado
  bool isStartup;     // true se quem vende é a própria startup (oferta primária)
  String? status;     // Estado atual: 'aberta', 'parcialmente_executada', 'executada'

  // Construtor: como "montar" um objeto Order.
  // "required" = obrigatório. Parâmetros sem "required" têm valor padrão após "=".
  Order({
    required this.id,
    required this.side,
    required this.type,
    required this.price,
    required this.qtyOriginal,
    required this.qty,
    this.mine = false,       // Valor padrão: não é minha
    this.isStartup = false,  // Valor padrão: não é da startup
    this.status = 'aberta',  // Valor padrão: ordem começa aberta
  });

  // "get" define uma propriedade calculada (computed property).
  // "isPartial" não é armazenada — é recalculada toda vez que alguém a lê.
  // Uma ordem é "parcial" se já foi parcialmente executada:
  // a quantidade original é maior que a restante, mas ainda sobrou algo.
  bool get isPartial => qtyOriginal > qty && qty > 0;
}

// =============================================================================
// MODELO: Trade (Negócio realizado)
// Representa uma transação que JÁ aconteceu: uma compra encontrou uma venda
// e os tokens foram transferidos. É o "histórico de preços".
// =============================================================================
class Trade {
  final String time;   // Horário no formato "HH:MM:SS", ex: "14:32:05"
  final String side;   // 'compra' ou 'venda' (perspectiva do comprador)
  final double price;  // Preço pelo qual o negócio foi fechado
  final int qty;       // Quantidade de tokens negociados

  Trade({
    required this.time,
    required this.side,
    required this.price,
    required this.qty,
  });
}

// =============================================================================
// MODELO: Wallet (Carteira do usuário)
// Representa o patrimônio do usuário logado: dinheiro e tokens.
// =============================================================================
class Wallet {
  double brl;          // Saldo em Reais disponível para usar
  int tokens;          // Tokens "livres" (disponíveis para vender)
  int tokensReserved;  // Tokens reservados em ordens de venda abertas
                       // (não pode vender os mesmos tokens duas vezes)

  Wallet({
    required this.brl,
    required this.tokens,
    required this.tokensReserved,
  });
}

// =============================================================================
// MODELO: Startup
// Representa uma empresa cadastrada no sistema com seus dados de negociação.
// =============================================================================
class Startup {
  final String id;              // ID único no Firebase
  final String nome;            // Nome completo, ex: "Acme Tecnologia"
  final String sigla;           // Abreviação, ex: "ACME"
  final double precoEmissao;    // Preço original de quando os tokens foram criados
  double? lastPrice;            // Último preço negociado (null se nunca houve negócio)
  final int tokensEmitidos;     // Total de tokens que existem para esta startup

  Startup({
    required this.id,
    required this.nome,
    required this.sigla,
    required this.precoEmissao,
    this.lastPrice,             // Opcional (pode ser nulo)
    required this.tokensEmitidos,
  });

  // Preço para exibir na tela:
  // Se já houve algum negócio, mostra o último preço.
  // Se nunca houve negócio, mostra o preço de emissão (preço inicial).
  // "??" = operador de coalescência nula: usa o valor da direita se o da esquerda for nulo.
  double get displayPrice => lastPrice ?? precoEmissao;

  // Calcula a variação percentual em relação ao preço de emissão.
  // Fórmula: ((preço_atual - preço_inicial) / preço_inicial) * 100
  // Ex: emissão R$10, atual R$12 → ((12-10)/10)*100 = +20%
  double get variation {
    if (lastPrice == null) return 0; // Sem negócio = sem variação
    return ((lastPrice! - precoEmissao) / precoEmissao) * 100;
    // "lastPrice!" usa "!" para afirmar que não é nulo (já verificamos acima)
  }

  // Texto formatado da variação para mostrar na tela.
  // Ex: "+20.00%" ou "-5.50%"
  String get variationText {
    if (lastPrice == null) return 'preco de emissao'; // Texto especial sem negócios
    final v = variation;
    // Ternário: "condição ? valor_se_true : valor_se_false"
    // Se v >= 0, adiciona "+" na frente; se negativo, o próprio número já tem "-"
    // ".toStringAsFixed(2)" formata com exatamente 2 casas decimais
    return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }
}

// =============================================================================
// ESTADO GLOBAL: OrderbookState
// Esta é a classe mais importante do arquivo. Ela é o "cérebro" da tela
// de negociação — guarda todos os dados e notifica a UI quando algo muda.
//
// "extends ChangeNotifier" significa que esta classe herda de ChangeNotifier:
// ela ganha o poder de chamar "notifyListeners()" que avisa todos os widgets
// que estão "ouvindo" para se redesenharem com os dados novos.
//
// Padrão de design: Provider / ChangeNotifier (gerenciamento de estado no Flutter)
// =============================================================================
class OrderbookState extends ChangeNotifier {

  // ── DADOS DO ESTADO ────────────────────────────────────────────────────────

  // "late" = será inicializado antes de ser usado (não necessariamente no construtor).
  // Usamos "late" aqui porque os dados vêm de parâmetros obrigatórios no construtor.
  late Wallet wallet;           // Carteira do usuário
  late Startup currentStartup;  // Startup atualmente selecionada para negociar

  // Livros de ordens (listas de ofertas abertas)
  List<Order> buyBook = [];   // Ordens de compra abertas
  List<Order> sellBook = [];  // Ordens de venda abertas
  List<Trade> trades = [];    // Histórico de negócios realizados

  // "Set" é como uma lista, mas sem duplicatas e sem ordem garantida.
  // Guarda os IDs das ordens que pertencem ao usuário logado.
  Set<String> myOrderIds = {};

  // Quantidade de tokens que a startup vendeu (dado vindo do servidor)
  int remoteTokensVendidos = 0;

  // Estado da interface do formulário de criação de ordem
  String currentTab = 'buy';    // Aba selecionada: 'buy' ou 'sell'
  String orderType = 'market';  // Tipo de ordem: 'market' ou 'limit'
  double inputPrice = 0;        // Preço digitado pelo usuário
  int inputQty = 0;             // Quantidade digitada pelo usuário

  // Construtor: recebe a carteira e a startup inicial
  OrderbookState({required this.wallet, required this.currentStartup});

  // ==========================================================================
  // SEÇÃO: MÉTODOS DE ATUALIZAÇÃO (Remote updates)
  // Estes métodos são chamados quando chegam novos dados do Firebase.
  // Cada um atualiza os dados e chama notifyListeners() para redesenhar a UI.
  // ==========================================================================

  // Atualiza apenas as ordens de compra.
  void updateBuyBook(List<Order> orders) {
    buyBook = orders;

    // Recalcula quais ordens são "minhas":
    // Mantém os IDs de ordens de venda que já eram minhas (usando where + any)
    // e adiciona os IDs das novas ordens de compra que são minhas.
    // "..." é o spread operator: "espalha" os elementos de um Set dentro de outro.
    myOrderIds = {
      ...myOrderIds.where((id) => sellBook.any((o) => o.id == id)), // IDs de venda meus
      ...orders.where((o) => o.mine).map((o) => o.id),             // IDs de compra meus
    };

    notifyListeners(); // Avisa a UI para se redesenhar
  }

  // Atualiza apenas as ordens de venda.
  void updateSellBook(List<Order> orders) {
    sellBook = orders;
    myOrderIds = {
      ...myOrderIds.where((id) => buyBook.any((o) => o.id == id)), // Mantém os de compra
      ...orders.where((o) => o.mine).map((o) => o.id),            // Adiciona os de venda
    };
    notifyListeners();
  }

  // Atualiza compras e vendas ao mesmo tempo (mais eficiente que chamar os dois acima).
  void updateBothBooks(List<Order> buys, List<Order> sells) {
    buyBook = buys;
    sellBook = sells;
    // Recria o Set completo de IDs a partir das duas listas
    myOrderIds = {
      ...buys.where((o) => o.mine).map((o) => o.id),
      ...sells.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners();
  }

  // Substitui a lista de trades pelo novo histórico vindo do servidor.
  void updateTrades(List<Trade> remoteTrades) {
    trades = remoteTrades;
    notifyListeners();
  }

  // Substitui a carteira inteira por uma nova versão.
  void updateWallet(Wallet w) {
    wallet = w;
    notifyListeners();
  }

  // Atualiza apenas a parte de tokens da carteira (sem mexer no saldo BRL).
  // Chamado quando muda a posição do usuário numa startup específica.
  void updatePosition(int tokensLivres, int tokensReservados) {
    // Cria uma nova Wallet mantendo o saldo BRL atual e atualizando só os tokens
    wallet = Wallet(
      brl: wallet.brl,              // Mantém o saldo em reais
      tokens: tokensLivres,         // Atualiza tokens disponíveis
      tokensReserved: tokensReservados, // Atualiza tokens reservados
    );
    notifyListeners();
  }

  // Atualiza o preço e o progresso de vendas da startup atual.
  void updateStartupState(double? lastPrice, int tokensVendidos) {
    currentStartup.lastPrice = lastPrice; // Atualiza o último preço negociado
    remoteTokensVendidos = tokensVendidos; // Atualiza quantos tokens a startup vendeu
    notifyListeners();
  }

  // Troca a startup que está sendo visualizada/negociada.
  // Limpa TODOS os dados da startup anterior ao trocar.
  void changeStartup(Startup startup) {
    currentStartup = startup;
    // Reseta tudo para evitar mostrar dados da startup antiga
    buyBook = [];
    sellBook = [];
    trades = [];
    myOrderIds = {};
    remoteTokensVendidos = 0;
    inputPrice = 0;
    inputQty = 0;
    notifyListeners();
  }

  // ==========================================================================
  // SEÇÃO: PROPRIEDADES CALCULADAS (Computed)
  // Não armazenam dados — calculam na hora a partir dos dados existentes.
  // ==========================================================================

  // Livro de compras ordenado por preço decrescente (maior oferta primeiro).
  // "[...buyBook]" cria uma CÓPIA da lista (para não alterar a original ao ordenar).
  List<Order> get sortedBuyBook {
    final sorted = [...buyBook];
    // ".sort()" ordena in-place. O comparador "(a, b) => ..." define a ordem:
    // "b.price.compareTo(a.price)" = decrescente (maior preço de compra no topo)
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }

  // Livro de vendas ordenado por preço crescente (menor oferta primeiro).
  // Quem quer comprar pega a oferta mais barata — por isso menor preço fica no topo.
  List<Order> get sortedSellBook {
    final sorted = [...sellBook];
    // "a.price.compareTo(b.price)" = crescente (menor preço de venda no topo)
    sorted.sort((a, b) => a.price.compareTo(b.price));
    return sorted;
  }

  // Melhor oferta de compra = maior preço que alguém quer pagar (topo do buy book).
  // "Order?" = pode ser nulo (se não houver ordens de compra).
  // Operador ternário: se a lista não for vazia, retorna o primeiro; senão, null.
  Order? get bestBid => sortedBuyBook.isNotEmpty ? sortedBuyBook.first : null;

  // Melhor oferta de venda = menor preço que alguém aceita receber (topo do sell book).
  Order? get bestAsk => sortedSellBook.isNotEmpty ? sortedSellBook.first : null;

  // Spread = diferença entre o melhor preço de venda e o melhor de compra.
  // Indica a "distância" entre compradores e vendedores.
  // Spread pequeno = mercado líquido. Spread grande = mercado ilíquido.
  double get spread {
    final bid = bestBid?.price; // "?." = acesso seguro (retorna null se bestBid for null)
    final ask = bestAsk?.price;
    if (bid == null || ask == null) return 0; // Sem os dois lados, não há spread
    return ask - bid;
  }

  // Getter simples que expõe o campo privado de forma mais semântica.
  int get startupTokensVendidos => remoteTokensVendidos;

  // Progresso de vendas da startup: de 0.0 (0%) a 1.0 (100%).
  // Ex: 500 tokens vendidos de 1000 emitidos = 0.5 (50%).
  // ".clamp(0.0, 1.0)" garante que o resultado fica entre 0 e 1
  // (evita valores impossíveis como 1.05 por arredondamento).
  double get startupSaleProgress {
    if (currentStartup.tokensEmitidos == 0) return 0; // Evita divisão por zero
    return (startupTokensVendidos / currentStartup.tokensEmitidos).clamp(0.0, 1.0);
  }

  // Volume total em tokens de todas as ordens de compra abertas.
  // ".fold(0, ...)" é como um "reduce": começa com 0 e acumula somando order.qty
  int get totalBidVolume => buyBook.fold(0, (total, order) => total + order.qty);

  // Volume total em tokens de todas as ordens de venda abertas.
  int get totalAskVolume => sellBook.fold(0, (total, order) => total + order.qty);

  // Estima o custo total (em R$) para executar uma ordem a mercado.
  // Para comprar: percorre o sell book do mais barato para o mais caro.
  // Para vender: percorre o buy book do mais caro para o mais barato.
  // Retorna null se não houver volume suficiente no livro para completar a ordem.
  double? estimateMarketTotal(String side, int qty) {
    if (qty <= 0) return null;

    // Se estou comprando, preciso olhar as ofertas de venda (e vice-versa)
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    if (book.isEmpty) return null;

    var remaining = qty;  // Tokens que ainda preciso "consumir"
    var total = 0.0;       // Custo acumulado

    for (final order in book) {
      // Pega o menor valor entre o que preciso e o que esta ordem oferece
      final take = remaining < order.qty ? remaining : order.qty;
      total += take * order.price; // Custo desta parcela
      remaining -= take;           // Desconta do que ainda preciso
      if (remaining <= 0) return total; // Consegui completar — retorna o total
    }

    return null; // Percorreu todo o livro e não havia volume suficiente
  }

  // Estima o preço médio de execução de uma ordem a mercado.
  // Ex: se comprar 100 tokens e custar R$150 no total, preço médio = R$1,50.
  double? estimateAverageMarketPrice(String side, int qty) {
    final total = estimateMarketTotal(side, qty);
    if (total == null || qty <= 0) return null;
    return total / qty;
  }

  // Calcula quantos tokens consigo comprar/vender com um valor em R$.
  // Útil quando o usuário digita "quero gastar R$500" em vez de "quero 200 tokens".
  int estimateMarketQtyForValue(String side, double amount) {
    if (amount <= 0) return 0;

    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    if (book.isEmpty) return 0;

    var remaining = amount; // Saldo disponível para gastar
    var qty = 0;             // Tokens acumulados

    for (final order in book) {
      final fullLevelCost = order.qty * order.price; // Custo para esvaziar esta ordem

      if (remaining >= fullLevelCost) {
        // Dinheiro suficiente para levar TODOS os tokens desta ordem
        qty += order.qty;
        remaining -= fullLevelCost;
        continue; // Vai para a próxima ordem
      }

      // Não dá para levar a ordem inteira: pega o máximo que o dinheiro permite
      // ".floor()" arredonda para baixo (não compramos frações de token)
      qty += (remaining / order.price).floor();
      break; // Para aqui, pois o dinheiro acabou
    }
    return qty;
  }

  // Retorna o total de tokens disponíveis no livro oposto para uma dada operação.
  // Ex: se quero comprar, retorna o total de tokens à venda no mercado.
  // Útil para mostrar "liquidez disponível" para o usuário.
  int availableMarketQty(String side) {
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    return book.fold(0, (total, order) => total + order.qty);
  }

  // ==========================================================================
  // SEÇÃO: SETTERS DE INTERFACE
  // Métodos simples que atualizam o estado da UI e redesenham a tela.
  // ==========================================================================

  // Muda a aba selecionada ('buy' ou 'sell') no formulário de ordem.
  void setTab(String tab) {
    currentTab = tab;
    notifyListeners();
  }

  // Muda o tipo de ordem ('market' ou 'limit') no formulário.
  void setOrderType(String type) {
    orderType = type;
    notifyListeners();
  }

  // ==========================================================================
  // SEÇÃO: FORMATAÇÃO
  // Utilitários para exibir números de forma legível para o usuário.
  // ==========================================================================

  // Formata um preço no estilo brasileiro: "R$ 1,50"
  // "toStringAsFixed(2)" = 2 casas decimais
  // ".replaceAll('.', ',')" = troca o ponto decimal pelo vírgula (padrão BR)
  // "R\$" = o "\" escapa o "$" para não ser interpretado como interpolação
  String formatPrice(double price) {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Formata uma quantidade com separador de milhar no estilo brasileiro: "1.234.567"
  // "replaceAllMapped" aplica uma função a cada ocorrência de um padrão (Regex).
  // A Regex "\B(?=(\d{3})+(?!\d))" encontra as posições onde inserir o ponto:
  //   \B         = posição que NÃO é uma borda de palavra (não o início)
  //   (?=        = lookahead: "seguido de..."
  //   (\d{3})+   = um ou mais grupos de 3 dígitos
  //   (?!\d)     = que NÃO seja seguido de mais dígito (fim da sequência)
  // Resultado: 1234567 → "1.234.567"
  String formatQty(int qty) {
    return qty.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), // Regex para encontrar onde colocar "."
          (match) => '.', // Substitui cada match por um ponto
        );
  }
}