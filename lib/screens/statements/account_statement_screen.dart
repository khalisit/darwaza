import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/broker_provider.dart';
import '../../models/broker.dart';
import '../../kurdish_reshaper.dart';

class AccountStatementScreen extends StatefulWidget {
  final String brokerId;
  const AccountStatementScreen({super.key, required this.brokerId});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<TransactionProvider>().loadTransactions(brokerId: widget.brokerId);
    context.read<PaymentProvider>().loadPayments(brokerId: widget.brokerId);
  }

  Broker? _getBroker() {
    try {
      return context.read<BrokerProvider>().brokers.firstWhere((b) => b.id == widget.brokerId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _printStatement() async {
    final broker = _getBroker();
    if (broker == null) return;

    final transactions = context.read<TransactionProvider>().transactions;
    final payments = context.read<PaymentProvider>().payments;

    // Use finalAmount (after discount) for all totals
    final totalGross = transactions.fold<double>(0, (sum, t) => sum + t.totalAmount);
    final totalDiscount = transactions.fold<double>(0, (sum, t) => sum + t.discount);
    final totalNet = transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final balance = totalNet - totalPaid;

    // Load font
    final regularData = await rootBundle.load('assets/fonts/NotoKufiArabic.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoKufiArabic-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    String k(String text) => KurdishReshaper.convert(text);

    final baseStyle = pw.TextStyle(font: regular, fontSize: 10);
    final boldStyle = pw.TextStyle(font: bold, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(font: bold, fontSize: 20, fontWeight: pw.FontWeight.bold);
    final subtitleStyle = pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey700);
    final summaryStyle = pw.TextStyle(font: bold, fontSize: 12, fontWeight: pw.FontWeight.bold);


    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Center(child: pw.Text(k('مارکێت دەروازە'), style: titleStyle)),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text(k('کەشفی حیساب'), style: subtitleStyle)),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.SizedBox(height: 12),

              // Broker info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(k('بریکار: ${broker.name}'), style: boldStyle),
                      if (broker.phone.isNotEmpty)
                        pw.Text(k('ژمارە: ${broker.phone}'), style: baseStyle),
                      if (broker.companyName != null && broker.companyName!.isNotEmpty)
                        pw.Text(k('کۆمپانیا: ${broker.companyName}'), style: baseStyle),
                    ],
                  ),
                  pw.Text(k('بەروار: ${formatDate(DateTime.now())}'), style: baseStyle),
                ],
              ),
              pw.SizedBox(height: 16),

              // Purchases table - with discount column
              pw.Text(k('کڕینەکان'), style: boldStyle.copyWith(fontSize: 12)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                cellAlignment: pw.Alignment.centerRight,
                headerDirection: pw.TextDirection.rtl,
                headerAlignment: pw.Alignment.centerRight,
                headerStyle: boldStyle,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellStyle: baseStyle,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                headers: [k('#'), k('بەروار'), k('بڕ'), k('داشکاندن'), k('بڕی نێت'), k('جۆر')],
                data: transactions.asMap().entries.map((e) {
                  final tx = e.value;
                  return [
                    '${e.key + 1}',
                    formatDate(tx.created),
                    formatMoney(tx.totalAmount),
                    tx.discount > 0 ? formatMoney(tx.discount) : '-',
                    formatMoney(tx.finalAmount),
                    k(tx.isCredit ? 'قەرز' : 'نەقد'),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),

              // Payments table
              pw.Text(k('پارەدانەکان'), style: boldStyle.copyWith(fontSize: 12)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                cellAlignment: pw.Alignment.centerRight,
                headerDirection: pw.TextDirection.rtl,
                headerAlignment: pw.Alignment.centerRight,
                headerStyle: boldStyle,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellStyle: baseStyle,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                headers: [k('#'), k('بەروار'), k('بڕ'), k('تێبینی')],
                data: payments.asMap().entries.map((e) {
                  final pay = e.value;
                  return [
                    '${e.key + 1}',
                    formatDate(pay.paymentDate),
                    formatMoney(pay.amount),
                    k(pay.notes ?? ''),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k('کۆی کڕینەکان (پێش داشکاندن):'), style: summaryStyle),
                  pw.Text(k('${formatMoney(totalGross)} د.ع'), style: summaryStyle),
                ],
              ),
              if (totalDiscount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(k('کۆی داشکاندنەکان:'), style: summaryStyle.copyWith(
                      color: PdfColors.red700,
                    )),
                    pw.Text(k('- ${formatMoney(totalDiscount)} د.ع'), style: summaryStyle.copyWith(
                      color: PdfColors.red700,
                    )),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(k('کۆی کڕینەکان (دوای داشکاندن):'), style: summaryStyle),
                    pw.Text(k('${formatMoney(totalNet)} د.ع'), style: summaryStyle),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k('کۆی پارەدانەکان:'), style: summaryStyle),
                  pw.Text(k('${formatMoney(totalPaid)} د.ع'), style: summaryStyle),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k('ماوە:'), style: summaryStyle.copyWith(fontSize: 14)),
                  pw.Text(k('${formatMoney(balance)} د.ع'), style: summaryStyle.copyWith(fontSize: 14)),
                ],
              ),

              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(k('مارکێت دەروازە'),
                    style: baseStyle.copyWith(color: PdfColors.grey600, fontSize: 8)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final broker = _getBroker();
    if (broker == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('بریکار نەدۆزرایەوە')),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('کەشفی حیساب - ${broker.name}'),
          actions: [
            FilledButton.icon(
              onPressed: _printStatement,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('چاپکردن'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Consumer2<TransactionProvider, PaymentProvider>(
          builder: (context, txProvider, payProvider, _) {
            if (txProvider.isLoading || payProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final transactions = txProvider.transactions;
            final payments = payProvider.payments;

            // Calculate all totals using finalAmount (after discount)
            final totalGross = transactions.fold<double>(0, (sum, t) => sum + t.totalAmount);
            final totalDiscount = transactions.fold<double>(0, (sum, t) => sum + t.discount);
            final totalNet = transactions.fold<double>(0, (sum, t) => sum + t.finalAmount);
            final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
            final balance = totalNet - totalPaid;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Broker Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(broker.name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(broker.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              if (broker.phone.isNotEmpty)
                                Text('ژمارە: ${broker.phone}',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey.shade600)),
                              if (broker.companyName != null &&
                                  broker.companyName!.isNotEmpty)
                                Text('کۆمپانیا: ${broker.companyName}',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Balance Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: balance > 0
                          ? [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]
                          : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: balance > 0
                          ? AppTheme.dangerColor.withValues(alpha: 0.2)
                          : AppTheme.successColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Show gross total
                      _summaryRow('کۆی کڕینەکان:', formatMoneyWithCurrency(totalGross),
                          AppTheme.warningColor),
                      // Show discount if exists
                      if (totalDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _summaryRow('کۆی داشکاندنەکان:', '- ${formatMoneyWithCurrency(totalDiscount)}',
                            AppTheme.dangerColor),
                        const SizedBox(height: 8),
                        _summaryRow('دوای داشکاندن:', formatMoneyWithCurrency(totalNet),
                            AppTheme.warningColor),
                      ],
                      const SizedBox(height: 8),
                      _summaryRow('کۆی پارەدانەکان:',
                          formatMoneyWithCurrency(totalPaid), AppTheme.successColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Colors.grey.shade300),
                      ),
                      _summaryRow(
                        'ماوە:',
                        formatMoneyWithCurrency(balance),
                        balance > 0 ? AppTheme.dangerColor : AppTheme.successColor,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Transactions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_cart_rounded,
                          color: AppTheme.warningColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('کڕینەکان (${transactions.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ...transactions.map((tx) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    tx.isCredit
                                        ? Icons.credit_card_rounded
                                        : Icons.money_rounded,
                                    color: tx.isCredit
                                        ? AppTheme.warningColor
                                        : AppTheme.successColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(formatMoneyWithCurrency(tx.finalAmount),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        if (tx.discount > 0)
                                          Row(
                                            children: [
                                              Icon(Icons.discount_rounded,
                                                  size: 12,
                                                  color: AppTheme.dangerColor.withValues(alpha: 0.7)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'داشکاندن: ${formatMoneyWithCurrency(tx.discount)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.dangerColor.withValues(alpha: 0.8),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '(${formatMoneyWithCurrency(tx.totalAmount)})',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(formatDate(tx.created),
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.grey.shade600)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (tx.isCredit
                                              ? AppTheme.warningColor
                                              : AppTheme.successColor)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(tx.isCredit ? 'قەرز' : 'نەقد',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: tx.isCredit
                                                ? AppTheme.warningColor
                                                : AppTheme.successColor)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),

                const SizedBox(height: 20),

                // Payments
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_rounded,
                          color: AppTheme.successColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('پارەدانەکان (${payments.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ...payments.map((pay) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: AppTheme.successColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  formatMoneyWithCurrency(pay.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.successColor),
                                ),
                              ),
                              Text(formatDate(pay.paymentDate),
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: isBold ? 18 : 14)),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: isBold ? 18 : 14)),
      ],
    );
  }
}
