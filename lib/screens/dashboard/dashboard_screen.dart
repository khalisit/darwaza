import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/activity_log_provider.dart';
import '../../services/pb_service.dart';
import 'home_screen.dart';
import '../brokers/brokers_screen.dart';
import '../transactions/transactions_screen.dart';
import '../payments/payments_screen.dart';
import '../users/user_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;
  const DashboardScreen({super.key, this.initialTab = 2});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _selectedIndex;
  late List<Widget> _screens;
  bool _lastIsAdmin = false;
  Timer? _realtimeDebounce;

  // Tracks which collections fired events during the debounce window so we
  // only reload the providers that actually need refreshing.
  final Set<String> _dirtyCollections = <String>{};

  static const _baseScreens = <Widget>[
    HomeScreen(),
    BrokersScreen(),
    TransactionsScreen(),
    PaymentsScreen(),
  ];

  List<_NavItem> _buildNavItems(bool isAdmin) {
    final items = <_NavItem>[
      const _NavItem(
        Icons.dashboard_outlined,
        Icons.dashboard_rounded,
        'داشبۆرد',
      ),
      const _NavItem(
        Icons.people_outline_rounded,
        Icons.people_rounded,
        'بریکارەکان',
      ),
      const _NavItem(
        Icons.shopping_cart_outlined,
        Icons.shopping_cart_rounded,
        'کڕینەکان',
        isCenter: true,
      ),
      const _NavItem(
        Icons.payments_outlined,
        Icons.payments_rounded,
        'پارەدان',
      ),
    ];
    if (isAdmin) {
      items.add(
        const _NavItem(
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings_rounded,
          'یوزەرەکان',
        ),
      );
    }
    return items;
  }

  void _rebuildScreens(bool isAdmin) {
    _lastIsAdmin = isAdmin;
    if (isAdmin) {
      _screens = [..._baseScreens, const UserManagementScreen()];
    } else {
      _screens = [..._baseScreens];
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _screens = [..._baseScreens];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ensureLoaded — avoids repeating the initial load if another screen
      // already triggered it.
      context.read<BrokerProvider>().ensureLoaded();
      _initRealtime();
    });
  }

  @override
  void dispose() {
    _disposeRealtime();
    super.dispose();
  }

  void _initRealtime() {
    final pb = PBService().pb;
    const collections = [
      'brokers',
      'transactions',
      'payments',
      'activity_logs',
    ];
    for (final c in collections) {
      pb.collection(c).subscribe('*', (_) => _scheduleRefresh(c));
    }
  }

  /// Debounced, scoped refresh. Only reloads the providers whose collections
  /// actually changed during the debounce window — instead of reloading
  /// EVERYTHING on every event.
  void _scheduleRefresh(String collection) {
    _dirtyCollections.add(collection);
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final dirty = Set<String>.from(_dirtyCollections);
      _dirtyCollections.clear();

      // Balances depend on transactions + payments + brokers list, so we
      // reload brokers whenever any of those three change.
      if (dirty.contains('brokers') ||
          dirty.contains('transactions') ||
          dirty.contains('payments')) {
        context.read<BrokerProvider>().loadBrokers(silent: true);
      }
      if (dirty.contains('transactions')) {
        context.read<TransactionProvider>().refreshCurrent();
      }
      if (dirty.contains('payments')) {
        context.read<PaymentProvider>().loadPayments();
      }
      if (dirty.contains('activity_logs')) {
        context.read<ActivityLogProvider>().loadLogs();
      }
    });
  }

  void _disposeRealtime() {
    _realtimeDebounce?.cancel();
    try {
      final pb = PBService().pb;
      for (final c in [
        'brokers',
        'transactions',
        'payments',
        'activity_logs',
      ]) {
        pb.collection(c).unsubscribe();
      }
    } catch (_) {}
  }

  void _onTabChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final useRail = isDesktop || isTablet;
    final isAdmin = context.select<AuthProvider, bool>((a) => a.isAdmin);
    final currentUserName = context.select<AuthProvider, String?>(
      (a) => a.currentUserName,
    );
    if (isAdmin != _lastIsAdmin) {
      _rebuildScreens(isAdmin);
    }
    final navItems = _buildNavItems(isAdmin);
    // Clamp index in case admin status changes
    if (_selectedIndex >= _screens.length) {
      _selectedIndex = 0;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // In RTL, leading sits on the visual right side.
          leadingWidth: 72,
          leading: TextButton(
            onPressed: () => _showDeleteAccountDialog(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color.fromARGB(255, 224, 11, 11),
                letterSpacing: 0.2,
              ),
            ),
          ),
          title: const Text('مارکێتی دەروازە'),
          actions: [
            // User info badge — tap to change password
            if (currentUserName != null)
              InkWell(
                onTap: () => _showChangePasswordDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentUserName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 22),
              tooltip: 'دەرچوون',
              onPressed: () => _showLogoutDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            if (useRail) _buildDesktopNav(navItems),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ],
        ),
        bottomNavigationBar: useRail
            ? null
            : _CustomBottomNav(
                items: navItems,
                selectedIndex: _selectedIndex,
                onTap: _onTabChanged,
              ),
      ),
    );
  }

  Widget _buildDesktopNav(List<_NavItem> items) {
    final isDesktop = Responsive.isDesktop(context);
    return Container(
      width: isDesktop ? 220 : 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo area
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.08),
                      AppTheme.accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'مارکێت',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isDesktop) const SizedBox(height: 8),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == _selectedIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _onTabChanged(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 14 : 0,
                          vertical: isDesktop ? 12 : 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                )
                              : null,
                        ),
                        child: isDesktop
                            ? Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      isSelected
                                          ? item.selectedIcon
                                          : item.icon,
                                      key: ValueKey(isSelected),
                                      size: item.isCenter ? 24 : 22,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    size: item.isCenter ? 26 : 22,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            title: const Text('گۆڕینی وشەی نهێنی'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'وشەی نهێنی ئێستا',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'وشەی نهێنی ئێستا بنووسە'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'وشەی نهێنی نوێ',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'وشەی نهێنی نوێ بنووسە';
                      }
                      if (v.length < 8) {
                        return 'لانیکەم ٨ پیت پێویستە';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'دووبارەکردنەوەی وشەی نهێنی نوێ',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v != newPasswordController.text) {
                        return 'وشەی نهێنی نوێ یەکناگرێتەوە';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە'),
              ),
              FilledButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isLoading = true);
                        try {
                          await context.read<AuthProvider>().changePassword(
                            oldPassword: oldPasswordController.text,
                            newPassword: newPasswordController.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text('وشەی نهێنی بە سەرکەوتوویی گۆڕدرا'),
                                  ],
                                ),
                                backgroundColor: AppTheme.successColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text('وشەی نهێنی ئێستا هەڵەیە'),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        }
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(isLoading ? 'چاوەڕوان بە...' : 'گۆڕین'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppTheme.warningColor,
              size: 28,
            ),
          ),
          title: const Text('دەرچوون'),
          content: const Text('دڵنیایت لە دەرچوون؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بەڵێ'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      _disposeRealtime();
      nav.popUntil((route) => route.isFirst);
      auth.logout();
    }
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: AppTheme.dangerColor,
              size: 28,
            ),
          ),
          title: const Text(
            'Delete Account',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'This will permanently delete your account and you will no longer be able to sign in. This action cannot be undone.\n\nAre you sure you want to continue?',
            style: TextStyle(height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      _disposeRealtime();
      await auth.deleteAccount();
      if (!mounted) return;
      nav.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to delete account. Please contact support or try again.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isCenter;
  const _NavItem(
    this.icon,
    this.selectedIcon,
    this.label, {
    this.isCenter = false,
  });
}

// ─── Custom Animated Bottom Navigation Bar ───
class _CustomBottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  highlightColor: Colors.transparent,
                  child: SizedBox.expand(
                    child: item.isCenter
                        ? _buildCenterItem(item, isSelected)
                        : _buildNormalItem(item, isSelected),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterItem(_NavItem item, bool isSelected) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isSelected ? 48 : 42,
          height: isSelected ? 48 : 42,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isSelected ? item.selectedIcon : item.icon,
            size: 22,
            color: isSelected ? Colors.white : AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNormalItem(_NavItem item, bool isSelected) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Top pill indicator
        Positioned(
          top: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: isSelected ? 20 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'NotoKufiArabic',
                    fontSize: isSelected ? 10 : 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
