import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite database helper for local storage
class DatabaseHelper {
  static const String _databaseName = 'mic_reader.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableAnalyses = 'analyses';
  static const String tableUserProfile = 'user_profile';

  // Singleton instance
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create analyses table
    await db.execute('''
      CREATE TABLE $tableAnalyses (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        image_path TEXT NOT NULL,
        organism TEXT,
        analyst_name TEXT,
        institution TEXT,
        notes TEXT,
        wells_json TEXT NOT NULL,
        mic_results_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create index on timestamp for sorting
    await db.execute('''
      CREATE INDEX idx_analyses_timestamp ON $tableAnalyses (timestamp DESC)
    ''');

    // Create user profile table
    await db.execute('''
      CREATE TABLE $tableUserProfile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        institution TEXT,
        preferred_language TEXT DEFAULT 'en',
        default_organism TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete database (for debugging/reset)
  Future<void> deleteDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
