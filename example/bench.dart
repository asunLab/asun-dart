import 'dart:convert';
import 'dart:typed_data';
import 'package:ason/ason.dart';

// ===========================================================================
// Benchmark data types
// ===========================================================================

class User implements AsonSchema {
  final int id;
  final String name;
  final String email;
  final int age;
  final double score;
  final bool active;
  final String role;
  final String city;

  User({required this.id, required this.name, required this.email,
        required this.age, required this.score, required this.active,
        required this.role, required this.city});

  @override List<String> get fieldNames => ['id', 'name', 'email', 'age', 'score', 'active', 'role', 'city'];
  @override List<String?> get fieldTypes => ['int', 'str', 'str', 'int', 'float', 'bool', 'str', 'str'];
  @override List<dynamic> get fieldValues => [id, name, email, age, score, active, role, city];

  factory User.fromMap(Map<String, dynamic> m) => User(
    id: m['id'] as int, name: m['name'] as String, email: m['email'] as String,
    age: m['age'] as int, score: (m['score'] as num).toDouble(),
    active: m['active'] as bool, role: m['role'] as String, city: m['city'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'email': email, 'age': age,
    'score': score, 'active': active, 'role': role, 'city': city,
  };

  @override bool operator ==(Object o) => o is User && id == o.id && name == o.name;
  @override int get hashCode => Object.hash(id, name);
}

class Task implements AsonSchema {
  final int id;
  final String title;
  final int priority;
  final bool done;
  final double hours;

  Task({required this.id, required this.title, required this.priority,
        required this.done, required this.hours});

  @override List<String> get fieldNames => ['id', 'title', 'priority', 'done', 'hours'];
  @override List<String?> get fieldTypes => ['int', 'str', 'int', 'bool', 'float'];
  @override List<dynamic> get fieldValues => [id, title, priority, done, hours];

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'priority': priority, 'done': done, 'hours': hours,
  };
}

class Project implements AsonSchema {
  final String name;
  final double budget;
  final bool active;
  final List<Task> tasks;

  Project({required this.name, required this.budget, required this.active, required this.tasks});

  @override List<String> get fieldNames => ['name', 'budget', 'active', 'tasks'];
  @override List<String?> get fieldTypes => ['str', 'float', 'bool', null];
  @override List<dynamic> get fieldValues => [name, budget, active, tasks];

  Map<String, dynamic> toJson() => {
    'name': name, 'budget': budget, 'active': active,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
}

class Team implements AsonSchema {
  final String name;
  final String lead;
  final int size;
  final List<Project> projects;

  Team({required this.name, required this.lead, required this.size, required this.projects});

  @override List<String> get fieldNames => ['name', 'lead', 'size', 'projects'];
  @override List<String?> get fieldTypes => ['str', 'str', 'int', null];
  @override List<dynamic> get fieldValues => [name, lead, size, projects];

  Map<String, dynamic> toJson() => {
    'name': name, 'lead': lead, 'size': size,
    'projects': projects.map((p) => p.toJson()).toList(),
  };
}

class Division implements AsonSchema {
  final String name;
  final String location;
  final int headcount;
  final List<Team> teams;

  Division({required this.name, required this.location, required this.headcount, required this.teams});

  @override List<String> get fieldNames => ['name', 'location', 'headcount', 'teams'];
  @override List<String?> get fieldTypes => ['str', 'str', 'int', null];
  @override List<dynamic> get fieldValues => [name, location, headcount, teams];

  Map<String, dynamic> toJson() => {
    'name': name, 'location': location, 'headcount': headcount,
    'teams': teams.map((t) => t.toJson()).toList(),
  };
}

class Company implements AsonSchema {
  final String name;
  final int founded;
  final double revenueM;
  final bool public_;
  final List<Division> divisions;
  final List<String> tags;

  Company({required this.name, required this.founded, required this.revenueM,
           required this.public_, required this.divisions, required this.tags});

  @override List<String> get fieldNames => ['name', 'founded', 'revenue_m', 'public', 'divisions', 'tags'];
  @override List<String?> get fieldTypes => ['str', 'int', 'float', 'bool', null, '[str]'];
  @override List<dynamic> get fieldValues => [name, founded, revenueM, public_, divisions, tags];

