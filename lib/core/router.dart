import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/splash/splash_screen.dart';
import '../features/login/login_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/posts/posts_screen.dart';
import '../features/posts/post_editor_screen.dart';
import '../features/media/media_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/posts', builder: (_, __) => const PostsScreen()),
          GoRoute(
            path: '/posts/edit/:id',
            builder: (_, state) => PostEditorScreen(postId: int.tryParse(state.pathParameters['id'] ?? '0')),
          ),
          GoRoute(
            path: '/posts/new',
            builder: (_, __) => const PostEditorScreen(),
          ),
          GoRoute(path: '/media', builder: (_, __) => const MediaScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
