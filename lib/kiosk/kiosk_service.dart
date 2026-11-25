import 'dart:async';

import 'package:flutter/services.dart';

/// Snapshot of the native kiosk state.
class KioskStatus {
  const KioskStatus({
    required this.platform,
    required this.active,
    required this.fullLock,
    required this.mode,
    required this.deviceOwner,
    this.message,
  });

  factory KioskStatus.fromMap(Map<Object?, Object?> map) => KioskStatus(
    platform: map['platform'] as String? ?? 'unknown',
    active: map['active'] as bool? ?? false,
    fullLock: map['fullLock'] as bool? ?? false,
    mode: map['mode'] as String? ?? 'none',
    deviceOwner: map['deviceOwner'] as bool? ?? false,
    message: map['message'] as String?,
  );

  static const unavailable = KioskStatus(
    platform: 'unknown',
    active: false,
    fullLock: false,
    mode: 'none',
    deviceOwner: false,
    message: 'Mode kiosk tidak didukung di platform ini.',
  );

  final String platform;

  /// The app is pinned/locked to the foreground.
  final bool active;

  /// The user cannot leave the app at all (Device Owner lock task,
  /// iOS assessment mode, Guided Access). Screen pinning is not a full lock.
  final bool fullLock;

  /// `lock_task`, `screen_pinning`, `assessment`, `single_app_mode`,
  /// `guided_access` or `none`.
  final String mode;

  /// Android only: the app is Device Owner.
  final bool deviceOwner;

  /// Optional hint from the native side, shown to the user.
  final String? message;

  bool get isAndroid => platform == 'android';
  bool get isIOS => platform == 'ios';

  String get modeLabel => switch (mode) {
    'lock_task' => 'Lock Task (Device Owner)',
    'screen_pinning' => 'Sematkan Aplikasi',
    'assessment' => 'Mode Asesmen',
    'single_app_mode' => 'Single App Mode',
    'guided_access' => 'Akses Terpandu',
    _ => 'Tidak aktif',
  };
}

/// Dart side of the `exam_browser/kiosk` channel, implemented in
/// `MainActivity.kt`/`KioskManager.kt` (Android) and `AppDelegate.swift` (iOS).
class KioskService {
  KioskService._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static final KioskService instance = KioskService._();

  static const MethodChannel _channel = MethodChannel('exam_browser/kiosk');

  final StreamController<String> _violations = StreamController.broadcast();

  /// Violations detected natively: `multi_window`, `screenshot`,
  /// `screen_recording`, `assessment_interrupted`.
  Stream<String> get violations => _violations.stream;

  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method == 'onViolation') {
      _violations.add(call.arguments as String);
    }
    return null;
  }

  Future<KioskStatus> status() => _invokeStatus('getStatus');

  Future<KioskStatus> start() => _invokeStatus('startKiosk');

  Future<KioskStatus> stop() => _invokeStatus('stopKiosk');

  /// Android only: removes Device Owner so the device returns to normal use.
  Future<bool> releaseDeviceOwner() async {
    try {
      return await _channel.invokeMethod<bool>('releaseDeviceOwner') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<KioskStatus> _invokeStatus(String method) async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(method);
      return map == null ? KioskStatus.unavailable : KioskStatus.fromMap(map);
    } on MissingPluginException {
      return KioskStatus.unavailable;
    }
  }
}
