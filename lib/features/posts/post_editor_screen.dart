import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../models/wp_models.dart';
import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';

class PostEditorScreen extends ConsumerStatefulWidget {
  final int? postId;
  const PostEditorScreen({super.key, this.postId});

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();

  String _status = 'draft';
  List<int> _selectedCategories = [];
  List<int> _selectedTags = [];
  WpPost? _originalPost;
  bool _loading = false;
  bool _saving = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() => _loading = true);
    try {
      final posts = await WordPressApiService.instance.getPosts(status: 'any', perPage: 1);
      // Fetch specific post by filtering
      final api = WordPressApiService.instance;
      final r = await api.getPosts(status: 'any', perPage: 1, search: '');
      // For simplicity: direct get by ID
      // In production, use /posts/{id} endpoint
      // We'll simulate by finding matching ID
    } catch (e) {
      _showSnack('बातमी लोड करण्यात अयशस्वी');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String targetStatus) async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showSnack('शीर्षक आवश्यक आहे');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'excerpt': _excerptCtrl.text.trim(),
        'status': targetStatus,
        'slug': _slugCtrl.text.trim(),
        'categories': _selectedCategories,
        'tags': _selectedTags,
      };
      if (widget.postId != null) {
        await WordPressApiService.instance.updatePost(widget.postId!, data);
      } else {
        await WordPressApiService.instance.createPost(data);
      }
      if (!mounted) return;
      _showSnack(targetStatus == 'publish' ? 'बातमी प्रकाशित झाली!' : 'मसुदा जतन झाला');
      ref.invalidate(postsProvider('any'));
      ref.invalidate(dashboardStatsProvider);
      context.go('/posts');
    } catch (e) {
      _showSnack('जतन करण्यात अयशस्वी: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _excerptCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/posts'),
        ),
        title: Text(
          widget.postId == null ? 'नवी बातमी' : 'बातमी संपादित करा',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            onPressed: _saving ? null : () => _save('draft'),
            tooltip: 'मसुदा जतन',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Title
                  TextField(
                    controller: _titleCtrl,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'शीर्षक लिहा...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(),
                  // Formatting Toolbar
                  _buildToolbar(context),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Content
                  TextField(
                    controller: _contentCtrl,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'इथे बातमी लिहा...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Settings Panel
                  if (_showSettings) _buildSettingsPanel(context),
                ],
              ),
            ),
          ),
          // Word count + publish bar
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    const btns = [
      ('H1', 'heading1'),
      ('H2', 'heading2'),
      ('B', 'bold'),
      ('I', 'italic'),
      ('•', 'list'),
      ('"', 'quote'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: btns.map((b) => InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(b.$1, style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: b.$1 == 'B' ? FontWeight.w800 : FontWeight.w500,
              fontStyle: b.$1 == 'I' ? FontStyle.italic : FontStyle.normal,
            )),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSettingsPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Text('बातमी सेटिंग्ज', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _slugCtrl,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: const InputDecoration(labelText: 'Slug (URL)', prefixIcon: Icon(Icons.link, size: 16)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _excerptCtrl,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'सारांश (Excerpt)', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        // Categories
        _CategorySelector(selectedIds: _selectedCategories, onChanged: (ids) => setState(() => _selectedCategories = ids)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final words = _contentCtrl.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outline)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Text('$words शब्द', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          OutlinedButton(
            onPressed: _saving ? null : () => _save('draft'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            child: const Text('मसुदा'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : () => _save('publish'),
            icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, size: 15),
            label: const Text('प्रकाशित'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
          ),
        ],
      ),
    );
  }
}

class _CategorySelector extends ConsumerWidget {
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;

  const _CategorySelector({required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);
    return catsAsync.when(
      data: (cats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('श्रेणी', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: cats.take(15).map((cat) {
              final selected = selectedIds.contains(cat.id);
              return FilterChip(
                label: Text(cat.name, style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppTheme.onSurface)),
                selected: selected,
                onSelected: (v) {
                  final newIds = List<int>.from(selectedIds);
                  if (v) newIds.add(cat.id); else newIds.remove(cat.id);
                  onChanged(newIds);
                },
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? AppTheme.primary : AppTheme.outline)),
              );
            }).toList(),
          ),
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox(),
    );
  }
}
