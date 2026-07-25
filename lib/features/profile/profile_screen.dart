import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final u = await WordPressApiService.instance.getCurrentUser();
      if (mounted) setState(() { _user = u; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('साइन आउट', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('तुम्हाला खरोखर साइन आउट करायचे आहे का?', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द करा')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('साइन आउट'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await WordPressApiService.instance.clearCredentials();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('प्रोफाइल')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // Avatar + Info
                Center(
                  child: Column(children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.person, size: 36, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _user?['name'] as String? ?? 'Admin',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      (_user?['roles'] as List?)?.join(', ') ?? 'Administrator',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                // Site info card
                _infoCard(context, [
                  _row(context, Icons.language, 'साइट URL', 'spnewsmaregaon.com'),
                  _row(context, Icons.email_outlined, 'ईमेल', _user?['email'] as String? ?? '—'),
                ]),
                const SizedBox(height: 14),
                // Settings
                _infoCard(context, [
                  _tileRow(context, Icons.article_outlined, 'बातम्या', () => context.go('/posts')),
                  const Divider(height: 1),
                  _tileRow(context, Icons.photo_library_outlined, 'मीडिया लायब्ररी', () => context.go('/media')),
                  const Divider(height: 1),
                  _tileRow(context, Icons.bar_chart_outlined, 'आकडेवारी', () => context.go('/analytics')),
                ]),
                const SizedBox(height: 14),
                // Logout
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 16, color: AppTheme.error),
                    label: const Text('साइन आउट', style: TextStyle(color: AppTheme.error)),
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.error),
                      foregroundColor: AppTheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: Text('SP Posting v1.0 • spnewsmaregaon.com', style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 17, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  Widget _tileRow(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: AppTheme.onSurfaceVariant),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
