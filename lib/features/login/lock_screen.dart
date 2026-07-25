import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';

import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isAuthenticated = false;
  String _displayName = 'Suresh';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _authenticate();
  }

  Future<void> _loadProfile() async {
    final profile = await WordPressApiService.instance.getUserProfile();
    if (mounted) {
      setState(() {
        if (profile['display_name']?.isNotEmpty == true) {
          _displayName = profile['display_name']!;
        }
        _avatarUrl = profile['avatar_url'];
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    setState(() => _isAuthenticating = true);
    
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        // If device has no biometrics/security, just let them in (or force a PIN fallback later)
        _handleSuccess();
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'कृपया ॲप उघडण्यासाठी बायोमेट्रिक पडताळणी करा',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuthenticate) {
        _handleSuccess();
      } else {
        setState(() => _isAuthenticating = false);
      }
    } catch (e) {
      // In case of error (e.g. no hardware), just let them in or show an error
      _handleSuccess(); 
    }
  }

  void _handleSuccess() {
    setState(() {
      _isAuthenticated = true;
      _isAuthenticating = false;
    });

    // We will show the animation for a couple seconds, then navigate to dashboard
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      // Show Welcome Animation
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie Success Animation
              Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_rc5d0f61.json',
                width: 150,
                height: 150,
                repeat: false,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome $_displayName !',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Lock screen UI
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ClipOval(
                child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Icons.person, size: 60, color: AppTheme.primary),
                      )
                    : const Icon(Icons.person, size: 60, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'पुन्हा स्वागत,',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 5),
            Text(
              _displayName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            if (_isAuthenticating)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, size: 24),
                label: const Text('साइन इन करण्यासाठी टॅप करा'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
