import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/broker_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/payment_provider.dart';
import '../../models/broker.dart';
import '../../models/payment.dart';
import 'brokers_screen.dart'; // Import to use BrokerFormSheet

class BrokerDetailScreen extends StatefulWidget {
  final String brokerId;
  const BrokerDetailScreen({super.key, required this.brokerId});

  @override
  State<BrokerDetailScreen> createState() => _BrokerDetailScreenState();
}

class _BrokerDetailScreenState extends State<BrokerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    context.read<TransactionProvider>().loadTransactions(brokerId: widget.brokerId);
    context.read<PaymentProvider>().loadPayments(brokerId: widget.brokerId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brokers = context.watch<BrokerProvider>().brokers;
    Broker? broker;
    try {
      broker = brokers.firstWhere((b) => b.id == widget.brokerId);
    } catch (_) {
      broker = null;
    }
    if (broker == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('بریکار نەدۆزرایەوە')),
        ),
      );
    }
    final Broker b = broker;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // Beautiful Sliver App Bar
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(right: 48, bottom: 60, left: 16),
                title: Text(
                  b.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        ),
                      ),
                    ),
                    // Decorative circles
                    Positioned(
                      right: -30,
                      top: -20,
                      child: CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -40,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  tooltip: 'دەسکاری کردن',
                  onPressed: () => _updateBroker(context, b),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  tooltip: 'ڕەشکردنەوە',
                  onPressed: () => _deleteBroker(context),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                  tooltip: 'کەشفی حیساب',
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/account-statement', arguments: widget.brokerId),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey.shade500,
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('کڕینەکان', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('پارەدانەکان', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Balance Card Section
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (b.companyName != null && b.companyName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 24, left: 24),
                        child: Row(
                          children: [
                            Icon(Icons.business_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(b.companyName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (b.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 24, left: 24),
                        child: Row(
                          children: [
                            Icon(Icons.phone_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(b.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textDirection: TextDirection.ltr),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    _BalanceCard(brokerId: widget.brokerId),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],

          // Tab Views
          body: Container(
            color: AppTheme.surfaceLight,
            child: TabBarView(
              controller: _tabController,
              children: [
                _TransactionsTab(
                  brokerId: widget.brokerId,
                  onQuickPay: (double amount) => _showAddPaymentDialog(prefillAmount: amount),
                ),
                _PaymentsTab(brokerId: widget.brokerId),
              ],
            ),
          ),
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => TweenAnimationBuilder<double>(
            key: ValueKey(_tabController.index),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: FloatingActionButton.extended(
                  heroTag: 'broker_detail_fab',
                  onPressed: () {
                    if (_tabController.index == 0) {
                      Navigator.of(context)
                          .pushNamed('/add-transaction', arguments: widget.brokerId);
                    } else {
                      _showAddPaymentDialog();
                    }
                  },
                  backgroundColor: _tabController.index == 0 
                      ? AppTheme.primaryColor 
                      : AppTheme.successColor,
                  icon: Icon(
                    _tabController.index == 0 ? Icons.add_shopping_cart_rounded : Icons.add_circle_outline_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _tabController.index == 0 ? 'کڕینی نوێ' : 'پارەدان',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _updateBroker(BuildContext context, Broker broker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BrokerFormSheet(
        broker: broker,
        onSave: () {
          // Provider will auto-refresh the data
        },
      ),
    );
  }

  void _deleteBroker(BuildContext context) {
    final txProvider = context.read<TransactionProvider>();
    final payProvider = context.read<PaymentProvider>();
    final totalDebt = txProvider.transactions.fold<double>(0, (s, t) => s + t.finalAmount);
    final totalPaid = payProvider.payments.fold<double>(0, (s, p) => s + p.amount);
    final balance = totalDebt - totalPaid;

    if (balance > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ناتوانیت ئەم بریکارە ڕەشبکەیتەوە، چونکە بڕی ${formatMoneyWithCurrency(balance)} قەرزی ماوە.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    final brokerProv = context.read<BrokerProvider>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('ڕەشکردنەوەی بریکار', style: TextStyle(color: AppTheme.dangerColor)),
          content: const Text('دڵنیایت لە ڕەشکردنەوەی ئەم بریکارە؟ بەم کارە تەواوی کڕین و پارەدانەکانی ئەم بریکارەش ڕەشدەبنەوە و ناگەڕێتەوە.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final success = await brokerProv.deleteBroker(widget.brokerId);
                  if (success) {
                    nav.pop();
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('هەڵە لە ڕەشکردنەوەی بریکار'),
                        backgroundColor: AppTheme.dangerColor,
                      ),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('هەڵە: $e'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('ڕەشکردنەوە'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog({double? prefillAmount}) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    List<XFile> receiptImages = [];
    List<Uint8List> receiptBytes = [];

    // Calculate current debt
    final txProvider = context.read<TransactionProvider>();
    final payProvider = context.read<PaymentProvider>();
    final totalDebt = txProvider.transactions.fold<double>(0, (s, t) => s + t.finalAmount);
    final totalPaid = payProvider.payments.fold<double>(0, (s, p) => s + p.amount);
    final balance = totalDebt - totalPaid;
    bool isSubmitting = false;

    void setAmount(double amt) {
      if (amt <= 0) return;
      final val = amt.truncate().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
      amountController.value = TextEditingValue(
        text: val,
        selection: TextSelection.collapsed(offset: val.length),
      );
    }

    if (prefillAmount != null && prefillAmount > 0) {
      setAmount(prefillAmount);
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
                            const Text('پارەدانی نوێ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 17)),
                            if (balance > 0)
                              Text(
                                  'قەرزی ماوە: ${formatMoneyWithCurrency(balance)}',
                                  style: TextStyle(
                                      color: AppTheme.dangerColor.withValues(alpha: 0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Quick amount buttons
                  if (balance > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _QuickAmtBtn(
                              label: 'هەمووی',
                              subtitle: formatMoneyWithCurrency(balance),
                              onTap: () => setAmount(balance),
                              color: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickAmtBtn(
                              label: 'نیوەی',
                              subtitle: formatMoneyWithCurrency(balance / 2),
                              onTap: () => setAmount(balance / 2),
                              color: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickAmtBtn(
                              label: 'چارییەک',
                              subtitle: formatMoneyWithCurrency(balance / 4),
                              onTap: () => setAmount(balance / 4),
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade300),
                      suffixText: 'د.ع',
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
                      if (v == null || v.isEmpty) return 'بڕ پێویستە';
                      final val = double.tryParse(v.replaceAll(',', ''));
                      if (val == null || val <= 0) return 'ژمارەی دروست بنووسە';
                      if (balance > 0 && val > balance) {
                        return 'ناتوانیت زیاتر لە ${formatMoneyWithCurrency(balance)} بدەیت';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Notes field
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'تێبینی (ئارەزوومەندانە)...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  // Receipt images
                  Row(
                    children: [
                      Text('پسوڵەی پارەدان', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
                      const Spacer(),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.camera_alt_rounded, size: 20, color: AppTheme.primaryColor),
                          tooltip: 'وێنە بگرە',
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setSheetState(() { receiptImages.add(picked); receiptBytes.add(bytes); });
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.photo_library_rounded, size: 20, color: AppTheme.primaryColor),
                        tooltip: 'لە گاڵەری',
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickMultiImage(imageQuality: 70);
                          if (picked.isNotEmpty) {
                            for (final p in picked) {
                              final bytes = await p.readAsBytes();
                              receiptImages.add(p);
                              receiptBytes.add(bytes);
                            }
                            setSheetState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  if (receiptImages.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: receiptImages.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(receiptBytes[i], width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2, right: 2,
                                child: GestureDetector(
                                  onTap: () => setSheetState(() { receiptImages.removeAt(i); receiptBytes.removeAt(i); }),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                              final payProvider = context.read<PaymentProvider>();
                              final brokerProv = context.read<BrokerProvider>();
                              final success = await payProvider.addPayment(
                                brokerId: widget.brokerId,
                                amount: double.parse(
                                    amountController.text.replaceAll(',', '')),
                                paymentDate: DateTime.now(),
                                notes: notesController.text.trim(),
                                receiptImages: receiptImages.isNotEmpty ? receiptImages : null,
                              );
                              if (success) {
                                brokerProv.loadBrokers();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'پارەدانەکە بە سەرکەوتوویی تۆمارکرا'),
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
                          : const Text('تۆمارکردنی پارەدان',
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

class _QuickAmtBtn extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _QuickAmtBtn({
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String brokerId;
  const _BalanceCard({required this.brokerId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, PaymentProvider>(
      builder: (context, txProvider, payProvider, _) {
        final totalDebt =
          txProvider.transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);
        final totalPaid =
            payProvider.payments.fold<double>(0, (sum, p) => sum + p.amount);
        final balance = totalDebt - totalPaid;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: balance > 0
                  ? [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]
                  : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
            ),
            border: Border.all(
              color: balance > 0
                  ? AppTheme.dangerColor.withValues(alpha: 0.2)
                  : AppTheme.successColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _BalanceItem(label: 'کۆی کڕین', amount: totalDebt, color: AppTheme.warningColor, icon: Icons.shopping_cart_rounded)),
                  Container(width: 1, height: 45, color: Colors.grey.shade300),
                  Expanded(child: _BalanceItem(label: 'کۆی پارەدان', amount: totalPaid, color: AppTheme.successColor, icon: Icons.payments_rounded)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white.withValues(alpha: 0.5), thickness: 1.5),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'قەرزی ماوە: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: balance > 0 ? AppTheme.dangerColor : AppTheme.successColor,
                    ),
                  ),
                  Text(
                    formatMoneyWithCurrency(balance),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: balance > 0 ? AppTheme.dangerColor : AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _BalanceItem({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatMoney(amount),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        Text('د.ع', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  final String brokerId;
  final void Function(double amount)? onQuickPay;
  const _TransactionsTab({required this.brokerId, this.onQuickPay});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, PaymentProvider>(
      builder: (context, provider, payProvider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.transactions.isEmpty) {
          return _EmptyState(icon: Icons.shopping_cart_outlined, message: 'هیچ کڕینێک نییە');
        }

        final totalDebt = provider.transactions.fold<double>(0, (s, t) => s + t.finalAmount);
        final totalPaid = payProvider.payments.fold<double>(0, (s, p) => s + p.amount);
        final remainingBalance = totalDebt - totalPaid;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: provider.transactions.length,
          itemBuilder: (context, index) {
            final tx = provider.transactions[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).pushNamed(
                    '/transaction-detail',
                    arguments: {'transactionId': tx.id, 'brokerId': brokerId},
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: tx.isCredit 
                                  ? [const Color(0xFFFDE68A), const Color(0xFFF59E0B)]
                                  : [const Color(0xFF6EE7B7), const Color(0xFF10B981)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (tx.isCredit ? AppTheme.warningColor : AppTheme.successColor).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(
                            tx.isCredit ? Icons.credit_card_rounded : Icons.money_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatMoneyWithCurrency(tx.finalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(formatDate(tx.transactionDate),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  if (tx.discount > 0) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.discount_rounded, size: 12, color: AppTheme.dangerColor.withValues(alpha: 0.7)),
                                  ],
                                ],
                              ),
                              if (tx.createdBy != null && tx.createdBy!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      tx.createdBy!,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tx.isCredit && onQuickPay != null && remainingBalance > 0)
                                  Clickable(
                                    onTap: () => onQuickPay!(remainingBalance),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      margin: const EdgeInsetsDirectional.only(end: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.payments_rounded,
                                          size: 16, color: AppTheme.successColor),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (tx.isCredit ? AppTheme.warningColor : AppTheme.successColor)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tx.isCredit ? 'قەرز' : 'نەقد',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: tx.isCredit ? AppTheme.warningColor : AppTheme.successColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final String brokerId;
  const _PaymentsTab({required this.brokerId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.payments.isEmpty) {
          return _EmptyState(icon: Icons.payments_outlined, message: 'هیچ پارەدانێک نییە');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: provider.payments.length,
          itemBuilder: (context, index) {
            final payment = provider.payments[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final url = provider.getPaymentReceiptUrl(payment);
                    if (url != null) {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(url, fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Padding(
                                padding: EdgeInsets.all(32),
                                child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: AppTheme.successColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatMoneyWithCurrency(payment.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.successColor)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(formatDate(payment.paymentDate),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                if (payment.createdBy != null && payment.createdBy!.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.person_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(payment.createdBy!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (payment.receipt != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image_rounded, size: 18, color: AppTheme.primaryColor),
                          ),
                        ),
                      if (payment.notes != null && payment.notes!.isNotEmpty)
                        Tooltip(
                          message: payment.notes!,
                          triggerMode: TooltipTriggerMode.tap,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: (){},
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.note_alt_outlined, size: 18, color: Colors.blue),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Clickable(
                        onTap: () => _confirmDeletePayment(context, payment, provider),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerColor),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePayment(BuildContext context, Payment payment, PaymentProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final brokerProv = context.read<BrokerProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('سڕینەوەی پارەدان', style: TextStyle(color: AppTheme.dangerColor)),
          content: Text('دڵنیایت لە سڕینەوەی پارەدانی ${formatMoneyWithCurrency(payment.amount)}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('نەخێر'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('سڕینەوە'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      try {
        final ok = await provider.deletePayment(payment.id, brokerId: brokerId);
        if (ok) {
          brokerProv.loadBrokers();
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('هەڵە لە سڕینەوەی پارەدان'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                        )
                      ],
                    ),
                    child: Icon(icon, size: 48, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 16),
                  Text(message, 
                      style: TextStyle(
                        color: Colors.grey.shade500, 
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    // Strip commas to parse
    final text = newValue.text.replaceAll(',', '');
    final value = double.tryParse(text);
    if (value == null) return oldValue.text.isEmpty ? newValue : oldValue;
    
    // Add commas back
    final formattedValue = value.truncate().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}
