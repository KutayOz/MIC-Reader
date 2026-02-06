import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import '../models/models.dart';

/// Repository for PlateAnalysis CRUD operations
class AnalysisRepository {
  final DatabaseHelper _dbHelper;

  AnalysisRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Save a new analysis or update existing
  Future<void> save(PlateAnalysis analysis) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final data = {
      'id': analysis.id,
      'timestamp': analysis.timestamp.toIso8601String(),
      'image_path': analysis.imagePath,
      'organism': analysis.organism,
      'analyst_name': analysis.analystName,
      'institution': analysis.institution,
      'notes': analysis.notes,
      'wells_json': jsonEncode(analysis.wells.map((w) => w.toJson()).toList()),
      'mic_results_json': jsonEncode(analysis.micResults.map((m) => m.toJson()).toList()),
      'created_at': now,
      'updated_at': now,
    };

    await db.insert(
      DatabaseHelper.tableAnalyses,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get analysis by ID
  Future<PlateAnalysis?> getById(String id) async {
    final db = await _dbHelper.database;

    final results = await db.query(
      DatabaseHelper.tableAnalyses,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;

    return _fromMap(results.first);
  }

  /// Get all analyses, ordered by timestamp descending
  Future<List<PlateAnalysis>> getAll({int? limit, int? offset}) async {
    final db = await _dbHelper.database;

    final results = await db.query(
      DatabaseHelper.tableAnalyses,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return results.map(_fromMap).toList();
  }

  /// Get recent analyses (last N)
  Future<List<PlateAnalysis>> getRecent({int count = 5}) async {
    return getAll(limit: count);
  }

  /// Get analyses by organism
  Future<List<PlateAnalysis>> getByOrganism(String organism) async {
    final db = await _dbHelper.database;

    final results = await db.query(
      DatabaseHelper.tableAnalyses,
      where: 'organism = ?',
      whereArgs: [organism],
      orderBy: 'timestamp DESC',
    );

    return results.map(_fromMap).toList();
  }

  /// Search analyses by notes or analyst name
  Future<List<PlateAnalysis>> search(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';

    final results = await db.query(
      DatabaseHelper.tableAnalyses,
      where: 'notes LIKE ? OR analyst_name LIKE ? OR organism LIKE ?',
      whereArgs: [searchQuery, searchQuery, searchQuery],
      orderBy: 'timestamp DESC',
    );

    return results.map(_fromMap).toList();
  }

  /// Update an existing analysis
  Future<void> update(PlateAnalysis analysis) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final data = {
      'timestamp': analysis.timestamp.toIso8601String(),
      'image_path': analysis.imagePath,
      'organism': analysis.organism,
      'analyst_name': analysis.analystName,
      'institution': analysis.institution,
      'notes': analysis.notes,
      'wells_json': jsonEncode(analysis.wells.map((w) => w.toJson()).toList()),
      'mic_results_json': jsonEncode(analysis.micResults.map((m) => m.toJson()).toList()),
      'updated_at': now,
    };

    await db.update(
      DatabaseHelper.tableAnalyses,
      data,
      where: 'id = ?',
      whereArgs: [analysis.id],
    );
  }

  /// Delete an analysis by ID
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;

    await db.delete(
      DatabaseHelper.tableAnalyses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all analyses
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableAnalyses);
  }

  /// Get count of all analyses
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableAnalyses}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Convert database map to PlateAnalysis
  PlateAnalysis _fromMap(Map<String, dynamic> map) {
    final wellsJson = jsonDecode(map['wells_json'] as String) as List<dynamic>;
    final micJson = jsonDecode(map['mic_results_json'] as String) as List<dynamic>;

    return PlateAnalysis(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      imagePath: map['image_path'] as String,
      organism: map['organism'] as String?,
      analystName: map['analyst_name'] as String?,
      institution: map['institution'] as String?,
      notes: map['notes'] as String?,
      wells: wellsJson
          .map((w) => WellResult.fromJson(w as Map<String, dynamic>))
          .toList(),
      micResults: micJson
          .map((m) => MicResult.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
