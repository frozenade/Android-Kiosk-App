import 'package:material_ui/material_ui.dart';

import 'screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExamBrowserApp());
}

class ExamBrowserApp extends StatelessWidget {
  const ExamBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0)),
      home: const SetupScreen(),
    );
  }
}
