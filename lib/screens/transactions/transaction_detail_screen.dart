import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/activity_log_provider.dart';
import '../../models/transaction.dart' as models;

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final String brokerId;
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    required this.brokerId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وردەکاری کڕین'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
              tooltip: 'دەسکاریکردن',
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/edit-transaction',
                  arguments: {
                    'transactionId': widget.transactionId,
                    'brokerId': widget.brokerId,
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerColor),
              tooltip: 'سڕینەوە',
              onPressed: () async {
                final txProvider = context.read<TransactionProvider>();
                final brokerProv = context.read<BrokerProvider>();
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    icon: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppTheme.dangerColor, size: 28),
                    ),
                    title: const Text('سڕینەوەی کڕین'),
                    content: const Text('دڵنیایت لە سڕینەوەی ئەم کڕینە؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('نەخێر'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.dangerColor),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('سڕینەوە'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  final ok = await txProvider.deleteTransaction(
                    widget.transactionId,
                    brokerId: widget.brokerId,
                  );
                  if (ok) {
                    // Only refresh and pop if still mounted
                    if (mounted) {
                      brokerProv.loadBrokers();
                      if (!context.mounted) return;
                      context.read<ActivityLogProvider>().loadLogs();
                      nav.pop();
                    }
                  } else {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('هەڵە لە سڕینەوەی کڕین'),
                          backgroundColor: AppTheme.dangerColor,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('هەڵە: $e'),
                        backgroundColor: AppTheme.dangerColor,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Consumer<TransactionProvider>(
          builder: (context, provider, _) {
            models.Transaction? tx;
            try {
              tx = provider.transactions
                  .firstWhere((t) => t.id == widget.transactionId);
            } catch (_) {
              return const Center(child: Text('کڕین نەدۆزرایەوە'));
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: tx.isCredit
                          ? [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)]
                          : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (tx.isCredit
                              ? AppTheme.warningColor
                              : AppTheme.successColor)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('جۆر:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: (tx.isCredit
                                      ? AppTheme.warningColor
                                      : AppTheme.successColor)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tx.isCredit ? 'قەرز' : 'نەقد',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: tx.isCredit
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('بەروار:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(formatDate(tx.transactionDate),
                              style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                      if (tx.partnerName != null && tx.partnerName!.isNotEmpty) ...[                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('شەریکە:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(tx.partnerName!,
                                style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ],
                      if (tx.createdBy != null && tx.createdBy!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تۆمارکەر:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_rounded, size: 14, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(tx.createdBy!,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppTheme.primaryColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.grey.shade300),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('کۆی گشتی:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18)),
                          Text(
                            formatMoneyWithCurrency(tx.finalAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: tx.isCredit
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                      if (tx.discount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.discount_rounded, size: 16, color: AppTheme.dangerColor.withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Text('داشکاندن:', style: TextStyle(color: AppTheme.dangerColor.withValues(alpha: 0.8), fontSize: 13)),
                              ],
                            ),
                            Row(
                              children: [
                                Text(formatMoneyWithCurrency(tx.totalAmount),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                        decoration: TextDecoration.lineThrough)),
                                const SizedBox(width: 8),
                                Text('- ${formatMoneyWithCurrency(tx.discount)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppTheme.dangerColor.withValues(alpha: 0.8))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.note_alt_outlined,
                                size: 18, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tx.notes!)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Receipts Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppTheme.secondaryColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('وەصڵەکان',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: provider.getReceipts(widget.transactionId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 32, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('هیچ وەصڵێک نییە',
                                style:
                                    TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }
                    final receipts = snapshot.data!;
                    return SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: receipts.length,
                        itemBuilder: (context, index) {
                          final url =
                              provider.getReceiptUrl(receipts[index]);
                          return Clickable(
                            onTap: () => _showReceiptDialog(context, url),
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              width: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e, s) => Container(
                                          color: Colors.grey.shade100,
                                          alignment: Alignment.center,
                                          child: Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.grey.shade400),
                                        )),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showReceiptDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
