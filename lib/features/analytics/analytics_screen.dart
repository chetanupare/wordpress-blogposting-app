import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentPostsProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('आकडेवारी')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentPostsProvider);
          ref.invalidate(dashboardStatsProvider);
        },
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Summary cards
            statsAsync.when(
              data: (stats) => Row(children: [
                Expanded(child: _bigStat(context, 'एकूण बातम्या', stats.totalPosts.toString(), Icons.article_outlined, AppTheme.primary)),
                const SizedBox(width: 10),
                Expanded(child: _bigStat(context, 'प्रकाशित', stats.published.toString(), Icons.check_circle_outline, const Color(0xFF1B873F))),
              ]),
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => Row(children: [
                Expanded(child: _bigStat(context, 'मसुदे', stats.drafts.toString(), Icons.drafts_outlined, AppTheme.onSurfaceVariant)),
                const SizedBox(width: 10),
                Expanded(child: _bigStat(context, 'टिप्पण्या', stats.pendingComments.toString(), Icons.chat_bubble_outline, AppTheme.warning)),
              ]),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),
            // Top Posts by read time (using word count as proxy)
            Text('अलीकडील बातम्या (शब्द संख्यानुसार)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            recentAsync.when(
              data: (posts) {
                final sorted = [...posts]..sort((a, b) => b.wordCount.compareTo(a.wordCount));
                return Column(
                  children: sorted.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final maxWords = sorted.first.wordCount;
                    final ratio = maxWords > 0 ? p.wordCount / maxWords : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: i == 0 ? AppTheme.primary : AppTheme.surface, borderRadius: BorderRadius.circular(6)),
                          child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == 0 ? Colors.white : AppTheme.onSurface))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.renderedTitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: AppTheme.outline,
                              valueColor: AlwaysStoppedAnimation<Color>(i == 0 ? AppTheme.primary : AppTheme.onSurfaceVariant),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        )),
                        const SizedBox(width: 10),
                        Text('${p.wordCount} शब्द', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Text('त्रुटी: $e', style: const TextStyle(fontSize: 12, color: AppTheme.error)),
            ),
            const SizedBox(height: 20),
            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Google Analytics ची तपशीलवार आकडेवारी पाहण्यासाठी analytics.google.com उघडा.',
                  style: TextStyle(fontSize: 11, color: AppTheme.primary.withOpacity(0.8)),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigStat(BuildContext context, String label, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}
