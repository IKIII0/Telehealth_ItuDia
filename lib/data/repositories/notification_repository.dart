import '../models/app_notification.dart';
import 'simulated_api.dart';

/// Repository notifikasi (data lokal per sesi aplikasi).
///
/// Status "sudah dibaca" disimpan di memori sehingga bertahan selama
/// aplikasi berjalan.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final List<AppNotification> _notifications = [
    const AppNotification(
      id: 'n1',
      title: 'Waktunya minum Paracetamol',
      message: 'Jadwal Siang pukul 14:00 belum ditandai diminum.',
      time: '10 menit lalu',
      category: NotificationCategory.medication,
    ),
    const AppNotification(
      id: 'n2',
      title: 'Dokter membalas pesan Anda',
      message: 'dr. Rifki Al Sauqy, Sp.JP mengirim pesan baru di konsultasi.',
      time: '35 menit lalu',
      category: NotificationCategory.chat,
    ),
    const AppNotification(
      id: 'n3',
      title: 'Konsultasi sedang berlangsung',
      message: 'Sesi chat dengan dr. Rifki Al Sauqy, Sp.JP masih aktif.',
      time: '1 jam lalu',
      category: NotificationCategory.consultation,
      isRead: true,
    ),
    const AppNotification(
      id: 'n4',
      title: 'Stok obat hampir habis',
      message:
          'Amoxicillin tersisa untuk 1 hari lagi. Siapkan obat berikutnya.',
      time: 'Kemarin',
      category: NotificationCategory.medication,
      isRead: true,
    ),
    const AppNotification(
      id: 'n5',
      title: 'Pengingat kontrol',
      message: 'Jadwal kontrol Anda di RS Jantung Harapan Kita minggu depan.',
      time: 'Kemarin',
      category: NotificationCategory.consultation,
      isRead: true,
    ),
    const AppNotification(
      id: 'n6',
      title: 'Pembaruan aplikasi',
      message: 'Versi terbaru tersedia dengan perbaikan performa.',
      time: '3 hari lalu',
      category: NotificationCategory.system,
      isRead: true,
    ),
  ];

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<List<AppNotification>> fetchAll({bool simulateError = false}) {
    return SimulatedApi.run(
      () => List<AppNotification>.of(_notifications),
      simulateError: simulateError,
    );
  }

  Future<void> markRead(String id) {
    return SimulatedApi.run(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index == -1) return;
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    });
  }

  Future<void> markAllRead() {
    return SimulatedApi.run(() {
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
  }
}
