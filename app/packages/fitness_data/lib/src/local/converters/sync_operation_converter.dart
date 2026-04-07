import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum SyncOperation {
  create,
  update,
  delete,
}

class SyncOperationConverter extends TypeConverter<SyncOperation, String> {
  const SyncOperationConverter();

  @override
  SyncOperation fromSql(String fromDb) {
    switch (fromDb) {
      case 'create':
        return SyncOperation.create;
      case 'update':
        return SyncOperation.update;
      case 'delete':
        return SyncOperation.delete;
      default:
        debugPrint('SyncOperationConverter: unknown value "$fromDb", falling back to create');
        return SyncOperation.create;
    }
  }

  @override
  String toSql(SyncOperation value) {
    switch (value) {
      case SyncOperation.create:
        return 'create';
      case SyncOperation.update:
        return 'update';
      case SyncOperation.delete:
        return 'delete';
    }
  }
}
