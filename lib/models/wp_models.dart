import 'dart:convert';

class WpPost {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String status;
  final String slug;
  final String dateGmt;
  final String modifiedGmt;
  final int? featuredMediaId;
  final String? featuredMediaUrl;
  final List<int> categories;
  final List<int> tags;
  final int author;
  final String? authorName;
  final String link;

  const WpPost({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.status,
    required this.slug,
    required this.dateGmt,
    required this.modifiedGmt,
    this.featuredMediaId,
    this.featuredMediaUrl,
    required this.categories,
    required this.tags,
    required this.author,
    this.authorName,
    required this.link,
  });

  String get renderedTitle => _stripHtml(title);
  String get renderedExcerpt => _stripHtml(excerpt);

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }

  int get wordCount {
    final plain = _stripHtml(content);
    return plain.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String get readingTime {
    final mins = (wordCount / 200).ceil();
    return '$mins मिनिट';
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(dateGmt).toLocal();
      const months = ['जाने', 'फेब्रु', 'मार्च', 'एप्रि', 'मे', 'जून', 'जुलै', 'ऑग', 'सप्टे', 'ऑक्टो', 'नोव्हे', 'डिसे'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateGmt;
    }
  }

  factory WpPost.fromJson(Map<String, dynamic> json) {
    return WpPost(
      id: json['id'] as int,
      title: (json['title']?['rendered'] ?? json['title'] ?? '') as String,
      content: (json['content']?['rendered'] ?? json['content'] ?? '') as String,
      excerpt: (json['excerpt']?['rendered'] ?? json['excerpt'] ?? '') as String,
      status: json['status'] as String? ?? 'draft',
      slug: json['slug'] as String? ?? '',
      dateGmt: json['date_gmt'] as String? ?? json['date'] as String? ?? '',
      modifiedGmt: json['modified_gmt'] as String? ?? '',
      featuredMediaId: json['featured_media'] as int?,
      featuredMediaUrl: json['_embedded']?['wp:featuredmedia']?[0]?['source_url'] as String?,
      categories: List<int>.from(json['categories'] ?? []),
      tags: List<int>.from(json['tags'] ?? []),
      author: json['author'] as int? ?? 1,
      authorName: json['_embedded']?['author']?[0]?['name'] as String?,
      link: json['link'] as String? ?? '',
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'content': content,
    'excerpt': excerpt,
    'status': status,
    'slug': slug,
    'categories': categories,
    'tags': tags,
  };
}

class WpCategory {
  final int id;
  final String name;
  final int count;
  final int parent;

  const WpCategory({required this.id, required this.name, required this.count, required this.parent});

  factory WpCategory.fromJson(Map<String, dynamic> json) => WpCategory(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        parent: json['parent'] as int? ?? 0,
      );
}

class WpTag {
  final int id;
  final String name;
  final int count;

  const WpTag({required this.id, required this.name, required this.count});

  factory WpTag.fromJson(Map<String, dynamic> json) => WpTag(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        count: json['count'] as int? ?? 0,
      );
}

class WpMedia {
  final int id;
  final String sourceUrl;
  final String title;
  final String mediaType;
  final String mimeType;
  final String? thumbnailUrl;
  final int? filesize;
  final String dateGmt;

  const WpMedia({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.mediaType,
    required this.mimeType,
    this.thumbnailUrl,
    this.filesize,
    required this.dateGmt,
  });

  bool get isImage => mediaType == 'image';

  factory WpMedia.fromJson(Map<String, dynamic> json) => WpMedia(
        id: json['id'] as int,
        sourceUrl: json['source_url'] as String? ?? '',
        title: (json['title']?['rendered'] ?? '') as String,
        mediaType: json['media_type'] as String? ?? 'image',
        mimeType: json['mime_type'] as String? ?? '',
        thumbnailUrl: json['media_details']?['sizes']?['thumbnail']?['source_url'] as String?,
        filesize: json['media_details']?['filesize'] as int?,
        dateGmt: json['date_gmt'] as String? ?? '',
      );
}

class DashboardStats {
  final int totalPosts;
  final int published;
  final int drafts;
  final int scheduled;
  final int pendingComments;
  final int media;
  final int categories;
  final int tags;

  const DashboardStats({
    required this.totalPosts,
    required this.published,
    required this.drafts,
    required this.scheduled,
    required this.pendingComments,
    required this.media,
    required this.categories,
    required this.tags,
  });
}
