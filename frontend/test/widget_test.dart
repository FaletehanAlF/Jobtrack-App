import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/main.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/register_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Onboarding menampilkan nama aplikasi, judul, dan tombol', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const JobTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('JobTrack'), findsOneWidget);
    expect(find.text('Mulai Sekarang'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Seluruh teks aplikasi memakai font Montserrat', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const JobTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final theme = Theme.of(tester.element(find.text('Mulai Sekarang')));

    expect(
      theme.textTheme.bodyMedium?.fontFamily ?? '',
      startsWith('Montserrat'),
    );
    expect(
      theme.textTheme.titleLarge?.fontFamily ?? '',
      startsWith('Montserrat'),
    );
    expect(
      theme.textTheme.labelLarge?.fontFamily ?? '',
      startsWith('Montserrat'),
    );
  });

  testWidgets('Tombol Mulai Sekarang membuka halaman register', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const JobTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Mulai Sekarang'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Tautan Masuk membuka halaman login', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const JobTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
