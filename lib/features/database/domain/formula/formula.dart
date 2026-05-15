/// Minimal Notion-formula subset evaluator. Pure Dart, no parser generator.
///
/// Supported:
/// - Literals: numbers (`3.14`, `-2`), strings (`"hello"`), `true`/`false`,
///   `empty` (null).
/// - Variable access: `prop("name")` or bare identifiers (the latter only
///   when the key is a simple Dart-style identifier).
/// - Arithmetic: `+` `-` `*` `/` (with `+` overloaded for string concat
///   when either operand is a string).
/// - Comparisons: `==` `!=` `>` `<` `>=` `<=`.
/// - Logic: `&&` `||` `!`.
/// - Conditional: `if(cond, then, else)`.
/// - Functions: `concat(...)`, `length(s)`, `upper(s)`, `lower(s)`,
///   `round(n)`, `floor(n)`, `ceil(n)`, `abs(n)`, `min(a,b)`, `max(a,b)`,
///   `contains(haystack, needle)`, `now()`, `today()`,
///   `format(n, "0.00")` (only `0` and `.` patterns supported).
///
/// NOT supported (yet): dates beyond ISO string comparison, regex,
/// rollup (the `rollup(...)` function is parsed but evaluator throws —
/// the call site provides the aggregated value via the row map under
/// the column key).
library;

import 'package:equatable/equatable.dart';

/// Public entry point. [expression] is the formula source. [row] is the
/// row's cells keyed by column key.
///
/// Returns a Dart value (num, String, bool, or null on empty/error).
/// On parse/eval failure returns the [FormulaError] wrapper so the
/// renderer can display the message inline rather than crashing.
Object? evaluateFormula(String expression, Map<String, Object?> row) {
  try {
    final tokens = _Lexer(expression).tokenise();
    final ast = _Parser(tokens).parse();
    return _Eval(row).visit(ast);
  } on FormulaError catch (e) {
    return e;
  } catch (e) {
    return FormulaError('$e');
  }
}

class FormulaError extends Equatable {
  const FormulaError(this.message);
  final String message;
  @override
  String toString() => '!err: $message';
  @override
  List<Object?> get props => [message];
}

// ── AST ─────────────────────────────────────────────────────────────────

sealed class _Node {}

class _Lit extends _Node {
  _Lit(this.value);
  final Object? value;
}

class _Var extends _Node {
  _Var(this.name);
  final String name;
}

class _BinOp extends _Node {
  _BinOp(this.op, this.l, this.r);
  final String op;
  final _Node l;
  final _Node r;
}

class _Unary extends _Node {
  _Unary(this.op, this.expr);
  final String op;
  final _Node expr;
}

class _Call extends _Node {
  _Call(this.fn, this.args);
  final String fn;
  final List<_Node> args;
}

// ── Lexer ───────────────────────────────────────────────────────────────

enum _TT {
  number,
  string,
  ident,
  lparen,
  rparen,
  comma,
  plus,
  minus,
  star,
  slash,
  eq,
  neq,
  gt,
  lt,
  gte,
  lte,
  and,
  or,
  not,
  eof,
}

class _Tok {
  _Tok(this.type, this.lexeme, [this.value]);
  final _TT type;
  final String lexeme;
  final Object? value;
}

class _Lexer {
  _Lexer(this.src);
  final String src;
  int _i = 0;

