import 'package:material_ui/material_ui.dart';

import '../kiosk/kiosk_service.dart';
import '../models/exam_config.dart';
import 'exam_screen.dart';

/// Proctor setup: exam URL, proctor password and kiosk status.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _password = TextEditingController();
  final _hosts = TextEditingController();
  KioskStatus? _status;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _url.dispose();
    _password.dispose();
    _hosts.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final status = await KioskService.instance.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _startExam() async {
    if (!_formKey.currentState!.validate()) return;
    final config = ExamConfig(
      examUrl: ExamConfig.parseUrl(_url.text)!,
      proctorPassword: _password.text,
      extraAllowedHosts: ExamConfig.parseHosts(_hosts.text),
    );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ExamScreen(config: config)));
    _refreshStatus();
  }

  Future<void> _releaseDeviceOwner() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lepas Device Owner?'),
        content: const Text(
          'Perangkat kembali normal dan mode kiosk penuh tidak tersedia lagi '
          'sampai Device Owner dipasang ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await KioskService.instance.releaseDeviceOwner();
    _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Browser')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Alamat ujian (URL)',
                        hintText: 'https://cbt.sekolah.sch.id',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => ExamConfig.parseUrl(v ?? '') == null
                          ? 'Masukkan URL yang valid'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Kata sandi pengawas',
                        helperText:
                            'Dipakai untuk membuka kunci dan keluar dari ujian',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v ?? '').length < 4 ? 'Minimal 4 karakter' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hosts,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Domain lain yang diizinkan (opsional)',
                        hintText: 'sso.sekolah.sch.id, cdn.contoh.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _startExam,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Ujian'),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status perangkat',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (status == null)
                              const Text('Memeriksa…')
                            else ...[
                              Text('Platform: ${status.platform}'),
                              Text('Mode kiosk: ${status.modeLabel}'),
                              if (status.isAndroid)
                                Text(
                                  status.deviceOwner
                                      ? 'Device Owner: ya (kiosk penuh)'
                                      : 'Device Owner: tidak (Sematkan Aplikasi)',
                                ),
                              if (status.message != null)
                                Text(
                                  status.message!,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                            if (status?.deviceOwner ?? false) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _releaseDeviceOwner,
                                child: const Text('Lepas Device Owner'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
