import 'dart:typed_data';
import 'schema.dart';

// ---------------------------------------------------------------------------
// Two-digit lookup table for fast integer formatting (itoa-style)
// ---------------------------------------------------------------------------
const _kDecDigits = '00010203040506070809'
    '10111213141516171819'
    '20212223242526272829'
    '30313233343536373839'
    '40414243444546474849'
    '50515253545556575859'
    '60616263646566676869'
    '70717273747576777879'
    '80818283848586878889'
    '90919293949596979899';

// ---------------------------------------------------------------------------
// ASON special characters that require quoting
// ---------------------------------------------------------------------------
const _kSpecial = <int>{
  0x2C, // ,
  0x28, // (
  0x29, // )
  0x5B, // [
  0x5D, // ]
  0x7B, // {
  0x7D, // }
  0x3A, // :
  0x22, // "
  0x5C, // \
  0x0A, // \n
  0x0D, // \r
  0x09, // \t
};

// ---------------------------------------------------------------------------
// Fast integer to buffer — zero allocation
// ---------------------------------------------------------------------------
final _intBuf = Uint8List(20); // max i64 digits

int _writeU64(Uint8List buf, int off, int v) {
  if (v == 0) {
    buf[off] = 0x30;
    return off + 1;
  }
  // Write digits in reverse
  int end = off + 20;
  int pos = end;
  while (v > 0) {
    pos--;
    buf[pos] = 0x30 + (v % 10);
    v ~/= 10;
  }
  // Shift to start
  final len = end - pos;
  for (int i = 0; i < len; i++) {
    buf[off + i] = buf[pos + i];
  }
  return off + len;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Encode a value to compact ASON string (unannotated schema).
///
/// Supports: [AsonSchema] objects, [List<AsonSchema>], [Map], primitives.
String encode(dynamic value) {
  final buf = StringBuffer();
  if (value is AsonSchema) {
    _encodeStruct(buf, value, false);
  } else if (value is List) {
    _encodeTopList(buf, value, false);
  } else if (value is Map) {
    _encodeMap(buf, value);
  } else {
    _encodeValue(buf, value);
  }
  return buf.toString();
}

/// Encode a value to ASON string with type-annotated schema.
String encodeTyped(dynamic value) {
  final buf = StringBuffer();
  if (value is AsonSchema) {
    _encodeStruct(buf, value, true);
  } else if (value is List) {
    _encodeTopList(buf, value, true);
  } else if (value is Map) {
    _encodeMap(buf, value);
  } else {
    _encodeValue(buf, value);
  }
  return buf.toString();
}

// ---------------------------------------------------------------------------
// Internal encoding
// ---------------------------------------------------------------------------

void _encodeStruct(StringBuffer buf, AsonSchema obj, bool typed) {
  final names = obj.fieldNames;
  final values = obj.fieldValues;
  final types = typed ? obj.fieldTypes : null;

  // Schema header: {field1:type,field2:type}:
  buf.write('{');
  for (int i = 0; i < names.length; i++) {
    if (i > 0) buf.write(',');
    buf.write(names[i]);
    if (typed && types != null && i < types.length) {
      final v = values[i];
      if (v is AsonSchema) {
        buf.write(':');
        _writeNestedSchema(buf, v, true);
      } else if (v is List && v.isNotEmpty && v.first is AsonSchema) {
        buf.write(':[');
        _writeNestedSchema(buf, v.first as AsonSchema, true);
        buf.write(']');
      } else {
        final t = types[i] ?? _inferType(v);
        if (t != null) {
          buf.write(':');
          buf.write(t);
        }
      }
    } else {
      final v = values[i];
      if (v is AsonSchema) {
        buf.write(':');
        _writeNestedSchema(buf, v, false);
      } else if (v is List && v.isNotEmpty && v.first is AsonSchema) {
        buf.write(':[');
        _writeNestedSchema(buf, v.first as AsonSchema, false);
        buf.write(']');
      }
    }
  }
  buf.write('}:');

  // Data tuple: (v1,v2,v3)
  buf.write('(');
  for (int i = 0; i < values.length; i++) {
    if (i > 0) buf.write(',');
    _encodeValue(buf, values[i]);
  }
  buf.write(')');
}

void _writeNestedSchema(StringBuffer buf, AsonSchema obj, bool typed) {
  final names = obj.fieldNames;
  final values = obj.fieldValues;
  final types = typed ? obj.fieldTypes : null;
  buf.write('{');
  for (int i = 0; i < names.length; i++) {
    if (i > 0) buf.write(',');
    buf.write(names[i]);
    if (typed && types != null && i < types.length) {
      final v = i < values.length ? values[i] : null;
      if (v is AsonSchema) {
        buf.write(':');
        _writeNestedSchema(buf, v, true);
      } else if (v is List && v.isNotEmpty && v.first is AsonSchema) {
        buf.write(':[');
        _writeNestedSchema(buf, v.first as AsonSchema, true);
        buf.write(']');
      } else {
        final t = types[i] ?? _inferType(v);
        if (t != null) {
          buf.write(':');
          buf.write(t);
        }
      }
    } else {
      final v = i < values.length ? values[i] : null;
      if (v is AsonSchema) {
        buf.write(':');
        _writeNestedSchema(buf, v, false);
      } else if (v is List && v.isNotEmpty && v.first is AsonSchema) {
        buf.write(':[');
        _writeNestedSchema(buf, v.first as AsonSchema, false);
        buf.write(']');
      }
    }
  }
  buf.write('}');
}

void _encodeTopList(StringBuffer buf, List list, bool typed) {
  if (list.isEmpty) {
    buf.write('[]');
    return;
  }

  final first = list.first;
  if (first is AsonSchema) {
    // Vec<Struct>: [{schema}]:(v1),(v2)
    buf.write('[');
    _writeNestedSchema(buf, first, typed);
    buf.write(']:');
    for (int i = 0; i < list.length; i++) {
      if (i > 0) buf.write(',');
      final obj = list[i] as AsonSchema;
      buf.write('(');
      final values = obj.fieldValues;
      for (int j = 0; j < values.length; j++) {
        if (j > 0) buf.write(',');
        _encodeValue(buf, values[j]);
      }
      buf.write(')');
    }
  } else {
    // Plain array: [v1,v2,v3]
    buf.write('[');
    for (int i = 0; i < list.length; i++) {
      if (i > 0) buf.write(',');
      _encodeValue(buf, list[i]);
    }
    buf.write(']');
  }
}

void _encodeValue(StringBuffer buf, dynamic v) {
  if (v == null) {
    // None — blank
    return;
  }
  if (v is bool) {
    buf.write(v ? 'true' : 'false');
    return;
  }
  if (v is int) {
    buf.write(v.toString());
    return;
  }
  if (v is double) {
    _writeDouble(buf, v);
    return;
  }
  if (v is String) {
    _writeString(buf, v);
    return;
  }
  if (v is AsonSchema) {
    // Nested struct → tuple
    buf.write('(');
    final values = v.fieldValues;
    for (int i = 0; i < values.length; i++) {
      if (i > 0) buf.write(',');
      _encodeValue(buf, values[i]);
    }
    buf.write(')');
    return;
  }
  if (v is List) {
    if (v.isNotEmpty && v.first is AsonSchema) {
      // Nested Vec<Struct>: [(v1,v2),(v3,v4)]
      buf.write('[');
      for (int i = 0; i < v.length; i++) {
        if (i > 0) buf.write(',');
        final obj = v[i] as AsonSchema;
        buf.write('(');
        final values = obj.fieldValues;
        for (int j = 0; j < values.length; j++) {
          if (j > 0) buf.write(',');
          _encodeValue(buf, values[j]);
        }
        buf.write(')');
      }
      buf.write(']');
    } else {
      buf.write('[');
      for (int i = 0; i < v.length; i++) {
        if (i > 0) buf.write(',');
        _encodeValue(buf, v[i]);
      }
      buf.write(']');
    }
    return;
  }
  if (v is Map) {
    _encodeMap(buf, v);
    return;
  }
  // Fallback
  _writeString(buf, v.toString());
}

void _encodeMap(StringBuffer buf, Map map) {
  buf.write('[');
  int idx = 0;
  for (final entry in map.entries) {
    if (idx > 0) buf.write(',');
    buf.write('(');
    _encodeValue(buf, entry.key);
    buf.write(',');
    _encodeValue(buf, entry.value);
    buf.write(')');
    idx++;
  }
  buf.write(']');
}

// ---------------------------------------------------------------------------
// String quoting — SIMD-like scan for special chars
// ---------------------------------------------------------------------------

bool _needsQuoting(String s) {
  if (s.isEmpty) return true;
  final units = s.codeUnits;
  if (units.first == 0x20 || units.last == 0x20) return true; // leading/trailing space
  if (s == 'true' || s == 'false') return true;

  // Check for ASON special chars
  for (int i = 0; i < units.length; i++) {
    if (_kSpecial.contains(units[i])) return true;
  }

  // Check if looks like a number
  int start = 0;
  if (units.isNotEmpty && units[0] == 0x2D) start = 1; // '-'
  if (start < units.length) {
    bool couldBeNumber = true;
    for (int i = start; i < units.length; i++) {
      final c = units[i];
      if (!((c >= 0x30 && c <= 0x39) || c == 0x2E)) {
        couldBeNumber = false;
        break;
      }
    }
    if (couldBeNumber) return true;
  }

  return false;
}

void _writeString(StringBuffer buf, String s) {
  if (_needsQuoting(s)) {
    _writeEscaped(buf, s);
  } else {
    buf.write(s);
  }
}

void _writeEscaped(StringBuffer buf, String s) {
  buf.write('"');
  final units = s.codeUnits;
  for (int i = 0; i < units.length; i++) {
    final c = units[i];
    switch (c) {
      case 0x22: // "
        buf.write(r'\"');
      case 0x5C: // \
        buf.write(r'\\');
      case 0x0A: // \n
        buf.write(r'\n');
      case 0x0D: // \r
        buf.write(r'\r');
      case 0x09: // \t
        buf.write(r'\t');
      case 0x2C: // ,
        buf.write(r'\,');
      case 0x28: // (
        buf.write(r'\(');
      case 0x29: // )
        buf.write(r'\)');
      case 0x5B: // [
        buf.write(r'\[');
      case 0x5D: // ]
        buf.write(r'\]');
      default:
        buf.writeCharCode(c);
    }
  }
  buf.write('"');
}

// ---------------------------------------------------------------------------
// Float formatting — fast path for common cases, no allocation
// ---------------------------------------------------------------------------

void _writeDouble(StringBuffer buf, double v) {
  if (v.isFinite && v == v.truncateToDouble()) {
    // Integer-valued float
    buf.write(v.toInt().toString());
    buf.write('.0');
    return;
  }
  if (v.isFinite) {
    // One decimal fast path
    final v10 = v * 10;
    if (v10 == v10.truncateToDouble() && v10.abs() < 1e15) {
      final vi = v10.toInt();
      final intPart = vi.abs() ~/ 10;
      final frac = vi.abs() % 10;
      if (vi < 0) buf.write('-');
      buf.write(intPart.toString());
      buf.write('.');
      buf.write(frac.toString());
      return;
    }
    // Two decimal fast path
    final v100 = v * 100;
    if (v100 == v100.truncateToDouble() && v100.abs() < 1e15) {
      final vi = v100.toInt();
      final intPart = vi.abs() ~/ 100;
      final frac = vi.abs() % 100;
      if (vi < 0) buf.write('-');
      buf.write(intPart.toString());
      buf.write('.');
      if (frac < 10) {
        buf.write('0');
      }
      // Trim trailing zero for two-decimal
      final d1 = frac ~/ 10;
      final d2 = frac % 10;
      buf.write(d1.toString());
      if (d2 != 0) buf.write(d2.toString());
      return;
    }
  }
  buf.write(v.toString());
}

String? _inferType(dynamic v) {
  if (v == null) return null;
  if (v is bool) return 'bool';
  if (v is int) return 'int';
  if (v is double) return 'float';
  if (v is String) return 'str';
  if (v is List) {
    if (v.isEmpty) return null;
    final inner = _inferType(v.first);
    return inner != null ? '[$inner]' : null;
  }
  if (v is Map) return 'map';
  return null;
}