  List<_Tok> tokenise() {
    final out = <_Tok>[];
    while (_i < src.length) {
      final c = src[_i];
      if (_isSpace(c)) {
        _i++;
        continue;
      }
      if (c == '(') {
        out.add(_Tok(_TT.lparen, '('));
        _i++;
      } else if (c == ')') {
        out.add(_Tok(_TT.rparen, ')'));
        _i++;
      } else if (c == ',') {
        out.add(_Tok(_TT.comma, ','));
        _i++;
      } else if (c == '+') {
        out.add(_Tok(_TT.plus, '+'));
        _i++;
      } else if (c == '-') {
        out.add(_Tok(_TT.minus, '-'));
        _i++;
      } else if (c == '*') {
        out.add(_Tok(_TT.star, '*'));
        _i++;
      } else if (c == '/') {
        out.add(_Tok(_TT.slash, '/'));
        _i++;
      } else if (c == '=' && _peek(1) == '=') {
        out.add(_Tok(_TT.eq, '=='));
        _i += 2;
      } else if (c == '!' && _peek(1) == '=') {
        out.add(_Tok(_TT.neq, '!='));
        _i += 2;
      } else if (c == '!') {
        out.add(_Tok(_TT.not, '!'));
        _i++;
      } else if (c == '>' && _peek(1) == '=') {
        out.add(_Tok(_TT.gte, '>='));
        _i += 2;
      } else if (c == '<' && _peek(1) == '=') {
        out.add(_Tok(_TT.lte, '<='));
        _i += 2;
      } else if (c == '>') {
        out.add(_Tok(_TT.gt, '>'));
        _i++;
      } else if (c == '<') {
        out.add(_Tok(_TT.lt, '<'));
        _i++;
      } else if (c == '&' && _peek(1) == '&') {
        out.add(_Tok(_TT.and, '&&'));
        _i += 2;
      } else if (c == '|' && _peek(1) == '|') {
        out.add(_Tok(_TT.or, '||'));
        _i += 2;
      } else if (c == '"' || c == "'") {
        out.add(_readString(c));
      } else if (_isDigit(c) || (c == '.' && _peek(1) != null && _isDigit(_peek(1)!))) {
        out.add(_readNumber());
      } else if (_isIdentStart(c)) {
        out.add(_readIdent());
      } else {
        throw FormulaError('unexpected character "$c" at $_i');
      }
    }
    out.add(_Tok(_TT.eof, ''));
    return out;
  }

  String? _peek(int offset) =>
      _i + offset < src.length ? src[_i + offset] : null;

  static bool _isSpace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';
  static bool _isDigit(String c) {
    final cc = c.codeUnitAt(0);
    return cc >= 0x30 && cc <= 0x39;
  }

  static bool _isIdentStart(String c) {
    final cc = c.codeUnitAt(0);
    return (cc >= 0x41 && cc <= 0x5A) ||
        (cc >= 0x61 && cc <= 0x7A) ||
        c == '_';
  }

  static bool _isIdentRest(String c) =>
      _isIdentStart(c) || _isDigit(c);

  _Tok _readString(String quote) {
    _i++; // opening quote
    final buf = StringBuffer();
    while (_i < src.length && src[_i] != quote) {
      if (src[_i] == '\\' && _i + 1 < src.length) {
        final n = src[_i + 1];
        buf.write(switch (n) {
          'n' => '\n',
          't' => '\t',
          '\\' => '\\',
          '"' => '"',
          "'" => "'",
          _ => n,
        });
        _i += 2;
      } else {
        buf.write(src[_i]);
        _i++;
      }
    }
    if (_i >= src.length) throw const FormulaError('unterminated string');
    _i++; // closing quote
    return _Tok(_TT.string, '"$buf"', buf.toString());
  }

  _Tok _readNumber() {
    final start = _i;
    while (_i < src.length && (_isDigit(src[_i]) || src[_i] == '.')) {
      _i++;
    }
    final lexeme = src.substring(start, _i);
    final v = num.tryParse(lexeme);
    if (v == null) throw FormulaError('bad number "$lexeme"');
    return _Tok(_TT.number, lexeme, v);
  }

  _Tok _readIdent() {
    final start = _i;
    while (_i < src.length && _isIdentRest(src[_i])) {
      _i++;
    }
    return _Tok(_TT.ident, src.substring(start, _i));
  }
}

// ── Parser (Pratt-ish) ──────────────────────────────────────────────────

class _Parser {
  _Parser(this.tokens);
  final List<_Tok> tokens;
  int _i = 0;

  _Node parse() {
    final node = _expr(0);
    if (_peek().type != _TT.eof) {
      throw FormulaError('trailing token: "${_peek().lexeme}"');
    }
    return node;
  }

  _Tok _peek() => tokens[_i];
  _Tok _advance() => tokens[_i++];

  bool _match(_TT t) {
    if (_peek().type == t) {
      _advance();
      return true;
    }
    return false;
  }

