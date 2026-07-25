import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dio/dio.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';

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
  bool _uploadingVideo = false;
  String _videoUploadStatus = '';

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
            _quillController = quill.QuillController(
              document: quill.Document.fromDelta(delta),
              selection: const TextSelection.collapsed(offset: 0),
            );
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
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'फोटो क्रॉप करा',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
          IOSUiSettings(
            title: 'फोटो क्रॉप करा',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
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

  Future<void> _pickAndUploadCloudinaryVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _uploadingVideo = true;
      _videoUploadStatus = 'व्हिडिओ तयार करत आहे...';
    });

    try {
      final file = File(picked.path);
      const cloudName = 'pa8qw536';
      const apiKey = '417576114439126';
      const apiSecret = '5TGhuJNEpjpbKsHWWtfvK2K9eyY';
      
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final strToSign = 'timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(strToSign)).toString();

      setState(() => _videoUploadStatus = 'अपलोड करत आहे (Cloudinary)...');

      final formData = FormData.fromMap({
        'api_key': apiKey,
        'timestamp': timestamp,
        'signature': signature,
        'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      });

      final res = await WordPressApiService.instance.dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
        data: formData,
        onSendProgress: (count, total) {
          if (total > 0 && mounted) {
            final pct = (count / total * 100).toStringAsFixed(0);
            setState(() => _videoUploadStatus = 'अपलोड करत आहे: $pct%');
          }
        },
      );

      if (res.statusCode == 200) {
        final secureUrl = res.data['secure_url'];
        
        // Insert shortcode or HTML tag directly into editor
        final index = _quillController.selection.baseOffset;
        final position = index > -1 ? index : _quillController.document.length;
        
        // Insert video tag
        _quillController.document.insert(position, '\n\n[video src="$secureUrl"]\n\n');
        _showSnack('व्हिडिओ यशस्वीरित्या जोडला!');
      }
    } catch (e) {
      debugPrint('Cloudinary Video Upload Error: $e');
      _showSnack('व्हिडिओ अपलोड अयशस्वी झाला!');
    } finally {
      if (mounted) setState(() { _uploadingVideo = false; _videoUploadStatus = ''; });
    }
  }

  Future<void> _generateAiImage() async {
    final groqKey = await WordPressApiService.instance.getGroqApiKey();
    if (groqKey == null || groqKey.isEmpty) {
      _showSnack('Groq API Key आढळली नाही. कृपया सेटिंग्ज तपासा.');
      return;
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnack('AI फोटो तयार करण्यासाठी आधी शीर्षक लिहा.');
      return;
    }

    setState(() {
      _uploadingVideo = true;
      _videoUploadStatus = 'AI Prompt तयार करत आहे...';
    });

    try {
      final res = await WordPressApiService.instance.dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant that writes short, descriptive English prompts for an image generation AI (like Midjourney/Pollinations). The prompt should generate a realistic news image suitable for a Marathi news portal. Just output the prompt text, no intro, no quotes.'},
            {'role': 'user', 'content': 'Create an image generation prompt for this Marathi news article title: $title'}
          ],
          'max_tokens': 50,
        },
      );

      final prompt = res.data['choices'][0]['message']['content'].toString().trim();
      
      if (mounted) setState(() => _videoUploadStatus = 'फोटो डाउनलोड करत आहे...');
      
      final encoded = Uri.encodeComponent(prompt);
      final url = 'https://image.pollinations.ai/prompt/$encoded';
      
      final file = File('${Directory.systemTemp.path}/ai_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await WordPressApiService.instance.dio.download(url, file.path);

      if (mounted) {
        setState(() {
          _selectedImageFile = file;
          _featuredMediaUrl = null;
        });
        _showSnack('AI फोटो तयार झाला!');
      }
    } catch (e) {
      debugPrint('AI Image Error: $e');
      _showSnack('AI फोटो तयार करण्यात अडचण आली.');
    } finally {
      if (mounted) setState(() { _uploadingVideo = false; _videoUploadStatus = ''; });
    }
  }

  Future<void> _aiSuggest() async {
    final groqKey = await WordPressApiService.instance.getGroqApiKey();
    if (groqKey == null || groqKey.isEmpty) {
      _showSnack('Groq API Key आढळली नाही.');
      return;
    }

    final plainText = _quillController.document.toPlainText();
    final index = _quillController.selection.baseOffset;
    final position = index > -1 ? index : plainText.length;
    final textContext = plainText.substring(0, position);

    if (textContext.trim().isEmpty) {
      _showSnack('मदत करण्यासाठी आधी थोडी माहिती लिहा.');
      return;
    }

    setState(() {
      _uploadingVideo = true;
      _videoUploadStatus = 'AI विचार करत आहे...';
    });

    try {
      final res = await WordPressApiService.instance.dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': 'You are an AI writing assistant for a Marathi news portal. Complete the sentence or write the next logical sentence in pure Marathi language based on the context. Keep it very short, around 1 sentence. Do not wrap in quotes or add conversational filler.'},
            {'role': 'user', 'content': 'Continue this text:\n$textContext'}
          ],
          'max_tokens': 100,
        },
      );

      final suggestion = res.data['choices'][0]['message']['content'].toString().trim();
      
      _quillController.document.insert(position, ' ' + suggestion);
      _quillController.updateSelection(TextSelection.collapsed(offset: position + suggestion.length + 1), quill.ChangeSource.local);
      
    } catch (e) {
      debugPrint('AI Suggest Error: $e');
      _showSnack('AI सुचवण्यात अडचण आली.');
    } finally {
      if (mounted) setState(() { _uploadingVideo = false; _videoUploadStatus = ''; });
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
      final deltaJson = List<Map<String, dynamic>>.from(_quillController.document.toDelta().toJson());
      final converter = QuillDeltaToHtmlConverter(
        deltaJson,
        ConverterOptions(),
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
    final deltaJson = List<Map<String, dynamic>>.from(_quillController.document.toDelta().toJson());
    final converter = QuillDeltaToHtmlConverter(deltaJson, ConverterOptions());
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
            icon: const Icon(Icons.auto_awesome, size: 24, color: Colors.amber),
            onPressed: _uploadingVideo ? null : _aiSuggest,
            tooltip: 'AI सुचवा (Groq Suggest)',
          ),
          IconButton(
            icon: const Icon(Icons.video_call_outlined, size: 24, color: AppTheme.primary),
            onPressed: _uploadingVideo ? null : _pickAndUploadCloudinaryVideo,
            tooltip: 'Cloudinary व्हिडिओ',
          ),
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
      body: Stack(
        children: [
          Column(
            children: [
              // Featured Image Selector
              Hero(
                tag: 'featured-image-${widget.postId ?? "new"}',
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
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InkWell(
                              onTap: _pickImage,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined, size: 40, color: AppTheme.primary),
                                  const SizedBox(height: 8),
                                  Text('गॅलरी (Gallery)', style: Theme.of(context).textTheme.labelMedium),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 60, color: AppTheme.outline),
                            InkWell(
                              onTap: _generateAiImage,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 40, color: Colors.amber),
                                  const SizedBox(height: 8),
                                  Text('AI फोटो (Groq)', style: Theme.of(context).textTheme.labelMedium),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: _generateAiImage,
                                  child: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _pickImage,
                                  child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.edit, color: Colors.white, size: 18)),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
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
                      ).animate().fade(delay: 100.ms, duration: 400.ms).slideX(begin: 0.05, end: 0),
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
                      ).animate().fade(delay: 200.ms, duration: 400.ms),
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
                      ).animate().fade(delay: 300.ms, duration: 500.ms),
                      const SizedBox(height: 60),
                      // Settings Panel
                      if (_showSettings) _buildSettingsPanel(context),
                    ],
                  ),
                ),
              ),
              // Bottom action bar
              _buildBottomBar(context).animate().fade(duration: 400.ms).slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
          if (_uploadingVideo)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(_videoUploadStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
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
