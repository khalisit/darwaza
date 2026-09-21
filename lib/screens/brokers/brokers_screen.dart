import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/broker_provider.dart';
import '../../models/broker.dart';

class BrokersScreen extends StatefulWidget {
  const BrokersScreen({super.key});

  @override
  State<BrokersScreen> createState() => _BrokersScreenState();
}

class _BrokersScreenState extends State<BrokersScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<BrokerProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            final allBrokers = provider.brokers;
            final totalBrokers = allBrokers.length;
            final debtCount = allBrokers.where((b) => b.balance > 0).length;
            final totalDebt = allBrokers
                .where((b) => b.balance > 0)
                .fold<double>(0, (s, b) => s + b.balance);

            final brokers = allBrokers.where((b) {
              final q = _searchQuery.toLowerCase();
              return b.name.toLowerCase().contains(q) ||
                  b.phone.contains(_searchQuery) ||
                  (b.companyName ?? '').toLowerCase().contains(q);
            }).toList();

            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () => provider.loadBrokers(),
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
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
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
                                            color: Colors.grey.shade400,
                                            size: 20),
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
                        const SizedBox(width: 10),
                        Clickable(
                          onTap: () => _showBrokerForm(context),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Summary bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
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
                            icon: Icons.people_rounded,
                            label: '\u06a9\u06c6\u06cc \u0628\u0631\u06cc\u06a9\u0627\u0631',
                            value: '$totalBrokers',
                            color: AppTheme.primaryColor,
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
                            icon: Icons.account_balance_wallet_rounded,
                            label: '\u06a9\u06c6\u06cc \u0642\u06d5\u0631\u0632',
                            value: formatMoneyWithCurrency(totalDebt),
                            color: AppTheme.dangerColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Broker list
                  Expanded(
                    child: brokers.isEmpty
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
                                      size: 48,
                                      color: Colors.grey.shade400),
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
                            padding: const EdgeInsets.fromLTRB(
                                20, 8, 20, 100),
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            itemCount: brokers.length,
                            itemBuilder: (context, index) {
                              final broker = brokers[index];
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(
                                    milliseconds:
                                        300 + (index % 10) * 50),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset:
                                        Offset(0, 15 * (1 - value)),
                                    child: Opacity(
                                        opacity: value,
                                        child: child),
                                  );
                                },
                                child: _buildBrokerCard(
                                    context, broker),
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

  Widget _buildBrokerCard(BuildContext context, Broker broker) {
    final hasDebt = broker.balance > 0;
    final typeColor = hasDebt ? AppTheme.dangerColor : AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Clickable(
        onTap: () => _showBrokerForm(context, broker: broker),
        onLongPress: () => _showOptions(context, broker),
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
              // Avatar — use CachedNetworkImage so we don't re-download on every rebuild.
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 46,
                  height: 46,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  alignment: Alignment.center,
                  child: broker.imageUrl != null && broker.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: broker.imageUrl!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (c, _) => Container(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          ),
                          errorWidget: (c, _, _) => Center(
                            child: Text(
                              broker.name.isNotEmpty
                                  ? broker.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          broker.name.isNotEmpty
                              ? broker.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
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
                        if (broker.createdBy != null &&
                            broker.createdBy!.isNotEmpty) ...[
                          Icon(Icons.person_outline_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text(broker.createdBy!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                          const SizedBox(width: 10),
                        ],
                        if (broker.phone.isNotEmpty) ...[
                          Icon(Icons.phone_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(broker.phone,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                              textDirection: TextDirection.ltr),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Balance + detail icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasDebt)
                        Clickable(
                          onTap: () => _confirmDelete(context, broker),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            margin:
                                const EdgeInsetsDirectional.only(end: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                size: 16,
                                color: AppTheme.dangerColor),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasDebt
                              ? '\u0642\u06d5\u0631\u0632'
                              : broker.balance < 0
                                  ? '\u0632\u06cc\u0627\u062f\u06cc'
                                  : '\u0628\u06ce \u0642\u06d5\u0631\u0632',
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

  void _showBrokerForm(BuildContext context, {Broker? broker}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BrokerFormSheet(
        broker: broker,
        onSave: () {},
      ),
    );
  }

  void _confirmDelete(BuildContext context, Broker broker) async {
    if (broker.balance > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\u0646\u0627\u062a\u0648\u0627\u0646\u06cc\u062a \u0626\u06d5\u0645 \u0628\u0631\u06cc\u06a9\u0627\u0631\u06d5 \u0628\u0633\u0695\u06cc\u062a\u06d5\u0648\u06d5\u060c \u0642\u06d5\u0631\u0632\u06cc ${formatMoneyWithCurrency(broker.balance)} \u0645\u0627\u0648\u06d5'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
    final brokerProv = context.read<BrokerProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('\u0633\u0695\u06cc\u0646\u06d5\u0648\u06d5\u06cc \u0628\u0631\u06cc\u06a9\u0627\u0631'),
          content: Text('\u062f\u06b5\u0646\u06cc\u0627\u06cc\u062a \u0644\u06d5 \u0633\u0695\u06cc\u0646\u06d5\u0648\u06d5\u06cc "${broker.name}"\u061f'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('\u0646\u06d5\u062e\u06ce\u0631'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('\u0633\u0695\u06cc\u0646\u06d5\u0648\u06d5'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      try {
        final ok = await brokerProv.deleteBroker(broker.id);
        if (!ok) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('هەڵە لە سڕینەوەی بریکار'),
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

  void _showOptions(BuildContext context, Broker broker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('\u0628\u06cc\u0646\u06cc\u0646\u06cc \u0648\u0631\u062f\u06d5\u06a9\u0627\u0631\u06cc'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context)
                        .pushNamed('/broker-detail', arguments: broker.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('\u062f\u06d5\u0633\u06a9\u0627\u0631\u06cc\u06a9\u0631\u062f\u0646',
                      style: TextStyle(color: AppTheme.primaryColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBrokerForm(context, broker: broker);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.dangerColor),
                  title: const Text('\u0633\u0695\u06cc\u0646\u06d5\u0648\u06d5',
                      style: TextStyle(color: AppTheme.dangerColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, broker);
                  },
                ),
              ],
            ),
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

// ── Beautiful Animated Broker Form Bottom Sheet ──────────────────────────

class BrokerFormSheet extends StatefulWidget {
  final Broker? broker;
  final VoidCallback onSave;
  const BrokerFormSheet({super.key, this.broker, required this.onSave});

  @override
  State<BrokerFormSheet> createState() => _BrokerFormSheetState();
}

class _BrokerFormSheetState extends State<BrokerFormSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _avatarScale;
  late Animation<Offset> _field1Slide;
  late Animation<Offset> _field2Slide;
  late Animation<Offset> _field3Slide;
  late Animation<double> _buttonFade;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  bool get isEditing => widget.broker != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.broker?.name);
    _phoneController = TextEditingController(text: widget.broker?.phone);
    _companyController = TextEditingController(
      text: widget.broker?.companyName,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _avatarScale = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );

    _field1Slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic),
    ));

    _field2Slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
    ));

    _field3Slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
    ));

    _buttonFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '\u0647\u06d5\u06b5\u0628\u0698\u0627\u0631\u062f\u0646\u06cc \u0648\u06ce\u0646\u06d5',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                if (!kIsWeb)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: AppTheme.primaryColor),
                    ),
                    title: const Text('\u06a9\u0627\u0645\u06ce\u0631\u0627'),
                    subtitle: Text('\u0648\u06ce\u0646\u06d5\u06cc\u06d5\u06a9\u06cc \u0646\u0648\u06ce \u0628\u06af\u0631\u06d5',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: AppTheme.warningColor),
                  ),
                  title: const Text('\u06af\u0627\u0644\u06d5\u0631\u06cc'),
                  subtitle: Text('\u0644\u06d5 \u06af\u0627\u0644\u06d5\u0631\u06cc \u0647\u06d5\u06b5\u0628\u0698\u06ce\u0631\u06d5',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 300,
      maxHeight: 300,
      imageQuality: 50,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<BrokerProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updateBroker(
        id: widget.broker!.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        imageBytes: _selectedImageBytes,
        imageName: _selectedImage?.name,
      );
    } else {
      success = await provider.addBroker(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        imageBytes: _selectedImageBytes,
        imageName: _selectedImage?.name,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        widget.onSave();
        Navigator.pop(context);
      }
    }
  }

  Widget _buildAvatar() {
    final hasImage = _selectedImage != null;
    final hasNetworkImage =
        widget.broker?.imageUrl != null && widget.broker!.imageUrl!.isNotEmpty;
    final name = _nameController.text;

    return ScaleTransition(
      scale: _avatarScale,
      child: Clickable(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 3,
                ),
                image: hasImage
                    ? DecorationImage(
                        image: MemoryImage(_selectedImageBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color:
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: hasImage
                  ? null
                  : hasNetworkImage
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: widget.broker!.imageUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (c, _) => const SizedBox(),
                            errorWidget: (c, _, _) => Center(
                              child: name.isNotEmpty
                                  ? Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryColor,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 40,
                                      color: AppTheme.primaryColor,
                                    ),
                            ),
                          ),
                        )
                      : Center(
                          child: name.isNotEmpty
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: AppTheme.primaryColor,
                                ),
                        ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  hasImage || hasNetworkImage
                      ? Icons.edit_rounded
                      : Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_rounded
                              : Icons.person_add_alt_1_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing
                            ? '\u062f\u06d5\u0633\u06a9\u0627\u0631\u06cc\u06a9\u0631\u062f\u0646\u06cc \u0628\u0631\u06cc\u06a9\u0627\u0631'
                            : '\u0628\u0631\u06cc\u06a9\u0627\u0631\u06cc \u0646\u0648\u06ce',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  _buildAvatar(),
                  const SizedBox(height: 8),
                  Text(
                    '\u06a9\u0644\u06cc\u06a9 \u0628\u06a9\u06d5 \u0628\u06c6 \u0647\u06d5\u06b5\u0628\u0698\u0627\u0631\u062f\u0646\u06cc \u0648\u06ce\u0646\u06d5',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  SlideTransition(
                    position: _field1Slide,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animController,
                        curve: const Interval(0.15, 0.5),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '\u0646\u0627\u0648\u06cc \u0628\u0631\u06cc\u06a9\u0627\u0631 *',
                          prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? '\u0646\u0627\u0648 \u067e\u06ce\u0648\u06cc\u0633\u062a\u06d5'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone field
                  SlideTransition(
                    position: _field2Slide,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animController,
                        curve: const Interval(0.25, 0.6),
                      ),
                      child: TextFormField(
                        controller: _phoneController,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: '\u0698\u0645\u0627\u0631\u06d5\u06cc \u0645\u06c6\u0628\u0627\u06cc\u0644 *',
                          prefixIcon: const Icon(Icons.phone_outlined,
                              size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? '\u0698\u0645\u0627\u0631\u06d5 \u067e\u06ce\u0648\u06cc\u0633\u062a\u06d5'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Company field
                  SlideTransition(
                    position: _field3Slide,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animController,
                        curve: const Interval(0.35, 0.7),
                      ),
                      child: TextFormField(
                        controller: _companyController,
                        decoration: InputDecoration(
                          labelText: '\u0646\u0627\u0648\u06cc \u06a9\u06c6\u0645\u067e\u0627\u0646\u06cc\u0627 (\u0626\u0627\u0631\u06d5\u0632\u0648\u0648\u0645\u06d5\u0646\u062f\u0627\u0646\u06d5)',
                          prefixIcon: const Icon(
                              Icons.business_outlined,
                              size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action buttons
                  FadeTransition(
                    opacity: _buttonFade,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('\u067e\u0627\u0634\u06af\u06d5\u0632\u0628\u0648\u0648\u0646\u06d5\u0648\u06d5'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isEditing
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                                isEditing ? '\u0646\u0648\u06ce\u06a9\u0631\u062f\u0646\u06d5\u0648\u06d5' : '\u0632\u06cc\u0627\u062f\u06a9\u0631\u062f\u0646'),
                          ),
                        ),
                      ],
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
