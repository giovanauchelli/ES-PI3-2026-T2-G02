import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../home/home_screen.dart'; // importa AppBottomNav

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedPeriodIndex = 0;

  final List<String> _periods = ['1 dia', '7 dias', '1 mês', '6 meses', 'YTD'];

  final List<Map<String, dynamic>> _startups = [
    {
      'name': 'AgroSense',
      'detail': '150 x R\$ 25,00',
      'value': 'R\$ 3.750',
      'change': '+8,2%',
    },
    {
      'name': 'AgroSense',
      'detail': '150 x R\$ 25,00',
      'value': 'R\$ 3.750',
      'change': '+8,2%',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Gradiente topo — idêntico ao HomeScreen
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFFE040FB),
                    Color(0xFFFF6B6B),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Filtro de período
                    _buildPeriodFilter(),
                    const SizedBox(height: 20),

                    // Cards Patrimônio / Lucro
                    _buildMetricCards(),
                    const SizedBox(height: 20),

                    // Gráfico
                    _buildChart(),
                    const SizedBox(height: 24),

                    // Seção Por Startup
                    const Text(
                      'Por Startup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Lista de startups com Divider entre elas
                    ..._startups.asMap().entries.map((entry) {
                      final index = entry.key;
                      final startup = entry.value;
                      return Column(
                        children: [
                          _buildStartupItem(startup),
                          if (index < _startups.length - 1)
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildPeriodFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriodIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: Text(
                _periods[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricCards() {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            label: 'Patrimônio',
            value: 'R\$ 7.150',
            valueColor: Colors.black87,
            subtitle: '+5,3%',
            subtitleColor: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            label: 'Lucro/ Prejuízo',
            value: '+R\$ 360',
            valueColor: const Color(0xFF2E7D32),
            subtitle: 'este mês',
            subtitleColor: Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String label,
    required String value,
    required Color valueColor,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FD),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FD),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 14,
            child: const Text(
              'R\$ 7.150',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: CustomPaint(
              painter: _LineChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupItem(Map<String, dynamic> startup) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  startup['name'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  startup['detail'],
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                startup['value'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                startup['change'],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gráfico de linha com gradiente ────────────────────────────
class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> points = [
      Offset(0, size.height * 0.88),
      Offset(size.width * 0.10, size.height * 0.85),
      Offset(size.width * 0.18, size.height * 0.80),
      Offset(size.width * 0.28, size.height * 0.78),
      Offset(size.width * 0.38, size.height * 0.72),
      Offset(size.width * 0.48, size.height * 0.65),
      Offset(size.width * 0.58, size.height * 0.55),
      Offset(size.width * 0.68, size.height * 0.42),
      Offset(size.width * 0.80, size.height * 0.28),
      Offset(size.width * 0.90, size.height * 0.18),
      Offset(size.width, size.height * 0.08),
    ];

    // Linha suavizada
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cx = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
    }

    // Preenchimento com gradiente
    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          const Color(0xFFE91E8C).withOpacity(0.28),
          const Color(0xFFE91E8C).withOpacity(0.02),
        ],
      );

    canvas.drawPath(fillPath, fillPaint);

    // Linha
    final linePaint = Paint()
      ..color = const Color(0xFFAD1457)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Ponto final
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = const Color(0xFFAD1457),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}