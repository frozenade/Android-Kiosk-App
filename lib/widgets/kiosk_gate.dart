import 'package:material_ui/material_ui.dart';

import '../kiosk/kiosk_service.dart';

/// Shown until kiosk mode is active; the exam page is not loaded before that.
class KioskGate extends StatelessWidget {
  const KioskGate({
    super.key,
    required this.status,
    required this.starting,
    required this.onRetry,
  });

  final KioskStatus? status;
  final bool starting;
  final VoidCallback onRetry;

  String _instructions(KioskStatus? s) {
    if (s == null) return 'Memeriksa mode kiosk…';
    if (s.isAndroid) {
      return 'Ketuk "Sematkan" / "Pin" pada dialog yang muncul. Jika dialog '
          'tidak muncul, aktifkan dulu Setelan > Keamanan > Sematkan aplikasi '
          '(App pinning), lalu ketuk tombol di bawah.';
    }
    if (s.isIOS) {
      return 'Aktifkan Akses Terpandu: Setelan > Aksesibilitas > Akses '
          'Terpandu, kembali ke aplikasi ini lalu klik tiga kali tombol samping '
          'dan ketuk "Mulai".';
    }
    return s.message ?? 'Mode kiosk tidak tersedia.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = status?.message;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.screen_lock_portrait,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Aktifkan mode kiosk', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(_instructions(status), textAlign: TextAlign.center),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: starting ? null : onRetry,
                icon: starting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock),
                label: const Text('Aktifkan mode kiosk'),
              ),
              const SizedBox(height: 8),
              Text(
                'Soal ujian dibuka otomatis setelah mode kiosk aktif.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
