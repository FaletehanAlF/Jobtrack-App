import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/models/job_model.dart';
import 'package:frontend/pages/jobs_page.dart';

final _job = JobModel(
  id: 1,
  recruiterId: 42,
  title: 'Senior Flutter Developer untuk Tim Produk Digital',
  description:
      'Kami mencari developer berpengalaman untuk membangun aplikasi '
      'mobile dan web. Kamu akan bekerja bersama tim produk, desain, dan '
      'backend untuk merilis fitur secara berkala. Kualifikasi: menguasai '
      'Flutter dan Dart, memahami state management, serta terbiasa dengan '
      'pengujian otomatis.',
  company: 'PT Teknologi Nusantara Digital',
  location: 'Jakarta Selatan, DKI Jakarta',
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
);

Widget _page() {
  final baseTheme = ThemeData(useMaterial3: true);

  return MaterialApp(
    theme: baseTheme.copyWith(
      textTheme: GoogleFonts.montserratTextTheme(baseTheme.textTheme),
    ),
    home: JobDetailPage(job: _job),
  );
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  for (final size in const [Size(320, 900), Size(800, 900), Size(1280, 900)]) {
    testWidgets('Detail lowongan tidak menumpuk pada lebar ${size.width}', (
      WidgetTester tester,
    ) async {
      _setSurfaceSize(tester, size);

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_job.title), findsOneWidget);
      expect(find.text(_job.company), findsOneWidget);
      expect(find.text(_job.location), findsOneWidget);
      expect(find.byKey(const Key('job-detail-location')), findsOneWidget);
      expect(find.byKey(const Key('job-detail-created-at')), findsOneWidget);
      expect(find.text('Deskripsi'), findsOneWidget);
      expect(find.text(_job.description), findsOneWidget);
    });
  }

  testWidgets('Teks di halaman detail memakai font Montserrat dari theme', (
    WidgetTester tester,
  ) async {
    _setSurfaceSize(tester, const Size(800, 900));

    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    final titleStyle = tester.widget<Text>(find.text(_job.title)).style;
    final descriptionStyle = tester
        .widget<Text>(find.text(_job.description))
        .style;

    expect(titleStyle?.fontFamily ?? '', startsWith('Montserrat'));
    expect(descriptionStyle?.fontFamily ?? '', startsWith('Montserrat'));
  });
}
