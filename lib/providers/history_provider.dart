import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/models.dart';
import '../data/repositories/analysis_repository.dart';

/// Provider for managing analysis history state
class HistoryProvider extends ChangeNotifier {
  final AnalysisRepository _repository;

  List<PlateAnalysis> _analyses = [];
  List<PlateAnalysis> _recentAnalyses = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  HistoryProvider({AnalysisRepository? repository})
      : _repository = repository ?? AnalysisRepository();

  // Getters
  List<PlateAnalysis> get analyses => _analyses;
  List<PlateAnalysis> get recentAnalyses => _recentAnalyses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  int get count => _analyses.length;

  /// Load all analyses from database
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _analyses = await _repository.getAll();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load recent analyses (for home screen)
  Future<void> loadRecent({int count = 5}) async {
    try {
      _recentAnalyses = await _repository.getRecent(count: count);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Save a new analysis
  Future<void> save(PlateAnalysis analysis) async {
    try {
      await _repository.save(analysis);

      // Add to local lists
      _analyses.insert(0, analysis);
      _recentAnalyses.insert(0, analysis);
      if (_recentAnalyses.length > 5) {
        _recentAnalyses.removeLast();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing analysis
  Future<void> update(PlateAnalysis analysis) async {
    try {
      await _repository.update(analysis);

      // Update in local lists
      final idx = _analyses.indexWhere((a) => a.id == analysis.id);
      if (idx >= 0) {
        _analyses[idx] = analysis;
      }

      final recentIdx = _recentAnalyses.indexWhere((a) => a.id == analysis.id);
      if (recentIdx >= 0) {
        _recentAnalyses[recentIdx] = analysis;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete an analysis
  Future<void> delete(String id) async {
    try {
      // Get analysis to delete its image file
      final analysis = _analyses.firstWhere(
        (a) => a.id == id,
        orElse: () => throw Exception('Analysis not found'),
      );

      // Delete from database
      await _repository.delete(id);

      // Delete image file
      final imageFile = File(analysis.imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      // Remove from local lists
      _analyses.removeWhere((a) => a.id == id);
      _recentAnalyses.removeWhere((a) => a.id == id);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Search analyses
  Future<void> search(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      await loadAll();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _analyses = await _repository.search(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear search and reload all
  void clearSearch() {
    _searchQuery = '';
    loadAll();
  }

  /// Get analysis by ID
  PlateAnalysis? getById(String id) {
    try {
      return _analyses.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update patient name (stored in notes field)
  Future<void> updatePatientName(String id, String? patientName) async {
    try {
      final analysis = getById(id);
      if (analysis == null) return;

      final updated = analysis.copyWith(notes: patientName);
      await update(updated);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
