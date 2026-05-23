import 'package:flutter/foundation.dart';

class Order {
  final int id;
  final String side; // 'buy' ou 'sell'
  final String type; // 'market' ou 'limit'
  double price;
  int qtyOriginal;
  int qty;
  bool mine;
  bool isStartup;
  String? status; // 'aberta', 'parcialmente_executada', 'executada'

  Order({
    required this.id,
    required this.side,
    required this.type,
    required this.price,
    required this.qtyOriginal,
    required this.qty,
    this.mine = false,
    this.isStartup = false,
    this.status = 'aberta',
  });

  bool get isPartial => qtyOriginal > qty && qty > 0;
}

class Trade {
  final String time;
  final String side; // 'compra' ou 'venda'
  final double price;
  final int qty;

  Trade({
    required this.time,
    required this.side,
    required this.price,
    required this.qty,
  });
}

class Wallet {
  double brl;
  int tokens;
  int tokensReserved;

  Wallet({
    required this.brl,
    required this.tokens,
    required this.tokensReserved,
  });
}

class Startup {
  final String id;
  final String nome;
  final double precoEmissao;
  double? lastPrice;
  final int tokensEmitidos;

  Startup({
    required this.id,
    required this.nome,
    required this.precoEmissao,
    this.lastPrice,
    required this.tokensEmitidos,
  });

  double get displayPrice => lastPrice ?? precoEmissao;

  double get variation {
    if (lastPrice == null) return 0;
    return ((lastPrice! - precoEmissao) / precoEmissao) * 100;
  }

  String get variationText {
    if (lastPrice == null) return 'preco de emissao';
    final v = variation;
    return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }
}

class OrderbookState extends ChangeNotifier {
  late Wallet wallet;
  late Startup currentStartup;

  List<Order> buyBook = [];
  List<Order> sellBook = [];
  List<Trade> trades = [];

  Set<int> myOrderIds = {};
  int _nextId = 1000;

  String currentTab = 'buy';
  String orderType = 'market';
  double inputPrice = 0;
  int inputQty = 0;

  OrderbookState({required this.wallet, required this.currentStartup}) {
    _initializeBook();
  }

  void _initializeBook() {
    sellBook = [
      Order(
        id: 100,
        side: 'sell',
        type: 'limit',
        price: currentStartup.precoEmissao,
        qtyOriginal: currentStartup.tokensEmitidos,
        qty: currentStartup.tokensEmitidos,
        mine: false,
        isStartup: true,
      ),
    ];

    buyBook = [
      Order(
        id: 1,
        side: 'buy',
        type: 'limit',
        price: 2.40,
        qtyOriginal: 150,
        qty: 150,
        mine: false,
        isStartup: false,
      ),
      Order(
        id: 2,
        side: 'buy',
        type: 'limit',
        price: 2.35,
        qtyOriginal: 300,
        qty: 300,
        mine: false,
        isStartup: false,
      ),
    ];
  }

  List<Order> get sortedBuyBook {
    final sorted = [...buyBook];
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }

  List<Order> get sortedSellBook {
    final sorted = [...sellBook];
    sorted.sort((a, b) => a.price.compareTo(b.price));
    return sorted;
  }

  Order? get bestBid => sortedBuyBook.isNotEmpty ? sortedBuyBook.first : null;
  Order? get bestAsk => sortedSellBook.isNotEmpty ? sortedSellBook.first : null;

  double get spread {
    final bid = bestBid?.price;
    final ask = bestAsk?.price;
    if (bid == null || ask == null) return 0;
    return ask - bid;
  }

  int get startupTokensDisponiveis {
    final startupOrders = sellBook.where((order) => order.isStartup);
    return startupOrders.fold(0, (total, order) => total + order.qty);
  }

  int get startupTokensVendidos {
    final sold = currentStartup.tokensEmitidos - startupTokensDisponiveis;
    return sold < 0 ? 0 : sold;
  }

  double get startupSaleProgress {
    if (currentStartup.tokensEmitidos == 0) return 0;
    return startupTokensVendidos / currentStartup.tokensEmitidos;
  }

  int get totalBidVolume => buyBook.fold(0, (total, order) => total + order.qty);

  int get totalAskVolume => sellBook.fold(0, (total, order) => total + order.qty);

  double? estimateMarketTotal(String side, int qty) {
    if (qty <= 0) return null;
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    if (book.isEmpty) return null;

    var remaining = qty;
    var total = 0.0;
    for (final order in book) {
      final take = remaining < order.qty ? remaining : order.qty;
      total += take * order.price;
      remaining -= take;
      if (remaining <= 0) {
        return total;
      }
    }

    return null;
  }

  double? estimateAverageMarketPrice(String side, int qty) {
    final total = estimateMarketTotal(side, qty);
    if (total == null || qty <= 0) return null;
    return total / qty;
  }

  void setTab(String tab) {
    currentTab = tab;
    notifyListeners();
  }

  void setOrderType(String type) {
    orderType = type;
    notifyListeners();
  }

