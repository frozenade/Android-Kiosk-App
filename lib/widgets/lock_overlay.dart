import 'package:material_ui/material_ui.dart';

/// Covers the exam after a violation until the proctor enters the password.
class LockOverlay extends StatefulWidget {
  const LockOverlay({
    super.key,
    required this.reason,
    required this.violationCount,
    required this.expectedPassword,
    required this.onUnlocked,
  });

  final String reason;
  final int violationCount;
  final String expectedPassword;
  final VoidCallback onUnlocked;

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text == widget.expectedPassword) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Kata sandi salah');
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 64, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Ujian dikunci', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(widget.reason, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    'Pelanggaran ke-${widget.violationCount}. '
                    'Panggil pengawas untuk membuka kunci.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi pengawas',
                      errorText: _error,
                      filled: true,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Buka kunci'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
