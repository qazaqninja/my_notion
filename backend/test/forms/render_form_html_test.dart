import 'package:backend/forms/form_schema.dart';
import 'package:backend/forms/render_form_html.dart';
import 'package:test/test.dart';

void main() {
  group('renderFormHtml (E56)', () {
    group('form skeleton', () {
      test('wraps a <form method="POST" action="/forms/<ulid>/submit">',
          () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'subject', type: FormFieldType.text),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(
          html,
          contains(
            '<form method="POST" '
            'action="/forms/01JABCD1234567890ABCDEFGHJ/submit"',
          ),
        );
        expect(html, contains('<button type="submit">'));
      });

      test('uses pageTitle as the document title when provided', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'q', type: FormFieldType.text),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
          pageTitle: 'Customer feedback',
        );
        expect(html, contains('<title>Customer feedback</title>'));
        expect(html, contains('<h1>Customer feedback</h1>'));
      });

      test('falls back to a generic title when pageTitle is null', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'q', type: FormFieldType.text),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<title>Submit a response</title>'));
      });
    });

    group('field renderers', () {
      test('text field → <input type="text" name="x">', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'subject', type: FormFieldType.text),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="text" name="subject"'));
      });

      test('number field → <input type="number" name="x">', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'age', type: FormFieldType.number),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="number" name="age"'));
      });

      test('checkbox field → <input type="checkbox" name="x">', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'agree', type: FormFieldType.checkbox),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="checkbox" name="agree"'));
      });

      test(
          'select field → <select name="x"><option>a</option><option>b</option></select>',
          () {
        const schema = FormSchema(fields: [
          FormFieldDef(
            name: 'priority',
            type: FormFieldType.select,
            options: ['low', 'medium', 'high'],
          ),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<select name="priority"'));
        expect(html, contains('<option value="low">low</option>'));
        expect(html, contains('<option value="medium">medium</option>'));
        expect(html, contains('<option value="high">high</option>'));
      });

      test('required field gets the `required` attribute', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
            name: 'email',
            type: FormFieldType.text,
            required: true,
          ),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('required'));
      });

      test('optional field has NO `required` attribute', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
            name: 'nickname',
            type: FormFieldType.text,
          ),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, isNot(contains(' required')));
      });
    });

    group('escaping', () {
      test('HTML-escapes field names with special chars', () {
        const schema = FormSchema(fields: [
          // While `.database.yaml` column names are normally tame, defend
          // against a malicious or curious user dropping HTML in there.
          FormFieldDef(
            name: 'sneaky"><script>alert(1)</script>',
            type: FormFieldType.text,
          ),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, isNot(contains('<script>alert(1)</script>')));
        expect(html, contains('&lt;script&gt;'));
      });

      test('HTML-escapes select option labels', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
            name: 'tag',
            type: FormFieldType.select,
            options: ['<b>bold</b>', 'plain'],
          ),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, isNot(contains('<b>bold</b>')));
        expect(html, contains('&lt;b&gt;bold&lt;/b&gt;'));
      });

      test('HTML-escapes the pageTitle so XSS in titles is neutered', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'q', type: FormFieldType.text),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
          pageTitle: '<script>alert(1)</script>',
        );
        expect(html, isNot(contains('<script>alert(1)</script>')));
        expect(html, contains('&lt;script&gt;'));
      });
    });

    group('empty schema', () {
      test('empty schema still renders a usable form skeleton (no fields)',
          () {
        const schema = FormSchema.empty;
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        // Form tag + submit button still present so the page renders
        // with a button — submit endpoint will 400 empty_body, but
        // the renderer itself doesn't gate.
        expect(html, contains('<form method="POST"'));
        expect(html, contains('<button type="submit">'));
        // No <input> / <select> elements.
        expect(html, isNot(contains('<input')));
        expect(html, isNot(contains('<select')));
      });
    });

    group('date fields (M1479)', () {
      test('FormFieldType.date emits <input type="date">', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'due_by', type: FormFieldType.date),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html,
            contains('<input type="date" name="due_by"></label>'));
      });

      test('required date carries the required attribute', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
              name: 'due_by',
              type: FormFieldType.date,
              required: true),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html,
            contains(
                '<input type="date" name="due_by" required></label>'));
      });
    });

    group('multi-select fields (M1482)', () {
      test('FormFieldType.multi emits a fieldset of checkboxes', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['red', 'green', 'blue']),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<fieldset>'));
        expect(html, contains('<legend>tags</legend>'));
        expect(
            html,
            contains(
                '<input type="checkbox" name="tags" value="red">'));
        expect(
            html,
            contains(
                '<input type="checkbox" name="tags" value="green">'));
        expect(
            html,
            contains(
                '<input type="checkbox" name="tags" value="blue">'));
      });

      test('multi never emits a `required` attribute on the boxes',
          () {
        // `required` on a checkbox group is a UX wart (browsers
        // require ALL boxes checked). Server-side `required`
        // catches the empty-submission case.
        const schema = FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              required: true,
              options: ['a']),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(
          html,
          isNot(contains('checkbox" name="tags" value="a" required')),
        );
      });

      test('multi options are HTML-escaped', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['<script>alert(1)</script>']),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, isNot(contains('<script>alert(1)</script>')));
        expect(html, contains('&lt;script&gt;'));
      });
    });

    // E60 slice 1 (M1610) — email field renders as HTML5 email input.
    group('email field', () {
      test('renders <input type="email">', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'contact', type: FormFieldType.email),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="email" name="contact"'));
      });

      test('required email gets HTML `required` attribute', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
              name: 'contact',
              type: FormFieldType.email,
              required: true),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="email" name="contact" required>'));
      });

      test('email input picked up by the CSS rule', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'contact', type: FormFieldType.email),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('input[type=email]'));
      });
    });

    // E60 slice 2 (M1612) — url field renders as HTML5 url input.
    group('url field', () {
      test('renders <input type="url">', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'website', type: FormFieldType.url),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="url" name="website"'));
      });

      test('required url gets HTML `required` attribute', () {
        const schema = FormSchema(fields: [
          FormFieldDef(
              name: 'website', type: FormFieldType.url, required: true),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('<input type="url" name="website" required>'));
      });

      test('url input picked up by the CSS rule', () {
        const schema = FormSchema(fields: [
          FormFieldDef(name: 'website', type: FormFieldType.url),
        ]);
        final html = renderFormHtml(
          ulid: '01JABCD1234567890ABCDEFGHJ',
          schema: schema,
        );
        expect(html, contains('input[type=url]'));
      });
    });
  });
}
