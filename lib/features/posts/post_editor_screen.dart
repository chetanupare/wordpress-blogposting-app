import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:markdown/markdown.dart' as md;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

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
  final _excerptCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  
  late quill.QuillController _quillController;
  final FocusNode _editorFocus = FocusNode();

  String _status = 'draft';
  List<int> _selectedCategories = [];
  List<int> _selectedTags = [];
  WpPost? _originalPost;
  
  File? _selectedImageFile;
  String? _featuredMediaUrl;
  int? _featuredMediaId;

  bool _loading = false;
  bool _saving = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    if (widget.postId != null) {
      _loadPost();
    }
  }

  Future<void> _loadPost() async {
    setState(() => _loading = true);
    try {
      final api = WordPressApiService.instance;
      // Ideally we should use /posts/{id}, using simple get for now
      final r = await api.dio.get('https://spnewsmaregaon.com/index.php?rest_route=/wp/v2/posts/${widget.postId}');
      if (r.statusCode == 200) {
        final data = r.data;
        _originalPost = WpPost.fromJson(data);
        _titleCtrl.text = _originalPost!.renderedTitle;
        _excerptCtrl.text = data['excerpt']['raw'] ?? '';
        _slugCtrl.text = _originalPost!.slug;
        _status = _originalPost!.status;
        _selectedCategories = _originalPost!.categories;
        _featuredMediaUrl = _originalPost!.featuredMediaUrl;
        _featuredMediaId = data['featured_media'] == 0 ? null : data['featured_media'];

        // Convert HTML to Quill Delta 
        try {
          String htmlContent = data['content']['rendered'] ?? '';
          if (htmlContent.isNotEmpty) {
            final delta = HtmlToDelta().convert(htmlContent);
            _quillController.document = quill.Document.fromDelta(delta);
          }
        } catch (e) {
          debugPrint('Delta parsing failed: $e');
        }
      }
    } catch (e) {
      _showSnack('बातमी लोड करण्यात अयशस्वी');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      // Use image cropper
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9
        ],
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'फोटो क्रॉप करा',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'फोटो क्रॉप करा',
          ),
        ],
      );

      if (cropped != null) {
        setState(() {
          _selectedImageFile = File(cropped.path);
          _featuredMediaUrl = null;
        });
      }
    }
  }

  Future<int?> _uploadFeaturedImage() async {
    if (_selectedImageFile == null) return _featuredMediaId;
    try {
      final targetPath = '${_selectedImageFile!.path}_compressed.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        _selectedImageFile!.absolute.path,
        targetPath,
        quality: 70,
      );

      final fileToUpload = compressedFile != null ? File(compressedFile.path) : _selectedImageFile!;

      final res = await WordPressApiService.instance.uploadMedia(
        fileToUpload, 
        _selectedImageFile!.path.split('/').last,
      );
      return res.id;
    } catch (e) {
      _showSnack('इमेज अपलोड अयशस्वी: $e');
      return null;
    }
  }

  Future<void> _save(String targetStatus) async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showSnack('शीर्षक आवश्यक आहे');
      return;
    }
    setState(() => _saving = true);
    
    try {
      // Convert Quill Delta to HTML
      final deltaJson = _quillController.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        deltaJson,
        ConverterOptions.options(),
      );
      final htmlContent = converter.convert();

      // Upload image if needed
      final mediaId = await _uploadFeaturedImage();

      final data = {
        'title': _titleCtrl.text.trim(),
        'content': htmlContent,
        'excerpt': _excerptCtrl.text.trim(),
        'status': targetStatus,
        'slug': _slugCtrl.text.trim(),
        'categories': _selectedCategories,
        if (mediaId != null) 'featured_media': mediaId,
      };

      if (widget.postId != null) {
        await WordPressApiService.instance.updatePost(widget.postId!, data);
      } else {
        await WordPressApiService.instance.createPost(data);
      }
      
      // Fire OneSignal Push Notification if publishing
      if (targetStatus == 'publish') {
         await _sendOneSignalPush(_titleCtrl.text.trim());
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

  Future<void> _sendOneSignalPush(String title) async {
    try {
      final creds = await WordPressApiService.instance.getOneSignalCredentials();
      final appId = creds['app_id'];
      final apiKey = creds['api_key'];
      
      if (appId == null || apiKey == null || appId.isEmpty || apiKey.isEmpty) return;

      await WordPressApiService.instance.dio.post(
        'https://onesignal.com/api/v1/notifications',
        options: Options(headers: {
          'Authorization': 'Basic $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'app_id': appId,
          'included_segments': ['Subscribed Users'],
          'headings': {'en': 'SP News Maregaon', 'mr': 'एसपी न्यूज मारेगाव'},
          'contents': {'en': title, 'mr': title},
        },
      );
    } catch (e) {
      debugPrint('Push failed: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showPreview() {
    // Generate HTML from Quill Editor
    final deltaJson = _quillController.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(deltaJson, ConverterOptions.options());
    final htmlContent = converter.convert();
    final title = _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'पूर्वावलोकन';
    
    final fullHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { font-family: -apple-system, sans-serif; padding: 16px; line-height: 1.6; color: #333; }
          h1 { font-size: 24px; font-weight: 700; margin-bottom: 24px; }
          img { max-width: 100%; height: auto; border-radius: 8px; margin-bottom: 16px; }
        </style>
      </head>
      <body>
        <h1>$title</h1>
        ${_featuredMediaUrl != null ? '<img src="$_featuredMediaUrl" />' : ''}
        $htmlContent
      </body>
      </html>
    ''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                AppBar(
                  title: const Text('पूर्वावलोकन'),
                  leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  backgroundColor: Colors.white,
                  elevation: 1,
                ),
                Expanded(
                  child: WebViewWidget(
                    controller: WebViewController()
                      ..loadHtmlString(fullHtml)
                      ..setBackgroundColor(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _excerptCtrl.dispose();
    _slugCtrl.dispose();
    _quillController.dispose();
    _editorFocus.dispose();
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
            icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
            onPressed: () => _showPreview(),
            tooltip: 'Preview (पूर्वावलोकन)',
          ),
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
          // Featured Image Selector
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline),
                image: _selectedImageFile != null
                    ? DecorationImage(image: FileImage(_selectedImageFile!), fit: BoxFit.cover)
                    : _featuredMediaUrl != null
                        ? DecorationImage(image: CachedNetworkImageProvider(_featuredMediaUrl!), fit: BoxFit.cover)
                        : null,
              ),
              child: _selectedImageFile == null && _featuredMediaUrl == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, size: 40, color: AppTheme.primary),
                        const SizedBox(height: 8),
                        Text('मुख्य फोटो निवडा (Featured Image)', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.edit, color: Colors.white, size: 18)),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  // Quill Editor Toolbar
                  quill.QuillToolbar.simple(
                    configurations: quill.QuillSimpleToolbarConfigurations(
                      controller: _quillController,
                      sharedConfigurations: const quill.QuillSharedConfigurations(
                        locale: Locale('mr'),
                      ),
                      showAlignmentButtons: true,
                      showCenterAlignment: true,
                      showCodeBlock: false,
                      showColorButton: true,
                      showDirection: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showInlineCode: false,
                      showListCheck: false,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Quill Editor Content
                  Container(
                    constraints: const BoxConstraints(minHeight: 300),
                    child: quill.QuillEditor.basic(
                      configurations: quill.QuillEditorConfigurations(
                        controller: _quillController,
                        sharedConfigurations: const quill.QuillSharedConfigurations(
                          locale: Locale('mr'),
                        ),
                      ),
                      focusNode: _editorFocus,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Settings Panel
                  if (_showSettings) _buildSettingsPanel(context),
                ],
              ),
            ),
          ),
          // Bottom action bar
          _buildBottomBar(context),
        ],
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
        _CategorySelector(selectedIds: _selectedCategories, onChanged: (ids) => setState(() => _selectedCategories = ids)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outline)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _saving ? null : () => _save('draft'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            child: const Text('मसुदा'),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _saving ? null : () => _save('publish'),
            icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, size: 15),
            label: const Text('प्रकाशित (Publish)'),
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
