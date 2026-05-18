/// User-visible toast label for the kebab "Copy body / plain / JSON"
/// actions. Centralised so future variants inherit the same
/// singular-vs-plural handling. `0 chars` over `0 char` matches the
/// legacy editor — "0 char" reads as a typo. Only `n == 1` triggers
/// the singular form.
///
/// `suffix` lets callers tail the label ("to clipboard" by default;
/// "as plain text" for copy-plain; "JSON" for copy-json).
String copiedCharsLabel(int n, {String suffix = 'to clipboard'}) {
  final unit = n == 1 ? 'char' : 'chars';
  return 'Copied $n $unit $suffix';
}