  Future<bool> submitOrder() async {
    if (inputQty <= 0 || inputQty > 1000000) {
      return false;
    }

    try {
      if (orderType == 'market') {
        return await _executeMarketOrder();
      }
      return _createLimitOrder();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _executeMarketOrder() async {
    if (currentTab == 'buy') {
      final sellSorted = sortedSellBook;
      if (sellSorted.isEmpty) return false;

      var remaining = inputQty;
      var totalCost = 0.0;
      for (final sellOrder in sellSorted) {
        final take = remaining < sellOrder.qty ? remaining : sellOrder.qty;
        totalCost += take * sellOrder.price;
        remaining -= take;
        if (remaining <= 0) break;
      }

      if (remaining > 0) return false;
      if (totalCost > wallet.brl) return false;

      remaining = inputQty;
      for (final sellOrder in sellSorted) {
        final take = remaining < sellOrder.qty ? remaining : sellOrder.qty;
        currentStartup.lastPrice = sellOrder.price;
        trades.add(
          Trade(
            time: _getCurrentTime(),
            side: 'compra',
            price: sellOrder.price,
            qty: take,
          ),
        );
        wallet.brl -= take * sellOrder.price;
        wallet.tokens += take;
        sellOrder.qty -= take;
        remaining -= take;

        if (sellOrder.qty <= 0) {
          sellBook.removeWhere((order) => order.id == sellOrder.id);
          myOrderIds.remove(sellOrder.id);
        }
        if (remaining <= 0) break;
      }

      inputQty = 0;
      notifyListeners();
      return true;
    }

    if (wallet.tokens < inputQty) return false;

    final buySorted = sortedBuyBook;
    if (buySorted.isEmpty) return false;

    var remaining = inputQty;
    for (final buyOrder in buySorted) {
      final take = remaining < buyOrder.qty ? remaining : buyOrder.qty;
      currentStartup.lastPrice = buyOrder.price;
      trades.add(
        Trade(
          time: _getCurrentTime(),
          side: 'venda',
          price: buyOrder.price,
          qty: take,
        ),
      );
      wallet.brl += take * buyOrder.price;
      wallet.tokens -= take;
      buyOrder.qty -= take;
      remaining -= take;

      if (buyOrder.qty <= 0) {
        buyBook.removeWhere((order) => order.id == buyOrder.id);
        myOrderIds.remove(buyOrder.id);
      }
      if (remaining <= 0) break;
    }

    inputQty = 0;
    notifyListeners();
    return true;
  }

  bool _createLimitOrder() {
    if (inputPrice <= 0) return false;

    final id = _nextId++;
    if (currentTab == 'buy') {
      final cost = inputPrice * inputQty;
      if (cost > wallet.brl) return false;
      wallet.brl -= cost;
      buyBook.add(
        Order(
          id: id,
          side: 'buy',
          type: 'limit',
          price: inputPrice,
          qtyOriginal: inputQty,
          qty: inputQty,
          mine: true,
          isStartup: false,
        ),
      );
      myOrderIds.add(id);
    } else {
      if (wallet.tokens < inputQty) return false;
      wallet.tokens -= inputQty;
      wallet.tokensReserved += inputQty;
      sellBook.add(
        Order(
          id: id,
          side: 'sell',
          type: 'limit',
          price: inputPrice,
          qtyOriginal: inputQty,
          qty: inputQty,
          mine: true,
          isStartup: false,
        ),
      );
      myOrderIds.add(id);
    }

    inputQty = 0;
    inputPrice = 0;
    _executeMatch();
    notifyListeners();
    return true;
  }

  void _executeMatch() {
    while (true) {
      final buySorted = sortedBuyBook;
      final sellSorted = sortedSellBook;

      if (buySorted.isEmpty || sellSorted.isEmpty) break;

      final buyOrder = buySorted.first;
      final sellOrder = sellSorted.first;

      if (buyOrder.price < sellOrder.price) break;

      final qty = buyOrder.qty < sellOrder.qty ? buyOrder.qty : sellOrder.qty;
      currentStartup.lastPrice = sellOrder.price;

      trades.add(
        Trade(
          time: _getCurrentTime(),
          side: 'compra',
          price: sellOrder.price,
          qty: qty,
        ),
      );

      if (myOrderIds.contains(buyOrder.id)) {
        wallet.tokens += qty;
      }
      if (myOrderIds.contains(sellOrder.id)) {
        wallet.tokens -= qty;
        wallet.tokensReserved -= qty;
        wallet.brl += sellOrder.price * qty;
      }

      buyOrder.qty -= qty;
      sellOrder.qty -= qty;

      if (buyOrder.qty <= 0) {
        buyBook.removeWhere((order) => order.id == buyOrder.id);
        myOrderIds.remove(buyOrder.id);
      }
      if (sellOrder.qty <= 0) {
        sellBook.removeWhere((order) => order.id == sellOrder.id);
        myOrderIds.remove(sellOrder.id);
      }
    }
  }

  void cancelOrder(int id, String side) {
    final book = side == 'buy' ? buyBook : sellBook;
    final idx = book.indexWhere((order) => order.id == id);
    if (idx == -1) return;

    final order = book[idx];
    if (side == 'buy') {
      wallet.brl += order.price * order.qty;
    } else {
      wallet.tokens += order.qty;
      wallet.tokensReserved -= order.qty;
    }

    book.removeAt(idx);
    myOrderIds.remove(id);
    notifyListeners();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  String formatPrice(double price) {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String formatQty(int qty) {
    return qty.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        );
  }
}
