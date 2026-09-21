import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pb_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final PBService _pb = PBService();
  List<RecordModel> _users = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _listAnimController;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _subscribeRealtime();
    });
  }

  void _subscribeRealtime() {
    if (_subscribed) return;
    _subscribed = true;
    _pb.pb.collection('users').subscribe('*', (e) {
      // Reload users on any change (create, update, delete)
      if (mounted) _loadUsers();
    });
  }

  @override
  void dispose() {
    _pb.pb.collection('users').unsubscribe('*');
    _listAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await _pb.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
        _listAnimController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text('تەنها ئەدمین دەستگەیشتنی هەیە',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 56, color: AppTheme.dangerColor.withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        const Text(
                          'نەتوانرا یوزەرەکان بارببکرێن',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.dangerColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لە PocketBase Admin Panel:\n'
                          'Collections → users → ⚙️ Settings → API Rules\n'
                          'List/Search بکە بە: @request.auth.role = "admin"',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadUsers,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('هەوڵبدەرەوە'),
                        ),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('هیچ یوزەرێک نییە',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final interval = Interval(
                        (index * 0.1).clamp(0.0, 0.6),
                        ((index * 0.1) + 0.4).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic,
                      );
                      return AnimatedBuilder(
                        animation: _listAnimController,
                        builder: (context, child) {
                          final value = interval.transform(
                              _listAnimController.value);
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: _UserCard(
                          user: _users[index],
                          currentUserId: auth.currentUserId ?? '',
                          onToggleActive: () => _toggleActive(_users[index]),
                          onResetPassword: () =>
                              _showResetPasswordDialog(_users[index]),
                          onEdit: () => _showEditUserDialog(_users[index]),
                          onDelete: () => _confirmDeleteUser(_users[index]),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'users_fab',
              onPressed: () => _showAddUserSheet(),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('یوزەری نوێ'),
            )
          : null,
    );
  }

  // ─── Toggle Active/Inactive ──────────────────────────────────────────
  Future<void> _toggleActive(RecordModel user) async {
    final isActive = user.data['active'] ?? true;
    final name = user.data['name'] ?? user.data['email'] ?? '';
    final action = isActive ? 'ناچالاککردن' : 'چالاککردن';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isActive ? AppTheme.warningColor : AppTheme.successColor)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive
                  ? Icons.person_off_rounded
                  : Icons.person_rounded,
              color: isActive ? AppTheme.warningColor : AppTheme.successColor,
              size: 28,
            ),
          ),
          title: Text('$action ی یوزەر'),
          content: Text('دڵنیایت لە $action ی "$name"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isActive ? AppTheme.warningColor : AppTheme.successColor,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _pb.toggleUserActive(user.id, !isActive);
        await _pb.logActivity(
          actionType: isActive ? 'deactivate' : 'activate',
          entityType: 'user',
          entityId: user.id,
          description:
              'یوزەری "$name" ${isActive ? 'ناچالاککرا' : 'چالاککرا'}',
        );
        await _loadUsers();
        if (mounted && isActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('یوزەر ناچالاککرا — لە داهاتوودا ناتوانێت بچێتە ژوورەوە'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('هەڵە: $e')),
          );
        }
      }
    }
  }

  // ─── Reset Password ──────────────────────────────────────────────────
  void _showResetPasswordDialog(RecordModel user) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  color: AppTheme.warningColor, size: 28),
            ),
            title: Text(
                'گۆڕینی وشەی نهێنی "${user.data['name'] ?? ''}"'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscure,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'وشەی نهێنی نوێ *',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'وشەی نهێنی پێویستە';
                      }
                      if (v.length < 8) return 'لانیکەم ٨ پیت';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscure,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'دووبارە وشەی نهێنی *',
                      prefixIcon:
                          Icon(Icons.lock_outline, size: 20),
                    ),
                    validator: (v) {
                      if (v != passwordController.text) {
                        return 'وشەی نهێنی یەکناگرێتەوە';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await _pb.resetUserPassword(
                        user.id, passwordController.text);
                    await _pb.logActivity(
                      actionType: 'reset_password',
                      entityType: 'user',
                      entityId: user.id,
                      description:
                          'وشەی نهێنی "${user.data['name'] ?? ''}" گۆڕدرا',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('وشەی نهێنی گۆڕدرا — یوزەر بە ئۆتۆماتیکی لۆگ ئاوت دەبێت'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('هەڵە: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('گۆڕین'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Edit User ───────────────────────────────────────────────────────
  void _showEditUserDialog(RecordModel user) {
    final nameController =
        TextEditingController(text: user.data['name']?.toString() ?? '');
    final emailController =
        TextEditingController(text: user.data['email']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    String selectedRole = user.data['role']?.toString() ?? 'user';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('دەسکاریکردنی یوزەر'),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'ناو *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'ناو پێویستە' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailController,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'ئیمەیڵ *',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'ئیمەیڵ پێویستە' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'ڕۆڵ',
                        prefixIcon:
                            Icon(Icons.admin_panel_settings_outlined, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'admin', child: Text('ئەدمین')),
                        DropdownMenuItem(
                            value: 'user', child: Text('یوزەر')),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedRole = v ?? 'user'),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await _pb.updateUser(user.id, {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'role': selectedRole,
                    });
                    await _pb.logActivity(
                      actionType: 'update',
                      entityType: 'user',
                      entityId: user.id,
                      description:
                          'یوزەری "${nameController.text.trim()}" نوێکرایەوە',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadUsers();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('هەڵە: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('نوێکردنەوە'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Delete User ─────────────────────────────────────────────────────
  Future<void> _confirmDeleteUser(RecordModel user) async {
    final name = user.data['name'] ?? user.data['email'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_forever_rounded,
                color: AppTheme.dangerColor, size: 28),
          ),
          title: const Text('سڕینەوەی یوزەر'),
          content: Text('دڵنیایت لە سڕینەوەی "$name"؟\nئەم کردارە ناگەڕێتەوە.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('سڕینەوە'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _pb.deleteUser(user.id);
        await _pb.logActivity(
          actionType: 'delete',
          entityType: 'user',
          entityId: user.id,
          description: 'یوزەری "$name" سڕایەوە',
        );
        await _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('هەڵە: $e')),
          );
        }
      }
    }
  }

  // ─── Add User Sheet ──────────────────────────────────────────────────
  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddUserSheet(onSaved: _loadUsers),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// User Card
// ═══════════════════════════════════════════════════════════════════════════

class _UserCard extends StatelessWidget {
  final RecordModel user;
  final String currentUserId;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.currentUserId,
    required this.onToggleActive,
    required this.onResetPassword,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.data['name']?.toString() ?? 'بێناو';
    final email = user.data['email']?.toString() ?? '';
    final role = user.data['role']?.toString() ?? 'user';
    final isActive = user.data['active'] ?? true;
    final isCurrentUser = user.id == currentUserId;
    final isAdmin = role == 'admin';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Status indicator bar
            Container(
              height: 3,
              color: isActive ? AppTheme.successColor : Colors.grey.shade400,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isAdmin
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.person_rounded,
                              color: isAdmin
                                  ? AppTheme.primaryColor
                                  : Colors.blue,
                              size: 26,
                            ),
                          ),
                          // Active indicator dot
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.successColor
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
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
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isActive
                                          ? null
                                          : Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'تۆ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.email_outlined,
                                    size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAdmin ? 'ئەدمین' : 'یوزەر',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isAdmin ? AppTheme.primaryColor : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons row
                  if (!isCurrentUser)
                    Row(
                      children: [
                        _ActionChip(
                          icon: isActive
                              ? Icons.person_off_outlined
                              : Icons.person_rounded,
                          label: isActive ? 'ناچالاک' : 'چالاک',
                          color: isActive
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                          onTap: onToggleActive,
                        ),
                        const SizedBox(width: 8),
                     //   _ActionChip(
                        //  icon: Icons.lock_reset_rounded,
                      //     label: 'پاسوۆرد',
                      //    color: Colors.orange,
                      //    onTap: onResetPassword,
                      //  ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          icon: Icons.edit_outlined,
                          label: 'دەسکاری',
                          color: AppTheme.primaryColor,
                          onTap: onEdit,
                        ),
                        const Spacer(),
                        _ActionChip(
                          icon: Icons.delete_outline_rounded,
                          label: 'سڕینەوە',
                          color: AppTheme.dangerColor,
                          onTap: onDelete,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add User Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _AddUserSheet extends StatefulWidget {
  final Future<void> Function() onSaved;
  const _AddUserSheet({required this.onSaved});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet>
    with SingleTickerProviderStateMixin {
  final PBService _pb = PBService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'user';
  bool _obscurePassword = true;
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _avatarScale;
  late Animation<Offset> _field1Slide;
  late Animation<Offset> _field2Slide;
  late Animation<Offset> _field3Slide;
  late Animation<Offset> _field4Slide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _avatarScale = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );

    _field1Slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.1, 0.45, curve: Curves.easeOutCubic),
    ));

    _field2Slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic),
    ));

    _field3Slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic),
    ));

    _field4Slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic),
    ));

    _buttonFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _pb.createUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _selectedRole,
      );
      await _pb.logActivity(
        actionType: 'create',
        entityType: 'user',
        description:
            'یوزەری "${_nameController.text.trim()}" زیادکرا بە ڕۆڵی $_selectedRole',
      );
      if (mounted) {
        await widget.onSaved();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e')),
        );
      }
    }
  }

  Widget _buildField({
    required Animation<Offset> slideAnim,
    required double fadeStart,
    required double fadeEnd,
    required Widget child,
  }) {
    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animController,
          curve: Interval(fadeStart, fadeEnd),
        ),
        child: child,
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
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                              AppTheme.primaryColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'زیادکردنی یوزەری نوێ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  ScaleTransition(
                    scale: _avatarScale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _selectedRole == 'admin'
                              ? [
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                                  AppTheme.primaryColor.withValues(alpha: 0.05),
                                ]
                              : [
                                  Colors.blue.withValues(alpha: 0.2),
                                  Colors.blue.withValues(alpha: 0.05),
                                ],
                        ),
                        border: Border.all(
                          color: _selectedRole == 'admin'
                              ? AppTheme.primaryColor.withValues(alpha: 0.3)
                              : Colors.blue.withValues(alpha: 0.3),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        _selectedRole == 'admin'
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_rounded,
                        size: 36,
                        color: _selectedRole == 'admin'
                            ? AppTheme.primaryColor
                            : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  _buildField(
                    slideAnim: _field1Slide,
                    fadeStart: 0.1,
                    fadeEnd: 0.45,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'ناو *',
                        prefixIcon:
                            const Icon(Icons.person_outline_rounded, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'ناو پێویستە' : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  _buildField(
                    slideAnim: _field2Slide,
                    fadeStart: 0.2,
                    fadeEnd: 0.55,
                    child: TextFormField(
                      controller: _emailController,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'ئیمەیڵ *',
                        prefixIcon:
                            const Icon(Icons.email_outlined, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'ئیمەیڵ پێویستە';
                        }
                        if (!v.contains('@')) return 'ئیمەیڵی دروست بنووسە';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  _buildField(
                    slideAnim: _field3Slide,
                    fadeStart: 0.3,
                    fadeEnd: 0.65,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'وشەی نهێنی *',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'وشەی نهێنی پێویستە';
                        }
                        if (v.length < 8) return 'لانیکەم ٨ پیت پێویستە';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Role selector
                  _buildField(
                    slideAnim: _field4Slide,
                    fadeStart: 0.4,
                    fadeEnd: 0.75,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.shield_outlined,
                              size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text('ڕۆڵ:',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _RoleOption(
                                    label: 'یوزەر',
                                    icon: Icons.person_rounded,
                                    isSelected: _selectedRole == 'user',
                                    color: Colors.blue,
                                    onTap: () =>
                                        setState(() => _selectedRole = 'user'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RoleOption(
                                    label: 'ئەدمین',
                                    icon: Icons.admin_panel_settings_rounded,
                                    isSelected: _selectedRole == 'admin',
                                    color: AppTheme.primaryColor,
                                    onTap: () =>
                                        setState(() => _selectedRole = 'admin'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Buttons
                  FadeTransition(
                    opacity: _buttonFade,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('پاشگەزبوونەوە'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                : const Icon(Icons.add_rounded, size: 20),
                            label: const Text('زیادکردن'),
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

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
