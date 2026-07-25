import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wp_models.dart';

class WordPressApiService {
  static const String _siteUrl = 'https://spnewsmaregaon.com';
  static const String _baseApi = '$_siteUrl/wp-json/wp/v2';
  // Plain permalink: ?p=ID style, so REST API base doesn't change
  // but we add index.php prefix support
  static const String _restBase = '$_siteUrl/index.php?rest_route=/wp/v2';

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;
  Dio get dio => _dio;

  static final WordPressApiService instance = WordPressApiService._();

  WordPressApiService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final username = await _storage.read(key: 'wp_username');
        final password = await _storage.read(key: 'wp_app_password');
        if (username != null && password != null) {
          final credentials = base64Encode(utf8.encode('$username:$password'));
          options.headers['Authorization'] = 'Basic $credentials';
        }
        options.headers['Content-Type'] = 'application/json';
        handler.next(options);
      },
    ));
  }

  // Helper to build API URL — supports plain permalinks
  String _url(String path) => '$_siteUrl/index.php?rest_route=/wp/v2$path';

  /// Test authentication
  Future<bool> testAuth() async {
    try {
      final r = await _dio.get(_url('/users/me'));
      return r.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return false;
      }
      rethrow;
    }
  }

  /// Save credentials to secure storage
  Future<void> saveCredentials(String username, String password, {String? osAppId, String? osApiKey, String? displayName, String? avatarUrl}) async {
    await _storage.write(key: 'wp_username', value: username);
    await _storage.write(key: 'wp_app_password', value: password);
    if (osAppId != null) await _storage.write(key: 'os_app_id', value: osAppId);
    if (osApiKey != null) await _storage.write(key: 'os_api_key', value: osApiKey);
    if (displayName != null) await _storage.write(key: 'wp_display_name', value: displayName);
    if (avatarUrl != null) await _storage.write(key: 'wp_avatar_url', value: avatarUrl);
  }

  Future<Map<String, String?>> getUserProfile() async {
    return {
      'display_name': await _storage.read(key: 'wp_display_name'),
      'avatar_url': await _storage.read(key: 'wp_avatar_url'),
    };
  }

  /// Get OneSignal Credentials
  Future<Map<String, String?>> getOneSignalCredentials() async {
    return {
      'app_id': await _storage.read(key: 'os_app_id'),
      'api_key': await _storage.read(key: 'os_api_key'),
    };
  }

  /// Clear credentials (logout)
  Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }

  /// Check if logged in
  Future<bool> isLoggedIn() async {
    final u = await _storage.read(key: 'wp_username');
    final p = await _storage.read(key: 'wp_app_password');
    return u != null && p != null;
  }

  // ─── Posts ────────────────────────────────────────────────────────────────

  Future<List<WpPost>> getPosts({
    String status = 'any',
    int page = 1,
    int perPage = 15,
    String? search,
  }) async {
    final r = await _dio.get(_url('/posts'), queryParameters: {
      'status': status,
      'page': page,
      'per_page': perPage,
      if (search != null && search.isNotEmpty) 'search': search,
      '_embed': 'wp:featuredmedia,author',
    });
    return (r.data as List).map((j) => WpPost.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<int> getPostCount(String status) async {
    final r = await _dio.get(_url('/posts'), queryParameters: {
      'status': status,
      'per_page': 1,
      '_fields': 'id',
    });
    return int.tryParse(r.headers.value('x-wp-total') ?? '0') ?? 0;
  }

  Future<WpPost> createPost(Map<String, dynamic> data) async {
    final r = await _dio.post(_url('/posts'), data: data);
    return WpPost.fromJson(r.data as Map<String, dynamic>);
  }

  Future<WpPost> updatePost(int id, Map<String, dynamic> data) async {
    final r = await _dio.post(_url('/posts/$id'), data: data);
    return WpPost.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deletePost(int id, {bool force = false}) async {
    await _dio.delete(_url('/posts/$id'), queryParameters: {'force': force});
  }

  // ─── Categories ───────────────────────────────────────────────────────────

  Future<List<WpCategory>> getCategories() async {
    final r = await _dio.get(_url('/categories'), queryParameters: {'per_page': 100, 'orderby': 'count', 'order': 'desc'});
    return (r.data as List).map((j) => WpCategory.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ─── Tags ─────────────────────────────────────────────────────────────────

  Future<List<WpTag>> getTags({String? search}) async {
    final r = await _dio.get(_url('/tags'), queryParameters: {
      'per_page': 50,
      if (search != null) 'search': search,
    });
    return (r.data as List).map((j) => WpTag.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ─── Media ────────────────────────────────────────────────────────────────

  Future<List<WpMedia>> getMedia({int page = 1, int perPage = 20}) async {
    final r = await _dio.get(_url('/media'), queryParameters: {'page': page, 'per_page': perPage});
    return (r.data as List).map((j) => WpMedia.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<WpMedia> uploadMedia(File file, String filename) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: filename),
    });
    final r = await _dio.post(
      _url('/media'),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return WpMedia.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteMedia(int id) async {
    await _dio.delete(_url('/media/$id'), queryParameters: {'force': true});
  }

  // ─── Dashboard Stats ──────────────────────────────────────────────────────

  Future<DashboardStats> getDashboardStats() async {
    final results = await Future.wait([
      getPostCount('publish'),
      getPostCount('draft'),
      getPostCount('future'),
      _getCommentCount('hold'),
      _getMediaCount(),
      _getCategoryCount(),
      _getTagCount(),
    ]);

    final published = results[0] as int;
    final drafts = results[1] as int;
    final scheduled = results[2] as int;

    return DashboardStats(
      totalPosts: published + drafts + scheduled,
      published: published,
      drafts: drafts,
      scheduled: scheduled,
      pendingComments: results[3] as int,
      media: results[4] as int,
      categories: results[5] as int,
      tags: results[6] as int,
    );
  }

  Future<int> _getCommentCount(String status) async {
    try {
      final r = await _dio.get(_url('/comments'), queryParameters: {'status': status, 'per_page': 1, '_fields': 'id'});
      return int.tryParse(r.headers.value('x-wp-total') ?? '0') ?? 0;
    } catch (_) { return 0; }
  }

  Future<int> _getMediaCount() async {
    try {
      final r = await _dio.get(_url('/media'), queryParameters: {'per_page': 1, '_fields': 'id'});
      return int.tryParse(r.headers.value('x-wp-total') ?? '0') ?? 0;
    } catch (_) { return 0; }
  }

  Future<int> _getCategoryCount() async {
    try {
      final r = await _dio.get(_url('/categories'), queryParameters: {'per_page': 1, '_fields': 'id'});
      return int.tryParse(r.headers.value('x-wp-total') ?? '0') ?? 0;
    } catch (_) { return 0; }
  }

  Future<int> _getTagCount() async {
    try {
      final r = await _dio.get(_url('/tags'), queryParameters: {'per_page': 1, '_fields': 'id'});
      return int.tryParse(r.headers.value('x-wp-total') ?? '0') ?? 0;
    } catch (_) { return 0; }
  }

  // ─── User ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCurrentUser() async {
    final r = await _dio.get(_url('/users/me'));
    return r.data as Map<String, dynamic>;
  }
}
