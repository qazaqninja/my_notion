/// Field types Quill's `.database.yaml` declares. Mirrors the
/// client-side `ColumnType` subset useful for public form
/// submission: free text, structured numbers, booleans (single
/// checkbox), one-of (select), dates (`<input type="date">` posts
/// ISO 8601 `YYYY-MM-DD`), and many-of (`multi`-select rendered
/// as a checkbox group whose repeated keys the parser joins with
/// `,` per the M1482 _parseForm update).
enum FormFieldType {
  /// Free-form text → `<input type="text">`.
  text,

  /// Numeric input → `<input type="number">` validated via [num.tryParse].
  number,

  /// Single boolean → `<input type="checkbox">`.
  checkbox,

  /// One-of choice from a fixed option set → `<select>`.
  select,

  /// Calendar date (ISO 8601 `YYYY-MM-DD`) → `<input type="date">`.
  date,

  /// Many-of choice from a fixed option set → checkbox group; repeated
  /// keys joined with `,` in the parser per M1482.
  multi,
}

/// One column definition pulled from a `.database.yaml` `columns:`
/// block. `options` is populated for `FormFieldType.select` and
/// `FormFieldType.multi` (M1482) — the universe of one-of /
/// many-of values respectively.
class FormFieldDef {
  /// Construct a column definition for the form schema.
  const FormFieldDef({
    required this.name,
    required this.type,
    this.required = false,
    this.options = const <String>[],
  });

  /// Column name as posted by the form — must match the
  /// `application/x-www-form-urlencoded` key.
  final String name;

  /// Widget shape + parser the column resolves to.
  final FormFieldType type;

  /// When true the validator rejects an empty / absent value.
  final bool required;

  /// Universe of allowed values for `select` + `multi`; empty for
  /// other types.
  final List<String> options;
}

/// Whole-form schema. A `FormSchema.empty` matches the "no schema
/// resolved, accept any non-empty body" fallback used by E48 — useful
/// during the rollout of F4 / F5 so existing form pages keep working
/// until their `.database.yaml` is populated.
class FormSchema {
  /// Construct a schema from a list of column definitions.
  const FormSchema({required this.fields});

  /// Column definitions in declaration order.
  final List<FormFieldDef> fields;

  /// Sentinel for "no schema resolved" — validator passes any
  /// non-empty body through unchanged.
  static const FormSchema empty = FormSchema(fields: <FormFieldDef>[]);
}

/// Minimal `.database.yaml` `columns:` parser. Looks for a top-level
/// `columns:` key followed by a sequence of `- name: …` blocks. Lines
/// outside the `columns:` block are ignored.
///
/// Hand-rolled (no `yaml` package dependency) to stay in line with the
/// existing `FrontmatterProbe` pattern: backend reads bodies dozens of
/// times per upsert, and a regex pass is faster + dependency-light for
/// a fixed shape we control. Falls back to `FormSchema.empty` whenever
/// the source doesn't include a `columns:` block, so a malformed or
/// missing schema doesn't break submissions — the route layer can
/// either reject (strict mode) or accept (lax mode) when the schema
/// is empty.
FormSchema parseFormSchema(String yamlBody) {
  final lines = yamlBody.split('\n');
  // 1. Locate the start of the `columns:` block.
  var i = 0;
  while (i < lines.length) {
    if (RegExp(r'^columns\s*:\s*$').hasMatch(lines[i])) break;
    i++;
  }
  if (i >= lines.length) return FormSchema.empty;
  i++; // step past the `columns:` line itself

  final fields = <FormFieldDef>[];
  while (i < lines.length) {
    final line = lines[i];
    // A new top-level key terminates the block.
    if (RegExp(r'^[^\s\-#]').hasMatch(line)) break;
    // Skip blank / comment lines.
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
      i++;
      continue;
    }
    // Expect a `- name: …` line opening a new entry.
    final dash = RegExp(r'^\s*-\s+name\s*:\s*(.+?)\s*$').firstMatch(line);
    if (dash == null) {
      i++;
      continue;
    }
    final name = _unquote(dash.group(1)!);
    var type = FormFieldType.text;
    var required = false;
    var options = const <String>[];
    i++;
    while (i < lines.length) {
      final nl = lines[i];
      if (nl.trim().isEmpty) {
        i++;
        continue;
      }
      // New entry (`-`) or new top-level key terminates the field block.
      if (RegExp(r'^\s*-\s+name\s*:').hasMatch(nl)) break;
      if (RegExp(r'^[^\s\-#]').hasMatch(nl)) break;
      final kv = RegExp(r'^\s+(\w+)\s*:\s*(.*?)\s*$').firstMatch(nl);
      if (kv == null) {
        i++;
        continue;
      }
      final key = kv.group(1)!;
      final value = _unquote(kv.group(2)!);
      switch (key) {
        case 'type':
          type = _parseType(value);
        case 'required':
          required = value == 'true' || value == 'yes';
        case 'options':
          options = _parseOptions(value);
      }
      i++;
    }
    fields.add(FormFieldDef(
      name: name,
      type: type,
      required: required,
      options: options,
    ));
  }
  return FormSchema(fields: fields);
}

