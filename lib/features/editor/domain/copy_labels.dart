/// User-visible toast label for the kebab "Copy body / plain / JSON"
/// actions. Centralised so future variants (copy-html, copy-json, …)
/// inherit the same singular-vs-plural handling.
///
/// `0 chars` over `0 char` matches the legacy editor — "0 char" reads
/// as a typo. Only `n == 1` triggers the singular form.
String copiedCharsLabel(int n) {
  final unit = n == 1 ? 'char' : 'chars';
  return 'Copied $n $unit to clipboard';
}
