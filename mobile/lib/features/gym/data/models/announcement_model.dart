class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final bool isPinned;
  final DateTime publishedAt;
  final String? authorName;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.publishedAt,
    this.authorName,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      authorName: (json['author'] as Map<String, dynamic>?)?['fullName'] as String?,
    );
  }
}
