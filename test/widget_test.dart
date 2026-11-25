import 'package:exam_browser/kiosk/kiosk_service.dart';
import 'package:exam_browser/main.dart';
import 'package:exam_browser/models/exam_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExamConfig', () {
    final config = ExamConfig(
      examUrl: Uri.parse('https://cbt.sekolah.sch.id/login'),
      proctorPassword: 'rahasia',
      extraAllowedHosts: ExamConfig.parseHosts(
        'sso.contoh.com, cdn.contoh.com',
      ),
    );

    test('allows the exam host, its subdomains and extra hosts', () {
      expect(
        config.isAllowed(Uri.parse('https://cbt.sekolah.sch.id/soal/1')),
        isTrue,
      );
      expect(
        config.isAllowed(Uri.parse('https://a.cbt.sekolah.sch.id/')),
        isTrue,
      );
      expect(
        config.isAllowed(Uri.parse('https://sso.contoh.com/auth')),
        isTrue,
      );
      expect(config.isAllowed(Uri.parse('about:blank')), isTrue);
    });

    test('blocks other sites and schemes', () {
      expect(config.isAllowed(Uri.parse('https://www.google.com')), isFalse);
      expect(
        config.isAllowed(Uri.parse('https://evilcbt.sekolah.sch.id.x.com')),
        isFalse,
      );
      expect(config.isAllowed(Uri.parse('intent://scan#Intent;end')), isFalse);
      expect(config.isAllowed(Uri.parse('mailto:a@b.c')), isFalse);
    });

    test('parses URLs', () {
      expect(ExamConfig.parseUrl('cbt.sekolah.sch.id')?.scheme, 'https');
      expect(
        ExamConfig.parseUrl('http://192.168.1.10/cbt')?.host,
        '192.168.1.10',
      );
      expect(ExamConfig.parseUrl('ftp://x.com'), isNull);
      expect(ExamConfig.parseUrl(''), isNull);
    });
  });

  testWidgets('setup screen shows status from the native channel', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('exam_browser/kiosk'), (
          call,
        ) async {
          return {
            'platform': 'android',
            'active': false,
            'fullLock': false,
            'mode': 'none',
            'deviceOwner': false,
          };
        });
    KioskService.instance; // registers the handler

    await tester.pumpWidget(const ExamBrowserApp());
    await tester.pumpAndSettle();

    expect(find.text('Mulai Ujian'), findsOneWidget);
    expect(find.text('Platform: android'), findsOneWidget);
    expect(
      find.text('Device Owner: tidak (Sematkan Aplikasi)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mulai Ujian'));
    await tester.pump();
    expect(find.text('Masukkan URL yang valid'), findsOneWidget);
  });
}
