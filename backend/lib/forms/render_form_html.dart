// File is an HTML template renderer — adjacent string literals are
// concatenated to assemble HTML/CSS without semantically meaningful
// whitespace. The missing_whitespace_between_adjacent_strings lint
// flags every line of these templates; the rule doesn't apply to
// this idiom.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:backend/forms/form_schema.dart';

/// E56 — pure-text renderer for the public form HTML served by
/// `GET /forms/<ulid>`. Takes the page's [FormSchema] (parsed from
/// the linked `.database.yaml` `columns:` block per F4) and emits
/// a self-contained HTML document with a single `<form>` posting
/// to `/forms/<ulid>/submit`.
///
/// Renders one input per field:
///   - text      → <input type="text" name="…">
///   - number    → <input type="number" name="…">
///   - checkbox  → <input type="checkbox" name="…">
///   - select    → <select name="…">… options …</select>
///   - date      → <input type="date" name="…">  (ISO YYYY-MM-DD)
///   - multi     → N <input type="checkbox" name="…" value="…"> per
///                 option (the route's _parseForm joins repeated
///                 keys with `,` so a multi-select group surfaces
///                 as `'a,b,c'` in validateSubmission's raw map).
///   - email     → <input type="email" name="…">  (E60 slice 1)
///   - url       → <input type="url" name="…">  (E60 slice 2)
///   - longtext  → <textarea name="…" rows="4"></textarea>  (E60 slice 3)
///
/// `required: true` fields get the HTML `required` attribute so
/// the browser validates before submit (the server still re-
/// validates via `validateSubmission` per F5 — never trust the
/// client). All user-controlled strings are HTML-escaped to
/// neuter `<script>` injection from a hostile column name or
/// option label.
///
/// The route wire-in (`GET /forms/<ulid>` in
/// backend/lib/forms/routes.dart) lands as a follow-up slice;
/// this slice is pure renderer + tests so the HTML shape is
/// pinned before any network handler depends on it.
String renderFormHtml({
  required String ulid,
  required FormSchema schema,
  String? pageTitle,
}) {
  const esc = HtmlEscape(HtmlEscapeMode.element);
  const attrEsc = HtmlEscape(HtmlEscapeMode.attribute);
  final title =
      pageTitle == null ? 'Submit a response' : esc.convert(pageTitle);
  final escUlid = attrEsc.convert(ulid);
  final fieldsHtml = StringBuffer();
  for (final f in schema.fields) {
    fieldsHtml.writeln(_renderField(f, esc, attrEsc));
  }
  return '<!doctype html>'
      '<html lang="en">'
      '<head>'
      '<meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<title>$title</title>'
      '<style>'
      'body{font-family:system-ui,sans-serif;max-width:560px;'
      'margin:40px auto;padding:0 16px;color:#222}'
      'h1{font-size:20px;margin:0 0 16px}'
      'form{display:flex;flex-direction:column;gap:14px}'
      'label{display:flex;flex-direction:column;gap:4px;'
      'font-size:13px;color:#555}'
      'input[type=text],input[type=number],input[type=date],'
      'input[type=email],input[type=url],select,textarea'
      '{font:inherit;padding:8px 10px;border:1px solid #ccc;border-radius:6px}'
      'textarea{resize:vertical;min-height:80px}'
      'button{font:inherit;padding:10px 16px;border-radius:6px;'
      'border:0;background:#222;color:#fff;cursor:pointer;'
      'align-self:flex-start}'
      '</style>'
      '</head>'
      '<body>'
      '<h1>$title</h1>'
      '<form method="POST" action="/forms/$escUlid/submit">'
      '$fieldsHtml'
      '<button type="submit">Submit</button>'
      '</form>'
      '</body>'
      '</html>';
}

String _renderField(
  FormFieldDef f,
  HtmlEscape elementEsc,
  HtmlEscape attrEsc,
) {
  final label = elementEsc.convert(f.name);
  final attrName = attrEsc.convert(f.name);
  final req = f.required ? ' required' : '';
  switch (f.type) {
    case FormFieldType.text:
      return '<label>$label'
          '<input type="text" name="$attrName"$req></label>';
    case FormFieldType.number:
      return '<label>$label'
          '<input type="number" name="$attrName"$req></label>';
    case FormFieldType.checkbox:
      // Checkbox stays on the same row as its label for clarity.
      return '<label style="flex-direction:row;align-items:center;gap:8px">'
          '<input type="checkbox" name="$attrName"$req>'
          '$label</label>';
    case FormFieldType.select:
      final options = StringBuffer();
      for (final opt in f.options) {
        final optLabel = elementEsc.convert(opt);
        final optAttr = attrEsc.convert(opt);
        options.writeln('<option value="$optAttr">$optLabel</option>');
      }
      return '<label>$label'
          '<select name="$attrName"$req>'
          '$options'
          '</select></label>';
    case FormFieldType.date:
      return '<label>$label'
          '<input type="date" name="$attrName"$req></label>';
    case FormFieldType.email:
      // E60 slice 1: HTML5 email input — browser does loose client-side
      // validation; server re-validates via the regex in
      // validateSubmission.
      return '<label>$label'
          '<input type="email" name="$attrName"$req></label>';
    case FormFieldType.url:
      // E60 slice 2: HTML5 url input — server enforces http/https only.
      return '<label>$label'
          '<input type="url" name="$attrName"$req></label>';
    case FormFieldType.longtext:
      // E60 slice 3: multi-line free text. `rows="4"` is the standard
      // Notion-form default; the CSS allows vertical resize so users
      // can grow the box for longer answers.
      return '<label>$label'
          '<textarea name="$attrName" rows="4"$req></textarea></label>';
    case FormFieldType.multi:
      // Group of checkboxes — one per option, all sharing the
      // field name. Each checked box posts as `name=value`,
      // which `_parseForm` joins into a comma-separated string
      // for `validateSubmission`.
      //
      // `required` on a checkbox group is a UX wart in browsers
      // (it requires ALL boxes to be checked), so we omit the
      // attribute and rely on the server-side `required` check
      // (the `missing` branch in validateSubmission fires when
      // no boxes are checked because nothing posts the key).
      final boxes = StringBuffer();
      for (final opt in f.options) {
        final optLabel = elementEsc.convert(opt);
        final optAttr = attrEsc.convert(opt);
        boxes.writeln(
            '<label style="flex-direction:row;align-items:center;gap:8px">'
            '<input type="checkbox" name="$attrName" value="$optAttr">'
            '$optLabel</label>');
      }
      return '<fieldset><legend>$label</legend>$boxes</fieldset>';
  }
}
