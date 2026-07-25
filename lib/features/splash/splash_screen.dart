import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'प्रारंभ करत आहे...';
  bool _hasError = false;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
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
        Future.microtask(() => context.go('/lock'));
      } else {
        Future.microtask(() => context.go('/login'));
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
            ).animate()
             .fade(duration: 800.ms)
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 800.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              'SP Posting',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w800),
            ).animate().fade(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 6),
            Text(
              'मारेगाव बातम्या व्यवस्थापक',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant),
            ).animate().fade(delay: 300.ms, duration: 600.ms),
            const SizedBox(height: 48),
            if (!_hasError) ...[
              Text(_statusMessage, style: Theme.of(context).textTheme.bodySmall).animate().fade(delay: 400.ms),
              const SizedBox(height: 12),
              SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.outline,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate().fade(delay: 500.ms, duration: 600.ms),
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
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
