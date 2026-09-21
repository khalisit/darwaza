import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/broker_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/payment_provider.dart';
import '../../models/broker.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Date filter
  String _dateFilter = 'today'; // today, week, month, custom, all
  DateTime? _customFrom;
  DateTime? _customTo;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(refresh: true);
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<TransactionProvider>();
      if (!provider.isLoading && !provider.isLoadingMore && provider.hasMore) {
        _loadData();
      }
    }
  }

  DateTime get _dateFrom {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'custom':
        return _customFrom ?? DateTime(now.year, now.month, now.day);
      default:
        return DateTime(2000);
    }
  }

  DateTime get _dateTo {
    final now = DateTime.now();
    if (_dateFilter == 'custom' && _customTo != null) {
      return _customTo!;
    }
    return now;
  }

  Future<void> _loadData({bool refresh = false}) async {
    final provider = context.read<TransactionProvider>();
    await provider.loadTransactionsPaginated(
      dateFrom: _dateFilter != 'all' ? _dateFrom : null,
      dateTo: _dateFilter != 'all' ? _dateTo : null,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      refresh: refresh,
    );
  }

  void _onFilterChanged(String filter) {
    setState(() => _dateFilter = filter);
    _loadData(refresh: true);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: now),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppTheme.primaryColor,
                  ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (range != null) {
      setState(() {
        _customFrom = range.start;
        _customTo = range.end;
        _dateFilter = 'custom';
      });
      _loadData(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BrokerProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search bar + Add button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          setState(() => _searchQuery = v);
                          _loadData(refresh: true);
                        },
                        decoration: InputDecoration(
                          hintText: '\u06af\u06d5\u0695\u0627\u0646...',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w400),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey.shade400, size: 22),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: Colors.grey.shade400, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _loadData(refresh: true);
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Clickable(
                    onTap: () => Navigator.of(context)
                        .pushNamed('/add-transaction')
                        .then((_) => _loadData(refresh: true)),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),

            // Date filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: '\u0626\u06d5\u0645\u0695\u06c6',
                      isSelected: _dateFilter == 'today',
                      onTap: () => _onFilterChanged('today'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '\u0626\u06d5\u0645 \u06be\u06d5\u0641\u062a\u06d5\u06cc\u06d5',
                      isSelected: _dateFilter == 'week',
                      onTap: () => _onFilterChanged('week'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '\u0626\u06d5\u0645 \u0645\u0627\u0646\u06af\u06d5',
                      isSelected: _dateFilter == 'month',
                      onTap: () => _onFilterChanged('month'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _dateFilter == 'custom' &&
                              _customFrom != null &&
                              _customTo != null
                          ? '${formatDate(_customFrom!)} - ${formatDate(_customTo!)}'
                          : '\u0628\u06d5\u0631\u0648\u0627\u0631\u06cc \u062f\u06cc\u0627\u0631\u06cc\u06a9\u0631\u0627\u0648',
                      isSelected: _dateFilter == 'custom',
                      icon: Icons.date_range_rounded,
                      onTap: _pickCustomRange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '\u06be\u06d5\u0645\u0648\u0648\u06cc',
                      isSelected: _dateFilter == 'all',
                      onTap: () => _onFilterChanged('all'),
                    ),
                  ],
                ),
              ),
            ),

            // Summary bar
            Consumer<TransactionProvider>(
              builder: (context, txProvider, _) {
                if (txProvider.isLoading || txProvider.transactions.isEmpty) {
                  return const SizedBox.shrink();
                }
                final txs = txProvider.transactions;
                final totalAmount =
                    txs.fold<double>(0, (sum, t) => sum + t.finalAmount);
                final creditCount = txs.where((t) => t.isCredit).length;
                final cashCount = txs.where((t) => !t.isCredit).length;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _MiniStat(
                          icon: Icons.account_balance_wallet_rounded,
                          label: '\u06a9\u06c6\u06cc \u06af\u0634\u062a\u06cc',
                          value: formatMoneyWithCurrency(totalAmount),
                          color: AppTheme.primaryColor,
                        ),
                        const Spacer(),
                        _MiniStat(
                          icon: Icons.schedule_rounded,
                          label: '\u0642\u06d5\u0631\u0632',
                          value: '$creditCount',
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 20),
                        _MiniStat(
                          icon: Icons.payments_rounded,
                          label: '\u0646\u06d5\u0642\u062f',
                          value: '$cashCount',
                          color: AppTheme.successColor,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Transaction list
            Expanded(
              child: Consumer2<TransactionProvider, BrokerProvider>(
                builder: (context, txProvider, brokerProvider, _) {
                  if (txProvider.isLoading && txProvider.transactions.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor),
                    );
                  }

                  if (txProvider.transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.shopping_cart_outlined,
                                size: 48, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? '\u06be\u06cc\u0686 \u0626\u06d5\u0646\u062c\u0627\u0645\u06ce\u06a9 \u0646\u06d5\u062f\u06c6\u0632\u0631\u0627\u06cc\u06d5\u0648\u06d5'
                                : '\u06be\u06cc\u0686 \u06a9\u0695\u06cc\u0646\u06ce\u06a9 \u0646\u06cc\u06cc\u06d5',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 15,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () => _loadData(refresh: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: txProvider.transactions.length +
                          (txProvider.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= txProvider.transactions.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.primaryColor),
                              ),
                            ),
                          );
                        }

                        final tx = txProvider.transactions[index];
                        final broker =
                            _findBroker(brokerProvider, tx.brokerId);

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration:
                              Duration(milliseconds: 300 + (index % 10) * 50),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 15 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TxCard(
                              brokerName: broker?.name ?? '\u0646\u06d5\u0646\u0627\u0633\u0631\u0627\u0648',
                              brokerImageUrl: broker?.imageUrl,
                              amount: tx.finalAmount,
                              isCredit: tx.isCredit,
                              date: tx.transactionDate,
                              partnerName: tx.partnerName,
                              createdBy: tx.createdBy,
                              hasDiscount: tx.discount > 0,
                              notes: tx.notes,
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  '/transaction-detail',
                                  arguments: {
                                    'transactionId': tx.id,
                                    'brokerId': tx.brokerId,
                                  },
                                ).then((_) => _loadData(refresh: true));
                              },
                              onQuickPay: tx.isCredit
                                  ? () => _showQuickPaySheet(
                                        brokerId: tx.brokerId,
                                        brokerName: broker?.name ?? '',
                                        amount: tx.finalAmount,
                                      )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Broker? _findBroker(BrokerProvider provider, String brokerId) {
    try {
      return provider.brokers.firstWhere((b) => b.id == brokerId);
    } catch (_) {
      return null;
    }
  }

  void _showQuickPaySheet({
    required String brokerId,
    required String brokerName,
    required double amount,
  }) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    void setAmount(double amt) {
      if (amt <= 0) return;
      final val = amt.truncate().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '\${m[1]},');
      amountController.value = TextEditingValue(
        text: val,
        selection: TextSelection.collapsed(offset: val.length),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: AppTheme.successColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('\u067e\u0627\u0631\u06d5\u062f\u0627\u0646\u06cc \u062e\u06ce\u0631\u0627',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 17)),
                            Text(brokerName,
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Quick amount buttons
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAmountBtn(
                          label: '\u06be\u06d5\u0645\u0648\u0648\u06cc',
                          subtitle: formatMoneyWithCurrency(amount),
                          onTap: () => setAmount(amount),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountBtn(
                          label: '\u0646\u06cc\u0648\u06d5\u06cc',
                          subtitle: formatMoneyWithCurrency(amount / 2),
                          onTap: () => setAmount(amount / 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountBtn(
                          label: '\u0686\u0627\u0631\u06cc\u06d5\u06a9',
                          subtitle: formatMoneyWithCurrency(amount / 4),
                          onTap: () => setAmount(amount / 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Amount field
                  TextFormField(
                    controller: amountController,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.successColor),
                    inputFormatters: [_CurrencyFormatter()],
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade300),
                      suffixText: '\u062f.\u0639',
                      filled: true,
                      fillColor: AppTheme.successColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '\u0628\u0695 \u067e\u06ce\u0648\u06cc\u0633\u062a\u06d5';
                      final val = double.tryParse(v.replaceAll(',', ''));
                      if (val == null || val <= 0) return '\u0698\u0645\u0627\u0631\u06d5\u06cc \u062f\u0631\u0648\u0633\u062a \u0628\u0646\u0648\u0648\u0633\u06d5';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Notes field
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: '\u062a\u06ce\u0628\u06cc\u0646\u06cc (\u0626\u0627\u0631\u06d5\u0632\u0648\u0648\u0645\u06d5\u0646\u062f\u0627\u0646\u06d5)...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSubmitting = true);
                              final payProvider =
                                  context.read<PaymentProvider>();
                              final brokerProv =
                                  context.read<BrokerProvider>();
                              final success = await payProvider.addPayment(
                                brokerId: brokerId,
                                amount: double.parse(
                                    amountController.text.replaceAll(',', '')),
                                paymentDate: DateTime.now(),
                                notes: notesController.text.trim(),
                              );
                              if (success) {
                                brokerProv.loadBrokers();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  _loadData(refresh: true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          '\u067e\u0627\u0631\u06d5\u062f\u0627\u0646\u06d5\u06a9\u06d5 \u0628\u06d5 \u0633\u06d5\u0631\u06a9\u06d5\u0648\u062a\u0648\u0648\u06cc\u06cc \u062a\u06c6\u0645\u0627\u0631\u06a9\u0631\u0627'),
                                      backgroundColor: AppTheme.successColor,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              }
                              setSheetState(() => isSubmitting = false);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('\u062a\u06c6\u0645\u0627\u0631\u06a9\u0631\u062f\u0646\u06cc \u067e\u0627\u0631\u06d5\u062f\u0627\u0646',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter chip ────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: isSelected ? Colors.white : Colors.grey.shade500),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini stat ──────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      ],
    );
  }
}

// ─── Transaction card ───────────────────────────────────────
class _TxCard extends StatelessWidget {
  final String brokerName;
  final String? brokerImageUrl;
  final double amount;
  final bool isCredit;
  final DateTime date;
  final String? notes;
  final String? partnerName;
  final String? createdBy;
  final bool hasDiscount;
  final VoidCallback onTap;
  final VoidCallback? onQuickPay;

  const _TxCard({
    required this.brokerName,
    this.brokerImageUrl,
    required this.amount,
    required this.isCredit,
    required this.date,
    this.notes,
    this.partnerName,
    this.createdBy,
    this.hasDiscount = false,
    required this.onTap,
    this.onQuickPay,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = isCredit ? AppTheme.warningColor : AppTheme.successColor;

    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Broker avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                image: brokerImageUrl != null && brokerImageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(brokerImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: brokerImageUrl != null && brokerImageUrl!.isNotEmpty
                  ? null
                  : Icon(
                      isCredit ? Icons.schedule_rounded : Icons.payments_rounded,
                      color: typeColor,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          brokerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (partnerName != null &&
                          partnerName!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            partnerName!,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                      if (hasDiscount)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4),
                          child: Icon(Icons.discount_rounded,
                              size: 14,
                              color:
                                  AppTheme.dangerColor.withValues(alpha: 0.6)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        formatDate(date),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      if (createdBy != null && createdBy!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.person_outline_rounded,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(createdBy!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                  if (notes != null && notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.note_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Amount & type badge & quick pay
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCredit ? '\u0642\u06d5\u0631\u0632' : '\u0646\u06d5\u0642\u062f',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoneyWithCurrency(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: typeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick amount button ────────────────────────────────────
class _QuickAmountBtn extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAmountBtn({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.successColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successColor)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(subtitle,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Currency formatter ─────────────────────────────────────
class _CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text.replaceAll(',', '');
    final value = double.tryParse(text);
    if (value == null) return oldValue.text.isEmpty ? newValue : oldValue;
    final formatted = value.truncate().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
