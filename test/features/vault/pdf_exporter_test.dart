import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/pdf_exporter.dart';
import 'package:path/path.dart' as p;

void main() {
  test('PdfExporter writes a non-empty PDF for the fixture vault', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_pdf_test_');
    final dest = File(p.join(tmp.path, 'vault.pdf'));

    final n = await const PdfExporter().export(
      src: Directory('fixtures/sample_vault'),
      dest: dest,
    );

    expect(n, greaterThan(0));
    expect(await dest.exists(), isTrue);
    final bytes = await dest.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    // PDF files start with the %PDF- magic number.
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, equals('%PDF-'));

    await tmp.delete(recursive: true);
  });

  test('PdfExporter handles a synthetic 2-page vault with cross-link', () async {
    final src = await Directory.systemTemp.createTemp('quill_pdf_src_');
    final dest = File(p.join(src.path, 'out.pdf'));

    await File(p.join(src.path, 'a.md')).writeAsString(
      '---\nid: 01HX0V9R5N6E8L3P7Q8S9U2X4B\ntitle: Foo\n---\n# Foo\n\nHello.\n',
    );
    await File(p.join(src.path, 'b.md')).writeAsString(
      '---\nid: 01HX0VEY5T6K7R9X4Y8Z0A3D4G\ntitle: Bar\n---\nSee [[01HX0V9R5N6E8L3P7Q8S9U2X4B]].\n',
    );

    final n = await const PdfExporter().export(src: src, dest: dest);
    expect(n, 2);
    final bytes = await dest.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), equals('%PDF-'));

    await src.delete(recursive: true);
  });
}
