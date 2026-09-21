import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/broker_provider.dart';
import '../../providers/payment_provider.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _filterType = 'all'; // all, debt, cash

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrokerProvider>().loadBrokers();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<BrokerProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            final allBrokers = provider.brokers;
            final totalDebt = allBrokers
                .where((b) => b.balance > 0)
                .fold<double>(0, (sum, b) => sum + b.balance);
            final debtCount = allBrokers.where((b) => b.balance > 0).length;
            final cashCount = allBrokers.where((b) => b.balance <= 0).length;

            var filteredBrokers = allBrokers.where((b) {
              final matchesSearch =
                  b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      b.phone.contains(_searchQuery) ||
                      (b.companyName ?? '')
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
              bool matchesFilter = true;
              if (_filterType == 'debt') matchesFilter = b.balance > 0;
              if (_filterType == 'cash') matchesFilter = b.balance <= 0;
              return matchesSearch && matchesFilter;
            }).toList();

            filteredBrokers.sort((a, b) => b.balance.compareTo(a.balance));

            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () => provider.loadBrokers(),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: '\u06af\u06d5\u0695\u0627\u0646 \u0628\u06c6 \u0628\u0631\u06cc\u06a9\u0627\u0631...',
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

                  // Filter chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: '\u0647\u06d5\u0645\u0648\u0648\u06cc',
                            isSelected: _filterType == 'all',
                            onTap: () =>
                                setState(() => _filterType = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '\u0642\u06d5\u0631\u0632\u062f\u0627\u0631',
                            isSelected: _filterType == 'debt',
                            onTap: () =>
                                setState(() => _filterType = 'debt'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '\u0628\u06ce \u0642\u06d5\u0631\u0632',
                            isSelected: _filterType == 'cash',
                            onTap: () =>
                                setState(() => _filterType = 'cash'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Summary bar
                  Padding(
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
                            label: '\u06a9\u06c6\u06cc \u0642\u06d5\u0631\u0632',
                            value: formatMoneyWithCurrency(totalDebt),
                            color: AppTheme.dangerColor,
                          ),
                          const Spacer(),
                          _MiniStat(
                            icon: Icons.warning_amber_rounded,
                            label: '\u0642\u06d5\u0631\u0632\u062f\u0627\u0631',
                            value: '$debtCount',
                            color: AppTheme.warningColor,
                          ),
                          const SizedBox(width: 20),
                          _MiniStat(
                            icon: Icons.check_circle_outline_rounded,
                            label: '\u0628\u06ce \u0642\u06d5\u0631\u0632',
                            value: '$cashCount',
                            color: AppTheme.successColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Broker list
                  Expanded(
                    child: filteredBrokers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.people_outline_rounded,
                                      size: 48, color: Colors.grey.shade400),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? '\u0647\u06cc\u0686 \u0626\u06d5\u0646\u062c\u0627\u0645\u06ce\u06a9 \u0646\u06d5\u062f\u06c6\u0632\u0631\u0627\u06cc\u06d5\u0648\u06d5'
                                      : '\u0647\u06cc\u0686 \u0628\u0631\u06cc\u06a9\u0627\u0631\u06ce\u06a9 \u0646\u06cc\u06cc\u06d5',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            itemCount: filteredBrokers.length,
                            itemBuilder: (context, index) {
                              final broker = filteredBrokers[index];
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(
                                    milliseconds:
                                        300 + (index % 10) * 50),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 15 * (1 - value)),
                                    child: Opacity(
                                        opacity: value, child: child),
                                  );
                                },
                                child: _buildBrokerTile(context, broker),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrokerTile(BuildContext context, dynamic broker) {
    final bool hasDebt = broker.balance > 0;
    final typeColor = hasDebt ? AppTheme.dangerColor : AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Clickable(
        onTap: () => Navigator.of(context)
            .pushNamed('/broker-detail', arguments: broker.id),
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
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  image: broker.imageUrl != null && broker.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(broker.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: broker.imageUrl != null && broker.imageUrl!.isNotEmpty
                    ? null
                    : Text(
                        broker.name.isNotEmpty
                            ? broker.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
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
                            broker.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (broker.companyName != null &&
                            broker.companyName!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              broker.companyName!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          hasDebt
                              ? '\u0642\u06d5\u0631\u0632'
                              : '\u0628\u06ce \u0642\u06d5\u0631\u0632',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (broker.phone.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.phone_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text(broker.phone,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                              textDirection: TextDirection.ltr),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Amount + pay button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasDebt)
                    Clickable(
                      onTap: () => _showPaymentSheet(
                        brokerId: broker.id,
                        brokerName: broker.name,
                        balance: broker.balance,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            size: 16, color: AppTheme.successColor),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    formatMoneyWithCurrency(broker.balance.abs()),
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
      ),
    );
  }

  void _showPaymentSheet({
    required String brokerId,
    required String brokerName,
    required double balance,
  }) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    List<XFile> receiptImages = [];
    List<Uint8List> receiptBytes = [];

    void setAmount(double amt) {
      if (amt <= 0) return;
      final val = amt.truncate().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17)),
                            Text(brokerName,
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          formatMoneyWithCurrency(balance),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.dangerColor,
                          ),
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
                          label: '\u0647\u06d5\u0645\u0648\u0648\u06cc',
                          subtitle: formatMoneyWithCurrency(balance),
                          onTap: () => setAmount(balance),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountBtn(
                          label: '\u0646\u06cc\u0648\u06d5\u06cc',
                          subtitle: formatMoneyWithCurrency(balance / 2),
                          onTap: () => setAmount(balance / 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountBtn(
                          label: '\u0686\u0627\u0631\u06cc\u06cc\u06d5\u06a9',
                          subtitle: formatMoneyWithCurrency(balance / 4),
                          onTap: () => setAmount(balance / 4),
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
                      fillColor:
                          AppTheme.successColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '\u0628\u0695 \u067e\u06ce\u0648\u06cc\u0633\u062a\u06d5';
                      final val =
                          double.tryParse(v.replaceAll(',', ''));
                      if (val == null || val <= 0) {
                        return '\u0698\u0645\u0627\u0631\u06d5\u06cc \u062f\u0631\u0648\u0633\u062a \u0628\u0646\u0648\u0648\u0633\u06d5';
                      }
                      if (balance > 0 && val > balance) {
                        return '\u0646\u0627\u062a\u0648\u0627\u0646\u06cc\u062a \u0632\u06cc\u0627\u062a\u0631 \u0644\u06d5 ${formatMoneyWithCurrency(balance)} \u0628\u062f\u06d5\u06cc\u062a';
                      }
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
                  const SizedBox(height: 12),
                  // Receipt images
                  Row(
                    children: [
                      Text('\u067e\u0633\u0648\u06b5\u06d5\u06cc \u067e\u0627\u0631\u06d5\u062f\u0627\u0646', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
                      const Spacer(),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.camera_alt_rounded, size: 20, color: AppTheme.primaryColor),
                          tooltip: '\u0648\u06ce\u0646\u06d5 \u0628\u06af\u0631\u06d5',
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
                        tooltip: '\u0644\u06d5 \u06af\u0627\u06b5\u06d5\u0631\u06cc',
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
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              setSheetState(
                                  () => isSubmitting = true);
                              final payProvider =
                                  context.read<PaymentProvider>();
                              final brokerProv =
                                  context.read<BrokerProvider>();
                              final success =
                                  await payProvider.addPayment(
                                brokerId: brokerId,
                                amount: double.parse(amountController
                                    .text
                                    .replaceAll(',', '')),
                                paymentDate: DateTime.now(),
                                notes:
                                    notesController.text.trim(),
                                receiptImages: receiptImages.isNotEmpty ? receiptImages : null,
                              );
                              if (success) {
                                brokerProv.loadBrokers();
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          '\u067e\u0627\u0631\u06d5\u062f\u0627\u0646\u06d5\u06a9\u06d5 \u0628\u06d5 \u0633\u06d5\u0631\u06a9\u06d5\u0648\u062a\u0648\u0648\u06cc\u06cc \u062a\u06c6\u0645\u0627\u0631\u06a9\u0631\u0627'),
                                      backgroundColor:
                                          AppTheme.successColor,
                                      behavior:
                                          SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10)),
                                    ),
                                  );
                                }
                              }
                              setSheetState(
                                  () => isSubmitting = false);
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
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                          : const Text(
                              '\u062a\u06c6\u0645\u0627\u0631\u06a9\u0631\u062f\u0646\u06cc \u067e\u0627\u0631\u06d5\u062f\u0627\u0646',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
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

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
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
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
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
          border:
              Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
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
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade500)),
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
