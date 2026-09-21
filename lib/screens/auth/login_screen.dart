import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _showPassword = false;
  final bool _showServerSettings = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _serverUrlController.text = auth.serverUrl;
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _animController.dispose();
    super.dispose();
  }

  static const String _whatsappNumber = '7502321637';

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (_showServerSettings && _serverUrlController.text.isNotEmpty) {
      await auth.setServerUrl(_serverUrlController.text.trim());
    }
    await auth.login(_emailController.text.trim(), _passwordController.text);
  }

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2E7D32)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هەژمار دروستکردن',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'بۆ دروستکردنی هەژماری نوێ، تکایە پەیوەندی بە واتساپ بکە:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_rounded,
                          color: Color(0xFF25D366), size: 22),
                      SizedBox(width: 10),
                      Text(
                        _whatsappNumber,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('داخستن'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: _whatsappNumber));
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ژمارەی واتساپ کۆپی کرا'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('کۆپی'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            // Left branding panel (desktop/tablet)
            if (isWide)
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B5E20),
                        Color(0xFF2E7D32),
                        Color(0xFF388E3C)
                      ],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                size: 72, color: Colors.white),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'مارکێتی دەروازە',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'NotoKufiArabic',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سیستەمی بەڕێوەبردنی مارکێت',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontFamily: 'NotoKufiArabic',
                            ),
                          ),
                          const SizedBox(height: 48),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _FeatureItem(
                                    icon: Icons.people_rounded,
                                    label: 'بریکارەکان'),
                                SizedBox(width: 40),
                                _FeatureItem(
                                    icon: Icons.receipt_long_rounded,
                                    label: 'کڕینەکان'),
                                SizedBox(width: 40),
                                _FeatureItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: 'حیسابات'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Login form
            Expanded(
              flex: isWide ? 4 : 1,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 48 : 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isWide) ...[
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1B5E20),
                                        Color(0xFF2E7D32)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.storefront_rounded,
                                      size: 48, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text('مارکێتی دەروازە',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 32),
                            ],
                            Text('چوونەژوورەوە',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('زانیارییەکانت بنووسە بۆ چوونەژوورەوە',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14)),
                            const SizedBox(height: 32),

                            // Server settings (hidden — default URL is pre-configured)

                            // Email
                            TextFormField(
                              controller: _emailController,
                              textDirection: TextDirection.ltr,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 15),
                              decoration: const InputDecoration(
                                labelText: 'ئیمەیڵ',
                                prefixIcon:
                                    Icon(Icons.email_outlined, size: 20),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'تکایە ئیمەیڵ بنووسە'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'وشەی نهێنی',
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'تکایە وشەی نهێنی بنووسە'
                                  : null,
                              onFieldSubmitted: (_) => _login(),
                            ),

                            // Error
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                if (auth.error == null) {
                                  return const SizedBox(height: 24);
                                }
                                final isDeactivated = auth.wasDeactivated;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: (isDeactivated ? AppTheme.warningColor : AppTheme.dangerColor)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: isDeactivated
                                          ? Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3))
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDeactivated ? Icons.block_rounded : Icons.error_outline,
                                          color: isDeactivated ? AppTheme.warningColor : AppTheme.dangerColor,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(auth.error!,
                                              style: TextStyle(
                                                  color: isDeactivated ? AppTheme.warningColor : AppTheme.dangerColor,
                                                  fontSize: 13,
                                                  fontWeight: isDeactivated ? FontWeight.w600 : FontWeight.normal)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Login Button
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: auth.isLoading ? null : _login,
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white),
                                          )
                                        : const Text('چوونەژوورەوە',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'هەژمارت نییە؟',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showCreateAccountDialog,
                                  child: const Text(
                                    'هەژمار دروست بکە',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'NotoKufiArabic')),
      ],
    );
  }
}