  void _expect(_TT t, String label) {
    if (_peek().type != t) {
      throw FormulaError('expected $label, got "${_peek().lexeme}"');
    }
    _advance();
  }

  // Precedence: 1 || · 2 && · 3 ==/!= · 4 </<=/>/>= · 5 +/- · 6 */ · 7 unary
  int _bp(_TT t) {
    switch (t) {
      case _TT.or:
        return 1;
      case _TT.and:
        return 2;
      case _TT.eq:
      case _TT.neq:
        return 3;
      case _TT.lt:
      case _TT.lte:
      case _TT.gt:
      case _TT.gte:
        return 4;
      case _TT.plus:
      case _TT.minus:
        return 5;
      case _TT.star:
      case _TT.slash:
        return 6;
      default:
        return 0;
    }
  }

  _Node _expr(int minBp) {
    var lhs = _atom();
    while (true) {
      final t = _peek();
      final bp = _bp(t.type);
      if (bp == 0 || bp < minBp) break;
      _advance();
      final rhs = _expr(bp + 1);
      lhs = _BinOp(t.lexeme, lhs, rhs);
    }
    return lhs;
  }

  _Node _atom() {
    final t = _peek();
    if (t.type == _TT.number) {
      _advance();
      return _Lit(t.value);
    }
    if (t.type == _TT.string) {
      _advance();
      return _Lit(t.value);
    }
    if (t.type == _TT.minus) {
      _advance();
      return _Unary('-', _atom());
    }
    if (t.type == _TT.not) {
      _advance();
      return _Unary('!', _atom());
    }
    if (t.type == _TT.lparen) {
      _advance();
      final inner = _expr(0);
      _expect(_TT.rparen, ')');
      return inner;
    }
    if (t.type == _TT.ident) {
      _advance();
      if (t.lexeme == 'true') return _Lit(true);
      if (t.lexeme == 'false') return _Lit(false);
      if (t.lexeme == 'empty' || t.lexeme == 'null') return _Lit(null);
      if (_match(_TT.lparen)) {
        // function call
        final args = <_Node>[];
        if (_peek().type != _TT.rparen) {
          args.add(_expr(0));
          while (_match(_TT.comma)) {
            args.add(_expr(0));
          }
        }
        _expect(_TT.rparen, ')');
        return _Call(t.lexeme, args);
      }
      return _Var(t.lexeme);
    }
    throw FormulaError('unexpected token "${t.lexeme}"');
  }
}

// ── Evaluator ───────────────────────────────────────────────────────────

class _Eval {
  _Eval(this.row);
  final Map<String, Object?> row;

  Object? visit(_Node n) {
    if (n is _Lit) return n.value;
    if (n is _Var) return _coerceRowValue(row[n.name]);
    if (n is _Unary) {
      final v = visit(n.expr);
      if (n.op == '-') return -_asNum(v);
      if (n.op == '!') return !_asBool(v);
      throw FormulaError('unknown unary op "${n.op}"');
    }
    if (n is _BinOp) return _binOp(n.op, visit(n.l), visit(n.r));
    if (n is _Call) return _call(n.fn, n.args.map(visit).toList());
    throw FormulaError('unhandled AST node: ${n.runtimeType}');
  }

  Object? _binOp(String op, Object? a, Object? b) {
    switch (op) {
      case '+':
        if (a is String || b is String) return '${a ?? ''}${b ?? ''}';
        return _asNum(a) + _asNum(b);
      case '-':
        return _asNum(a) - _asNum(b);
      case '*':
        return _asNum(a) * _asNum(b);
      case '/':
        final bn = _asNum(b);
        if (bn == 0) return const FormulaError('division by zero');
        return _asNum(a) / bn;
      case '==':
        return _equal(a, b);
      case '!=':
        return !_equal(a, b);
      case '>':
        return _cmp(a, b) > 0;
      case '<':
        return _cmp(a, b) < 0;
      case '>=':
        return _cmp(a, b) >= 0;
      case '<=':
        return _cmp(a, b) <= 0;
      case '&&':
        return _asBool(a) && _asBool(b);
      case '||':
        return _asBool(a) || _asBool(b);
    }
    throw FormulaError('unknown operator "$op"');
  }

