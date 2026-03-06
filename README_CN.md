# ason

[![Pub Version](https://img.shields.io/pub/v/ason.svg)](https://pub.dev/packages/ason)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

高性能 [ASON](https://github.com/athxx/ason)（Array-Schema Object Notation）Dart 编解码库 —— 一种面向 LLM 交互和大规模数据传输的高效序列化格式。

[English](README.md)

## 什么是 ASON？

ASON 将 **Schema** 与 **数据** 分离，消除了 JSON 中每个对象都重复出现 Key 的冗余。Schema 只声明一次，数据行仅保留纯值：

```text
JSON (100 tokens):
{"users":[{"id":1,"name":"Alice","active":true},{"id":2,"name":"Bob","active":false}]}

ASON (~35 tokens, 节省 65%):
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

| 方面       | JSON         | ASON             |
| ---------- | ------------ | ---------------- |
| Token 效率 | 100%         | 30–70% ✓         |
| Key 重复   | 每个对象都有 | 声明一次 ✓       |
| 人类可读   | 是           | 是 ✓             |
| 嵌套结构   | ✓            | ✓                |
| 类型注解   | 无           | 可选 ✓           |
| 序列化速度 | 1x           | **~1.7x 更快** ✓ |
| 数据体积   | 100%         | **40–55%** ✓     |

## 快速开始

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  ason: ^0.1.0
```

### 序列化与反序列化结构体

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

  // 序列化
  final s = encode(user);
  assert(s == '{id,name,active}:(1,Alice,true)');

  // 反序列化
  final user2 = decodeWith(s, User.fromMap);
  assert(user2.id == 1 && user2.name == 'Alice');
}
```

### 带类型注解序列化

使用 `encodeTyped` 输出带类型注解的 Schema —— 适用于文档生成、LLM 提示词和跨语言数据交换：

```dart
final s = encodeTyped(user);
// 输出: {id:int,name:str,active:bool}:(1,Alice,true)

// 反序列化同时支持带注解和不带注解的 Schema
final user2 = decodeWith(s, User.fromMap);
```

### 序列化与反序列化 List（Schema 驱动）

对于 `List<AsonSchema>`，ASON 只写入一次 Schema，每个元素以紧凑元组形式输出 —— 这是相比 JSON 的核心优势：

```dart
final users = [
  User(id: 1, name: 'Alice', active: true),
  User(id: 2, name: 'Bob', active: false),
];

// 无注解 Schema
final s = encode(users);
// 输出: [{id,name,active}]:(1,Alice,true),(2,Bob,false)

// 带类型注解 Schema
final s2 = encodeTyped(users);
// 输出: [{id:int,name:str,active:bool}]:(1,Alice,true),(2,Bob,false)

// 反序列化 —— 两种格式均可
final users2 = decodeListWith(s, User.fromMap);
```

## 支持的类型

| 类型       | ASON 表示             | 示例                     |
| ---------- | --------------------- | ------------------------ |
| int        | 纯数字                | `42`, `-100`             |
| double     | 带小数点              | `3.14`, `-0.5`           |
| bool       | 字面量                | `true`, `false`          |
| String     | 无引号或有引号        | `Alice`, `"Carol Smith"` |
| null       | 留空                  | _(空白)_ 表示 null       |
| List       | `[v1,v2,v3]`          | `[rust,go,python]`       |
| Map        | `[(k1,v1),(k2,v2)]`   | `[(age,30),(score,95)]`  |
| 嵌套结构体 | `(field1,field2)`     | `(Engineering,500000)`   |

### 嵌套结构体

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

// Schema 自动反映嵌套结构：
// {name:str,dept:{title:str}}:(Alice,(Engineering))
```

### 可选字段

```text
// 有值:    {id,label}:(1,hello)
// null:   {id,label}:(1,)
```

### 数组与字典

```text
// 数组字段:
{name,tags}:(Alice,[rust,go,python])

// 字典字段:
{name,attrs}:(Alice,[(age,30),(score,95)])
```

### 类型注解（可选）

ASON Schema 支持**可选的**类型注解。两种形式完全等价 —— 反序列化器对它们的处理完全一致：

```text
// 不带注解（encode 的默认输出）
{id,name,salary,active}:(1,Alice,5000.50,true)

// 带注解（encodeTyped 的输出）
{id:int,name:str,salary:float,active:bool}:(1,Alice,5000.50,true)
```

注解是**纯粹的装饰性元数据** —— 它们不影响解析和反序列化行为。

**适用场景：**

- LLM 提示词 — 帮助模型理解并生成正确的数据
- API 文档 — 无需外部文档即可自描述 Schema
- 跨语言数据交换 — 消除类型歧义（`42` 是 int 还是 double？）
- 调试 — 一眼看出数据类型

### 注释

```text
/* 用户列表 */
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

### 多行格式

```text
[{id:int, name:str, active:bool}]:
  (1, Alice, true),
  (2, Bob, false),
  (3, "Carol Smith", true)
```

## API 参考

### 文本格式

| 函数                           | 说明                                        |
| ------------------------------ | ------------------------------------------- |
| `encode(value)`                | 序列化 → 无注解 Schema `{id,name}:`         |
| `encodeTyped(value)`           | 序列化 → 带注解 Schema `{id:int,name:str}:` |
| `decode(input)`                | 反序列化为动态 Map/List（两种格式均可）      |
| `decodeWith(input, factory)`   | 反序列化为类型化对象                         |
| `decodeListWith(input, factory)` | 反序列化为类型化列表                       |

### 美化格式

| 函数                          | 说明                        |
| ----------------------------- | --------------------------- |
| `encodePretty(value)`         | 美化格式 ASON（无注解）     |
| `encodePrettyTyped(value)`    | 美化格式 ASON（带注解）     |

### 二进制格式

| 函数                                             | 说明                    |
| ------------------------------------------------ | ----------------------- |
| `encodeBinary(value)`                            | 编码为紧凑二进制字节    |
| `decodeBinaryWith(data, fields, types, factory)` | 解码为类型化对象        |
| `decodeBinaryListWith(data, fields, types, factory)` | 解码为类型化列表    |

## 性能

在 Linux 上使用 Dart VM 测试，与 `dart:convert` JSON 对比：

### 序列化（ASON 快 1.6–2.1 倍）

| 场景            | JSON      | ASON      | 加速比    |
| --------------- | --------- | --------- | --------- |
| 扁平结构 × 1000 | 103.03 ms | 60.55 ms  | **1.70x** |
| 5 层嵌套 × 100  | 419.77 ms | 197.67 ms | **2.12x** |
| 大数据量 (10k)  | 106.09 ms | 62.67 ms  | **1.69x** |

### 反序列化（ASON 快 1.1–2.5 倍）

| 场景            | JSON      | ASON      | 加速比    |
| --------------- | --------- | --------- | --------- |
| 扁平结构 × 1000 | 74.24 ms  | 65.97 ms  | **1.13x** |
| 5 层嵌套 × 100  | 336.29 ms | 137.31 ms | **2.45x** |
| 大数据量 (10k)  | 84.78 ms  | 68.83 ms  | **1.23x** |

### 体积节省

| 场景            | JSON     | ASON 文本 | ASON 二进制 | 文本节省 | 二进制节省 |
| --------------- | -------- | --------- | ----------- | -------- | ---------- |
| 扁平结构 × 1000 | 118.8 KB | 55.4 KB   | 72.7 KB     | **53%**  | **39%**    |
| 5 层嵌套 × 100  | 438.1 KB | 170.2 KB  | 225.4 KB    | **61%**  | **49%**    |
| 大数据量 (10k)  | 1.2 MB   | 576.8 KB  | 744.5 KB    | **53%**  | **39%**    |

### 为什么 ASON 更快？

1. **零哈希匹配** — Schema 只解析一次，数据字段通过位置索引 `O(1)` 映射，无需每行对 Key 字符串计算哈希。
2. **模式驱动解析** — 解码器通过 Schema 已知每个字段的类型，可以直接调用对应方法，而非运行时推断类型。CPU 分支预测命中率接近 100%。
3. **极小内存分配** — 所有数据行共享同一个 Schema 引用，无需为每行重复分配 Key 字符串的内存。

运行基准测试：

```bash
dart run example/bench.dart
```

## 示例

```bash
# 基础用法
dart run example/basic.dart

# 全面测试（全类型、嵌套结构、边界用例）
dart run example/complex.dart

# 性能基准（ASON vs JSON，吞吐量，体积比较）
dart run example/bench.dart
```

## ASON 格式规范

完整的 [ASON 规范](https://github.com/athxx/ason/blob/main/docs/ASON_SPEC_CN.md) 包含语法规则、BNF 文法、转义规则、类型系统及 LLM 集成最佳实践。

### 语法速查表

| 元素     | Schema 语法                 | 数据语法            |
| -------- | --------------------------- | ------------------- |
| 对象     | `{field1:type,field2:type}` | `(val1,val2)`       |
| 简单数组 | `field:[type]`              | `[v1,v2,v3]`        |
| 对象数组 | `field:[{f1:type,f2:type}]` | `[(v1,v2),(v3,v4)]` |
| 字典     | `field:map[K,V]`            | `[(k1,v1),(k2,v2)]` |
| 嵌套对象 | `field:{f1:type,f2:type}`   | `(v1,(v3,v4))`      |
| 空值     | —                           | _(空白)_            |
| 空字符串 | —                           | `""`                |
| 注释     | —                           | `/* ... */`         |

## 许可证

MIT
