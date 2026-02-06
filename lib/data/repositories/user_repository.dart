import '../local/database_helper.dart';

/// User profile data for persistence
class UserProfile {
  final String name;
  final String? institution;
  final String preferredLanguage;
  final String? defaultOrganism;

  const UserProfile({
    required this.name,
    this.institution,
    this.preferredLanguage = 'en',
    this.defaultOrganism,
  });
}

/// Repository for user profile persistence
class UserRepository {
  final DatabaseHelper _dbHelper;

  UserRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Save or update user profile
  Future<void> save(UserProfile profile) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final data = {
      'id': 1, // Single user app
      'name': profile.name,
      'institution': profile.institution,
      'preferred_language': profile.preferredLanguage,
      'default_organism': profile.defaultOrganism,
      'created_at': now,
      'updated_at': now,
    };

    // Check if profile exists
    final existing = await db.query(
      DatabaseHelper.tableUserProfile,
      where: 'id = 1',
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(DatabaseHelper.tableUserProfile, data);
    } else {
      data.remove('created_at'); // Don't update created_at
      await db.update(
        DatabaseHelper.tableUserProfile,
        data,
        where: 'id = 1',
      );
    }
  }

  /// Get user profile
  Future<UserProfile?> get() async {
    final db = await _dbHelper.database;

    final results = await db.query(
      DatabaseHelper.tableUserProfile,
      where: 'id = 1',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final map = results.first;
    return UserProfile(
      name: map['name'] as String,
      institution: map['institution'] as String?,
      preferredLanguage: map['preferred_language'] as String? ?? 'en',
      defaultOrganism: map['default_organism'] as String?,
    );
  }

  /// Check if user profile exists (for first-run detection)
  Future<bool> exists() async {
    final db = await _dbHelper.database;

    final results = await db.query(
      DatabaseHelper.tableUserProfile,
      where: 'id = 1',
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Delete user profile
  Future<void> delete() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableUserProfile, where: 'id = 1');
  }
}
