import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme.dart';
import '../../providers/broker_provider.dart';
import '../../kurdish_reshaper.dart';

class GeneralStatementScreen extends StatelessWidget {
  const GeneralStatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('کەشفی حیسابی گشتی'),
          actions: [
            FilledButton.icon(
              onPressed: () => _printGeneralStatement(context),
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
        body: Consumer<BrokerProvider>(
          builder: (context, brokerProvider, _) {
            if (brokerProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final brokers = brokerProvider.brokers;
            final totalDebt = brokers.fold<double>(0, (s, b) => s + b.totalDebt);
            final totalPaid = brokers.fold<double>(0, (s, b) => s + b.totalPaid);
            final totalBalance = totalDebt - totalPaid;
            final brokersWithDebt = brokers.where((b) => b.balance > 0).toList()
              ..sort((a, b) => b.balance.compareTo(a.balance));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('کۆی کڕینەکان:', formatMoneyWithCurrency(totalDebt)),
                      const SizedBox(height: 8),
                      _summaryRow('کۆی پارەدانەکان:', formatMoneyWithCurrency(totalPaid)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Colors.grey.shade300),
                      ),
                      _summaryRow(
                        'ماوەی گشتی:',
                        formatMoneyWithCurrency(totalBalance),
                        isBold: true,
                        valueColor: totalBalance > 0 ? AppTheme.dangerColor : AppTheme.successColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Broker list header
                Row(
                  children: [
                    const Icon(Icons.people_rounded, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'بریکارەکان (${brokers.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('بریکار', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      Expanded(flex: 2, child: Text('کڕین', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('پارەدان', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('ماوە', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.left)),
                    ],
                  ),
                ),

                // Broker rows
                ...brokers.asMap().entries.map((e) {
                  final broker = e.value;
                  final isLast = e.key == brokers.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: isLast
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade200, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(broker.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              if (broker.companyName != null && broker.companyName!.isNotEmpty)
                                Text(broker.companyName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatMoney(broker.totalDebt),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatMoney(broker.totalPaid),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatMoney(broker.balance),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: broker.balance > 0 ? AppTheme.dangerColor : AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (brokersWithDebt.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.dangerColor),
                      const SizedBox(width: 8),
                      Text(
                        'قەرزدارەکان (${brokersWithDebt.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...brokersWithDebt.map((broker) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(broker.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text(
                                  formatMoneyWithCurrency(broker.balance),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.dangerColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: isBold ? 18 : 14)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: isBold ? 18 : 14)),
      ],
    );
  }

  Future<void> _printGeneralStatement(BuildContext context) async {
    final brokers = context.read<BrokerProvider>().brokers;
    if (brokers.isEmpty) return;

    final totalDebt = brokers.fold<double>(0, (s, b) => s + b.totalDebt);
    final totalPaid = brokers.fold<double>(0, (s, b) => s + b.totalPaid);
    final totalBalance = totalDebt - totalPaid;

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
              pw.Center(child: pw.Text(k('کەشفی حیسابی گشتی'), style: subtitleStyle)),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text(k('بەروار: ${formatDate(DateTime.now())}'), style: baseStyle)),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.SizedBox(height: 14),

              // All brokers table
              pw.Text(k('لیستی بریکارەکان'), style: boldStyle.copyWith(fontSize: 12)),
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
                headers: [k('#'), k('بریکار'), k('کۆمپانیا'), k('کۆی کڕین'), k('کۆی پارەدان'), k('ماوە')],
                data: brokers.asMap().entries.map((e) {
                  final b = e.value;
                  return [
                    '${e.key + 1}',
                    k(b.name),
                    k(b.companyName ?? ''),
                    formatMoney(b.totalDebt),
                    formatMoney(b.totalPaid),
                    formatMoney(b.balance),
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
                  pw.Text(k('کۆی گشتی کڕینەکان:'), style: summaryStyle),
                  pw.Text(k('${formatMoney(totalDebt)} د.ع'), style: summaryStyle),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k('کۆی گشتی پارەدانەکان:'), style: summaryStyle),
                  pw.Text(k('${formatMoney(totalPaid)} د.ع'), style: summaryStyle),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k('ماوەی گشتی:'), style: summaryStyle.copyWith(fontSize: 14)),
                  pw.Text(k('${formatMoney(totalBalance)} د.ع'), style: summaryStyle.copyWith(fontSize: 14)),
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
}
