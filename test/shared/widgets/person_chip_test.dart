import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:my_notion/shared/widgets/person_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: makeTheme(Brightness.light, AccentKey.sage),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders avatar + name', (tester) async {
    await tester.pumpWidget(_wrap(const PersonChip(name: 'Alice')));
    expect(find.text('A'), findsOneWidget); // initial
    expect(find.text('Alice'), findsOneWidget); // name
  });

  testWidgets('compact mode drops the name label', (tester) async {
    await tester.pumpWidget(
      _wrap(const PersonChip(name: 'Alice', compact: true)),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('empty name falls back to ?', (tester) async {
    await tester.pumpWidget(_wrap(const PersonChip(name: '')));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('same name → same avatar colour', (tester) async {
    await tester.pumpWidget(_wrap(
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonChip(name: 'Alice'),
          SizedBox(width: 10),
          PersonChip(name: 'Alice'),
        ],
      ),
    ));
    final containers = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>()
        .toList();
    expect(containers.length, greaterThanOrEqualTo(2));
    expect(containers[0], equals(containers[1]));
  });
}
