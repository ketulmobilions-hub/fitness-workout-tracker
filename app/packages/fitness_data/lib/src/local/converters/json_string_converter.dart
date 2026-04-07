import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class JsonStringConverter
    extends TypeConverter<Map<String, dynamic>, String> {
  const JsonStringConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('JsonStringConverter: failed to decode "$fromDb": $e');
    }
    return {};
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}
