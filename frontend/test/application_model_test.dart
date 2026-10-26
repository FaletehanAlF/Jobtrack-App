import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/application_model.dart';

void main() {
  group('ApplicationModel.fromJson', () {
    test('mem-parsing lamaran dan ringkasan lowongan dari backend', () {
      final application = ApplicationModel.fromJson({
        'id': 12,
        'job_id': 3,
        'status': 'submitted',
        'created_at': '2026-10-20T14:45:29.000Z',
        'job': {
          'id': 3,
          'title': 'Flutter Developer',
          'company': 'PT Contoh',
          'location': 'Jakarta',
        },
      });

      expect(application.id, 12);
      expect(application.jobId, 3);
      expect(application.isSubmitted, isTrue);
      expect(application.isRejected, isFalse);
      expect(application.statusLabel, 'Dikirim');
      expect(application.createdAt, isNotNull);
      expect(application.job.id, 3);
      expect(application.job.title, 'Flutter Developer');
      expect(application.job.company, 'PT Contoh');
      expect(application.job.location, 'Jakarta');
    });

    test('status rejected memakai label Ditolak', () {
      final application = ApplicationModel.fromJson({
        'id': 13,
        'job_id': 4,
        'status': 'rejected',
        'created_at': '2026-10-21T10:00:00.000Z',
        'job': {
          'id': 4,
          'title': 'Data Analyst',
          'company': 'PT Contoh',
          'location': 'Bandung',
        },
      });

      expect(application.isRejected, isTrue);
      expect(application.statusLabel, 'Ditolak');
    });

    test('objek job yang hilang ditolak agar data tidak disamarkan', () {
      expect(
        () => ApplicationModel.fromJson({
          'id': 14,
          'job_id': 5,
          'status': 'submitted',
          'created_at': '2026-10-21T10:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('tanggal tidak valid menjadi null, bukan waktu sekarang', () {
      final application = ApplicationModel.fromJson({
        'id': 15,
        'job_id': 6,
        'status': 'submitted',
        'created_at': 'bukan-tanggal',
        'job': {
          'id': 6,
          'title': 'QA Engineer',
          'company': 'PT Contoh',
          'location': 'Surabaya',
        },
      });

      expect(application.createdAt, isNull);
    });
  });

  group('ApplicationStats.fromApplications', () {
    test('menghitung total dan status yang didukung backend', () {
      final applications = [
        _application(id: 1, status: 'submitted'),
        _application(id: 2, status: 'rejected'),
        _application(id: 3, status: 'submitted'),
        _application(id: 4, status: 'submitted'),
      ];

      final stats = ApplicationStats.fromApplications(applications);

      expect(stats.total, 4);
      expect(stats.submitted, 3);
      expect(stats.rejected, 1);
    });

    test('daftar kosong menghasilkan semua angka nol', () {
      final stats = ApplicationStats.fromApplications(const []);

      expect(stats.total, 0);
      expect(stats.submitted, 0);
      expect(stats.rejected, 0);
    });
  });
}

ApplicationModel _application({required int id, required String status}) {
  return ApplicationModel(
    id: id,
    jobId: id,
    status: status,
    createdAt: DateTime(2026, 10, 20),
    job: ApplicationJob(
      id: id,
      title: 'Lowongan $id',
      company: 'PT Contoh',
      location: 'Jakarta',
    ),
  );
}
