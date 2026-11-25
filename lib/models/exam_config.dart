/// Settings for one exam session, entered by the proctor on the setup screen.
class ExamConfig {
  const ExamConfig({
    required this.examUrl,
    required this.proctorPassword,
    this.extraAllowedHosts = const [],
  });

  final Uri examUrl;

  /// Unlocks the exam after a violation and allows leaving kiosk mode.
  final String proctorPassword;

  /// Other domains the exam may navigate to (e.g. a login/SSO server).
  final List<String> extraAllowedHosts;

  /// Parses user input into an exam URL, defaulting to https.
  static Uri? parseUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  static List<String> parseHosts(String input) => input
      .split(RegExp(r'[,\s]+'))
      .map((h) => h.trim().toLowerCase())
      .where((h) => h.isNotEmpty)
      .toList();

  /// Whether the web view may open [uri]. Anything else is blocked so the
  /// exam cannot be used to browse the web.
  bool isAllowed(Uri uri) {
    if (const {'about', 'data', 'blob'}.contains(uri.scheme)) return true;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return [
      examUrl.host.toLowerCase(),
      ...extraAllowedHosts,
    ].any((h) => host == h || host.endsWith('.$h'));
  }
}
