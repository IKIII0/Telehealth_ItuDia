/// Jenis notifikasi untuk menentukan ikon dan warna.
enum NotificationCategory { medication, consultation, chat, system }

/// Satu notifikasi yang tampil di halaman Notifikasi.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final String time;
  final NotificationCategory category;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      time: time,
      category: category,
      isRead: isRead ?? this.isRead,
    );
  }
}
