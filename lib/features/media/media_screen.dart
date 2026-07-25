import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers.dart';
import '../../models/wp_models.dart';
import '../../services/wordpress_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_widgets.dart';

class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;
    setState(() { _uploading = true; _uploadProgress = 0; });
    try {
      final file = File(picked.path);
      final filename = picked.name;
      await WordPressApiService.instance.uploadMedia(file, filename);
      ref.invalidate(mediaProvider);
      if (mounted) _showSnack('फोटो यशस्वीरित्या अपलोड झाला!');
    } catch (e) {
      if (mounted) _showSnack('अपलोड अयशस्वी: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
            title: const Text('कॅमेरा', style: TextStyle(fontSize: 14)),
            onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
            title: const Text('गॅलरी', style: TextStyle(fontSize: 14)),
            onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('मीडिया लायब्ररी')),
      body: Column(
        children: [
          if (_uploading)
            LinearProgressIndicator(color: AppTheme.primary, backgroundColor: AppTheme.outline),
          Expanded(
            child: mediaAsync.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: 12,
                itemBuilder: (_, __) => const ShimmerBox(width: double.infinity, height: double.infinity, radius: 10),
              ),
              error: (e, _) => Center(child: Text('त्रुटी: $e', style: const TextStyle(fontSize: 12, color: AppTheme.error))),
              data: (media) {
                if (media.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.photo_library_outlined, size: 44, color: AppTheme.onSurfaceVariant.withOpacity(0.4)),
                    const SizedBox(height: 10),
                    Text('कोणताही मीडिया नाही', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant)),
                  ]));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(mediaProvider),
                  color: AppTheme.primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                    itemCount: media.length,
                    itemBuilder: (_, i) => _MediaTile(media: media[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadSheet,
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final WpMedia media;
  const _MediaTile({required this.media});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPreview(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: media.isImage
            ? CachedNetworkImage(
                imageUrl: media.thumbnailUrl ?? media.sourceUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.outline),
                errorWidget: (_, __, ___) => Container(color: AppTheme.surface, child: const Icon(Icons.broken_image_outlined, color: AppTheme.onSurfaceVariant)),
              )
            : Container(
                color: AppTheme.surface,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.insert_drive_file_outlined, color: AppTheme.onSurfaceVariant, size: 28),
                  const SizedBox(height: 4),
                  Text(media.mimeType.split('/').last, style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                ]),
              ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: media.isImage ? CachedNetworkImage(imageUrl: media.sourceUrl, fit: BoxFit.contain, width: double.infinity) : const Padding(padding: EdgeInsets.all(32), child: Icon(Icons.insert_drive_file_outlined, size: 64, color: AppTheme.primary)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(media.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('बंद करा')),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
