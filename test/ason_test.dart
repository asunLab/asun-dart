import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:ason/ason.dart';

class User implements AsonSchema {
  final int id;
  final String name;
  final bool active;

  User({required this.id, required this.name, required this.active});

  @override List<String> get fieldNames => ['id', 'name', 'active'];
  @override List<String?> get fieldTypes => ['int', 'str', 'bool'];
  @override List<dynamic> get fieldValues => [id, name, active];

  factory User.fromMap(Map<String, dynamic> m) => User(
    id: m['id'] as int, name: m['name'] as String, active: m['active'] as bool,
  );

  @override bool operator ==(Object o) => o is User && id == o.id && name == o.name && active == o.active;
  @override int get hashCode => Object.hash(id, name, active);
}

class Dept implements AsonSchema {
  final String title;
  Dept({required this.title});
  @override List<String> get fieldNames => ['title'];
  @override List<String?> get fieldTypes => ['str'];
  @override List<dynamic> get fieldValues => [title];
  factory Dept.fromMap(Map<String, dynamic> m) => Dept(title: m['title'] as String);
  @override bool operator ==(Object o) => o is Dept && title == o.title;
  @override int get hashCode => title.hashCode;
}

class Employee implements AsonSchema {
  final String name;
  final Dept dept;
  final bool active;

  Employee({required this.name, required this.dept, required this.active});
  @override List<String> get fieldNames => ['name', 'dept', 'active'];
  @override List<String?> get fieldTypes => ['str', null, 'bool'];
  @override List<dynamic> get fieldValues => [name, dept, active];

  factory Employee.fromMap(Map<String, dynamic> m) {
    final d = m['dept'];
    final dept = d is Map<String, dynamic>
        ? Dept.fromMap(d) : Dept(title: (d is List ? d.first.toString() : d.toString()));
    return Employee(name: m['name'] as String, dept: dept, active: m['active'] as bool);
  }
  @override bool operator ==(Object o) => o is Employee && name == o.name && dept == o.dept;
  @override int get hashCode => Object.hash(name, dept);
}

