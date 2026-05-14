// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quill_database.dart';

// ignore_for_file: type=lint
class $PagesTable extends Pages with TableInfo<$PagesTable, Page> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ulidMeta = const VerificationMeta('ulid');
  @override
  late final GeneratedColumn<String> ulid = GeneratedColumn<String>(
    'ulid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 26,
      maxTextLength: 26,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frontmatterJsonMeta = const VerificationMeta(
    'frontmatterJson',
  );
  @override
  late final GeneratedColumn<String> frontmatterJson = GeneratedColumn<String>(
    'frontmatter_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyTextMeta = const VerificationMeta(
    'bodyText',
  );
  @override
  late final GeneratedColumn<String> bodyText = GeneratedColumn<String>(
    'body_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _databaseIdMeta = const VerificationMeta(
    'databaseId',
  );
  @override
  late final GeneratedColumn<String> databaseId = GeneratedColumn<String>(
    'database_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ulid,
    relativePath,
    title,
    frontmatterJson,
    bodyText,
    mtimeMs,
    databaseId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Page> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ulid')) {
      context.handle(
        _ulidMeta,
        ulid.isAcceptableOrUnknown(data['ulid']!, _ulidMeta),
      );
    } else if (isInserting) {
      context.missing(_ulidMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('frontmatter_json')) {
      context.handle(
        _frontmatterJsonMeta,
        frontmatterJson.isAcceptableOrUnknown(
          data['frontmatter_json']!,
          _frontmatterJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frontmatterJsonMeta);
    }
    if (data.containsKey('body_text')) {
      context.handle(
        _bodyTextMeta,
        bodyText.isAcceptableOrUnknown(data['body_text']!, _bodyTextMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyTextMeta);
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    }
    if (data.containsKey('database_id')) {
      context.handle(
        _databaseIdMeta,
        databaseId.isAcceptableOrUnknown(data['database_id']!, _databaseIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ulid};
  @override
  Page map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Page(
      ulid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ulid'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      frontmatterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frontmatter_json'],
      )!,
      bodyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_text'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      )!,
      databaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}database_id'],
      ),
    );
  }

  @override
  $PagesTable createAlias(String alias) {
    return $PagesTable(attachedDatabase, alias);
  }
}