  Object? _call(String fn, List<Object?> args) {
    switch (fn) {
      case 'prop':
        _arity(fn, args, 1);
        final key = '${args[0]}';
        return _coerceRowValue(row[key]);
      case 'if':
        _arity(fn, args, 3);
        return _asBool(args[0]) ? args[1] : args[2];
      case 'concat':
        return args.map((v) => v?.toString() ?? '').join();
      case 'length':
        _arity(fn, args, 1);
        return (args[0]?.toString() ?? '').length;
      case 'upper':
        _arity(fn, args, 1);
        return (args[0]?.toString() ?? '').toUpperCase();
      case 'lower':
        _arity(fn, args, 1);
        return (args[0]?.toString() ?? '').toLowerCase();
      case 'round':
        _arity(fn, args, 1);
        return _asNum(args[0]).round();
      case 'floor':
        _arity(fn, args, 1);
        return _asNum(args[0]).floor();
      case 'ceil':
        _arity(fn, args, 1);
        return _asNum(args[0]).ceil();
      case 'abs':
        _arity(fn, args, 1);
        return _asNum(args[0]).abs();
      case 'min':
        _arity(fn, args, 2);
        final x = _asNum(args[0]);
        final y = _asNum(args[1]);
        return x < y ? x : y;
      case 'max':
        _arity(fn, args, 2);
        final x = _asNum(args[0]);
        final y = _asNum(args[1]);
        return x > y ? x : y;
      case 'contains':
        _arity(fn, args, 2);
        final h = args[0]?.toString() ?? '';
        final n = args[1]?.toString() ?? '';
        return h.contains(n);
      case 'now':
        _arity(fn, args, 0);
        return DateTime.now().toIso8601String();
      case 'today':
        _arity(fn, args, 0);
        final n = DateTime.now();
        return '${n.year.toString().padLeft(4, '0')}-'
            '${n.month.toString().padLeft(2, '0')}-'
            '${n.day.toString().padLeft(2, '0')}';
      case 'format':
        _arity(fn, args, 2);
        return _format(_asNum(args[0]), args[1]?.toString() ?? '');
      case 'rollup':
        // Rollups are pre-computed by the renderer into the row map under
        // the formula column's key. If we get here it means the call site
        // didn't pre-aggregate.
        throw const FormulaError('rollup() must be pre-aggregated by caller');
    }
    throw FormulaError('unknown function "$fn"');
  }

  static String _format(num n, String pattern) {
    final dot = pattern.indexOf('.');
    if (dot < 0) return n.toStringAsFixed(0);
    final decimals = pattern.length - dot - 1;
    return n.toStringAsFixed(decimals);
  }

  void _arity(String fn, List<Object?> args, int expected) {
    if (args.length != expected) {
      throw FormulaError('$fn() expected $expected args, got ${args.length}');
    }
  }

  static Object? _coerceRowValue(Object? raw) {
    if (raw == null) return null;
    if (raw is num || raw is bool) return raw;
    final s = raw.toString();
    if (s.isEmpty) return null;
    // Try number first; fall back to bool keywords, then string.
    final n = num.tryParse(s);
    if (n != null) return n;
    if (s.toLowerCase() == 'true') return true;
    if (s.toLowerCase() == 'false') return false;
    return s;
  }

  static num _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return n;
    }
    if (v is bool) return v ? 1 : 0;
    return 0;
  }

  static bool _asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty && v.toLowerCase() != 'false';
    return v != null;
  }

  static bool _equal(Object? a, Object? b) {
    if (a == null && b == null) return true;
    if (a is num && b is num) return a == b;
    if (a is bool || b is bool) return _asBool(a) == _asBool(b);
    return '${a ?? ''}' == '${b ?? ''}';
  }

  static int _cmp(Object? a, Object? b) {
    if (a is num && b is num) return a.compareTo(b);
    final na = _asNum(a);
    final nb = _asNum(b);
    if (a is num || b is num) return na.compareTo(nb);
    return '${a ?? ''}'.compareTo('${b ?? ''}');
  }
}
