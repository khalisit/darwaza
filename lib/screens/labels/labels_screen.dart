import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/pb_service.dart';
import '../../models/transaction.dart';
import '../../kurdish_reshaper.dart';

// ─── Custom Label (user-created, local only) ───
class _CustomLabel {
  String id;
  String name;
  double price;
  String extraText;
  String storeName;      // custom store name text
  String priceLabelText; // e.g. "نرخ:" or custom
  bool showStoreName;
  bool showPrice;
  bool showDate;
  bool showName;
  bool showExtraText;
  bool showPriceLabel;   // show the "نرخ:" label beside price
  bool showCurrency;     // show "د.ع" after price
  int labelCount;
  DateTime created;

  _CustomLabel({
    required this.id,
    required this.name,
    required this.price,
    this.extraText = '',
    this.storeName = 'مارکێت دەروازە',
    this.priceLabelText = 'نرخ:',
    this.showStoreName = true,
    this.showPrice = true,
    this.showDate = false,
    this.showName = true,
    this.showExtraText = true,
    this.showPriceLabel = true,
    this.showCurrency = true,
    this.labelCount = 1,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'extraText': extraText,
    'storeName': storeName,
    'priceLabelText': priceLabelText,
    'showStoreName': showStoreName,
    'showPrice': showPrice,
    'showDate': showDate,
    'showName': showName,
    'showExtraText': showExtraText,
    'showPriceLabel': showPriceLabel,
    'showCurrency': showCurrency,
    'labelCount': labelCount,
    'created': created.toIso8601String(),
  };

  factory _CustomLabel.fromJson(Map<String, dynamic> j) => _CustomLabel(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    price: (j['price'] ?? 0).toDouble(),
    extraText: j['extraText'] ?? '',
    storeName: j['storeName'] ?? 'مارکێت دەروازە',
    priceLabelText: j['priceLabelText'] ?? 'نرخ:',
    showStoreName: j['showStoreName'] ?? true,
    showPrice: j['showPrice'] ?? true,
    showDate: j['showDate'] ?? false,
    showName: j['showName'] ?? true,
    showExtraText: j['showExtraText'] ?? true,
    showPriceLabel: j['showPriceLabel'] ?? true,
    showCurrency: j['showCurrency'] ?? true,
    labelCount: j['labelCount'] ?? 1,
    created: DateTime.tryParse(j['created'] ?? '') ?? DateTime.now(),
  );
}

/// Aggregated item from transaction_items + saved sell price
class _AggregatedItem {
  final String name;
  final String unit;
  final double lastBuyPrice;
  final int totalQuantity;
  double? sellPrice;
  String? priceRecordId;
  String? note;

  _AggregatedItem({
    required this.name,
    required this.unit,
    required this.lastBuyPrice,
    required this.totalQuantity,
    this.sellPrice,
    this.priceRecordId,
    this.note,
  });

