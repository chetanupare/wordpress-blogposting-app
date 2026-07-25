import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  String _statusMessage = 'प्रारंभ करत आहे...';
  bool _hasError = false;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _runHealthChecks();
  }

  Future<void> _runHealthChecks() async {
    try {
      if (!mounted) return;
      setState(() => _statusMessage = 'इंटरनेट कनेक्शन तपासत आहे...');
      // 1. Check Internet DNS
      final result = await InternetAddress.lookup('spnewsmaregaon.com').timeout(const Duration(seconds: 10));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('इंटरनेट कनेक्शन नाही (No internet)');
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'वेबसाइट तपासत आहे...');
      final api = WordPressApiService.instance;
      // 2. Check Website Reachability
      final ping = await api.dio.get('https://spnewsmaregaon.com/').timeout(const Duration(seconds: 10));
      if (ping.statusCode != 200 && ping.statusCode != 301 && ping.statusCode != 302) {
        throw Exception('वेबसाइट उपलब्ध नाही (HTTP ${ping.statusCode})');
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'API रूट तपासत आहे...');
      // 3. Check WP API Route
      final routeCheck = await api.dio.get('https://spnewsmaregaon.com/index.php?rest_route=/').timeout(const Duration(seconds: 10));
      if (routeCheck.statusCode != 200) {
        throw Exception('API रूट चुकीचा आहे (API Not Found - HTTP ${routeCheck.statusCode})');
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'लॉगिन तपासत आहे...');
      
      final loggedIn = await api.isLoggedIn();
      
      // Delay slightly for UX
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      
      if (loggedIn) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorDetail = 'Error: $e';
        _statusMessage = 'त्रुटी आढळली! (Check failed)';
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/images/logo.webp', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SP Posting',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'मारेगाव बातम्या व्यवस्थापक',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 48),
              if (!_hasError) ...[
                Text(_statusMessage, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    backgroundColor: AppTheme.outline,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ] else ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 32),
                      const SizedBox(height: 8),
                      Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                      const SizedBox(height: 4),
                      Text(_errorDetail, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _hasError = false; _errorDetail = ''; });
                          _runHealthChecks();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                        child: const Text('पुन्हा प्रयत्न करा (Retry)'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
