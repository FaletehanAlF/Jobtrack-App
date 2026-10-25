import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/job_model.dart';

void main() {
  group('JobModel.fromJson', () {
    test('mem-parsing data valid', () {
      final job = JobModel.fromJson({
        'id': 1,
        'recruiter_id': 2,
        'title': 'Software Engineer',
        'description': 'Deskripsi lowongan',
        'company': 'PT Contoh',
        'location': 'Jakarta',
        'created_at': '2026-10-20T14:45:29.000Z',
        'updated_at': '2026-10-21T14:45:29.000Z',
      });

      expect(job.id, 1);
      expect(job.recruiterId, 2);
      expect(job.title, 'Software Engineer');
      expect(job.description, 'Deskripsi lowongan');
      expect(job.company, 'PT Contoh');
      expect(job.location, 'Jakarta');
      expect(job.createdAt, isNotNull);
      expect(job.updatedAt, isNotNull);
    });

    test('id atau recruiter_id tidak valid melempar FormatException', () {
      expect(
        () => JobModel.fromJson({
          'id': null,
          'recruiter_id': 2,
          'title': 'Software Engineer',
          'description': 'Deskripsi',
          'company': 'PT Contoh',
          'location': 'Jakarta',
          'created_at': '2026-10-20T14:45:29.000Z',
          'updated_at': '2026-10-21T14:45:29.000Z',
        }),
        throwsFormatException,
      );

      expect(
        () => JobModel.fromJson({
          'id': 1,
          'recruiter_id': '2',
          'title': 'Software Engineer',
          'description': 'Deskripsi',
          'company': 'PT Contoh',
          'location': 'Jakarta',
          'created_at': '2026-10-20T14:45:29.000Z',
          'updated_at': '2026-10-21T14:45:29.000Z',
        }),
        throwsFormatException,
      );
    });

    test('tanggal tidak valid tidak diubah menjadi waktu sekarang', () {
      final job = JobModel.fromJson({
        'id': 1,
        'recruiter_id': 2,
        'title': 'Software Engineer',
        'description': 'Deskripsi',
        'company': 'PT Contoh',
        'location': 'Jakarta',
        'created_at': 'bukan-tanggal',
        'updated_at': '2026-10-21T14:45:29.000Z',
      });

      expect(job.createdAt, isNull);
      expect(job.updatedAt, isNotNull);
    });
  });
}
