import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../models/wp_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/status_badge.dart';
import '../../services/wordpress_api.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final recentAsync = ref.watch(recentPostsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentPostsProvider);
        },
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverList(delegate: SliverChildListDelegate([
                const SizedBox(height: 14),
                // Quick Actions
                _buildQuickActions(context),
                const SizedBox(height: 16),
                // Stats Grid
                Text('सारांश', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                statsAsync.when(
                  data: (stats) => _buildStatsGrid(context, stats),
                  loading: () => GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5, children: List.generate(3, (_) => const DashboardStatShimmer())),
                  error: (e, _) => Text('त्रुटी: $e', style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                ),
                const SizedBox(height: 20),
                // Recent Posts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('अलीकडील बातम्या', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    TextButton(onPressed: () => context.go('/posts'), child: const Text('सर्व पहा', style: TextStyle(fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 6),
                recentAsync.when(
                  data: (posts) => Column(children: posts.map((p) => _recentPostItem(context, p)).toList()),
                  loading: () => Column(children: List.generate(3, (_) => const PostCardShimmer())),
                  error: (e, _) => Text('त्रुटी: $e', style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                ),
                const SizedBox(height: 80),
              ])),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/posts/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.surfaceCard,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SP Posting', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          Text('मारेगाव न्यूज डॅशबोर्ड', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFEEF2FF),
            child: const Icon(Icons.person, size: 20, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _actionChip(context, Icons.add, 'नवी बातमी', () => context.go('/posts/new')),
          const SizedBox(width: 8),
          _actionChip(context, Icons.upload_outlined, 'मीडिया', () => context.go('/media')),
          const SizedBox(width: 8),
          _actionChip(context, Icons.drafts_outlined, 'मसुदे', () => context.go('/posts')),
        ],
      ),
    );
  }

  Widget _actionChip(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: AppTheme.onSurface),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ]),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, DashboardStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _statCard(context, Icons.article_outlined, 'एकूण बातम्या', stats.totalPosts.toString(), null),
        _statCard(context, Icons.check_circle_outline, 'प्रकाशित', stats.published.toString(), AppTheme.success),
        _statCard(context, Icons.drafts_outlined, 'मसुदे', stats.drafts.toString(), null),
      ],
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String label, String count, Color? color) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 22, color: c),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wideCard(BuildContext context, IconData icon, String label, String count, Color? highlightColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlightColor?.withOpacity(0.3) ?? AppTheme.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: highlightColor ?? AppTheme.onSurface)),
          ]),
          Icon(icon, size: 22, color: (highlightColor ?? AppTheme.onSurfaceVariant).withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _recentPostItem(BuildContext context, WpPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.renderedTitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(post.formattedDate, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge.fromStatus(post.status),
        ],
      ),
    );
  }
}
