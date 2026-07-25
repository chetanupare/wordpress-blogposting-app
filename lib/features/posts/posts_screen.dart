import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../core/providers.dart';
import '../../models/wp_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/status_badge.dart';
import '../../services/wordpress_api.dart';

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  String _selectedStatus = 'any';
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  final _filters = [
    ('any', 'सर्व'),
    ('publish', 'प्रकाशित'),
    ('draft', 'मसुदा'),
    ('future', 'नियोजित'),
    ('trash', 'हटविले'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider(_selectedStatus));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration.collapsed(hintText: 'शोधा...'),
                onChanged: (_) => setState(() {}),
              )
            : const Text('बातम्या'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, size: 20),
            onPressed: () => setState(() { _searching = !_searching; if (!_searching) _searchCtrl.clear(); }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppTheme.surfaceCard,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final selected = _selectedStatus == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedStatus = f.$1);
                        ref.read(postsProvider(f.$1).notifier).refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppTheme.primary : AppTheme.outline),
                        ),
                        child: Text(
                          f.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          // Posts list
          Expanded(
            child: postsAsync.when(
              loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const PostCardShimmer(),
              ),
              error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
                const SizedBox(height: 8),
                Text('त्रुटी: $e', style: const TextStyle(fontSize: 12, color: AppTheme.error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => ref.read(postsProvider(_selectedStatus).notifier).refresh(), child: const Text('पुन्हा प्रयत्न')),
              ])),
              data: (posts) {
                final filtered = _searchCtrl.text.isEmpty
                    ? posts
                    : posts.where((p) => p.renderedTitle.toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();
                if (filtered.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.article_outlined, size: 44, color: AppTheme.onSurfaceVariant.withOpacity(0.4)),
                    const SizedBox(height: 10),
                    Text('कोणत्याही बातम्या आढळल्या नाहीत', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant)),
                  ]));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(postsProvider(_selectedStatus).notifier).refresh(),
                  color: AppTheme.primary,
                  child: AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        return AnimationConfiguration.staggeredList(
                          position: i,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: _PostCard(post: filtered[i]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        spacing: 12,
        spaceBetweenChildren: 8,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.edit),
            label: 'नवी बातमी (New Post)',
            onTap: () => context.go('/posts/new'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload),
            label: 'मीडिया (Media)',
            onTap: () => context.go('/media'),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final WpPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(post.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('बातमी हटवायची?'),
            content: const Text('तुम्हाला नक्की ही बातमी कचरापेटीत (Trash) टाकायची आहे का?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('नाही')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                child: const Text('हटवा (Delete)'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        // Optimistic UI or call delete via API
        try {
          // Delete via Riverpod provider or direct API call
          await WordPressApiService.instance.dio.delete(
            'https://spnewsmaregaon.com/index.php?rest_route=/wp/v2/posts/${post.id}',
          );
        } catch (e) {
          // Error handling
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => context.go('/posts/edit/${post.id}'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Row(
            children: [
              // Thumbnail
              Hero(
                tag: 'featured-image-${post.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: post.featuredMediaUrl != null
                      ? CachedNetworkImage(
                          imageUrl: post.featuredMediaUrl!,
                          width: 72, height: 72, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(width: 72, height: 72, color: AppTheme.surface),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge.fromStatus(post.status),
                        GestureDetector(
                          onTap: () => context.go('/posts/edit/${post.id}'),
                          child: const Text('Edit', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.renderedTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(post.formattedDate, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined, size: 11, color: AppTheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(post.readingTime, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.image_outlined, color: AppTheme.onSurfaceVariant, size: 28),
  );
}