  Map<String, dynamic> toJson() => {
    'name': name, 'founded': founded, 'revenue_m': revenueM, 'public': public_,
    'divisions': divisions.map((d) => d.toJson()).toList(), 'tags': tags,
  };
}

// ===========================================================================
// Data generators
// ===========================================================================

List<User> generateUsers(int n) {
  const names = ['Alice', 'Bob', 'Carol', 'David', 'Eve', 'Frank', 'Grace', 'Hank'];
  const roles = ['engineer', 'designer', 'manager', 'analyst'];
  const cities = ['NYC', 'LA', 'Chicago', 'Houston', 'Phoenix'];
  return List.generate(n, (i) => User(
    id: i, name: names[i % names.length],
    email: '${names[i % names.length].toLowerCase()}@example.com',
    age: 25 + (i % 40), score: 50.0 + (i % 50) + 0.5,
    active: i % 3 != 0, role: roles[i % roles.length], city: cities[i % cities.length],
  ));
}

List<Company> generateCompanies(int n) {
  const locations = ['NYC', 'London', 'Tokyo', 'Berlin'];
  const leads = ['Alice', 'Bob', 'Carol', 'David'];
  return List.generate(n, (i) => Company(
    name: 'Corp_$i', founded: 1990 + (i % 35), revenueM: 10.0 + i * 5.5,
    public_: i % 2 == 0,
    divisions: List.generate(2, (d) => Division(
      name: 'Div_${i}_$d', location: locations[d % 4], headcount: 50 + d * 20,
      teams: List.generate(2, (t) => Team(
        name: 'Team_${i}_${d}_$t', lead: leads[t % 4], size: 5 + t * 2,
        projects: List.generate(3, (p) => Project(
          name: 'Proj_${t}_$p', budget: 100.0 + p * 50.5, active: p % 2 == 0,
          tasks: List.generate(4, (tk) => Task(
            id: i * 100 + d * 10 + t * 5 + tk,
            title: 'Task_$tk', priority: tk % 3 + 1,
            done: tk % 2 == 0, hours: 2.0 + tk * 1.5,
          )),
        )),
      )),
    )),
    tags: ['enterprise', 'tech', 'sector_${i % 5}'],
  ));
}

// ===========================================================================
// Benchmark helpers
// ===========================================================================

class BenchResult {
  final String name;
  final double jsonSerMs, asonSerMs, jsonDeMs, asonDeMs;
  final int jsonBytes, asonBytes;
  final double? binSerMs, binDeMs;
  final int? binBytes;

  BenchResult({required this.name, required this.jsonSerMs, required this.asonSerMs,
               required this.jsonDeMs, required this.asonDeMs,
               required this.jsonBytes, required this.asonBytes,
               this.binSerMs, this.binDeMs, this.binBytes});

  void print_() {
    final serRatio = jsonSerMs / asonSerMs;
    final deRatio = jsonDeMs / asonDeMs;
    final saving = (1.0 - asonBytes / jsonBytes) * 100.0;

    print('  $name');
    print('    Serialize:   JSON ${jsonSerMs.toStringAsFixed(2).padLeft(8)}ms | ASON ${asonSerMs.toStringAsFixed(2).padLeft(8)}ms | ratio ${serRatio.toStringAsFixed(2)}x ${serRatio >= 1.0 ? "✓ ASON faster" : ""}');
    print('    Deserialize: JSON ${jsonDeMs.toStringAsFixed(2).padLeft(8)}ms | ASON ${asonDeMs.toStringAsFixed(2).padLeft(8)}ms | ratio ${deRatio.toStringAsFixed(2)}x ${deRatio >= 1.0 ? "✓ ASON faster" : ""}');
    print('    Size:        JSON ${jsonBytes.toString().padLeft(8)} B | ASON ${asonBytes.toString().padLeft(8)} B | saving ${saving.toStringAsFixed(0)}%');
    if (binSerMs != null && binBytes != null) {
      final binSerRatio = jsonSerMs / binSerMs!;
      final binSaving = (1.0 - binBytes! / jsonBytes) * 100.0;
      if (binDeMs != null) {
        final binDeRatio = jsonDeMs / binDeMs!;
        print('    BIN Ser: ${binSerMs!.toStringAsFixed(2).padLeft(8)}ms (${binSerRatio.toStringAsFixed(1)}x) | BIN De: ${binDeMs!.toStringAsFixed(2).padLeft(8)}ms (${binDeRatio.toStringAsFixed(1)}x) | BIN: ${binBytes!.toString().padLeft(8)} B (${binSaving.toStringAsFixed(0)}%)');
      } else {
        print('    BIN Ser: ${binSerMs!.toStringAsFixed(2).padLeft(8)}ms (${binSerRatio.toStringAsFixed(1)}x) | BIN: ${binBytes!.toString().padLeft(8)} B (${binSaving.toStringAsFixed(0)}%)');
      }
    }
  }
}

String _formatBytes(int b) {
  if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
  if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '$b B';
}

// ===========================================================================
// Benchmarks
// ===========================================================================

BenchResult benchFlat(int count, int iterations) {
  final users = generateUsers(count);
  final jsonList = users.map((u) => u.toJson()).toList();

  // JSON serialize
  String jsonStr = '';
  final sw1 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    jsonStr = jsonEncode(jsonList);
  }
  sw1.stop();

  // ASON serialize
  String asonStr = '';
  final sw2 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    asonStr = encode(users);
  }
  sw2.stop();

  // JSON deserialize
  final sw3 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    jsonDecode(jsonStr);
  }
  sw3.stop();

  // ASON deserialize
  final sw4 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    decode(asonStr);
  }
  sw4.stop();

  // BIN
  Uint8List binBuf = Uint8List(0);
  final sw5 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    binBuf = encodeBinary(users);
  }
  sw5.stop();

  return BenchResult(
    name: 'Flat struct × $count (8 fields)',
    jsonSerMs: sw1.elapsedMicroseconds / 1000,
    asonSerMs: sw2.elapsedMicroseconds / 1000,
    jsonDeMs: sw3.elapsedMicroseconds / 1000,
    asonDeMs: sw4.elapsedMicroseconds / 1000,
    jsonBytes: jsonStr.length,
    asonBytes: asonStr.length,
    binSerMs: sw5.elapsedMicroseconds / 1000,
    binBytes: binBuf.length,
  );
}

