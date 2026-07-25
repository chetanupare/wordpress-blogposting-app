import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _useAppPassword = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await WordPressApiService.instance.saveCredentials(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      final ok = await WordPressApiService.instance.testAuth();
      if (!mounted) return;
      if (ok) {
        context.go('/dashboard');
      } else {
        await WordPressApiService.instance.clearCredentials();
        setState(() { _error = 'चुकीचे नाव किंवा पासवर्ड. पुन्हा प्रयत्न करा.'; });
      }
    } catch (e) {
      setState(() { _error = 'सर्व्हरशी जोडण्यात अयशस्वी: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.article_rounded, size: 36, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              // Login Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.outline),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('पुन्हा स्वागत!', style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 4),
                      Text(
                        _useAppPassword
                            ? 'Application Password वापरून साइन इन करा.'
                            : 'SP News Maregaon व्यवस्थापित करण्यासाठी साइन इन करा.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      // Site URL (read-only)
                      TextFormField(
                        initialValue: 'spnewsmaregaon.com',
                        readOnly: true,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          labelText: 'WordPress साइट URL',
                          prefixIcon: Icon(Icons.link, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Username
                      TextFormField(
                        controller: _usernameCtrl,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          labelText: 'वापरकर्तानाम',
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'आवश्यक' : null,
                      ),
                      const SizedBox(height: 12),
                      // Password
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: _useAppPassword ? 'Application Password' : 'पासवर्ड',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'आवश्यक' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, size: 15, color: AppTheme.error),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_error!, style: TextStyle(fontSize: 11, color: AppTheme.error))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('साइन इन'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: const [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('किंवा', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant))),
                        Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 14),
                      // App Password toggle
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.key_outlined, size: 16),
                          label: Text(_useAppPassword ? 'सामान्य पासवर्ड वापरा' : 'Application Password वापरा'),
                          onPressed: () => setState(() { _useAppPassword = !_useAppPassword; _passwordCtrl.clear(); }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'टीप: WordPress Admin → Users → Profile मध्ये Application Password तयार करा.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
