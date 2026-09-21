import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/broker_provider.dart';
import '../../models/broker.dart';


class AddTransactionScreen extends StatefulWidget {
  final String? editTransactionId;
  final String? brokerId;

  const AddTransactionScreen({
    super.key,
    this.editTransactionId,
    this.brokerId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _partnerController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isCredit = true;
  DateTime _transactionDate = DateTime.now();
  String? _selectedBrokerId;
  List<TransactionItem> _items = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  final List<XFile> _receiptImages = [];
  final List<Uint8List> _receiptImageBytes = [];

  int _currentStep = 0;


  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;


  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _receiptImages.add(pickedFile);
          _receiptImageBytes.add(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '\u06be\u06d5\u06b5\u06d5 \u0695\u0648\u0648\u06cc\u062f\u0627 \u0644\u06d5 \u0648\u06d5\u0631\u06af\u0631\u062a\u0646\u06cc \u0648\u06ce\u0646\u06d5\u06a9\u06d5: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedBrokerId = widget.brokerId;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    if (widget.editTransactionId != null) {
      final txList = context.read<TransactionProvider>().transactions;
      final txIndex = txList.indexWhere(
        (t) => t.id == widget.editTransactionId,
      );
      if (txIndex == -1) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final tx = txList[txIndex];
      _partnerController.text = tx.partnerName ?? '';
      _notesController.text = tx.notes ?? '';
      _discountController.text = tx.discount > 0
          ? formatMoney(tx.discount)
          : '';
      _totalAmountController.text = tx.totalAmount > 0
          ? formatMoney(tx.totalAmount)
          : '';
      _isCredit = tx.isCredit;
      _transactionDate = tx.transactionDate;
      _selectedBrokerId = tx.brokerId;

      try {
        await context.read<TransactionProvider>().loadTransactionItems(tx.id);
        if (!mounted) return;
        final items = context.read<TransactionProvider>().currentItems;
        setState(() {
          _items = List.from(items);
          _isInitialized = true;
        });
      } catch (e) {
        setState(() => _isInitialized = true);
      }
    } else {
      setState(() => _isInitialized = true);
    }
    _fadeController.forward();
  }

  @override
  void dispose() {
    _partnerController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _totalAmountController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }


  double get _subtotal {
    if (_items.isNotEmpty) {
      return _items.fold(0, (sum, item) => sum + item.totalPrice);
    }
    return double.tryParse(_totalAmountController.text.replaceAll(',', '')) ?? 0;
  }

  double get _discount {
    return double.tryParse(_discountController.text.replaceAll(',', '')) ?? 0;
  }

  double get _finalTotal {
    return _subtotal - _discount;
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrokerId == null || _selectedBrokerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062a\u06a9\u0627\u06cc\u06d5 \u0628\u0631\u06cc\u06a9\u0627\u0631\u06ce\u06a9 \u0647\u06d5\u06b5\u0628\u0698\u06ce\u0631\u06d5',
          ),
        ),
      );
      return;
    }
    final manualTotal = double.tryParse(_totalAmountController.text.replaceAll(',', '')) ?? 0;
    if (_items.isEmpty && manualTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062a\u06a9\u0627\u06cc\u06d5 \u0628\u0695\u06cc \u067e\u0627\u0631\u06d5\u06a9\u06d5 \u062f\u0627\u062e\u06b5 \u0628\u06a9\u06d5',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isEditing = widget.editTransactionId != null;
      final provider = context.read<TransactionProvider>();
      final itemsMap = _items
          .map(
            (i) => {
              'item_name': i.itemName,
              'quantity': i.quantity,
              'unit': i.unit,
              'unit_price': i.unitPrice,
              'total_price': i.totalPrice,
            },
          )
          .toList();

      bool success = false;

      if (isEditing) {
        success = await provider.updateTransaction(
          id: widget.editTransactionId!,
          brokerId: _selectedBrokerId ?? '',
          isCredit: _isCredit,
          notes: _notesController.text.trim(),
          partnerName: _partnerController.text.trim(),
          discount: _discount,
          transactionDate: _transactionDate,
          items: itemsMap,
          totalAmount: _items.isEmpty ? manualTotal : null,
        );

        if (success && _receiptImages.isNotEmpty) {
          await Future.wait(List.generate(
            _receiptImages.length,
            (i) => provider.uploadReceipt(
              widget.editTransactionId!,
              _receiptImageBytes[i],
              _receiptImages[i].name,
            ),
          ));
        }
      } else {
        final newId = await provider.createTransaction(
          brokerId: _selectedBrokerId ?? '',
          isCredit: _isCredit,
          notes: _notesController.text.trim(),
          partnerName: _partnerController.text.trim(),
          discount: _discount,
          transactionDate: _transactionDate,
          items: itemsMap,
          totalAmount: _items.isEmpty ? manualTotal : null,
        );
        success = newId != null;

        if (success && _receiptImages.isNotEmpty) {
          await Future.wait(List.generate(
            _receiptImages.length,
            (i) => provider.uploadReceipt(
              newId,
              _receiptImageBytes[i],
              _receiptImages[i].name,
            ),
          ));
        }
      }

      if (success && mounted) {
        // Silent refresh in background — realtime will also fire, and the
        // in-flight guard in BrokerProvider coalesces duplicate requests.
        context.read<BrokerProvider>().loadBrokers(silent: true);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? '\u06a9\u0695\u06cc\u0646\u06d5\u06a9\u06d5 \u0628\u06d5 \u0633\u06d5\u0631\u06a9\u06d5\u0648\u062a\u0648\u0648\u06cc\u06cc \u0646\u0648\u06ce\u06a9\u0631\u0627\u06cc\u06d5\u0648\u06d5'
                  : '\u06a9\u0695\u06cc\u0646\u06d5\u06a9\u06d5 \u0628\u06d5 \u0633\u06d5\u0631\u06a9\u06d5\u0648\u062a\u0648\u0648\u06cc\u06cc \u062a\u06c6\u0645\u0627\u0631\u06a9\u0631\u0627',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final brokers = context.watch<BrokerProvider>().brokers;
    final isEditing = widget.editTransactionId != null;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW > 700 ? (screenW - 660) / 2 : 20.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Clickable(
        onTap: _dismissKeyboard,
        child: Scaffold(
          backgroundColor: AppTheme.surfaceLight,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverAppBar(
                  expandedHeight: 100,
                  floating: true,
                  snap: true,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: AppTheme.surfaceLight,
                  foregroundColor: AppTheme.textPrimary,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsetsDirectional.only(
                      start: 56,
                      bottom: 16,
                      end: 16,
                    ),
                    title: Text(
                      isEditing
                          ? '\u062f\u06d5\u0633\u062a\u06a9\u0627\u0631\u06cc \u06a9\u0695\u06cc\u0646'
                          : '\u06a9\u0695\u06cc\u0646\u06cc \u0646\u0648\u06ce',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        fontFamily: 'NotoKufiArabic',
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            formatMoneyWithCurrency(_finalTotal),
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPad + 4,
                      vertical: 4,
                    ),
                    child: _buildStepIndicator(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                              child: child,
                            ),
                          );
                        },
                        child: _currentStep == 0
                            ? _buildInfoStep(brokers)
                            : _buildSummaryStep(isEditing),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(isEditing),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = [
      '\u0632\u0627\u0646\u06cc\u0627\u0631\u06cc',
      '\u06a9\u06c6\u062a\u0627\u06cc\u06cc',
    ];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return Expanded(
          child: Clickable(
            onTap: () => setState(() => _currentStep = i),
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 2,
                          color: isDone
                              ? AppTheme.primaryColor
                              : Colors.grey.shade200,
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? AppTheme.primaryColor
                            : isDone
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: isActive || isDone
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: AppTheme.primaryColor,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                ),
                              ),
                      ),
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 2,
                          color: i < _currentStep
                              ? AppTheme.primaryColor
                              : Colors.grey.shade200,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppTheme.primaryColor
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInfoStep(List<Broker> brokers) {
    // Reset broker selection if the broker no longer exists
    if (_selectedBrokerId != null &&
        !brokers.any((b) => b.id == _selectedBrokerId)) {
      _selectedBrokerId = null;
    }

    return Column(
      key: const ValueKey('step_info'),
      children: [
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                '\u0634\u0648\u06ce\u0646\u06cc \u06a9\u0695\u06cc\u0646',
                Icons.store_rounded,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedBrokerId,
                isExpanded: true,
                decoration: _inputDecoration(
                  '\u0628\u0631\u06cc\u06a9\u0627\u0631 \u06be\u06d5\u06b5\u0628\u0698\u06ce\u0631\u06d5',
                ),
                items: [
                  ...brokers.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ),
                ],
                validator: (v) => v == null || v.isEmpty
                    ? '\u062a\u06a9\u0627\u06cc\u06d5 \u0628\u0631\u06cc\u06a9\u0627\u0631\u06ce\u06a9 \u06be\u06d5\u06b5\u0628\u0698\u06ce\u0631\u06d5'
                    : null,
                onChanged: (v) {
                  setState(() {
                    _selectedBrokerId = v;
                    if (v != null) {
                      final broker = brokers.firstWhere((b) => b.id == v);
                      _partnerController.text =
                          broker.companyName ?? broker.name;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _partnerController,
                decoration: _inputDecoration(
                  '\u0646\u0627\u0648\u06cc \u0634\u0648\u06ce\u0646\u06cc \u06a9\u0695\u06cc\u0646 *',
                ),
                validator: (v) => v == null || v.isEmpty
                    ? '\u062a\u06a9\u0627\u06cc\u06d5 \u0646\u0627\u0648\u06cc \u0634\u0648\u06ce\u0646\u06cc \u06a9\u0695\u06cc\u0646 \u0628\u0646\u0648\u0648\u0633\u06d5'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            final paymentCard = _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    '\u062c\u06c6\u0631\u06cc \u067e\u0627\u0631\u06d5\u062f\u0627\u0646',
                    Icons.payments_rounded,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          label: '\u0642\u06d5\u0631\u0632',
                          icon: Icons.schedule_rounded,
                          isSelected: _isCredit,
                          color: AppTheme.warningColor,
                          onTap: () => setState(() => _isCredit = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeChip(
                          label: '\u0646\u06d5\u0642\u062f',
                          icon: Icons.payments_rounded,
                          isSelected: !_isCredit,
                          color: AppTheme.successColor,
                          onTap: () => setState(() => _isCredit = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            final dateCard = _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    '\u0628\u06d5\u0631\u0648\u0627\u0631',
                    Icons.calendar_today_rounded,
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: context,
                        initialDate: _transactionDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                      );
                      if (dt != null) setState(() => _transactionDate = dt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.7,
                            ),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatDate(_transactionDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: paymentCard),
                  const SizedBox(width: 12),
                  Expanded(child: dateCard),
                ],
              );
            }
            return Column(
              children: [
                paymentCard,
                const SizedBox(height: 16),
                dateCard,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryStep(bool isEditing) {
    return Column(
      key: const ValueKey('step_summary'),
      children: [
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                '\u0628\u0695\u06cc \u067e\u0627\u0631\u06d5',
                Icons.attach_money_rounded,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalAmountController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
                inputFormatters: [_CommaNumberFormatter()],
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade300,
                  ),
                  suffixText: '\u062f.\u0639',
                  suffixStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                  filled: true,
                  fillColor: AppTheme.primaryColor.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '\u062f\u0627\u0634\u06a9\u0627\u0646\u062f\u0646',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppTheme.dangerColor,
                        fontWeight: FontWeight.w600,
                      ),
                      inputFormatters: [_CommaNumberFormatter()],
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        suffixText: '\u062f.\u0639',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_discount > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Colors.grey.shade200),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '\u06a9\u06c6\u06cc \u06a9\u06c6\u062a\u0627\u06cc\u06cc',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          formatMoneyWithCurrency(_finalTotal),
                          key: ValueKey(_finalTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                '\u062a\u06ce\u0628\u06cc\u0646\u06cc',
                Icons.note_alt_outlined,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      '\u062a\u06ce\u0628\u06cc\u0646\u06cc \u0626\u0627\u0631\u06d5\u0632\u0648\u0648\u0645\u06d5\u0646\u062f\u0627\u0646\u06d5...',
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle(
                    '\u0648\u06ce\u0646\u06d5\u06cc \u067e\u0633\u0648\u06b5\u06d5\u06a9\u0627\u0646',
                    Icons.receipt_long_rounded,
                  ),
                  if (_receiptImages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_receiptImages.length}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_receiptImages.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _receiptImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _receiptImageBytes[index],
                              height: 100,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Clickable(
                              onTap: () => setState(
                                () { _receiptImages.removeAt(index); _receiptImageBytes.removeAt(index); },
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (!kIsWeb)
                    Expanded(
                      child: _buildImageButton(
                        icon: Icons.camera_alt_outlined,
                        label: '\u06a9\u0627\u0645\u06ce\u0631\u0627',
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                  if (!kIsWeb) const SizedBox(width: 10),
                  Expanded(
                    child: _buildImageButton(
                      icon: Icons.photo_library_outlined,
                      label: kIsWeb ? '\u0647\u06d5\u06b5\u0628\u0698\u0627\u0631\u062f\u0646\u06cc \u0648\u06ce\u0646\u06d5' : '\u06af\u0627\u0644\u06d5\u0631\u06cc',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isEditing) {
    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW > 700 ? (screenW - 660) / 2 : 20.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        hPad,
        12,
        hPad,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Text(
                  '\u067e\u06ce\u0634\u0648\u0648',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 50,
              child: FilledButton(
                onPressed: _currentStep < 1
                    ? () {
                        if (_currentStep == 0 &&
                            !_formKey.currentState!.validate()) {
                          return;
                        }
                        setState(() => _currentStep++);
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : _isLoading
                    ? null
                    : _saveTransaction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _currentStep < 1
                            ? '\u062f\u0648\u0627\u062a\u0631'
                            : isEditing
                            ? '\u067e\u0627\u0634\u06d5\u06a9\u06d5\u0648\u062a\u06a9\u0631\u062f\u0646\u06cc \u06af\u06c6\u0695\u0627\u0646\u06a9\u0627\u0631\u06cc'
                            : '\u067e\u0627\u0634\u06d5\u06a9\u06d5\u0648\u062a\u06a9\u0631\u062f\u0646\u06cc \u06a9\u0695\u06cc\u0646',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Clickable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade500,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.grey.shade50,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CommaNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final cleanText = newValue.text.replaceAll(',', '');
    if (double.tryParse(cleanText) == null) return oldValue;

    String formatted;
    if (cleanText.contains('.')) {
      final parts = cleanText.split('.');
      formatted = '${_addCommas(parts[0])}.${parts[1]}';
    } else {
      formatted = _addCommas(cleanText);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _addCommas(String s) {
    if (s.isEmpty || s == '-') return s;
    final isNeg = s.startsWith('-');
    final digits = isNeg ? s.substring(1) : s;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return isNeg ? '-$buffer' : buffer.toString();
  }
}
