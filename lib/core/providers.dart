import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wordpress_api.dart';
import '../models/wp_models.dart';

final apiProvider = Provider<WordPressApiService>((ref) => WordPressApiService.instance);

// Auth
final authProvider = FutureProvider<bool>((ref) async {
  return WordPressApiService.instance.isLoggedIn();
});

// Dashboard stats
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  return ref.watch(apiProvider).getDashboardStats();
});

// Posts list
final postsProvider = StateNotifierProvider.family<PostsNotifier, AsyncValue<List<WpPost>>, String>(
  (ref, status) => PostsNotifier(ref.watch(apiProvider), status),
);

class PostsNotifier extends StateNotifier<AsyncValue<List<WpPost>>> {
  final WordPressApiService _api;
  final String _status;
  int _page = 1;
  bool _hasMore = true;

  PostsNotifier(this._api, this._status) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }
    try {
      final posts = await _api.getPosts(status: _status, page: _page);
      if (refresh || _page == 1) {
        state = AsyncValue.data(posts);
      } else {
        state = AsyncValue.data([...state.value ?? [], ...posts]);
      }
      if (posts.length < 15) _hasMore = false;
      else _page++;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load(refresh: true);

  bool get hasMore => _hasMore;
}

// Categories
final categoriesProvider = FutureProvider<List<WpCategory>>((ref) async {
  return ref.watch(apiProvider).getCategories();
});

// Tags
final tagsProvider = FutureProvider<List<WpTag>>((ref) async {
  return ref.watch(apiProvider).getTags();
});

// Media
final mediaProvider = FutureProvider<List<WpMedia>>((ref) async {
  return ref.watch(apiProvider).getMedia();
});

// Recent posts (dashboard)
final recentPostsProvider = FutureProvider<List<WpPost>>((ref) async {
  return ref.watch(apiProvider).getPosts(status: 'any', page: 1, perPage: 5);
});
