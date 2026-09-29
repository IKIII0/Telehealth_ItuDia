import 'package:flutter_test/flutter_test.dart';
import 'package:telehealth_app/data/models/doctor.dart';
import 'package:telehealth_app/data/models/journal.dart';
import 'package:telehealth_app/data/models/medication.dart';

void main() {
  group('Doctor', () {
    test('inisial dibuat dari nama', () {
      const doctor = Doctor(
        id: 'doc1',
        name: 'Dr. Ahmad Fauzi, Sp.JP',
        specialization: 'Spesialis Jantung',
        experience: 12,
        rating: 4.9,
        price: 150000,
        available: true,
        hospital: 'RS',
        bio: 'bio',
        education: 'edu',
      );
      expect(doctor.initials, 'AF');
    });

    test('copyWith mengubah field tanpa mengubah id', () {
      const doctor = Doctor(
        id: 'doc1',
        name: 'Dr. A',
        specialization: 'Dokter Umum',
        experience: 1,
        rating: 4.0,
        price: 50000,
        available: true,
        hospital: 'RS',
        bio: 'bio',
        education: 'edu',
      );
      final updated = doctor.copyWith(name: 'Dr. B', available: false);
      expect(updated.id, 'doc1');
      expect(updated.name, 'Dr. B');
      expect(updated.available, isFalse);
    });
  });

  group('Medication', () {
    test('menghitung jadwal total dan yang sudah diminum', () {
      final medication = Medication(
        id: 'med1',
        name: 'Obat',
        dose: '500 mg',
        frequency: '2x sehari',
        startDate: '01 Jan 2025',
        endDate: '05 Jan 2025',
        note: '-',
        doctorId: 'doc1',
        schedules: [
          MedicationSchedule(time: 'Pagi', hour: '08:00', taken: true),
          MedicationSchedule(time: 'Malam', hour: '20:00'),
        ],
      );
      expect(medication.totalSchedules, 2);
      expect(medication.takenSchedules, 1);
    });

    test('copyWith mempertahankan id', () {
      final medication = Medication(
        id: 'med9',
        name: 'Obat',
        dose: '1',
        frequency: '1x sehari',
        startDate: '-',
        endDate: '-',
        note: '-',
        doctorId: 'doc1',
        schedules: [MedicationSchedule(time: 'Pagi', hour: '08:00')],
      );
      final updated = medication.copyWith(name: 'Obat Baru');
      expect(updated.id, 'med9');
      expect(updated.name, 'Obat Baru');
    });
  });

  group('JournalEntry', () {
    test('copyWith mempertahankan id dan categoryId', () {
      final entry = JournalEntry(
        id: 'je1',
        categoryId: 'cat1',
        value: 120,
        date: DateTime(2024, 9, 20),
        status: 'Normal',
        systolic: 120,
        diastolic: 80,
      );
      final updated = entry.copyWith(status: 'Perhatian', note: 'tes');
      expect(updated.id, 'je1');
      expect(updated.categoryId, 'cat1');
      expect(updated.status, 'Perhatian');
      expect(updated.note, 'tes');
    });
  });
}
