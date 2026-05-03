import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../home/home_screen.dart'; // importa AppBottomNav

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPeriodIndex = 0;

  // Inicializa com valor padrão seguro — evita LateInitializationError
  AnimationController? _chartController;
  Animation<double> _chartAnimation = const AlwaysStoppedAnimation(0.0);

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
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController!,
      curve: Curves.easeInOut,
    );
    // Garante que a tela já renderizou antes de iniciar a animação
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chartController?.forward();
    });
  }

  @override
  void dispose() {
    _chartController?.dispose();
    super.dispose();
  }

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD7DEEC) : Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF234794)
                      : const Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              child: Text(
                _periods[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF000141)
                      : Colors.black54,
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
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEAEAF0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
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
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 253, 253, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _chartAnimation,
          builder: (context, _) {
            return CustomPaint(
              painter: _LineChartPainter(progress: _chartAnimation.value),
              child: const SizedBox.expand(),
            );
          },
        ),
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

// ── Gráfico de linha com animação, grid e gradiente ───────────
class _LineChartPainter extends CustomPainter {
  final double progress;

  _LineChartPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 12;
    const double paddingRight = 70;
    const double paddingTop = 24;
    const double paddingBottom = 12;

    final chartW = size.width - paddingLeft - paddingRight;
    final chartH = size.height - paddingTop - paddingBottom;

    // ── Grid lines horizontais ──────────────────────────
    final gridPaint = Paint()
      ..color = const Color.fromARGB(255, 236, 236, 241)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const int gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = paddingTop + chartH * i / gridLines;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + chartW, y),
        gridPaint,
      );
    }

    // ── Pontos normalizados ─────────────────────────────
    final rawPoints = [
      const Offset(0.00, 0.88),
      const Offset(0.07, 0.86),
      const Offset(0.13, 0.83),
      const Offset(0.20, 0.80),
      const Offset(0.27, 0.77),
      const Offset(0.33, 0.74),
      const Offset(0.40, 0.70),
      const Offset(0.47, 0.66),
      const Offset(0.53, 0.61),
      const Offset(0.60, 0.55),
      const Offset(0.67, 0.48),
      const Offset(0.73, 0.42),
      const Offset(0.80, 0.34),
      const Offset(0.87, 0.25),
      const Offset(0.93, 0.17),
      const Offset(1.00, 0.08),
    ];

    final points = rawPoints
        .map((p) => Offset(
              paddingLeft + p.dx * chartW,
              paddingTop + p.dy * chartH,
            ))
        .toList();

    // ── Calcula até onde desenhar com base no progress ──
    final totalSegments = points.length - 1;
    final double clampedProgress = progress.clamp(0.0, 1.0);
    final currentSegment =
        (clampedProgress * totalSegments).floor().clamp(0, totalSegments - 1);
    final segmentProgress = (clampedProgress * totalSegments) - currentSegment;

    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i <= totalSegments; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cx = (prev.dx + curr.dx) / 2;

      if (i < currentSegment + 1) {
        // Segmento completo
        linePath.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
      } else if (i == currentSegment + 1) {
        // Segmento parcial
        final t = clampedProgress >= 1.0 ? 1.0 : segmentProgress;
        final endX = prev.dx + (curr.dx - prev.dx) * t;
        final endY = prev.dy + (curr.dy - prev.dy) * t;
        linePath.cubicTo(cx, prev.dy, cx, endY, endX, endY);
        break;
      }
    }

    // Ponto animado atual
    final Offset animatedEnd;
    if (clampedProgress >= 1.0) {
      animatedEnd = points.last;
    } else {
      final prev = points[currentSegment];
      final curr = points[currentSegment + 1];
      animatedEnd = Offset(
        prev.dx + (curr.dx - prev.dx) * segmentProgress,
        prev.dy + (curr.dy - prev.dy) * segmentProgress,
      );
    }

    // Preenchimento gradiente
    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath.lineTo(animatedEnd.dx, paddingTop + chartH);
    fillPath.lineTo(points.first.dx, paddingTop + chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, paddingTop),
        Offset(0, paddingTop + chartH),
        [
          const Color(0xFFE91E8C).withOpacity(0.25),
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

    // Ponto animado na ponta
    canvas.drawCircle(
      animatedEnd,
      5,
      Paint()..color = const Color(0xFFAD1457),
    );

    // Label aparece só quando a animação termina
    if (clampedProgress >= 1.0) {
      const labelStyle = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      );
      final tp = TextPainter(
        text: const TextSpan(text: 'R\$ 7.150', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(animatedEnd.dx + 8, animatedEnd.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.progress != progress;
}