  double get profit => (sellPrice ?? 0) - lastBuyPrice;
  double get profitPercent =>
      lastBuyPrice > 0 && sellPrice != null ? (profit / lastBuyPrice) * 100 : 0;
}

// ─── Label Size Presets ───
class _LabelSize {
  final String name;
  final double widthMm;
  final double heightMm;
  const _LabelSize(this.name, this.widthMm, this.heightMm);
}

const _labelSizes = [
  _LabelSize('40 × 30', 40, 30),
  _LabelSize('50 × 30', 50, 30),
  _LabelSize('60 × 40', 60, 40),
  _LabelSize('70 × 40', 70, 40),
  _LabelSize('80 × 50', 80, 50),
];

// ══════════════════════════════════════════════════════════════
// ─── Labels Screen ───
// ══════════════════════════════════════════════════════════════
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});
  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  List<_AggregatedItem> _items = [];

  // Pagination
  static const _pageSize = 30;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  // Label settings (persisted)
  int _sizeIndex = 2;
  double _customW = 60;
  double _customH = 40;
  bool _showStoreName = true;
  bool _showBuyPrice = false;
  bool _showDate = true;
  int _labelCount = 1;

  // Cached fonts
  pw.Font? _regular;
  pw.Font? _bold;

  // Custom labels (user-created, local)
  List<_CustomLabel> _customLabels = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadFonts();
    _loadItems();
    _loadCustomLabels();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _visibleCount < _filtered.length) {
      setState(() => _isLoadingMore = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _visibleCount = (_visibleCount + _pageSize).clamp(0, _filtered.length);
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _sizeIndex = p.getInt('label_size') ?? 2;
      _customW = p.getDouble('label_custom_w') ?? 60;
      _customH = p.getDouble('label_custom_h') ?? 40;
      _showStoreName = p.getBool('label_store') ?? true;
      _showBuyPrice = p.getBool('label_buy') ?? false;
      _showDate = p.getBool('label_date') ?? true;
      _labelCount = p.getInt('label_count') ?? 1;
    });
  }

  Future<void> _saveSettings() async {
    final p = await SharedPreferences.getInstance();
    p.setInt('label_size', _sizeIndex);
    p.setDouble('label_custom_w', _customW);
    p.setDouble('label_custom_h', _customH);
    p.setBool('label_store', _showStoreName);
    p.setBool('label_buy', _showBuyPrice);
    p.setBool('label_date', _showDate);
    p.setInt('label_count', _labelCount);
  }

  Future<void> _loadCustomLabels() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('custom_labels');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        if (mounted) {
          setState(() {
            _customLabels = list
                .map((e) => _CustomLabel.fromJson(e as Map<String, dynamic>))
                .toList();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveCustomLabels() async {
    final p = await SharedPreferences.getInstance();
    p.setString(
      'custom_labels',
      jsonEncode(_customLabels.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _loadFonts() async {
    final r = await rootBundle.load('assets/fonts/NotoKufiArabic.ttf');
    final b = await rootBundle.load('assets/fonts/NotoKufiArabic-Bold.ttf');
    _regular = pw.Font.ttf(r);
    _bold = pw.Font.ttf(b);
  }

  /// Normalize Kurdish text for reliable matching
  String _normalize(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll('\u200C', '').replaceAll('\u200D', '');

  /// Find price data from priceMap with fuzzy Kurdish name matching
  Map<String, dynamic>? _findPrice(
      Map<String, Map<String, dynamic>> priceMap, String itemName) {
    final norm = _normalize(itemName);
    // 1. Exact key match
    if (priceMap.containsKey(itemName)) return priceMap[itemName];
    // 2. Normalized match
    for (final entry in priceMap.entries) {
      if (_normalize(entry.key) == norm) return entry.value;
    }
    return null;
  }

  Future<void> _loadItems() async {
    try {
      final txRecords = await PBService().getAllTransactionItems();
      List priceRecords = [];
      try {
        priceRecords = await PBService().getAllItemPrices();
      } catch (e) {
        debugPrint('⚠️ getAllItemPrices failed: $e — trying auth refresh...');
        // Token might have expired — try refreshing auth and retry once
        try {
          await PBService().tryRefreshAuth();
          priceRecords = await PBService().getAllItemPrices();
        } catch (e2) {
          debugPrint('⚠️ Retry after auth refresh also failed: $e2');
        }
      }

      debugPrint('📦 txRecords: ${txRecords.length}, priceRecords: ${priceRecords.length}');

      final parsed =
          txRecords.map((r) => TransactionItem.fromJson(r.toJson())).toList();

      final priceMap = <String, Map<String, dynamic>>{};
      for (final p in priceRecords) {
        final name = p.getStringValue('item_prices').trim();
        final price = p.getDoubleValue('sell_price');
        priceMap[name] = {
          'sell_price': price,
          'id': p.id,
          'note': p.getStringValue('note'),
        };
        debugPrint('💰 price record: "$name" → $price');
      }

      final map = <String, _AggregatedItem>{};
      for (final item in parsed) {
        final key = item.itemName.trim();
        if (key.isEmpty) continue;
        final existing = map[key];
        if (existing == null) {
          final saved = _findPrice(priceMap, key);
          final sp = saved != null ? (saved['sell_price'] as double) : null;
          map[key] = _AggregatedItem(
            name: key,
            unit: item.unit,
            lastBuyPrice: item.unitPrice,
            totalQuantity: item.quantity,
            sellPrice: (sp != null && sp > 0) ? sp : null,
            priceRecordId: saved?['id'] as String?,
            note: saved?['note'] as String?,
          );
        } else {
          map[key] = _AggregatedItem(
            name: key,
            unit: item.unit.isNotEmpty ? item.unit : existing.unit,
            lastBuyPrice: item.unitPrice,
            totalQuantity: existing.totalQuantity + item.quantity,
            sellPrice: existing.sellPrice,
            priceRecordId: existing.priceRecordId,
            note: existing.note,
          );
        }
      }

      _items = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      debugPrint('⚠️ _loadItems error: $e');
      _items = [];
    }
  }

  List<_AggregatedItem> get _filtered {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) => i.name.contains(_searchQuery)).toList();
  }

  List<_CustomLabel> get _filteredCustomLabels {
    if (_searchQuery.isEmpty) return _customLabels;
    return _customLabels.where((l) =>
      l.name.contains(_searchQuery) ||
      l.extraText.contains(_searchQuery) ||
      l.storeName.contains(_searchQuery)
    ).toList();
  }

  _LabelSize get _currentSize => _sizeIndex < _labelSizes.length
      ? _labelSizes[_sizeIndex]
      : _LabelSize('${_customW.toInt()} × ${_customH.toInt()}', _customW, _customH);


  // ── Quick Print Custom Label ──
  Future<void> _printCustomLabel(_CustomLabel label) async {
    if (_regular == null || _bold == null) await _loadFonts();
    if (_regular == null || _bold == null) return;

    final size = _currentSize;
    final pdfBytes = await _buildCustomLabelPdf(label: label, size: size);

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'label_${label.name}',
      format: PdfPageFormat(
        size.widthMm * PdfPageFormat.mm,
        size.heightMm * PdfPageFormat.mm,
      ),
    );
  }

  // ── Custom Label PDF (respects per-label toggles) ──
  Future<Uint8List> _buildCustomLabelPdf({
    required _CustomLabel label,
    required _LabelSize size,
  }) async {
    String k(String t) => KurdishReshaper.convert(t);

    final pageW = size.widthMm * PdfPageFormat.mm;
    final pageH = size.heightMm * PdfPageFormat.mm;
    final format = PdfPageFormat(pageW, pageH, marginAll: 0);

    final storeFontSize = pageH * 0.075;
    final nameFontLarge = pageH * 0.13;
    final priceFontLabel = pageH * 0.07;
    final priceFontValue = pageH * 0.14;
    final smallFont = pageH * 0.058;
    final tinyFont = pageH * 0.05;

    final count = label.labelCount > 0 ? label.labelCount : 1;
    final pdf = pw.Document();

    for (int i = 0; i < count; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.symmetric(
              horizontal: pageW * 0.04, vertical: pageH * 0.03),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (label.showStoreName && label.storeName.isNotEmpty) ...[
                  pw.Center(
                    child: pw.Text(k(label.storeName),
                        style: pw.TextStyle(
                            font: _bold!, fontSize: storeFontSize)),
                  ),
                  pw.Divider(
                      thickness: 0.6,
                      height: pageH * 0.02,
                      color: PdfColors.black),
                ],
                if (label.showName && label.name.isNotEmpty)
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Padding(
                        padding: pw.EdgeInsets.symmetric(
                            horizontal: pageW * 0.02),
                        child: pw.Text(k(label.name),
                            style: pw.TextStyle(
                                font: _bold!, fontSize: nameFontLarge),
                            textAlign: pw.TextAlign.center,
                            maxLines: 2),
                      ),
                    ),
                  )
                else
                  pw.Expanded(child: pw.SizedBox()),
                if (label.showPrice)
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(
                        horizontal: pageW * 0.04, vertical: pageH * 0.025),
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        if (label.showPriceLabel)
                          pw.Text(k(label.priceLabelText),
                              style: pw.TextStyle(
                                  font: _regular!,
                                  fontSize: priceFontLabel)),
                        pw.Text(
                          k(label.showCurrency
                              ? '${formatMoney(label.price)} د.ع'
                              : formatMoney(label.price)),
                          style: pw.TextStyle(
                              font: _bold!, fontSize: priceFontValue),
                        ),
                      ],
                    ),
                  ),
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: pageH * 0.01),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (label.showExtraText &&
                          label.extraText.isNotEmpty)
                        pw.Expanded(
                          child: pw.Text(k(label.extraText),
                              style: pw.TextStyle(
                                  font: _regular!,
                                  fontSize: tinyFont,
                                  color: PdfColors.grey600),
                              maxLines: 2),
                        ),
                      if (label.showDate)
                        pw.Text(formatDate(DateTime.now()),
                            style: pw.TextStyle(
                                font: _regular!,
                                fontSize: smallFont,
                                color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  // ── Open Label Editor Page ──
  Future<void> _openLabelEditor({_CustomLabel? existing}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _LabelEditorPage(existing: existing),
      ),
    );

    if (result == null) return;

    final action = result['action'] as String;

    if (action == 'delete' && existing != null) {
      setState(() {
        _customLabels.removeWhere((l) => l.id == existing.id);
      });
      _saveCustomLabels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لەیبڵ سڕایەوە'),
              behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    final name = result['name'] as String;
    final price = result['price'] as double;
    final extraText = result['extraText'] as String;
    final shouldPrint = action == 'save_print';

    void applyTo(_CustomLabel lbl) {
      lbl.name = name;
      lbl.price = price;
      lbl.extraText = extraText;
      lbl.storeName = result['storeName'] as String;
      lbl.priceLabelText = result['priceLabelText'] as String;
      lbl.showStoreName = result['showStoreName'] as bool;
      lbl.showName = result['showName'] as bool;
      lbl.showPrice = result['showPrice'] as bool;
      lbl.showPriceLabel = result['showPriceLabel'] as bool;
      lbl.showCurrency = result['showCurrency'] as bool;
      lbl.showDate = result['showDate'] as bool;
      lbl.showExtraText = result['showExtraText'] as bool;
      lbl.labelCount = result['labelCount'] as int;
    }

    setState(() {
      if (existing != null) {
        applyTo(existing);
      } else {
        final lbl = _CustomLabel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          price: price,
        );
        applyTo(lbl);
        _customLabels.insert(0, lbl);
      }
    });
    _saveCustomLabels();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${name.isNotEmpty ? name : "لەیبڵ"} پاشەکەوت کرا'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (shouldPrint) {
      final label = existing ?? _customLabels.first;
      await _printCustomLabel(label);
    }
  }

  // ── Settings Bottom Sheet ──
  void _showSettings() {
    int tempSize = _sizeIndex;
    double tempCW = _customW;
    double tempCH = _customH;
    bool tempStore = _showStoreName;
    bool tempBuy = _showBuyPrice;
    bool tempDate = _showDate;
    int tempCount = _labelCount;
    final countCtrl = TextEditingController(text: '$_labelCount');
    final cwCtrl = TextEditingController(text: '${_customW.toInt()}');
    final chCtrl = TextEditingController(text: '${_customH.toInt()}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.tune_rounded,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('ڕێکخستنی لەیبڵ',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Label size
                    const Text('قەبارەی لەیبڵ (mm)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _labelSizes.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final isCustom = i == _labelSizes.length;
                          final sel = i == tempSize;
                          return Clickable(
                            onTap: () => setSheetState(() => tempSize = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: sel
                                    ? null
                                    : Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCustom)
                                    Icon(Icons.edit_rounded, size: 12,
                                        color: sel ? Colors.white : Colors.grey.shade700),
                                  if (isCustom) const SizedBox(width: 4),
                                  Text(
                                    isCustom ? 'دەستی' : _labelSizes[i].name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          sel ? FontWeight.w600 : FontWeight.w400,
                                      color: sel
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Custom size fields
                    if (tempSize == _labelSizes.length) ...[                    
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cwCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              onChanged: (v) => tempCW = double.tryParse(v) ?? 60,
                              decoration: InputDecoration(
                                labelText: 'پانی (mm)',
                                labelStyle: const TextStyle(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('×', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: chCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              onChanged: (v) => tempCH = double.tryParse(v) ?? 40,
                              decoration: InputDecoration(
                                labelText: 'بەرزی (mm)',
                                labelStyle: const TextStyle(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Label count
                    Row(
                      children: [
                        const Text('ژمارەی لەیبڵ بۆ هەر کاڵایەک',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        SizedBox(
                          width: 70,
                          height: 40,
                          child: TextField(
                            controller: countCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            onChanged: (v) {
                              tempCount = int.tryParse(v) ?? 1;
                            },
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Toggles
                    _SheetToggle(
                      label: 'ناوی فرۆشگا',
                      icon: Icons.store_rounded,
                      value: tempStore,
                      onChanged: (v) => setSheetState(() => tempStore = v),
                    ),
                    _SheetToggle(
                      label: 'نرخی کڕین',
                      icon: Icons.shopping_cart_outlined,
                      value: tempBuy,
                      onChanged: (v) => setSheetState(() => tempBuy = v),
                    ),
                    _SheetToggle(
                      label: 'بەروار',
                      icon: Icons.calendar_today_rounded,
                      value: tempDate,
                      onChanged: (v) => setSheetState(() => tempDate = v),
                    ),
                    const SizedBox(height: 16),

                    // Save
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _sizeIndex = tempSize;
                            _customW = tempCW > 0 ? tempCW : 60;
                            _customH = tempCH > 0 ? tempCH : 40;
                            _showStoreName = tempStore;
                            _showBuyPrice = tempBuy;
                            _showDate = tempDate;
                            _labelCount = tempCount > 0 ? tempCount : 1;
                          });
                          _saveSettings();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('پاشەکەوتکردن'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomLabels;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        appBar: AppBar(
          title: const Text('لەیبڵەکان'),
          actions: [
            IconButton(
              onPressed: _showSettings,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppTheme.primaryColor, size: 20),
              ),
              tooltip: 'ڕێکخستنی پرێنتەر',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openLabelEditor(),
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Icons.add_rounded),
          label: const Text('لەیبڵی نوێ',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: Column(
          children: [
            // ── Search ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'گەڕان بۆ لەیبڵ...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),

            // ── Stats ──
            if (_customLabels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    _StatChip(
                        '${filtered.length}', 'لەیبڵ', AppTheme.primaryColor),
                    const Spacer(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentSize.name} mm',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Labels List ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_outline_rounded,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'هیچ لەیبڵێک نەدۆزرایەوە'
                                : 'هیچ لەیبڵێک نییە',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'دوگمەی + دابگرە بۆ زیادکردنی لەیبڵ',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(
                              milliseconds: 250 + (i % 30) * 30),
                          curve: Curves.easeOut,
                          builder: (_, val, child) => Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - val)),
                              child: child,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildCustomLabelCard(filtered[i]),
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

  // ── Custom Label Card ──
  Widget _buildCustomLabelCard(_CustomLabel label) {
    // Count active sections
    final activeParts = <String>[];
    if (label.showStoreName) activeParts.add('فرۆشگا');
    if (label.showName) activeParts.add('ناو');
    if (label.showPrice) activeParts.add('نرخ');
    if (label.showExtraText && label.extraText.isNotEmpty) activeParts.add('نوسین');
    if (label.showDate) activeParts.add('بەروار');

    return Dismissible(
      key: ValueKey(label.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('سڕینەوەی لەیبڵ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: Text(
                  'دڵنیایت لە سڕینەوەی "${label.name.isNotEmpty ? label.name : "لەیبڵ"}"؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('نەخێر'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor),
                  child: const Text('سڕینەوە'),
                ),
              ],
            ),
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        setState(() {
          _customLabels.removeWhere((l) => l.id == label.id);
        });
        _saveCustomLabels();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لەیبڵ سڕایەوە'),
              behavior: SnackBarBehavior.floating),
        );
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openLabelEditor(existing: label),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit_note_rounded,
                      color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.name.isNotEmpty ? label.name : 'بێ ناو',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: label.name.isNotEmpty
                              ? Colors.black
                              : Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (label.showPrice && label.price > 0) ...[
                            const Icon(Icons.sell_rounded,
                                size: 12, color: AppTheme.successColor),
                            const SizedBox(width: 3),
                            Text(
                              '${formatMoney(label.price)} د.ع',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (label.labelCount > 1) ...[
                            Icon(Icons.copy_rounded,
                                size: 11, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text('×${label.labelCount}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Active section chips
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: activeParts
                            .map((p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.06),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(p,
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                Clickable(
                  onTap: () => _printCustomLabel(label),
                  child: Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.print_rounded,
                        color: AppTheme.primaryColor, size: 20),
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

// ══════════════════════════════════════════════════════════════
// ─── Label Editor Page (Full Screen) ───
// ══════════════════════════════════════════════════════════════

class _LabelEditorPage extends StatefulWidget {
  final _CustomLabel? existing;
  const _LabelEditorPage({this.existing});

  @override
  State<_LabelEditorPage> createState() => _LabelEditorPageState();
}

class _LabelEditorPageState extends State<_LabelEditorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _extraCtrl;
  late final TextEditingController _storeNameCtrl;
  late final TextEditingController _priceLabelCtrl;
  late final TextEditingController _countCtrl;

  late bool _showStoreName;
  late bool _showName;
  late bool _showPrice;
  late bool _showPriceLabel;
  late bool _showCurrency;
  late bool _showDate;
  late bool _showExtraText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl = TextEditingController(
      text: e != null && e.price > 0 ? formatMoney(e.price) : '',
    );
    _extraCtrl = TextEditingController(text: e?.extraText ?? '');
    _storeNameCtrl =
        TextEditingController(text: e?.storeName ?? 'مارکێت دەروازە');
    _priceLabelCtrl =
        TextEditingController(text: e?.priceLabelText ?? 'نرخ:');
    _countCtrl = TextEditingController(text: '${e?.labelCount ?? 1}');

    _showStoreName = e?.showStoreName ?? true;
    _showName = e?.showName ?? true;
    _showPrice = e?.showPrice ?? true;
    _showPriceLabel = e?.showPriceLabel ?? true;
    _showCurrency = e?.showCurrency ?? true;
    _showDate = e?.showDate ?? false;
    _showExtraText = e?.showExtraText ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _extraCtrl.dispose();
    _storeNameCtrl.dispose();
    _priceLabelCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildResult(String action) => {
        'action': action,
        'name': _nameCtrl.text.trim(),
        'price':
            double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
        'extraText': _extraCtrl.text.trim(),
        'storeName': _storeNameCtrl.text.trim(),
        'priceLabelText': _priceLabelCtrl.text.trim(),
        'showStoreName': _showStoreName,
        'showName': _showName,
        'showPrice': _showPrice,
        'showPriceLabel': _showPriceLabel,
        'showCurrency': _showCurrency,
        'showDate': _showDate,
        'showExtraText': _showExtraText,
        'labelCount': int.tryParse(_countCtrl.text) ?? 1,
      };

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('سڕینەوەی لەیبڵ',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
              'دڵنیایت لە سڕینەوەی "${widget.existing?.name ?? "لەیبڵ"}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor),
              child: const Text('سڕینەوە'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, {'action': 'delete'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final currentPrice =
        double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    final currentName = _nameCtrl.text.trim();
    final currentStore = _storeNameCtrl.text.trim();
    final currentExtra = _extraCtrl.text.trim();
    final currentPriceLabel = _priceLabelCtrl.text.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        appBar: AppBar(
          title: Text(isEditing ? 'دەستکاری لەیبڵ' : 'لەیبڵی نوێ'),
          actions: [
            if (isEditing)
              IconButton(
                onPressed: _confirmDelete,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.dangerColor, size: 20),
                ),
                tooltip: 'سڕینەوە',
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
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
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _buildResult('save')),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('پاشەکەوت',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _buildResult('save_print')),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('پاشەکەوت و چاپ',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Live Preview ──
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_rounded,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text('پێشبینینی لەیبڵ',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPreview(
                      currentName: currentName,
                      currentPrice: currentPrice,
                      currentStore: currentStore,
                      currentExtra: currentExtra,
                      currentPriceLabel: currentPriceLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Input Fields ──
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    if (_showName) ...[
                      _fieldLabel('ناوی کاڵا'),
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: _fieldDecoration(
                          hint: 'ناوی کاڵا بنووسە...',
                          icon: Icons.label_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Price
                    if (_showPrice) ...[
                      _fieldLabel('نرخ'),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]'))
                        ],
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 26,
                              fontWeight: FontWeight.w800),
                          suffixText: _showCurrency ? 'د.ع' : null,
                          suffixStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500),
                          filled: true,
                          fillColor: AppTheme.primaryColor
                              .withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Store Name
                    if (_showStoreName) ...[
                      _fieldLabel('ناوی فرۆشگا'),
                      TextField(
                        controller: _storeNameCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: _fieldDecoration(
                          hint: 'ناوی فرۆشگا...',
                          icon: Icons.store_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Price Label
                    if (_showPrice && _showPriceLabel) ...[
                      _fieldLabel('نوسینی لەپێش نرخ'),
                      TextField(
                        controller: _priceLabelCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: _fieldDecoration(
                          hint: 'نرخ:',
                          icon: Icons.text_fields_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Extra Text
                    if (_showExtraText) ...[
                      _fieldLabel('نوسینی زیادە'),
                      TextField(
                        controller: _extraCtrl,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText:
                              'هەر نوسینێک بنووسە بۆ لەسەر لەیبڵ...',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 48),
                            child:
                                Icon(Icons.note_alt_outlined, size: 18),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Label Count
                    Row(
                      children: [
                        const Icon(Icons.copy_rounded,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('ژمارەی لەیبڵ',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        SizedBox(
                          width: 70,
                          height: 40,
                          child: TextField(
                            controller: _countCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Visibility Toggles ──
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.toggle_on_rounded,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text('بەشەکانی لەیبڵ',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _toggleRow(Icons.store_rounded, 'ناوی فرۆشگا',
                        _showStoreName, (v) => setState(() => _showStoreName = v)),
                    _toggleRow(Icons.label_rounded, 'ناوی کاڵا',
                        _showName, (v) => setState(() => _showName = v)),
                    _toggleRow(Icons.sell_rounded, 'نرخ',
                        _showPrice, (v) => setState(() => _showPrice = v)),
                    if (_showPrice)
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Column(
                          children: [
                            _toggleRow(
                                Icons.text_fields_rounded,
                                'نوسینی نرخ (نرخ:)',
                                _showPriceLabel,
                                (v) => setState(
                                    () => _showPriceLabel = v)),
                            _toggleRow(
                                Icons.currency_exchange_rounded,
                                'دراو (د.ع)',
                                _showCurrency,
                                (v) => setState(
                                    () => _showCurrency = v)),
                          ],
                        ),
                      ),
                    _toggleRow(Icons.note_alt_rounded, 'نوسینی زیادە',
                        _showExtraText, (v) => setState(() => _showExtraText = v)),
                    _toggleRow(Icons.calendar_today_rounded, 'بەروار',
                        _showDate, (v) => setState(() => _showDate = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700)),
    );
  }

  InputDecoration _fieldDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, size: 18),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
  }

  Widget _toggleRow(IconData icon, String label, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(label, style: const TextStyle(fontSize: 13))),
          SizedBox(
            height: 28,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.primaryColor,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview({
    required String currentName,
    required double currentPrice,
    required String currentStore,
    required String currentExtra,
    required String currentPriceLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_showStoreName && currentStore.isNotEmpty) ...[
            Text(currentStore,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800)),
            Divider(height: 12, color: Colors.grey.shade300),
          ],
          if (_showName) ...[
            Text(
              currentName.isNotEmpty ? currentName : 'ناوی کاڵا',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: currentName.isNotEmpty
                    ? Colors.black
                    : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          if (_showPrice)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  if (_showPriceLabel &&
                      currentPriceLabel.isNotEmpty)
                    Text(currentPriceLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600)),
                  Text(
                    currentPrice > 0
                        ? _showCurrency
                            ? '${formatMoney(currentPrice)} د.ع'
                            : formatMoney(currentPrice)
                        : _showCurrency
                            ? '٠ د.ع'
                            : '٠',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: currentPrice > 0
                          ? Colors.black
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          if (_showExtraText && currentExtra.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(currentExtra,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (_showDate) ...[
            const SizedBox(height: 6),
            Text(formatDate(DateTime.now()),
                style: TextStyle(
                    fontSize: 9, color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ─── Small Widgets ───
// ══════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _StatChip(this.count, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}




class _SheetToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SheetToggle(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ─── Shared Label PDF Builder ───
// ══════════════════════════════════════════════════════════════
Future<Uint8List> _sharedBuildLabelPdf({
  required String itemName,
  required String unit,
  required double sellPrice,
  required double buyPrice,
  required int labelCount,
  required String note,
  required bool showBuyPrice,
  required bool showDate,
  required bool showStoreName,
  required _LabelSize size,
  required pw.Font regular,
  required pw.Font bold,
}) async {
  String k(String t) => KurdishReshaper.convert(t);

  final pageW = size.widthMm * PdfPageFormat.mm;
  final pageH = size.heightMm * PdfPageFormat.mm;
  final format = PdfPageFormat(pageW, pageH, marginAll: 0);

  final storeFontSize = pageH * 0.075;
  final nameFontLarge = pageH * 0.13;
  final priceFontLabel = pageH * 0.07;
  final priceFontValue = pageH * 0.14;
  final smallFont = pageH * 0.058;
  final tinyFont = pageH * 0.05;

  final pdf = pw.Document();

  for (int i = 0; i < labelCount; i++) {
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.symmetric(
            horizontal: pageW * 0.04, vertical: pageH * 0.03),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (showStoreName) ...[
                pw.Center(
                  child: pw.Text(k('مارکێت دەروازە'),
                      style:
                          pw.TextStyle(font: bold, fontSize: storeFontSize)),
                ),
                pw.Divider(
                    thickness: 0.6,
                    height: pageH * 0.02,
                    color: PdfColors.black),
              ],
              pw.Expanded(
                child: pw.Center(
                  child: pw.Padding(
                    padding:
                        pw.EdgeInsets.symmetric(horizontal: pageW * 0.02),
                    child: pw.Text(k(itemName),
                        style: pw.TextStyle(
                            font: bold, fontSize: nameFontLarge),
                        textAlign: pw.TextAlign.center,
                        maxLines: 2),
                  ),
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(
                    horizontal: pageW * 0.04, vertical: pageH * 0.025),
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(k('نرخ:'),
                        style: pw.TextStyle(
                            font: regular, fontSize: priceFontLabel)),
                    pw.Text(k('${formatMoney(sellPrice)} د.ع'),
                        style: pw.TextStyle(
                            font: bold, fontSize: priceFontValue)),
                  ],
                ),
              ),
              if (showBuyPrice)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: pageH * 0.01),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(k('نرخی کڕین:'),
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: tinyFont,
                              color: PdfColors.grey600)),
                      pw.Text(k('${formatMoney(buyPrice)} د.ع'),
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: tinyFont,
                              color: PdfColors.grey600)),
                    ],
                  ),
                ),
              pw.Padding(
                padding: pw.EdgeInsets.only(top: pageH * 0.01),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(k(unit),
                        style: pw.TextStyle(
                            font: regular,
                            fontSize: smallFont,
                            color: PdfColors.grey700)),
                    if (note.isNotEmpty)
                      pw.Text(k(note),
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: tinyFont,
                              color: PdfColors.grey600)),
                    if (showDate)
                      pw.Text(formatDate(DateTime.now()),
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: smallFont,
                              color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  return await pdf.save();
}
