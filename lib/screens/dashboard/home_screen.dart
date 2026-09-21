import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/broker_provider.dart';
import '../../providers/activity_log_provider.dart';
import '../../models/activity_log.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _headerController;
  late final AnimationController _cardsController;
  late final AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityLogProvider>().loadLogs();
      _headerController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _cardsController.forward();
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _listController.forward();
      });
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardsController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BrokerProvider>(
      builder: (context, brokerProvider, _) {
        if (brokerProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
            ),
          );
        }

        final brokers = brokerProvider.brokers;
        final totalDebt =
            brokers.fold<double>(0, (sum, b) => sum + b.totalDebt);
        final totalPaid =
            brokers.fold<double>(0, (sum, b) => sum + b.totalPaid);
        final totalBalance = totalDebt - totalPaid;
        final brokersWithDebt = brokers
            .where((b) => b.balance > 0)
            .toList()
          ..sort((a, b) => b.balance.compareTo(a.balance));

        final paidPercent =
            totalDebt > 0 ? (totalPaid / totalDebt).clamp(0.0, 1.0) : 1.0;

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            await brokerProvider.loadBrokers();
            if (context.mounted) {
              await context.read<ActivityLogProvider>().loadLogs();
            }
            _headerController.reset();
            _cardsController.reset();
            _listController.reset();
            _headerController.forward();
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) _cardsController.forward();
            });
            Future.delayed(const Duration(milliseconds: 450), () {
              if (mounted) _listController.forward();
            });
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildHeroCard(totalDebt, totalPaid, totalBalance, paidPercent),
              const SizedBox(height: 16),
              _buildStatChips(brokers.length, totalDebt, totalPaid),
              const SizedBox(height: 12),
              _buildGeneralStatementButton(context),
              const SizedBox(height: 8),
              _buildLabelsButton(context),
              const SizedBox(height: 20),
              _buildActivitySection(context),
              const SizedBox(height: 20),
              _buildDebtSection(context, brokersWithDebt),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(
      double totalDebt, double totalPaid, double totalBalance, double paidPercent) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _headerController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _headerController, curve: Curves.easeOut),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: AnimatedBuilder(
                      animation: _headerController,
                      builder: (context, child) {
                        final animatedPercent =
                            paidPercent * _headerController.value;
                        return CustomPaint(
                          painter: _RingPainter(
                            progress: animatedPercent,
                            trackColor: Colors.white.withValues(alpha: 0.15),
                            progressColor: Colors.white,
                            strokeWidth: 5,
                          ),
                          child: Center(
                            child: Text(
                              '${(animatedPercent * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u0626\u06ce\u0645\u06d5 \u0642\u06d5\u0631\u0632\u062f\u0627\u0631\u06cc\u0646',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            formatMoneyWithCurrency(totalBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeroMiniStat(
                      label: '\u06a9\u0695\u06cc\u0646',
                      value: formatMoneyWithCurrency(totalDebt),
                      icon: Icons.shopping_cart_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _HeroMiniStat(
                      label: '\u067e\u0627\u0631\u06d5\u062f\u0627\u0646',
                      value: formatMoneyWithCurrency(totalPaid),
                      icon: Icons.payments_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChips(int brokerCount, double totalDebt, double totalPaid) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _cardsController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _cardsController, curve: Curves.easeOut),
        child: Row(
          children: [
            _ChipCard(
              icon: Icons.people_rounded,
              color: const Color(0xFF3B82F6),
              label: '\u0628\u0631\u06cc\u06a9\u0627\u0631',
              value: '$brokerCount',
            ),
            const SizedBox(width: 10),
            _ChipCard(
              icon: Icons.trending_up_rounded,
              color: AppTheme.warningColor,
              label: '\u06a9\u0695\u06cc\u0646',
              value: formatMoney(totalDebt),
            ),
            const SizedBox(width: 10),
            _ChipCard(
              icon: Icons.trending_down_rounded,
              color: AppTheme.successColor,
              label: '\u067e\u0627\u0631\u06d5\u062f\u0627\u0646',
              value: formatMoney(totalPaid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralStatementButton(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _cardsController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _cardsController, curve: Curves.easeOut),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/general-statement'),
            icon: const Icon(Icons.summarize_rounded, size: 18),
            label: const Text('کەشفی حیسابی گشتی'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelsButton(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _cardsController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _cardsController, curve: Curves.easeOut),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/labels'),
            icon: const Icon(Icons.label_rounded, size: 18),
            label: const Text('لەیبڵی کاڵاکان'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _listController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _listController, curve: Curves.easeOut),
        child: Consumer<ActivityLogProvider>(
          builder: (context, logProvider, _) {
            final logs = logProvider.logs;
            if (logs.isEmpty && !logProvider.isLoading) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  title: '\u06a9\u0627\u0631\u06d5\u06a9\u0627\u0646\u06cc \u062f\u0648\u0627\u06cc\u06cc\u06d5',
                ),
                const SizedBox(height: 10),
                if (logProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF7C3AED)),
                    ),
                  )
                else
                  ...logs.take(5).indexed.map((entry) {
                    final (i, log) = entry;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 350 + i * 80),
                      curve: Curves.easeOut,
                      builder: (context, val, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * (1 - val)),
                          child: Opacity(opacity: val, child: child),
                        );
                      },
                      child: _ActivityTile(log: log),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDebtSection(
      BuildContext context, List brokersWithDebt) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _listController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _listController, curve: Curves.easeOut),
        child: brokersWithDebt.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppTheme.dangerColor,
                    title: '\u0642\u06d5\u0631\u0632\u06cc \u0626\u06ce\u0645\u06d5 (${brokersWithDebt.length})',
                  ),
                  const SizedBox(height: 10),
                  ...brokersWithDebt.indexed.map((entry) {
                    final (i, broker) = entry;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 350 + i * 80),
                      curve: Curves.easeOut,
                      builder: (context, val, child) {
                        return Transform.translate(
                          offset: Offset(0, 12 * (1 - val)),
                          child: Opacity(opacity: val, child: child),
                        );
                      },
                      child: _DebtBrokerTile(broker: broker),
                    );
                  }),
                ],
              )
            : _buildNoDebtState(),
      ),
    );
  }

  Widget _buildNoDebtState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded,
                  size: 52, color: AppTheme.successColor),
            ),
            const SizedBox(height: 16),
            const Text(
              '\u0647\u06cc\u0686 \u0642\u06d5\u0631\u0632\u06ce\u06a9\u0645\u0627\u0646 \u0646\u06cc\u06cc\u06d5!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '\u0647\u06d5\u0645\u0648\u0648 \u062d\u06cc\u0633\u0627\u0628\u06d5\u06a9\u0627\u0646 \u0695\u0627\u0633\u062a\u06a9\u0631\u0627\u0648\u0646\u06d5\u062a\u06d5\u0648\u06d5',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ChipCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityLog log;
  const _ActivityTile({required this.log});

  IconData _getIcon() {
    switch (log.actionType) {
      case 'create':
        return Icons.add_circle_outline_rounded;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'payment':
        return Icons.payments_outlined;
      case 'login':
        return Icons.login_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionInfo = log.actionIcon;
    final color = Color(actionInfo.colorValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(_getIcon(), size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.description,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(log.userName,
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade500)),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(formatDate(log.created),
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                actionInfo.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtBrokerTile extends StatelessWidget {
  final dynamic broker;
  const _DebtBrokerTile({required this.broker});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        broker.imageUrl != null && broker.imageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Clickable(
        onTap: () => Navigator.of(context)
            .pushNamed('/broker-detail', arguments: broker.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  alignment: Alignment.center,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: broker.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 120),
                          placeholder: (c, _) => Container(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          ),
                          errorWidget: (c, _, _) => Text(
                            broker.name.isNotEmpty
                                ? broker.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor),
                          ),
                        )
                      : Text(
                          broker.name.isNotEmpty
                              ? broker.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(broker.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (broker.companyName != null &&
                        broker.companyName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(broker.companyName!,
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatMoneyWithCurrency(broker.balance),
                  style: const TextStyle(
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress;
}