BenchResult benchDeep(int count, int iterations) {
  final companies = generateCompanies(count);
  final jsonList = companies.map((c) => c.toJson()).toList();

  String jsonStr = '';
  final sw1 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    jsonStr = jsonEncode(jsonList);
  }
  sw1.stop();

  String asonStr = '';
  final sw2 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    asonStr = encode(companies);
  }
  sw2.stop();

  final sw3 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    jsonDecode(jsonStr);
  }
  sw3.stop();

  final sw4 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    decode(asonStr);
  }
  sw4.stop();

  Uint8List binBuf = Uint8List(0);
  final sw5 = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    binBuf = encodeBinary(companies);
  }
  sw5.stop();

  return BenchResult(
    name: '5-level deep × $count (Company>Division>Team>Project>Task)',
    jsonSerMs: sw1.elapsedMicroseconds / 1000,
    asonSerMs: sw2.elapsedMicroseconds / 1000,
    jsonDeMs: sw3.elapsedMicroseconds / 1000,
    asonDeMs: sw4.elapsedMicroseconds / 1000,
    jsonBytes: jsonStr.length,
    asonBytes: asonStr.length,
    binSerMs: sw5.elapsedMicroseconds / 1000,
    binBytes: binBuf.length,
  );
}

// ===========================================================================
// Main
// ===========================================================================

void main() {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║          ASON-Dart vs JSON Comprehensive Benchmark          ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');

  const iterations = 100;
  print('Iterations per test: $iterations\n');

  // Section 1: Flat struct
  print('┌─────────────────────────────────────────────┐');
  print('│  Section 1: Flat Struct (schema-driven vec) │');
  print('└─────────────────────────────────────────────┘');

  for (final count in [100, 500, 1000, 5000]) {
    final r = benchFlat(count, iterations);
    r.print_();
    print('');
  }

  // Section 2: 5-level deep
  print('┌──────────────────────────────────────────────────────────┐');
  print('│  Section 2: 5-Level Deep Nesting (Company hierarchy)    │');
  print('└──────────────────────────────────────────────────────────┘');

  for (final count in [10, 50, 100]) {
    final r = benchDeep(count, iterations);
    r.print_();
    print('');
  }

  // Section 3: Large payload
  print('┌──────────────────────────────────────────────┐');
  print('│  Section 3: Large Payload (10k records)      │');
  print('└──────────────────────────────────────────────┘');

  final rLarge = benchFlat(10000, 10);
  print('  (10 iterations for large payload)');
  rLarge.print_();
  print('');

  // Section 4: Single struct roundtrip
  print('┌──────────────────────────────────────────────┐');
  print('│  Section 4: Single Struct Roundtrip (10000x) │');
  print('└──────────────────────────────────────────────┘');

  final user = User(
    id: 1, name: 'Alice', email: 'alice@example.com',
    age: 30, score: 95.5, active: true, role: 'engineer', city: 'NYC',
  );

  final sw1 = Stopwatch()..start();
  for (int i = 0; i < 10000; i++) {
    final s = encode(user);
    decode(s);
  }
  sw1.stop();

  final sw2 = Stopwatch()..start();
  for (int i = 0; i < 10000; i++) {
    final s = jsonEncode(user.toJson());
    jsonDecode(s);
  }
  sw2.stop();

  final asonMs = sw1.elapsedMicroseconds / 1000;
  final jsonMs = sw2.elapsedMicroseconds / 1000;
  print('  Flat:  ASON ${asonMs.toStringAsFixed(2).padLeft(8)}ms | JSON ${jsonMs.toStringAsFixed(2).padLeft(8)}ms | ratio ${(jsonMs / asonMs).toStringAsFixed(2)}x');

  // Section 5: Size summary
  print('\n┌──────────────────────────────────────────────┐');
  print('│  Section 5: Size Comparison Summary          │');
  print('└──────────────────────────────────────────────┘');

  final users1k = generateUsers(1000);
  final asonSize = encode(users1k).length;
  final jsonSize = jsonEncode(users1k.map((u) => u.toJson()).toList()).length;
  final binSize = encodeBinary(users1k).length;

  print('  1000 flat structs:');
  print('    JSON:      ${_formatBytes(jsonSize)}');
  print('    ASON text: ${_formatBytes(asonSize)} (${((1.0 - asonSize / jsonSize) * 100).toStringAsFixed(0)}% smaller)');
  print('    ASON bin:  ${_formatBytes(binSize)} (${((1.0 - binSize / jsonSize) * 100).toStringAsFixed(0)}% smaller)');

  print('\n╔══════════════════════════════════════════════════════════════╗');
  print('║                    Benchmark Complete                        ║');
  print('╚══════════════════════════════════════════════════════════════╝');
}
