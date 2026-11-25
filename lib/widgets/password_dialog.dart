import 'package:material_ui/material_ui.dart';

/// Asks for the proctor password. Returns true when it matches [expected].
Future<bool> askProctorPassword(
  BuildContext context, {
  required String expected,
  required String title,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(expected: expected, title: title),
  );
  return ok ?? false;
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.expected, required this.title});

  final String expected;
  final String title;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text == widget.expected) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Kata sandi salah');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Kata sandi pengawas',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
