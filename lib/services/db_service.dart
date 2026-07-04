import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/capture_item.dart';

/// Handles all local persistence for capture history.
/// Uses sqflite_common_ffi for desktop (macOS/Windows/Linux).
///
/// NOTE: sqfliteFfiInit() and databaseFactory = databaseFactoryFfi
/// MUST be called in main() before runApp() — this is done in lib/main.dart.
class DbService {
  DbService._internal();
  static final DbService instance = DbService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationSupportDirectory();
    final dbPath = p.join(docsDir.path, 'snap_ocr_history.db');

    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE history (
              id TEXT PRIMARY KEY,
              imagePath TEXT NOT NULL,
              extractedText TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<void> insert(CaptureItem item) async {
    try {
      final db = await database;
      await db.insert(
        'history',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('DbService.insert error: $e');
    }
  }

  Future<List<CaptureItem>> getAll() async {
    try {
      final db = await database;
      final rows = await db.query('history', orderBy: 'createdAt DESC');
      return rows.map((r) => CaptureItem.fromMap(r)).toList();
    } catch (e) {
      debugPrint('DbService.getAll error: $e');
      return [];
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await database;
      await db.delete('history', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('DbService.delete error: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete('history');
    } catch (e) {
      debugPrint('DbService.clearAll error: $e');
    }
  }
}
