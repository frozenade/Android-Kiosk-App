import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../kiosk/kiosk_service.dart';
import '../models/exam_config.dart';
import '../widgets/kiosk_gate.dart';
import '../widgets/lock_overlay.dart';
import '../widgets/password_dialog.dart';

/// Suffix added to the web view's user agent so the exam server can refuse
/// ordinary browsers.
const examUserAgentSuffix = 'ExamBrowser/1.0';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.config});

  final ExamConfig config;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  final _kiosk = KioskService.instance;
  late final WebViewController _web;
  StreamSubscription<String>? _violationSub;
  Timer? _watchdog;

  KioskStatus? _status;
  bool _starting = false;
  bool _examStarted = false;
  bool _exiting = false;
  bool _leftApp = false;
  double _progress = 0;
  String? _lockReason;
  int _violationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web = _buildWebView();
    _violationSub = _kiosk.violations.listen(_onViolation);
    _startKiosk();
    _watchdog = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkKiosk(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _violationSub?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ---- Kiosk -------------------------------------------------------------

  Future<void> _startKiosk() async {
    if (_starting || _exiting) return;
    setState(() => _starting = true);
    try {
      _applyStatus(await _kiosk.start());
    } on PlatformException catch (e) {
      _showSnack('Gagal mengaktifkan mode kiosk: ${e.message}');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _checkKiosk() async {
    if (_exiting || _starting) return;
    final wasActive = _status?.active ?? false;
    final status = await _kiosk.status();
    if (!mounted || _exiting) return;
    _applyStatus(status);
    if (_examStarted && wasActive && !status.active) {
      // Unpinned / Guided Access ended / assessment interrupted.
      _onViolation('kiosk_exited');
      _startKiosk();
    }
  }

  void _applyStatus(KioskStatus status) {
    if (!mounted) return;
    setState(() {
      // Keep the native hint when a later poll carries none.
      _status =
          status.message == null && _status?.message != null && !status.active
          ? KioskStatus(
              platform: status.platform,
              active: status.active,
              fullLock: status.fullLock,
              mode: status.mode,
              deviceOwner: status.deviceOwner,
              message: _status!.message,
            )
          : status;
    });
    if (status.active && !_examStarted) {
      _examStarted = true;
      _web.loadRequest(widget.config.examUrl);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_examStarted || _exiting) return;
    // With a full lock the student cannot leave; a pause then just means the
    // screen was switched off, so it is not counted.
    if (_status?.fullLock ?? false) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftApp = true;
    } else if (state == AppLifecycleState.resumed && _leftApp) {
      _leftApp = false;
      _onViolation('app_left');
    }
  }

  void _onViolation(String type) {
    if (!_examStarted || _exiting || !mounted) return;
    setState(() {
      _violationCount++;
      _lockReason = _describeViolation(type);
    });
    _notifyWebPage(type);
  }

  static String _describeViolation(String type) => switch (type) {
    'app_left' => 'Anda meninggalkan aplikasi ujian.',
    'kiosk_exited' => 'Mode kiosk dimatikan selama ujian.',
    'multi_window' => 'Layar terbagi / jendela mengambang terdeteksi.',
    'screenshot' => 'Tangkapan layar terdeteksi.',
    'screen_recording' => 'Perekaman atau pencerminan layar terdeteksi.',
    'assessment_interrupted' => 'Mode asesmen terhenti.',
    _ => 'Pelanggaran terdeteksi ($type).',
  };

  /// Lets the exam page log violations:
  /// `window.addEventListener('examBrowserViolation', e => ...)`.
  void _notifyWebPage(String type) {
    final detail = jsonEncode({'type': type, 'count': _violationCount});
    _web
        .runJavaScript(
          "window.dispatchEvent(new CustomEvent('examBrowserViolation',"
          '{detail: $detail}));',
        )
        .catchError((_) {});
  }

  // ---- Web view ----------------------------------------------------------

  WebViewController _buildWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // The exam page can call `ExamBrowser.postMessage('finish')` when done.
      ..addJavaScriptChannel(
        'ExamBrowser',
        onMessageReceived: (m) {
          if (m.message == 'finish') _exitExam();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onNavigationRequest: (request) {
            if (!request.isMainFrame) return NavigationDecision.navigate;
            final uri = Uri.tryParse(request.url);
            if (uri != null && widget.config.isAllowed(uri)) {
              return NavigationDecision.navigate;
            }
            _showSnack('Alamat diblokir: ${uri?.host ?? request.url}');
            return NavigationDecision.prevent;
          },
        ),
      );
    _tagUserAgent(controller);
    return controller;
  }

  Future<void> _tagUserAgent(WebViewController controller) async {
    try {
      final ua = await controller.getUserAgent() ?? '';
      await controller.setUserAgent('$ua $examUserAgentSuffix'.trim());
    } catch (_) {
      // Keep the default user agent.
    }
  }

  // ---- Exit --------------------------------------------------------------

  Future<void> _confirmExit() async {
    final ok = await askProctorPassword(
      context,
      expected: widget.config.proctorPassword,
      title: 'Keluar dari ujian?',
    );
    if (ok) await _exitExam();
  }

  Future<void> _exitExam() async {
    if (_exiting) return;
    _exiting = true;
    _watchdog?.cancel();
    await _kiosk.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Material(
                    color: theme.colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            status?.active ?? false
                                ? Icons.lock
                                : Icons.lock_open,
                            size: 18,
                            color: status?.active ?? false
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${widget.config.examUrl.host} · '
                              '${status?.modeLabel ?? '…'}',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (_violationCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Chip(
                                label: Text('$_violationCount pelanggaran'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Muat ulang',
                            onPressed: _examStarted
                                ? () => _web.reload()
                                : null,
                            icon: const Icon(Icons.refresh),
                          ),
                          IconButton(
                            tooltip: 'Keluar',
                            onPressed: _confirmExit,
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_examStarted && _progress < 1)
                    LinearProgressIndicator(value: _progress),
                  Expanded(
                    child: _examStarted
                        ? WebViewWidget(controller: _web)
                        : KioskGate(
                            status: status,
                            starting: _starting,
                            onRetry: _startKiosk,
                          ),
                  ),
                ],
              ),
              if (_lockReason != null)
                LockOverlay(
                  reason: _lockReason!,
                  violationCount: _violationCount,
                  expectedPassword: widget.config.proctorPassword,
                  onUnlocked: () => setState(() => _lockReason = null),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
