import 'package:flutter_test/flutter_test.dart';
import 'package:telehealth_app/data/models/journal.dart';
import 'package:telehealth_app/data/models/medication.dart';
import 'package:telehealth_app/data/repositories/conversation_repository.dart';
import 'package:telehealth_app/data/repositories/doctor_repository.dart';
import 'package:telehealth_app/data/repositories/journal_repository.dart';
import 'package:telehealth_app/data/repositories/medication_repository.dart';
import 'package:telehealth_app/data/repositories/simulated_api.dart';

void main() {
  group('DoctorRepository', () {
    test('memuat daftar dokter', () async {
      final doctors = await DoctorRepository.instance.fetchAll();
      expect(doctors, isNotEmpty);
    });

    test('menyediakan data referensi spesialisasi (minimal 5)', () {
      expect(
        DoctorRepository.instance.specializations.length,
        greaterThanOrEqualTo(5),
      );
    });

    test('findById mengembalikan dokter yang sesuai relasi', () async {
      final doctors = await DoctorRepository.instance.fetchAll();
      final first = doctors.first;
      final found = await DoctorRepository.instance.findById(first.id);
      expect(found?.id, first.id);
    });

    test('findById mengembalikan null untuk id tidak dikenal', () async {
      final found = await DoctorRepository.instance.findById('tidak-ada');
      expect(found, isNull);
    });
  });

  group('MedicationRepository (CRUD)', () {
    test('memuat data obat', () async {
      final medications = await MedicationRepository.instance.fetchAll();
      expect(medications, isNotEmpty);
    });

    test('create menambah data', () async {
      final before = (await MedicationRepository.instance.fetchAll()).length;
      await MedicationRepository.instance.create(
        name: 'Obat Uji',
        dose: '100 mg',
        frequency: '1x sehari',
        note: '-',
        doctorId: 'doc1',
        schedules: [MedicationSchedule(time: 'Pagi', hour: '08:00')],
      );
      final after = (await MedicationRepository.instance.fetchAll()).length;
      expect(after, before + 1);
    });

    test('update mengubah data tanpa membuat data baru', () async {
      final created = await MedicationRepository.instance.create(
        name: 'Obat Update',
        dose: '200 mg',
        frequency: '2x sehari',
        note: '-',
        doctorId: 'doc1',
        schedules: [MedicationSchedule(time: 'Pagi', hour: '08:00')],
      );
      final countBefore =
          (await MedicationRepository.instance.fetchAll()).length;
      await MedicationRepository.instance.update(
        created.copyWith(name: 'Obat Update Baru'),
      );
      final medications = await MedicationRepository.instance.fetchAll();
      expect(medications.length, countBefore);
      final updated = medications.firstWhere((m) => m.id == created.id);
      expect(updated.name, 'Obat Update Baru');
    });

    test('delete menghapus data', () async {
      final created = await MedicationRepository.instance.create(
        name: 'Obat Hapus',
        dose: '50 mg',
        frequency: '1x sehari',
        note: '-',
        doctorId: 'doc1',
        schedules: [MedicationSchedule(time: 'Pagi', hour: '08:00')],
      );
      final before = (await MedicationRepository.instance.fetchAll()).length;
      await MedicationRepository.instance.delete(created.id);
      final after = (await MedicationRepository.instance.fetchAll()).length;
      expect(after, before - 1);
    });

    test('toggleTaken mengubah status jadwal', () async {
      final medications = await MedicationRepository.instance.fetchAll();
      final medication = medications.first;
      final before = medication.schedules.first.taken;
      await MedicationRepository.instance.toggleTaken(medication.id, 0);
      final refreshed = (await MedicationRepository.instance.fetchAll())
          .firstWhere((m) => m.id == medication.id);
      expect(refreshed.schedules.first.taken, !before);
    });
  });

  group('JournalRepository (CRUD)', () {
    test('menyediakan kategori referensi (minimal 5)', () async {
      final categories = await JournalRepository.instance.fetchCategories();
      expect(categories.length, greaterThanOrEqualTo(5));
    });

    test('memuat minimal 20 record utama', () async {
      final entries = await JournalRepository.instance.fetchEntries();
      expect(entries.length, greaterThanOrEqualTo(20));
    });

    test('setiap entri memiliki relasi categoryId yang valid', () async {
      final entries = await JournalRepository.instance.fetchEntries();
      final ids = JournalRepository.instance.categories
          .map((c) => c.id)
          .toSet();
      for (final entry in entries) {
        expect(ids.contains(entry.categoryId), isTrue);
      }
    });

    test('create, update, dan delete berjalan', () async {
      final created = await JournalRepository.instance.create(
        JournalEntry(
          id: '',
          categoryId: 'cat2',
          value: 110,
          date: DateTime(2024, 9, 26),
          status: 'Normal',
          note: 'uji',
        ),
      );
      expect(created.id, isNotEmpty);

      await JournalRepository.instance.update(
        created.copyWith(value: 130, status: 'Perhatian'),
      );
      final refreshed = (await JournalRepository.instance.fetchEntries())
          .firstWhere((e) => e.id == created.id);
      expect(refreshed.value, 130);

      await JournalRepository.instance.delete(created.id);
      final after = await JournalRepository.instance.fetchEntries();
      expect(after.any((e) => e.id == created.id), isFalse);
    });

    test('fetchByCategory menyaring berdasarkan relasi', () async {
      final entries = await JournalRepository.instance.fetchByCategory('cat1');
      expect(entries.every((e) => e.categoryId == 'cat1'), isTrue);
    });
  });

  group('ConversationRepository', () {
    test('memuat daftar percakapan', () async {
      final conversations = await ConversationRepository.instance.fetchAll();
      expect(conversations, isNotEmpty);
    });

    test('delete menghapus percakapan', () async {
      final conversations = await ConversationRepository.instance.fetchAll();
      final before = conversations.length;
      await ConversationRepository.instance.delete(conversations.first.id);
      final after = await ConversationRepository.instance.fetchAll();
      expect(after.length, before - 1);
    });
  });

  group('SimulatedApi', () {
    test('melempar SimulatedFailure saat simulateError aktif', () async {
      await expectLater(
        SimulatedApi.run(() => 1, simulateError: true),
        throwsA(isA<SimulatedFailure>()),
      );
    });

    test('mengembalikan data saat normal', () async {
      final result = await SimulatedApi.run(() => 42);
      expect(result, 42);
    });
  });
}