FormFieldType _parseType(String raw) {
  switch (raw.toLowerCase()) {
    case 'number':
    case 'integer':
    case 'int':
    case 'float':
      return FormFieldType.number;
    case 'checkbox':
    case 'bool':
    case 'boolean':
      return FormFieldType.checkbox;
    case 'select':
    case 'enum':
      return FormFieldType.select;
    case 'date':
    case 'datetime':
      return FormFieldType.date;
    case 'multi':
    case 'multi_select':
    case 'multiselect':
      return FormFieldType.multi;
    case 'text':
    case 'string':
    case '':
    default:
      return FormFieldType.text;
  }
}

/// Inline flow-style sequence: `[a, b, c]`. Empty / non-flow values
/// fall through to an empty list. Quoted entries are unwrapped.
List<String> _parseOptions(String raw) {
  if (!raw.startsWith('[') || !raw.endsWith(']')) return const <String>[];
  final inner = raw.substring(1, raw.length - 1).trim();
  if (inner.isEmpty) return const <String>[];
  return inner
      .split(',')
      .map((s) => _unquote(s.trim()))
      .where((s) => s.isNotEmpty)
      .toList();
}

String _unquote(String s) =>
    s.replaceAll(RegExp(r"""^["']|["']$"""), '');

/// Result of running a form payload against a schema. `errors` is
/// keyed by field name; an empty map means "valid".
class FormValidationResult {
  /// Construct a validation result. Empty [errors] means success;
  /// [normalized] carries the type-coerced field values to persist.
  const FormValidationResult({required this.errors, required this.normalized});

  /// Field-name → typed error code. Empty when the submission validated.
  final Map<String, String> errors;

  /// Coerced field values to store as JSONB. Booleans, numbers, and
  /// `List<String>` for multi-select land as native Dart types.
  final Map<String, Object?> normalized;

  /// True iff the submission passed validation.
  bool get isValid => errors.isEmpty;
}

/// Validate a parsed form-urlencoded submission against [schema].
/// Coerces each input to the column's expected type, surfaces typed
/// error codes on mismatch.
FormValidationResult validateSubmission(
  FormSchema schema,
  Map<String, String> raw,
) {
  // Empty schema = legacy "any non-empty body" — return the raw map.
  if (schema.fields.isEmpty) {
    return FormValidationResult(
      errors: const <String, String>{},
      normalized: Map<String, Object?>.from(raw),
    );
  }
  final errors = <String, String>{};
  final normalized = <String, Object?>{};
  for (final field in schema.fields) {
    final input = raw[field.name];
    final missing = input == null || input.isEmpty;
    if (missing) {
      if (field.required) errors[field.name] = 'required';
      continue;
    }
    switch (field.type) {
      case FormFieldType.text:
        normalized[field.name] = input;
      case FormFieldType.number:
        final n = num.tryParse(input);
        if (n == null || n.isNaN || n.isInfinite) {
          // `num.tryParse('NaN')` and `'Infinity'` both succeed —
          // reject them explicitly so a form-submitter can't smuggle
          // non-finite values past the validator.
          errors[field.name] = 'expected_number';
        } else {
          normalized[field.name] = n;
        }
      case FormFieldType.checkbox:
        final v = input.toLowerCase();
        if (v == 'true' || v == 'on' || v == 'yes' || v == '1') {
          normalized[field.name] = true;
        } else if (v == 'false' || v == 'off' || v == 'no' || v == '0') {
          normalized[field.name] = false;
        } else {
          errors[field.name] = 'expected_checkbox';
        }
      case FormFieldType.select:
        if (!field.options.contains(input)) {
          errors[field.name] = 'not_in_options';
        } else {
          normalized[field.name] = input;
        }
      case FormFieldType.date:
        // Browser `<input type="date">` posts ISO 8601 YYYY-MM-DD.
        // DateTime.tryParse handles that plus the longer datetime
        // forms a future `<input type="datetime-local">` would emit
        // (YYYY-MM-DDThh:mm). Normalised to a stable ISO string so
        // downstream consumers don't have to re-parse.
        final dt = DateTime.tryParse(input);
        if (dt == null) {
          errors[field.name] = 'expected_date';
        } else {
          normalized[field.name] = dt.toIso8601String();
        }
      case FormFieldType.multi:
        // The route's `_parseForm` (M1482) joins repeated keys with
        // `,` so a checkbox group named `tag` with values `a`, `b`,
        // `c` arrives here as the single string `'a,b,c'`. Split,
        // trim, drop empties, validate each ∈ field.options. Empty
        // selections were already caught by the `missing` branch
        // above (an unchecked group sends no key at all).
        final picks = input
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final bad = picks.where((p) => !field.options.contains(p));
        if (bad.isNotEmpty) {
          errors[field.name] = 'not_in_options';
        } else {
          normalized[field.name] = picks;
        }
    }
  }
  return FormValidationResult(errors: errors, normalized: normalized);
}
