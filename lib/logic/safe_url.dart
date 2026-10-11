/// Links the app may hand to the system: web pages and e-mail only.
/// Returns null for anything else (intent:, file:, javascript:, garbage).
Uri? launchableUri(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  switch (uri.scheme) {
    case 'https':
    case 'http':
      return uri.host.isEmpty ? null : uri;
    case 'mailto':
      return uri.path.isEmpty ? null : uri;
    default:
      return null;
  }
}
