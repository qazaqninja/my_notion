import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/trello_to_database.dart';

void main() {
  group('TrelloToDatabase.convert', () {
    test('basic board → name + status options + cards', () {
      const json = '''{
  "name": "Sprint",
  "lists": [
    {"id": "L1", "name": "To Do", "closed": false},
    {"id": "L2", "name": "Doing", "closed": false},
    {"id": "L3", "name": "Done",  "closed": false}
  ],
  "cards": [
    {"id":"C1","name":"task one","desc":"line one","idList":"L1","labels":[{"name":"urgent"}],"closed":false,"due":"2026-06-01T00:00:00.000Z"},
    {"id":"C2","name":"task two","desc":"","idList":"L2","labels":[],"closed":false}
  ]
}''';
      final board = TrelloToDatabase.convert(json)!;
      expect(board.name, 'Sprint');
      expect(board.statusOptions, ['To Do', 'Doing', 'Done']);
      expect(board.cards.length, 2);
      expect(board.cards[0].title, 'task one');
      expect(board.cards[0].status, 'To Do');
      expect(board.cards[0].labels, ['urgent']);
      expect(board.cards[0].due, '2026-06-01');
      expect(board.cards[1].title, 'task two');
      expect(board.cards[1].status, 'Doing');
    });

    test('closed cards are skipped', () {
      const json = '''{
  "name": "X",
  "lists": [{"id":"L1","name":"A","closed":false}],
  "cards": [
    {"name":"keep","idList":"L1","closed":false},
    {"name":"drop","idList":"L1","closed":true}
  ]
}''';
      final board = TrelloToDatabase.convert(json)!;
      expect(board.cards.map((c) => c.title), ['keep']);
    });

    test('cards in closed lists are skipped', () {
      const json = '''{
  "name": "X",
  "lists": [
    {"id":"L1","name":"Open","closed":false},
    {"id":"L2","name":"Archive","closed":true}
  ],
  "cards": [
    {"name":"keep","idList":"L1","closed":false},
    {"name":"archived","idList":"L2","closed":false}
  ]
}''';
      final board = TrelloToDatabase.convert(json)!;
      expect(board.cards.map((c) => c.title), ['keep']);
      // closed list isn't in status options either.
      expect(board.statusOptions, ['Open']);
    });

    test('garbage / non-board JSON → null', () {
      expect(TrelloToDatabase.convert('not json'), isNull);
      expect(TrelloToDatabase.convert('[1,2,3]'), isNull);
      expect(TrelloToDatabase.convert('{}'), isNull);
    });

    test('handles missing labels / due gracefully', () {
      const json = '''{
  "name": "Min",
  "lists": [{"id":"L1","name":"List","closed":false}],
  "cards":[{"name":"only","idList":"L1","closed":false}]
}''';
      final c = TrelloToDatabase.convert(json)!.cards.single;
      expect(c.labels, isEmpty);
      expect(c.due, isNull);
    });
  });
}