void main() {
  group('Encode', () {
    test('single struct unannotated', () {
      final u = User(id: 1, name: 'Alice', active: true);
      expect(encode(u), '{id,name,active}:(1,Alice,true)');
    });

    test('single struct typed', () {
      final u = User(id: 1, name: 'Alice', active: true);
      expect(encodeTyped(u), '{id:int,name:str,active:bool}:(1,Alice,true)');
    });

    test('vec of structs', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      expect(encode(users), '[{id,name,active}]:(1,Alice,true),(2,Bob,false)');
    });

    test('vec typed', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      expect(encodeTyped(users), '[{id:int,name:str,active:bool}]:(1,Alice,true),(2,Bob,false)');
    });

    test('nested struct', () {
      final e = Employee(name: 'Alice', dept: Dept(title: 'Engineering'), active: true);
      expect(encode(e), '{name,dept:{title},active}:(Alice,(Engineering),true)');
    });

    test('nested struct typed', () {
      final e = Employee(name: 'Alice', dept: Dept(title: 'Engineering'), active: true);
      expect(encodeTyped(e), '{name:str,dept:{title:str},active:bool}:(Alice,(Engineering),true)');
    });

    test('escaped string', () {
      final u = User(id: 1, name: 'hello, world', active: true);
      final s = encode(u);
      expect(s.contains('"'), true);
    });

    test('float formatting', () {
      final buf = StringBuffer();
      // Use the public API to test float encoding
      final m = <String, dynamic>{'v': 95.5};
      // Encode a map-like value
      final result = encode([_FloatStruct(v: 95.5)]);
      expect(result.contains('95.5'), true);
    });

    test('negative numbers', () {
      final result = encode([_NumStruct(a: -42, b: -3.15)]);
      expect(result.contains('-42'), true);
      expect(result.contains('-3.15'), true);
    });
  });

  group('Decode', () {
    test('single struct', () {
      final u = decodeWith('{id,name,active}:(1,Alice,true)', User.fromMap);
      expect(u.id, 1);
      expect(u.name, 'Alice');
      expect(u.active, true);
    });

    test('typed schema', () {
      final u = decodeWith('{id:int,name:str,active:bool}:(1,Alice,true)', User.fromMap);
      expect(u.id, 1);
      expect(u.name, 'Alice');
      expect(u.active, true);
    });

    test('vec of structs', () {
      final users = decodeListWith(
        '[{id,name,active}]:(1,Alice,true),(2,Bob,false)',
        User.fromMap,
      );
      expect(users.length, 2);
      expect(users[0].name, 'Alice');
      expect(users[1].name, 'Bob');
    });

    test('multiline', () {
      final users = decodeListWith(
        '[{id:int,name:str,active:bool}]:\n  (1, Alice, true),\n  (2, Bob, false)',
        User.fromMap,
      );
      expect(users.length, 2);
    });

    test('quoted string', () {
      final u = decodeWith('{id,name,active}:(1,"Carol Smith",true)', User.fromMap);
      expect(u.name, 'Carol Smith');
    });

    test('optional field with value', () {
      final m = decode('{id,label}:(1,hello)') as Map<String, dynamic>;
      expect(m['id'], 1);
      expect(m['label'], 'hello');
    });

    test('optional field with null', () {
      final m = decode('{id,label}:(2,)') as Map<String, dynamic>;
      expect(m['id'], 2);
      expect(m['label'], null);
    });

    test('array field', () {
      final m = decode('{name,tags}:(Alice,[rust,go])') as Map<String, dynamic>;
      expect(m['tags'], ['rust', 'go']);
    });

    test('map field', () {
      final m = decode('{name,attrs}:(Alice,[(age,30),(score,95)])') as Map<String, dynamic>;
      expect(m['name'], 'Alice');
    });

    test('nested struct', () {
      final m = decode('{name,dept:{title}}:(Alice,(Manager))') as Map<String, dynamic>;
      expect(m['name'], 'Alice');
    });

    test('float field', () {
      final m = decode('{id,value}:(1,95.5)') as Map<String, dynamic>;
      expect(m['value'], 95.5);
    });

    test('negative number', () {
      final m = decode('{a,b}:(-42,-3.15)') as Map<String, dynamic>;
      expect(m['a'], -42);
      expect(m['b'], -3.15);
    });

    test('comment stripping', () {
      final m = decode('/* users */ {id,name,active}:(1,Alice,true)') as Map<String, dynamic>;
      expect(m['id'], 1);
    });

    test('trailing comma', () {
      final users = decodeListWith(
        '[{id,name,active}]:(1,Alice,true),(2,Bob,false),',
        User.fromMap,
      );
      expect(users.length, 2);
    });
  });

  group('Roundtrip', () {
    test('single struct', () {
      final u = User(id: 42, name: 'Bob', active: false);
      final s = encode(u);
      final u2 = decodeWith(s, User.fromMap);
      expect(u, u2);
    });

    test('typed roundtrip', () {
      final u = User(id: 42, name: 'Bob', active: false);
      final s = encodeTyped(u);
      final u2 = decodeWith(s, User.fromMap);
      expect(u, u2);
    });

    test('nested struct', () {
      final e = Employee(name: 'Alice', dept: Dept(title: 'Eng'), active: true);
      final s = encode(e);
      final e2 = decodeWith(s, Employee.fromMap);
      expect(e, e2);
    });
  });

  group('Binary', () {
    test('encode/decode struct', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final bin = encodeBinary(u);
      final u2 = decodeBinaryWith(
        bin, ['id', 'name', 'active'],
        [FieldType.int_, FieldType.string_, FieldType.bool_],
        User.fromMap,
      );
      expect(u, u2);
    });

    test('encode/decode vec', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      final bin = encodeBinary(users);
      final users2 = decodeBinaryListWith(
        bin, ['id', 'name', 'active'],
        [FieldType.int_, FieldType.string_, FieldType.bool_],
        User.fromMap,
      );
      expect(users2.length, 2);
      expect(users[0], users2[0]);
      expect(users[1], users2[1]);
    });

    test('binary smaller than JSON', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final bin = encodeBinary(u);
      final json = '{"id":1,"name":"Alice","active":true}';
      expect(bin.length < json.length, true);
    });
  });

  group('Pretty', () {
    test('simple struct', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final p = encodePretty(u);
      expect(p, '{id, name, active}:(1, Alice, true)');
    });

    test('typed simple', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final p = encodePrettyTyped(u);
      expect(p, '{id:int, name:str, active:bool}:(1, Alice, true)');
    });

    test('array has newlines', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      final p = encodePretty(users);
      expect(p.contains('\n'), true);
    });

    test('pretty roundtrip', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final p = encodePretty(u);
      final u2 = decodeWith(p, User.fromMap);
      expect(u, u2);
    });
  });
}

// Helper structs for testing
class _FloatStruct implements AsonSchema {
  final double v;
  _FloatStruct({required this.v});
  @override List<String> get fieldNames => ['v'];
  @override List<String?> get fieldTypes => ['float'];
  @override List<dynamic> get fieldValues => [v];
}

class _NumStruct implements AsonSchema {
  final int a;
  final double b;
  _NumStruct({required this.a, required this.b});
  @override List<String> get fieldNames => ['a', 'b'];
  @override List<String?> get fieldTypes => ['int', 'float'];
  @override List<dynamic> get fieldValues => [a, b];
}
