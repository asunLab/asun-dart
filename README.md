# ason

[![Pub Version](https://img.shields.io/pub/v/ason.svg)](https://pub.dev/packages/ason)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A high-performance [ASON](https://github.com/athxx/ason) (Array-Schema Object Notation) encoder/decoder for Dart — a token-efficient, schema-driven data format designed for LLM interactions and large-scale data transmission.

[中文文档](README_CN.md)

## What is ASON?

ASON separates **schema** from **data**, eliminating repetitive keys found in JSON. The schema is declared once, and data rows carry only values:

```text
JSON (100 tokens):
{"users":[{"id":1,"name":"Alice","active":true},{"id":2,"name":"Bob","active":false}]}

ASON (~35 tokens, 65% saving):
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

| Aspect              | JSON         | ASON             |
| ------------------- | ------------ | ---------------- |
| Token efficiency    | 100%         | 30–70% ✓         |
| Key repetition      | Every object | Declared once ✓  |
| Human readable      | Yes          | Yes ✓            |
| Nested structs      | ✓            | ✓                |
| Type annotations    | No           | Optional ✓       |
| Serialization speed | 1x           | **~1.7x faster** ✓ |
| Data size           | 100%         | **40–55%** ✓     |

## Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ason: ^0.1.0
```

### Serialize & Deserialize a Struct

```dart
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
}

void main() {
  final user = User(id: 1, name: 'Alice', active: true);

  // Serialize
  final s = encode(user);
  assert(s == '{id,name,active}:(1,Alice,true)');

  // Deserialize
  final user2 = decodeWith(s, User.fromMap);
  assert(user2.id == 1 && user2.name == 'Alice');
}
```

### Serialize with Type Annotations

Use `encodeTyped` to output a type-annotated schema — useful for documentation, LLM prompts, and cross-language exchange:

```dart
final s = encodeTyped(user);
// Output: {id:int,name:str,active:bool}:(1,Alice,true)

// Deserializer accepts both annotated and unannotated schemas
final user2 = decodeWith(s, User.fromMap);
```

### Serialize & Deserialize a List (Schema-Driven)

For `List<AsonSchema>`, ASON writes the schema **once** and emits each element as a compact tuple — the key advantage over JSON:

```dart
final users = [
  User(id: 1, name: 'Alice', active: true),
  User(id: 2, name: 'Bob', active: false),
];

// Unannotated schema
final s = encode(users);
// Output: [{id,name,active}]:(1,Alice,true),(2,Bob,false)

// Type-annotated schema
final s2 = encodeTyped(users);
// Output: [{id:int,name:str,active:bool}]:(1,Alice,true),(2,Bob,false)

// Deserialize — accepts both forms
final users2 = decodeListWith(s, User.fromMap);
```

## Supported Types

| Type           | ASON Representation   | Example                  |
| -------------- | --------------------- | ------------------------ |
| int            | Plain number          | `42`, `-100`             |
| double         | Decimal number        | `3.14`, `-0.5`           |
| bool           | Literal               | `true`, `false`          |
| String         | Unquoted or quoted    | `Alice`, `"Carol Smith"` |
| null           | Empty (blank)         | _(blank)_ for null       |
| List           | `[v1,v2,v3]`          | `[rust,go,python]`       |
| Map            | `[(k1,v1),(k2,v2)]`   | `[(age,30),(score,95)]`  |
| Nested struct  | `(field1,field2)`     | `(Engineering,500000)`   |

### Nested Structs

```dart
class Dept implements AsonSchema {
  final String title;
  // ...fieldNames/fieldTypes/fieldValues
}

class Employee implements AsonSchema {
  final String name;
  final Dept dept;
  // ...fieldNames/fieldTypes/fieldValues
}

// Schema reflects nesting:
// {name:str,dept:{title:str}}:(Alice,(Engineering))
```

### Optional Fields

```text
// With value:   {id,label}:(1,hello)
// With null:    {id,label}:(1,)
```

### Arrays & Maps

```text
// Array field:
{name,tags}:(Alice,[rust,go,python])

// Map field:
{name,attrs}:(Alice,[(age,30),(score,95)])
```

### Type Annotations (Optional)

ASON schema supports **optional** type annotations. Both forms are fully equivalent — the deserializer handles them identically:

```text
// Without annotations (default output of encode)
{id,name,salary,active}:(1,Alice,5000.50,true)

// With annotations (output of encodeTyped)
{id:int,name:str,salary:float,active:bool}:(1,Alice,5000.50,true)
```

Annotations are **purely decorative metadata** — they do not affect parsing or deserialization behavior.

**When to use annotations:**

- LLM prompts — helps models understand and generate correct data
- API documentation — self-describing schema without external docs
- Cross-language exchange — eliminates type ambiguity (is `42` an int or double?)
- Debugging — see data types at a glance

### Comments

```text
/* user list */
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

### Multiline Format

```text
[{id:int, name:str, active:bool}]:
  (1, Alice, true),
  (2, Bob, false),
  (3, "Carol Smith", true)
```

## API Reference

### Text Format

| Function                    | Description                                                  |
| --------------------------- | ------------------------------------------------------------ |
| `encode(value)`             | Serialize → unannotated schema `{id,name}:`                  |
| `encodeTyped(value)`        | Serialize → annotated schema `{id:int,name:str}:`            |
| `decode(input)`             | Deserialize to dynamic Map/List (both schema forms)          |
| `decodeWith(input, factory)` | Deserialize to typed object using factory                    |
| `decodeListWith(input, factory)` | Deserialize to typed list using factory                 |

### Pretty Format

| Function                     | Description                                   |
| ---------------------------- | --------------------------------------------- |
| `encodePretty(value)`        | Pretty-formatted ASON (unannotated)           |
| `encodePrettyTyped(value)`   | Pretty-formatted ASON (annotated)             |

### Binary Format

| Function                                        | Description                          |
| ----------------------------------------------- | ------------------------------------ |
| `encodeBinary(value)`                           | Encode to compact binary bytes       |
| `decodeBinaryWith(data, fields, types, factory)` | Decode binary to typed object       |
| `decodeBinaryListWith(data, fields, types, factory)` | Decode binary to typed list    |

## Performance

Benchmarked on Linux, Dart VM, comparing ASON against `dart:convert` JSON:

### Serialization (ASON is 1.6–2.1x faster)

| Scenario            | JSON      | ASON     | Speedup   |
| ------------------- | --------- | -------- | --------- |
| Flat struct × 1000  | 103.03 ms | 60.55 ms | **1.70x** |
| 5-level deep × 100  | 419.77 ms | 197.67 ms | **2.12x** |
| Large payload (10k) | 106.09 ms | 62.67 ms | **1.69x** |

### Deserialization (ASON is 1.1–2.5x faster)

| Scenario            | JSON      | ASON     | Speedup   |
| ------------------- | --------- | -------- | --------- |
| Flat struct × 1000  | 74.24 ms  | 65.97 ms | **1.13x** |
| 5-level deep × 100  | 336.29 ms | 137.31 ms | **2.45x** |
| Large payload (10k) | 84.78 ms  | 68.83 ms | **1.23x** |

### Size Savings

| Scenario            | JSON     | ASON text | ASON binary | Text saving | Binary saving |
| ------------------- | -------- | --------- | ----------- | ----------- | ------------- |
| Flat struct × 1000  | 118.8 KB | 55.4 KB   | 72.7 KB     | **53%**     | **39%**       |
| 5-level deep × 100  | 438.1 KB | 170.2 KB  | 225.4 KB    | **61%**     | **49%**       |
| Large payload (10k) | 1.2 MB   | 576.8 KB  | 744.5 KB    | **53%**     | **39%**       |

### Why is ASON Faster?

1. **Zero key-hashing** — Schema is parsed once; data fields are mapped by position index `O(1)`, no per-row key string hashing.
2. **Schema-driven parsing** — The decoder knows the expected type of each field from the schema, enabling direct parsing instead of runtime type inference. CPU branch prediction hits ~100%.
3. **Minimal memory allocation** — All data rows share one schema reference. No repeated key string allocation.

Run the benchmark yourself:

```bash
dart run example/bench.dart
```

## Examples

```bash
# Basic usage
dart run example/basic.dart

# Comprehensive (all types, nested structs, edge cases)
dart run example/complex.dart

# Performance benchmark (ASON vs JSON, throughput, size)
dart run example/bench.dart
```

## ASON Format Specification

See the full [ASON Spec](https://github.com/athxx/ason/blob/main/docs/ASON_SPEC_CN.md) for syntax rules, BNF grammar, escape rules, type system, and LLM integration best practices.

### Syntax Quick Reference

| Element       | Schema                      | Data                |
| ------------- | --------------------------- | ------------------- |
| Object        | `{field1:type,field2:type}` | `(val1,val2)`       |
| Array         | `field:[type]`              | `[v1,v2,v3]`        |
| Object array  | `field:[{f1:type,f2:type}]` | `[(v1,v2),(v3,v4)]` |
| Map           | `field:map[K,V]`            | `[(k1,v1),(k2,v2)]` |
| Nested object | `field:{f1:type,f2:type}`   | `(v1,(v3,v4))`      |
| Null          | —                           | _(blank)_           |
| Empty string  | —                           | `""`                |
| Comment       | —                           | `/* ... */`         |

## License

MIT