class Page extends DataClass implements Insertable<Page> {
  final String ulid;
  final String relativePath;
  final String title;
  final String frontmatterJson;
  final String bodyText;
  final int mtimeMs;
  final String? databaseId;
  const Page({
    required this.ulid,
    required this.relativePath,
    required this.title,
    required this.frontmatterJson,
    required this.bodyText,
    required this.mtimeMs,
    this.databaseId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ulid'] = Variable<String>(ulid);
    map['relative_path'] = Variable<String>(relativePath);
    map['title'] = Variable<String>(title);
    map['frontmatter_json'] = Variable<String>(frontmatterJson);
    map['body_text'] = Variable<String>(bodyText);
    map['mtime_ms'] = Variable<int>(mtimeMs);
    if (!nullToAbsent || databaseId != null) {
      map['database_id'] = Variable<String>(databaseId);
    }
    return map;
  }

  PagesCompanion toCompanion(bool nullToAbsent) {
    return PagesCompanion(
      ulid: Value(ulid),
      relativePath: Value(relativePath),
      title: Value(title),
      frontmatterJson: Value(frontmatterJson),
      bodyText: Value(bodyText),
      mtimeMs: Value(mtimeMs),
      databaseId: databaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(databaseId),
    );
  }

  factory Page.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Page(
      ulid: serializer.fromJson<String>(json['ulid']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      title: serializer.fromJson<String>(json['title']),
      frontmatterJson: serializer.fromJson<String>(json['frontmatterJson']),
      bodyText: serializer.fromJson<String>(json['bodyText']),
      mtimeMs: serializer.fromJson<int>(json['mtimeMs']),
      databaseId: serializer.fromJson<String?>(json['databaseId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ulid': serializer.toJson<String>(ulid),
      'relativePath': serializer.toJson<String>(relativePath),
      'title': serializer.toJson<String>(title),
      'frontmatterJson': serializer.toJson<String>(frontmatterJson),
      'bodyText': serializer.toJson<String>(bodyText),
      'mtimeMs': serializer.toJson<int>(mtimeMs),
      'databaseId': serializer.toJson<String?>(databaseId),
    };
  }

  Page copyWith({
    String? ulid,
    String? relativePath,
    String? title,
    String? frontmatterJson,
    String? bodyText,
    int? mtimeMs,
    Value<String?> databaseId = const Value.absent(),
  }) => Page(
    ulid: ulid ?? this.ulid,
    relativePath: relativePath ?? this.relativePath,
    title: title ?? this.title,
    frontmatterJson: frontmatterJson ?? this.frontmatterJson,
    bodyText: bodyText ?? this.bodyText,
    mtimeMs: mtimeMs ?? this.mtimeMs,
    databaseId: databaseId.present ? databaseId.value : this.databaseId,
  );
  Page copyWithCompanion(PagesCompanion data) {
    return Page(
      ulid: data.ulid.present ? data.ulid.value : this.ulid,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      title: data.title.present ? data.title.value : this.title,
      frontmatterJson: data.frontmatterJson.present
          ? data.frontmatterJson.value
          : this.frontmatterJson,
      bodyText: data.bodyText.present ? data.bodyText.value : this.bodyText,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      databaseId: data.databaseId.present
          ? data.databaseId.value
          : this.databaseId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Page(')
          ..write('ulid: $ulid, ')
          ..write('relativePath: $relativePath, ')
          ..write('title: $title, ')
          ..write('frontmatterJson: $frontmatterJson, ')
          ..write('bodyText: $bodyText, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('databaseId: $databaseId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ulid,
    relativePath,
    title,
    frontmatterJson,
    bodyText,
    mtimeMs,
    databaseId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Page &&
          other.ulid == this.ulid &&
          other.relativePath == this.relativePath &&
          other.title == this.title &&
          other.frontmatterJson == this.frontmatterJson &&
          other.bodyText == this.bodyText &&
          other.mtimeMs == this.mtimeMs &&
          other.databaseId == this.databaseId);
}

class PagesCompanion extends UpdateCompanion<Page> {
  final Value<String> ulid;
  final Value<String> relativePath;
  final Value<String> title;
  final Value<String> frontmatterJson;
  final Value<String> bodyText;
  final Value<int> mtimeMs;
  final Value<String?> databaseId;
  final Value<int> rowid;
  const PagesCompanion({
    this.ulid = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.title = const Value.absent(),
    this.frontmatterJson = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.databaseId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PagesCompanion.insert({
    required String ulid,
    required String relativePath,
    required String title,
    required String frontmatterJson,
    required String bodyText,
    this.mtimeMs = const Value.absent(),
    this.databaseId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ulid = Value(ulid),
       relativePath = Value(relativePath),
       title = Value(title),
       frontmatterJson = Value(frontmatterJson),
       bodyText = Value(bodyText);
  static Insertable<Page> custom({
    Expression<String>? ulid,
    Expression<String>? relativePath,
    Expression<String>? title,
    Expression<String>? frontmatterJson,
    Expression<String>? bodyText,
    Expression<int>? mtimeMs,
    Expression<String>? databaseId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ulid != null) 'ulid': ulid,
      if (relativePath != null) 'relative_path': relativePath,
      if (title != null) 'title': title,
      if (frontmatterJson != null) 'frontmatter_json': frontmatterJson,
      if (bodyText != null) 'body_text': bodyText,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (databaseId != null) 'database_id': databaseId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PagesCompanion copyWith({
    Value<String>? ulid,
    Value<String>? relativePath,
    Value<String>? title,
    Value<String>? frontmatterJson,
    Value<String>? bodyText,
    Value<int>? mtimeMs,
    Value<String?>? databaseId,
    Value<int>? rowid,
  }) {
    return PagesCompanion(
      ulid: ulid ?? this.ulid,
      relativePath: relativePath ?? this.relativePath,
      title: title ?? this.title,
      frontmatterJson: frontmatterJson ?? this.frontmatterJson,
      bodyText: bodyText ?? this.bodyText,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      databaseId: databaseId ?? this.databaseId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ulid.present) {
      map['ulid'] = Variable<String>(ulid.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (frontmatterJson.present) {
      map['frontmatter_json'] = Variable<String>(frontmatterJson.value);
    }
    if (bodyText.present) {
      map['body_text'] = Variable<String>(bodyText.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (databaseId.present) {
      map['database_id'] = Variable<String>(databaseId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PagesCompanion(')
          ..write('ulid: $ulid, ')
          ..write('relativePath: $relativePath, ')
          ..write('title: $title, ')
          ..write('frontmatterJson: $frontmatterJson, ')
          ..write('bodyText: $bodyText, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('databaseId: $databaseId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RelationsTable extends Relations
    with TableInfo<$RelationsTable, Relation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fromUlidMeta = const VerificationMeta(
    'fromUlid',
  );
  @override
  late final GeneratedColumn<String> fromUlid = GeneratedColumn<String>(
    'from_ulid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toUlidMeta = const VerificationMeta('toUlid');
  @override
  late final GeneratedColumn<String> toUlid = GeneratedColumn<String>(
    'to_ulid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [fromUlid, toUlid, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'relations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Relation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('from_ulid')) {
      context.handle(
        _fromUlidMeta,
        fromUlid.isAcceptableOrUnknown(data['from_ulid']!, _fromUlidMeta),
      );
    } else if (isInserting) {
      context.missing(_fromUlidMeta);
    }
    if (data.containsKey('to_ulid')) {
      context.handle(
        _toUlidMeta,
        toUlid.isAcceptableOrUnknown(data['to_ulid']!, _toUlidMeta),
      );
    } else if (isInserting) {
      context.missing(_toUlidMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fromUlid, toUlid, position};
  @override
  Relation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Relation(
      fromUlid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_ulid'],
      )!,
      toUlid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_ulid'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $RelationsTable createAlias(String alias) {
    return $RelationsTable(attachedDatabase, alias);
  }
}

class Relation extends DataClass implements Insertable<Relation> {
  final String fromUlid;
  final String toUlid;
  final int position;
  const Relation({
    required this.fromUlid,
    required this.toUlid,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['from_ulid'] = Variable<String>(fromUlid);
    map['to_ulid'] = Variable<String>(toUlid);
    map['position'] = Variable<int>(position);
    return map;
  }

  RelationsCompanion toCompanion(bool nullToAbsent) {
    return RelationsCompanion(
      fromUlid: Value(fromUlid),
      toUlid: Value(toUlid),
      position: Value(position),
    );
  }

  factory Relation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Relation(
      fromUlid: serializer.fromJson<String>(json['fromUlid']),
      toUlid: serializer.fromJson<String>(json['toUlid']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fromUlid': serializer.toJson<String>(fromUlid),
      'toUlid': serializer.toJson<String>(toUlid),
      'position': serializer.toJson<int>(position),
    };
  }

  Relation copyWith({String? fromUlid, String? toUlid, int? position}) =>
      Relation(
        fromUlid: fromUlid ?? this.fromUlid,
        toUlid: toUlid ?? this.toUlid,
        position: position ?? this.position,
      );
  Relation copyWithCompanion(RelationsCompanion data) {
    return Relation(
      fromUlid: data.fromUlid.present ? data.fromUlid.value : this.fromUlid,
      toUlid: data.toUlid.present ? data.toUlid.value : this.toUlid,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Relation(')
          ..write('fromUlid: $fromUlid, ')
          ..write('toUlid: $toUlid, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fromUlid, toUlid, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Relation &&
          other.fromUlid == this.fromUlid &&
          other.toUlid == this.toUlid &&
          other.position == this.position);
}

class RelationsCompanion extends UpdateCompanion<Relation> {
  final Value<String> fromUlid;
  final Value<String> toUlid;
  final Value<int> position;
  final Value<int> rowid;
  const RelationsCompanion({
    this.fromUlid = const Value.absent(),
    this.toUlid = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RelationsCompanion.insert({
    required String fromUlid,
    required String toUlid,
    required int position,
    this.rowid = const Value.absent(),
  }) : fromUlid = Value(fromUlid),
       toUlid = Value(toUlid),
       position = Value(position);
  static Insertable<Relation> custom({
    Expression<String>? fromUlid,
    Expression<String>? toUlid,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fromUlid != null) 'from_ulid': fromUlid,
      if (toUlid != null) 'to_ulid': toUlid,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RelationsCompanion copyWith({
    Value<String>? fromUlid,
    Value<String>? toUlid,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return RelationsCompanion(
      fromUlid: fromUlid ?? this.fromUlid,
      toUlid: toUlid ?? this.toUlid,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fromUlid.present) {
      map['from_ulid'] = Variable<String>(fromUlid.value);
    }
    if (toUlid.present) {
      map['to_ulid'] = Variable<String>(toUlid.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RelationsCompanion(')
          ..write('fromUlid: $fromUlid, ')
          ..write('toUlid: $toUlid, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatabasesTable extends Databases
    with TableInfo<$DatabasesTable, Database> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatabasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaYamlMeta = const VerificationMeta(
    'schemaYaml',
  );
  @override
  late final GeneratedColumn<String> schemaYaml = GeneratedColumn<String>(
    'schema_yaml',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, folderPath, schemaYaml];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'databases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Database> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('schema_yaml')) {
      context.handle(
        _schemaYamlMeta,
        schemaYaml.isAcceptableOrUnknown(data['schema_yaml']!, _schemaYamlMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaYamlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Database map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Database(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      schemaYaml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schema_yaml'],
      )!,
    );
  }

  @override
  $DatabasesTable createAlias(String alias) {
    return $DatabasesTable(attachedDatabase, alias);
  }
}

class Database extends DataClass implements Insertable<Database> {
  final String id;
  final String name;
  final String folderPath;
  final String schemaYaml;
  const Database({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.schemaYaml,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['folder_path'] = Variable<String>(folderPath);
    map['schema_yaml'] = Variable<String>(schemaYaml);
    return map;
  }

  DatabasesCompanion toCompanion(bool nullToAbsent) {
    return DatabasesCompanion(
      id: Value(id),
      name: Value(name),
      folderPath: Value(folderPath),
      schemaYaml: Value(schemaYaml),
    );
  }

  factory Database.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Database(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      schemaYaml: serializer.fromJson<String>(json['schemaYaml']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'folderPath': serializer.toJson<String>(folderPath),
      'schemaYaml': serializer.toJson<String>(schemaYaml),
    };
  }

  Database copyWith({
    String? id,
    String? name,
    String? folderPath,
    String? schemaYaml,
  }) => Database(
    id: id ?? this.id,
    name: name ?? this.name,
    folderPath: folderPath ?? this.folderPath,
    schemaYaml: schemaYaml ?? this.schemaYaml,
  );
  Database copyWithCompanion(DatabasesCompanion data) {
    return Database(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      schemaYaml: data.schemaYaml.present
          ? data.schemaYaml.value
          : this.schemaYaml,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Database(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('folderPath: $folderPath, ')
          ..write('schemaYaml: $schemaYaml')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, folderPath, schemaYaml);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Database &&
          other.id == this.id &&
          other.name == this.name &&
          other.folderPath == this.folderPath &&
          other.schemaYaml == this.schemaYaml);
}

class DatabasesCompanion extends UpdateCompanion<Database> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> folderPath;
  final Value<String> schemaYaml;
  final Value<int> rowid;
  const DatabasesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.schemaYaml = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatabasesCompanion.insert({
    required String id,
    required String name,
    required String folderPath,
    required String schemaYaml,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       folderPath = Value(folderPath),
       schemaYaml = Value(schemaYaml);
  static Insertable<Database> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? folderPath,
    Expression<String>? schemaYaml,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (folderPath != null) 'folder_path': folderPath,
      if (schemaYaml != null) 'schema_yaml': schemaYaml,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatabasesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? folderPath,
    Value<String>? schemaYaml,
    Value<int>? rowid,
  }) {
    return DatabasesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      schemaYaml: schemaYaml ?? this.schemaYaml,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (schemaYaml.present) {
      map['schema_yaml'] = Variable<String>(schemaYaml.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatabasesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('folderPath: $folderPath, ')
          ..write('schemaYaml: $schemaYaml, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$QuillDatabase extends GeneratedDatabase {
  _$QuillDatabase(QueryExecutor e) : super(e);
  $QuillDatabaseManager get managers => $QuillDatabaseManager(this);
  late final $PagesTable pages = $PagesTable(this);
  late final $RelationsTable relations = $RelationsTable(this);
  late final $DatabasesTable databases = $DatabasesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pages,
    relations,
    databases,
  ];
}

typedef $$PagesTableCreateCompanionBuilder =
    PagesCompanion Function({
      required String ulid,
      required String relativePath,
      required String title,
      required String frontmatterJson,
      required String bodyText,
      Value<int> mtimeMs,
      Value<String?> databaseId,
      Value<int> rowid,
    });
typedef $$PagesTableUpdateCompanionBuilder =
    PagesCompanion Function({
      Value<String> ulid,
      Value<String> relativePath,
      Value<String> title,
      Value<String> frontmatterJson,
      Value<String> bodyText,
      Value<int> mtimeMs,
      Value<String?> databaseId,
      Value<int> rowid,
    });

class $$PagesTableFilterComposer
    extends Composer<_$QuillDatabase, $PagesTable> {
  $$PagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frontmatterJson => $composableBuilder(
    column: $table.frontmatterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get databaseId => $composableBuilder(
    column: $table.databaseId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PagesTableOrderingComposer
    extends Composer<_$QuillDatabase, $PagesTable> {
  $$PagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ulid => $composableBuilder(
    column: $table.ulid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frontmatterJson => $composableBuilder(
    column: $table.frontmatterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get databaseId => $composableBuilder(
    column: $table.databaseId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PagesTableAnnotationComposer
    extends Composer<_$QuillDatabase, $PagesTable> {
  $$PagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ulid =>
      $composableBuilder(column: $table.ulid, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get frontmatterJson => $composableBuilder(
    column: $table.frontmatterJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyText =>
      $composableBuilder(column: $table.bodyText, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<String> get databaseId => $composableBuilder(
    column: $table.databaseId,
    builder: (column) => column,
  );
}

class $$PagesTableTableManager
    extends
        RootTableManager<
          _$QuillDatabase,
          $PagesTable,
          Page,
          $$PagesTableFilterComposer,
          $$PagesTableOrderingComposer,
          $$PagesTableAnnotationComposer,
          $$PagesTableCreateCompanionBuilder,
          $$PagesTableUpdateCompanionBuilder,
          (Page, BaseReferences<_$QuillDatabase, $PagesTable, Page>),
          Page,
          PrefetchHooks Function()
        > {
  $$PagesTableTableManager(_$QuillDatabase db, $PagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ulid = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> frontmatterJson = const Value.absent(),
                Value<String> bodyText = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<String?> databaseId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PagesCompanion(
                ulid: ulid,
                relativePath: relativePath,
                title: title,
                frontmatterJson: frontmatterJson,
                bodyText: bodyText,
                mtimeMs: mtimeMs,
                databaseId: databaseId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ulid,
                required String relativePath,
                required String title,
                required String frontmatterJson,
                required String bodyText,
                Value<int> mtimeMs = const Value.absent(),
                Value<String?> databaseId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PagesCompanion.insert(
                ulid: ulid,
                relativePath: relativePath,
                title: title,
                frontmatterJson: frontmatterJson,
                bodyText: bodyText,
                mtimeMs: mtimeMs,
                databaseId: databaseId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PagesTableProcessedTableManager =
    ProcessedTableManager<
      _$QuillDatabase,
      $PagesTable,
      Page,
      $$PagesTableFilterComposer,
      $$PagesTableOrderingComposer,
      $$PagesTableAnnotationComposer,
      $$PagesTableCreateCompanionBuilder,
      $$PagesTableUpdateCompanionBuilder,
      (Page, BaseReferences<_$QuillDatabase, $PagesTable, Page>),
      Page,
      PrefetchHooks Function()
    >;
typedef $$RelationsTableCreateCompanionBuilder =
    RelationsCompanion Function({
      required String fromUlid,
      required String toUlid,
      required int position,
      Value<int> rowid,
    });
typedef $$RelationsTableUpdateCompanionBuilder =
    RelationsCompanion Function({
      Value<String> fromUlid,
      Value<String> toUlid,
      Value<int> position,
      Value<int> rowid,
    });

class $$RelationsTableFilterComposer
    extends Composer<_$QuillDatabase, $RelationsTable> {
  $$RelationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fromUlid => $composableBuilder(
    column: $table.fromUlid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toUlid => $composableBuilder(
    column: $table.toUlid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RelationsTableOrderingComposer
    extends Composer<_$QuillDatabase, $RelationsTable> {
  $$RelationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fromUlid => $composableBuilder(
    column: $table.fromUlid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toUlid => $composableBuilder(
    column: $table.toUlid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RelationsTableAnnotationComposer
    extends Composer<_$QuillDatabase, $RelationsTable> {
  $$RelationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fromUlid =>
      $composableBuilder(column: $table.fromUlid, builder: (column) => column);

  GeneratedColumn<String> get toUlid =>
      $composableBuilder(column: $table.toUlid, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$RelationsTableTableManager
    extends
        RootTableManager<
          _$QuillDatabase,
          $RelationsTable,
          Relation,
          $$RelationsTableFilterComposer,
          $$RelationsTableOrderingComposer,
          $$RelationsTableAnnotationComposer,
          $$RelationsTableCreateCompanionBuilder,
          $$RelationsTableUpdateCompanionBuilder,
          (
            Relation,
            BaseReferences<_$QuillDatabase, $RelationsTable, Relation>,
          ),
          Relation,
          PrefetchHooks Function()
        > {
  $$RelationsTableTableManager(_$QuillDatabase db, $RelationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RelationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RelationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RelationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fromUlid = const Value.absent(),
                Value<String> toUlid = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RelationsCompanion(
                fromUlid: fromUlid,
                toUlid: toUlid,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fromUlid,
                required String toUlid,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => RelationsCompanion.insert(
                fromUlid: fromUlid,
                toUlid: toUlid,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RelationsTableProcessedTableManager =
    ProcessedTableManager<
      _$QuillDatabase,
      $RelationsTable,
      Relation,
      $$RelationsTableFilterComposer,
      $$RelationsTableOrderingComposer,
      $$RelationsTableAnnotationComposer,
      $$RelationsTableCreateCompanionBuilder,
      $$RelationsTableUpdateCompanionBuilder,
      (Relation, BaseReferences<_$QuillDatabase, $RelationsTable, Relation>),
      Relation,
      PrefetchHooks Function()
    >;
typedef $$DatabasesTableCreateCompanionBuilder =
    DatabasesCompanion Function({
      required String id,
      required String name,
      required String folderPath,
      required String schemaYaml,
      Value<int> rowid,
    });
typedef $$DatabasesTableUpdateCompanionBuilder =
    DatabasesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> folderPath,
      Value<String> schemaYaml,
      Value<int> rowid,
    });

class $$DatabasesTableFilterComposer
    extends Composer<_$QuillDatabase, $DatabasesTable> {
  $$DatabasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemaYaml => $composableBuilder(
    column: $table.schemaYaml,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatabasesTableOrderingComposer
    extends Composer<_$QuillDatabase, $DatabasesTable> {
  $$DatabasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemaYaml => $composableBuilder(
    column: $table.schemaYaml,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatabasesTableAnnotationComposer
    extends Composer<_$QuillDatabase, $DatabasesTable> {
  $$DatabasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schemaYaml => $composableBuilder(
    column: $table.schemaYaml,
    builder: (column) => column,
  );
}

class $$DatabasesTableTableManager
    extends
        RootTableManager<
          _$QuillDatabase,
          $DatabasesTable,
          Database,
          $$DatabasesTableFilterComposer,
          $$DatabasesTableOrderingComposer,
          $$DatabasesTableAnnotationComposer,
          $$DatabasesTableCreateCompanionBuilder,
          $$DatabasesTableUpdateCompanionBuilder,
          (
            Database,
            BaseReferences<_$QuillDatabase, $DatabasesTable, Database>,
          ),
          Database,
          PrefetchHooks Function()
        > {
  $$DatabasesTableTableManager(_$QuillDatabase db, $DatabasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatabasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatabasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatabasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> schemaYaml = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatabasesCompanion(
                id: id,
                name: name,
                folderPath: folderPath,
                schemaYaml: schemaYaml,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String folderPath,
                required String schemaYaml,
                Value<int> rowid = const Value.absent(),
              }) => DatabasesCompanion.insert(
                id: id,
                name: name,
                folderPath: folderPath,
                schemaYaml: schemaYaml,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DatabasesTableProcessedTableManager =
    ProcessedTableManager<
      _$QuillDatabase,
      $DatabasesTable,
      Database,
      $$DatabasesTableFilterComposer,
      $$DatabasesTableOrderingComposer,
      $$DatabasesTableAnnotationComposer,
      $$DatabasesTableCreateCompanionBuilder,
      $$DatabasesTableUpdateCompanionBuilder,
      (Database, BaseReferences<_$QuillDatabase, $DatabasesTable, Database>),
      Database,
      PrefetchHooks Function()
    >;

class $QuillDatabaseManager {
  final _$QuillDatabase _db;
  $QuillDatabaseManager(this._db);
  $$PagesTableTableManager get pages =>
      $$PagesTableTableManager(_db, _db.pages);
  $$RelationsTableTableManager get relations =>
      $$RelationsTableTableManager(_db, _db.relations);
  $$DatabasesTableTableManager get databases =>
      $$DatabasesTableTableManager(_db, _db.databases);
}
