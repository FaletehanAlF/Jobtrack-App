import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/job_model.dart';
import 'package:frontend/pages/jobs_page.dart';

void main() {
  testWidgets('Halaman detail lowongan memiliki bagian Ajukan Lamaran', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailPage(
          job: JobModel(
            id: 1,
            recruiterId: 42,
            title: 'Test Job',
            description: 'Test desc',
            company: 'Test Co',
            location: 'Test loc',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajukan Lamaran'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.text('Pilih CV'), findsOneWidget);
    expect(find.text('Kirim Lamaran'), findsOneWidget);
  });
}
