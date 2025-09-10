import 'package:flutter/foundation.dart';
import '../core/models/Doctor.dart';
import '../db/DBHelper.dart';
import 'CoreSessionProvider.dart';


enum DoctorViewMode {
  list,
  table,
  card,
}

class DoctorProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CoreSessionProvider _sessionProvider;

  DoctorProvider(this._sessionProvider);

  // ==================== STATE VARIABLES ====================

  // UI State
  DoctorViewMode _viewMode = DoctorViewMode.table;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _errorMessage;
  String? _successMessage;

  // Search and Filter State
  String _searchQuery = '';
  String _selectedSpecializationFilter = '';
  String _selectedSeniorityFilter = '';
  List<Doctor> _filteredDoctors = [];

  // Selection State (for table operations)
  Set<int> _selectedDoctorIds = {};
  Doctor? _editingDoctor;

  // Sort State
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // ==================== GETTERS ====================

  // UI State Getters
  DoctorViewMode get viewMode => _viewMode;
  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Data Getters
  List<Doctor> get allDoctors => _sessionProvider.allDoctors;
  List<Doctor> get displayedDoctors => _filteredDoctors.isEmpty ? _getSortedDoctors(allDoctors) : _getSortedDoctors(_filteredDoctors);
  List<String> get availableSpecializations => _sessionProvider.specializations;
  Map<String, int> get specializationCounts => _sessionProvider.specializationCounts;

  // Search and Filter Getters
  String get searchQuery => _searchQuery;
  String get selectedSpecializationFilter => _selectedSpecializationFilter;
  String get selectedSeniorityFilter => _selectedSeniorityFilter;
  bool get hasActiveFilters => _searchQuery.isNotEmpty || _selectedSpecializationFilter.isNotEmpty || _selectedSeniorityFilter.isNotEmpty;

  // Selection Getters
  Set<int> get selectedDoctorIds => Set.unmodifiable(_selectedDoctorIds);
  Doctor? get editingDoctor => _editingDoctor;
  bool get hasSelection => _selectedDoctorIds.isNotEmpty;
  int get selectionCount => _selectedDoctorIds.length;

  // Sort Getters
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  // ==================== DOCTOR CRUD OPERATIONS ====================

  /// Add new doctor
  Future<bool> addDoctor({
    required String name,
    required String specialization,
    required String seniority,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final doctor = Doctor(
        name: name.trim(),
        specialization: specialization,
        seniority: seniority,
      );

      final id = await _dbHelper.insertDoctor(doctor);

      if (id > 0) {
        // Create doctor with the new ID
        final newDoctor = Doctor(
          id: id,
          name: name.trim(),
          specialization: specialization,
          seniority: seniority,
        );

        // Notify session provider to update shared data
        await _sessionProvider.onDoctorAdded(newDoctor);

        // Refresh filters if needed
        _applyFilters();

        _setSuccess('Doctor "${name.trim()}" added successfully');
        return true;
      }

      _setError('Failed to add doctor');
      return false;

    } catch (e) {
      _setError('Failed to add doctor: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update existing doctor
  Future<bool> updateDoctor({
    required int doctorId,
    required String name,
    required String specialization,
    required String seniority,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedDoctor = Doctor(
        id: doctorId,
        name: name.trim(),
        specialization: specialization,
        seniority: seniority,
      );

      final result = await _dbHelper.updateDoctor(updatedDoctor);

      if (result > 0) {
        // Notify session provider to update shared data
        await _sessionProvider.onDoctorUpdated(updatedDoctor);

        // Refresh filters
        _applyFilters();

        // Clear editing state
        _editingDoctor = null;
        _isEditing = false;

        _setSuccess('Doctor updated successfully');
        return true;
      }

      _setError('Failed to update doctor');
      return false;

    } catch (e) {
      _setError('Failed to update doctor: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete doctor(s)
  Future<bool> deleteDoctors(List<int> doctorIds) async {
    _setLoading(true);
    _clearMessages();

    try {
      int deletedCount = 0;

      for (int doctorId in doctorIds) {
        final result = await _dbHelper.deleteDoctor(doctorId);
        if (result > 0) {
          deletedCount++;
          await _sessionProvider.onDoctorDeleted(doctorId);
        }
      }

      if (deletedCount > 0) {
        // Clear selection and refresh filters
        _selectedDoctorIds.clear();
        _applyFilters();

        final message = deletedCount == 1
            ? 'Doctor deleted successfully'
            : '$deletedCount doctors deleted successfully';
        _setSuccess(message);
        return true;
      }

      _setError('Failed to delete doctors');
      return false;

    } catch (e) {
      _setError('Failed to delete doctors: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete single doctor
  Future<bool> deleteDoctor(int doctorId) async {
    return await deleteDoctors([doctorId]);
  }

  // ==================== SEARCH AND FILTER OPERATIONS ====================

  /// Set search query and apply filters
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _applyFilters();
    notifyListeners();
  }

  /// Set specialization filter
  void setSpecializationFilter(String specialization) {
    _selectedSpecializationFilter = specialization;
    _applyFilters();
    notifyListeners();
  }

  /// Set seniority filter
  void setSeniorityFilter(String seniority) {
    _selectedSeniorityFilter = seniority;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedSpecializationFilter = '';
    _selectedSeniorityFilter = '';
    _filteredDoctors.clear();
    notifyListeners();
  }

  /// Apply current filters to doctor list
  void _applyFilters() {
    List<Doctor> filtered = List.from(allDoctors);

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((doctor) {
        return doctor.name.toLowerCase().contains(query) ||
            (doctor.specialization?.toLowerCase().contains(query) ?? false) ||
            (doctor.seniority?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply specialization filter
    if (_selectedSpecializationFilter.isNotEmpty) {
      filtered = filtered.where((doctor) =>
      doctor.specialization == _selectedSpecializationFilter
      ).toList();
    }

    // Apply seniority filter
    if (_selectedSeniorityFilter.isNotEmpty) {
      filtered = filtered.where((doctor) =>
      doctor.seniority == _selectedSeniorityFilter
      ).toList();
    }

    _filteredDoctors = filtered;
  }

  // ==================== SELECTION OPERATIONS ====================

  /// Toggle doctor selection
  void toggleDoctorSelection(int doctorId) {
    if (_selectedDoctorIds.contains(doctorId)) {
      _selectedDoctorIds.remove(doctorId);
    } else {
      _selectedDoctorIds.add(doctorId);
    }
    notifyListeners();
  }

  /// Select all visible doctors
  void selectAllVisible() {
    _selectedDoctorIds.addAll(
        displayedDoctors.map((doctor) => doctor.id!).where((id) => id != null)
    );
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    _selectedDoctorIds.clear();
    notifyListeners();
  }

  /// Check if doctor is selected
  bool isDoctorSelected(int doctorId) {
    return _selectedDoctorIds.contains(doctorId);
  }

  // ==================== EDITING OPERATIONS ====================

  /// Start editing a doctor
  void startEditing(Doctor doctor) {
    _editingDoctor = doctor;
    _isEditing = true;
    _clearMessages();
    notifyListeners();
  }

  /// Cancel editing
  void cancelEditing() {
    _editingDoctor = null;
    _isEditing = false;
    _clearMessages();
    notifyListeners();
  }

  // ==================== SORTING OPERATIONS ====================

  /// Set sort column and direction
  void setSorting(String column, bool ascending) {
    _sortColumn = column;
    _sortAscending = ascending;
    notifyListeners();
  }

  /// Toggle sort direction for column
  void toggleSort(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    notifyListeners();
  }

  /// Get sorted doctors list
  List<Doctor> _getSortedDoctors(List<Doctor> doctors) {
    List<Doctor> sorted = List.from(doctors);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumn) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'specialization':
          comparison = (a.specialization ?? '').compareTo(b.specialization ?? '');
          break;
        case 'seniority':
          comparison = (a.seniority ?? '').compareTo(b.seniority ?? '');
          break;
        case 'id':
          comparison = (a.id ?? 0).compareTo(b.id ?? 0);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  // ==================== VIEW MODE OPERATIONS ====================

  /// Set display view mode
  void setViewMode(DoctorViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  // ==================== UTILITY METHODS ====================

  /// Get doctor by ID
  Doctor? getDoctorById(int id) {
    return _sessionProvider.getDoctorById(id);
  }

  /// Get doctors by specialization
  List<Doctor> getDoctorsBySpecialization(String specialization) {
    return _sessionProvider.getDoctorsBySpecialization(specialization);
  }

  /// Get available seniority levels
  List<String> getAvailableSeniorities() {
    return allDoctors
        .map((doctor) => doctor.seniority)
        .where((seniority) => seniority != null && seniority.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  /// Refresh data from session provider
  Future<void> refreshData() async {
    await _sessionProvider.refreshSharedData();
    _applyFilters();
    notifyListeners();
  }

  // ==================== STATE MANAGEMENT HELPERS ====================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    print('Doctor Provider Error: $error');
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    print('Doctor Provider Success: $message');
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear success message
  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  /// Clear all messages
  void clearAllMessages() {
    _clearMessages();
    notifyListeners();
  }

  // ==================== STATISTICS AND ANALYTICS ====================

  /// Get doctor statistics
  Map<String, dynamic> getDoctorStatistics() {
    final doctors = allDoctors;
    final specializations = <String, int>{};
    final seniorities = <String, int>{};

    for (final doctor in doctors) {
      // Count specializations
      if (doctor.specialization != null && doctor.specialization!.isNotEmpty) {
        specializations[doctor.specialization!] =
            (specializations[doctor.specialization!] ?? 0) + 1;
      }

      // Count seniorities
      if (doctor.seniority != null && doctor.seniority!.isNotEmpty) {
        seniorities[doctor.seniority!] =
            (seniorities[doctor.seniority!] ?? 0) + 1;
      }
    }

    return {
      'totalDoctors': doctors.length,
      'totalSpecializations': specializations.length,
      'specializationBreakdown': specializations,
      'seniorityBreakdown': seniorities,
      'filteredCount': displayedDoctors.length,
      'selectedCount': selectionCount,
    };
  }

  // ==================== DEBUG METHODS ====================

  /// Get provider state info for debugging
  Map<String, dynamic> getProviderInfo() {
    return {
      'totalDoctors': allDoctors.length,
      'displayedDoctors': displayedDoctors.length,
      'searchQuery': _searchQuery,
      'specializationFilter': _selectedSpecializationFilter,
      'seniorityFilter': _selectedSeniorityFilter,
      'selectedCount': selectionCount,
      'isLoading': _isLoading,
      'isEditing': _isEditing,
      'viewMode': _viewMode.toString(),
      'sortColumn': _sortColumn,
      'sortAscending': _sortAscending,
    };
  }

  /// Print provider status
  void printProviderStatus() {
    print('Doctor Provider Status: ${getProviderInfo()}');
  }
}