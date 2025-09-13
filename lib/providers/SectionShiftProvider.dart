import 'package:flutter/foundation.dart';
import '../core/models/Doctor.dart';
import '../core/models/SectionShift.dart';
import '../db/DBHelper.dart';
import 'ScheduleSessionProvider.dart';


class SectionShiftProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ScheduleSessionProvider _sessionProvider;

  SectionShiftProvider(this._sessionProvider);

  // ==================== FORM STATE ====================

  String? _selectedSpecialization;
  int? _selectedDoctorId;
  List<String> _selectedDates = [];

  // ==================== UI STATE ====================

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // ==================== DATA STATE ====================

  List<Doctor> _doctorsForSelectedSpecialization = [];
  List<SectionShift> _currentSessionSectionShifts = [];

  // ==================== GETTERS ====================

  // Form State Getters
  String? get selectedSpecialization => _selectedSpecialization;
  int? get selectedDoctorId => _selectedDoctorId;
  List<String> get selectedDates => List.unmodifiable(_selectedDates);

  // UI State Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Data Getters
  List<Doctor> get doctorsForSelectedSpecialization => List.unmodifiable(_doctorsForSelectedSpecialization);
  List<SectionShift> get currentSessionSectionShifts => List.unmodifiable(_currentSessionSectionShifts);

  // Session State from ScheduleSessionProvider
  String? get currentMonth => _sessionProvider.currentMonth;
  bool get isSessionActive => _sessionProvider.isSessionActive;
  List<String> get availableSpecializations => _sessionProvider.availableSpecializations;
  List<Doctor> get allDoctors => _sessionProvider.getAllSessionDoctors();

  // Computed Properties
  bool get canSave => _selectedDoctorId != null && _selectedDates.isNotEmpty && isSessionActive;
  bool get hasUnsavedData => _selectedSpecialization != null || _selectedDoctorId != null || _selectedDates.isNotEmpty;
  int get totalSectionShiftsCount => _currentSessionSectionShifts.length;
  bool get hasCompletedSectionShifts => _currentSessionSectionShifts.isNotEmpty;

  // ==================== INITIALIZATION ====================

  /// Initialize provider for current session
  void initializeForSession() {
    if (!isSessionActive) {
      _setError('No active session. Please start a session first.');
      return;
    }

    _clearFormData();
    _loadExistingSectionShifts();
    _clearMessages();
    notifyListeners();
  }
// Add these methods to your SectionShiftProvider class:

  /// Get specializations that still have unassigned doctors
  List<String> getAvailableSpecializationsWithDoctors() {
    final assignedDoctorIds = _currentSessionSectionShifts
        .map((shift) => shift.doctorId)
        .toSet();

    return availableSpecializations.where((specialization) {
      final doctorsInSpec = _sessionProvider.getDoctorsForSpecialization(specialization);
      // Check if any doctor in this specialization is still unassigned
      return doctorsInSpec.any((doctor) =>
      doctor.id != null && !assignedDoctorIds.contains(doctor.id));
    }).toList();
  }

  /// Get count of available (unassigned) doctors for a specific specialization
  int getAvailableDoctorCountForSpecialization(String specialization) {
    if (specialization.isEmpty) return 0;

    final assignedDoctorIds = _currentSessionSectionShifts
        .map((shift) => shift.doctorId)
        .toSet();

    final doctorsInSpecialization = _sessionProvider.getDoctorsForSpecialization(specialization);

    return doctorsInSpecialization
        .where((doctor) => doctor.id != null && !assignedDoctorIds.contains(doctor.id))
        .length;
  }
  /// Get unassigned doctors for a specific specialization
  List<Doctor> getAvailableDoctorsForSpecialization(String specialization) {
    if (specialization.isEmpty) return [];

    final assignedDoctorIds = _currentSessionSectionShifts
        .map((shift) => shift.doctorId)
        .toSet();

    final doctorsInSpec = _sessionProvider.getDoctorsForSpecialization(specialization);

    return doctorsInSpec.where((doctor) =>
    doctor.id != null && !assignedDoctorIds.contains(doctor.id)).toList();
  }
  /// Load existing section shifts for current session
  Future<void> _loadExistingSectionShifts() async {
    if (currentMonth == null) return;

    try {
      _currentSessionSectionShifts = await _dbHelper.getSectionShiftsByMonth(currentMonth!);

      // Update session provider with current count
      _sessionProvider.updateSectionShiftsProgress(_currentSessionSectionShifts.length);

    } catch (e) {
      _setError('Failed to load existing section shifts: $e');
    }
  }

  // ==================== SPECIALIZATION MANAGEMENT ====================

// Add these methods to your SectionShiftProvider class:

  /// Update the date of a specific section shift
  Future<bool> updateSectionShiftDate(int shiftId, String newDate) async {
    if (!_validateSession()) return false;

    _setLoading(true);

    try {
      // Validate the new date
      if (!_validateDate(newDate)) return false;

      // Check if the shift exists
      final shift = _currentSessionSectionShifts.firstWhere(
            (s) => s.id == shiftId,
        orElse: () => throw Exception('Shift not found'),
      );

      // Check for duplicate (same doctor on same date)
      final existingShift = await _checkForDuplicateShift(shift.doctorId, newDate);
      if (existingShift) {
        _setError('Doctor already has a shift on $newDate');
        return false;
      }

      // Update in database
      final updatedShift = SectionShift(
        id: shiftId,
        doctorId: shift.doctorId,
        date: newDate,
        // Add other properties as needed
      );

      await _dbHelper.updateSectionShift(updatedShift);

      // Update local state
      final index = _currentSessionSectionShifts.indexWhere((s) => s.id == shiftId);
      if (index != -1) {
        _currentSessionSectionShifts[index] = updatedShift;
      }

      // Update session provider progress
      _sessionProvider.updateSectionShiftsProgress(_currentSessionSectionShifts.length);

      _setSuccess('Shift date updated successfully');
      return true;

    } catch (e) {
      _setError('Failed to update shift date: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a specific section shift
  Future<bool> deleteSectionShift(int shiftId) async {
    if (!_validateSession()) return false;

    _setLoading(true);

    try {
      // Delete from database
      await _dbHelper.deleteSectionShift(shiftId);

      // Remove from local state
      _currentSessionSectionShifts.removeWhere((shift) => shift.id == shiftId);

      // Update session provider progress
      _sessionProvider.updateSectionShiftsProgress(_currentSessionSectionShifts.length);

      // Re-check step completion
      _checkStepCompletion();

      _setSuccess('Section shift deleted successfully');
      return true;

    } catch (e) {
      _setError('Failed to delete section shift: $e');
      return false;
    } finally {
      _setLoading(false);
    }
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

  /// Check for duplicate shift (same doctor on same date)
  Future<bool> _checkForDuplicateShift(int doctorId, String date) async {
    try {
      // Check in current session shifts
      final hasLocal = _currentSessionSectionShifts.any(
            (shift) => shift.doctorId == doctorId && shift.date == date,
      );

      if (hasLocal) return true;

      // Check in database (in case of concurrent modifications)
      final hasInDb = await _dbHelper.doctorHasShiftOnDate(doctorId, date);
      return hasInDb;

    } catch (e) {
      print('Error checking for duplicate shift: $e');
      return false;
    }
  }

  /// Validate date format and constraints
  bool _validateDate(String date) {
    // Check date format (YYYY-MM-DD)
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(date)) {
      _setError('Invalid date format. Use YYYY-MM-DD format.');
      return false;
    }

    // Check if date belongs to current month
    if (currentMonth != null && !date.startsWith(currentMonth!)) {
      _setError('Date must be in the current session month ($currentMonth).');
      return false;
    }

    // Check if date is not in the past (optional)
    final selectedDate = DateTime.parse(date);
    final today = DateTime.now();
    if (selectedDate.isBefore(DateTime(today.year, today.month, today.day))) {
      _setError('Cannot select past dates.');
      return false;
    }

    return true;
  }

  /// Validate session state
  bool _validateSession() {
    if (!isSessionActive) {
      _setError('No active session. Please start a session first.');
      return false;
    }
    return true;
  }

  /// Check if step should be marked complete
  void _checkStepCompletion() {
    // Step 1: Insert Section Shifts - complete when any shifts added
    bool step1Complete = _currentSessionSectionShifts.isNotEmpty;
    _sessionProvider.markStepCompleted(ScheduleStep.insertSectionShifts, step1Complete);

    // Step 2: View Section Shifts - complete when minimum threshold reached
    bool step2Complete = _hasMetViewStepCriteria();
    _sessionProvider.markStepCompleted(ScheduleStep.viewSectionShifts, step2Complete);
  }

  /// Check if view step completion criteria are met
  bool _hasMetViewStepCriteria() {
    if (_currentSessionSectionShifts.isEmpty) return false;

    // Option 1: Minimum number of shifts (e.g., at least 5)
    if (_currentSessionSectionShifts.length < 5) return false;

    // Option 2: All specializations have at least one shift
    Set<String> specializationsWithShifts = {};
    for (var shift in _currentSessionSectionShifts) {
      final doctor = allDoctors.firstWhere(
            (d) => d.id == shift.doctorId,
        orElse: () => Doctor(id: shift.doctorId, name: '', specialization: '', seniority: ''),
      );
      if (doctor.specialization != null && doctor.specialization!.isNotEmpty) {
        specializationsWithShifts.add(doctor.specialization!);
      }
    }

    // Check if at least 50% of specializations are covered
    return specializationsWithShifts.length >= (availableSpecializations.length * 0.5);
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    print('❌ SectionShift Error: $error');
    notifyListeners();
  }

  /// Set success message
  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    print('✅ SectionShift Success: $message');
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  /// Set selected specialization and load doctors
  Future<void> setSelectedSpecialization(String? specialization) async {
    if (!_validateSession()) return;

    _setLoading(true);
    _clearMessages();

    try {
      _selectedSpecialization = specialization;
      _selectedDoctorId = null; // Reset doctor selection
      _doctorsForSelectedSpecialization.clear();

      if (specialization != null) {
        _loadDoctorsForSpecialization(specialization);
      }

    } catch (e) {
      _setError('Failed to load doctors for specialization: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load doctors for selected specialization
  void _loadDoctorsForSpecialization(String specialization) {
    try {
      _doctorsForSelectedSpecialization = _sessionProvider.getDoctorsForSpecialization(specialization);

      if (_doctorsForSelectedSpecialization.isEmpty) {
        _setError('No doctors found for $specialization specialization.');
      }

    } catch (e) {
      _setError('Failed to load doctors: $e');
      _doctorsForSelectedSpecialization.clear();
    }
  }

  // ==================== DOCTOR MANAGEMENT ====================

  /// Set selected doctor
  void setSelectedDoctorId(int? doctorId) {
    if (!_validateSession()) return;

    _selectedDoctorId = doctorId;
    _clearMessages();
    notifyListeners();
  }

  /// Get selected doctor object
  Doctor? getSelectedDoctor() {
    if (_selectedDoctorId == null) return null;

    return _doctorsForSelectedSpecialization
        .where((doctor) => doctor.id == _selectedDoctorId)
        .firstOrNull;
  }

  // ==================== DATE MANAGEMENT ====================

  /// Add a date to the selected dates list
  void addDate(String date) {
    if (!_validateSession()) return;

    if (!_validateDate(date)) return;

    if (!_selectedDates.contains(date)) {
      _selectedDates.add(date);
      _selectedDates.sort(); // Keep dates sorted
      _clearMessages();
      notifyListeners();
    } else {
      _setError('Date $date is already selected.');
    }
  }

  /// Remove a date from the selected dates list
  void removeDate(String date) {
    if (!_validateSession()) return;

    _selectedDates.remove(date);
    _clearMessages();
    notifyListeners();
  }

  /// Update a date at specific index
  void updateDate(int index, String newDate) {
    if (!_validateSession()) return;

    if (!_validateDate(newDate)) return;

    if (index >= 0 && index < _selectedDates.length) {
      // Check if new date is already in list (excluding current index)
      final tempList = List<String>.from(_selectedDates);
      tempList.removeAt(index);

      if (tempList.contains(newDate)) {
        _setError('Date $newDate is already selected.');
        return;
      }

      _selectedDates[index] = newDate;
      _selectedDates.sort(); // Keep dates sorted
      _clearMessages();
      notifyListeners();
    }
  }

  /// Clear all selected dates
  void clearDates() {
    _selectedDates.clear();
    _clearMessages();
    notifyListeners();
  }

  /// Check if date is already selected
  bool isDateSelected(String date) {
    return _selectedDates.contains(date);
  }

  /// Validate date format and constraints


  // ==================== SAVE OPERATIONS ====================

  /// Save section shifts for selected doctor and dates
  Future<bool> saveSectionShifts() async {
    if (!_validateSession()) return false;
    if (!_validateSaveConditions()) return false;

    _setLoading(true);
    _clearMessages();

    try {
      final doctor = getSelectedDoctor();
      if (doctor == null) {
        _setError('Selected doctor not found.');
        return false;
      }

      List<SectionShift> newShifts = [];

      // Create section shifts for each selected date
      for (String date in _selectedDates) {
        // Check for duplicates
        final existingShift = await _checkForDuplicateShift(doctor.id!, date);
        if (existingShift) {
          _setError('Section shift for ${doctor.name} on $date already exists.');
          return false;
        }

        final sectionShift = SectionShift(
          doctorId: doctor.id!,
          date: date,
        );

        final id = await _dbHelper.insertSectionShift(sectionShift);

        if (id > 0) {
          newShifts.add(SectionShift(
            id: id,
            doctorId: doctor.id!,
            date: date,
          ));
        }
      }

      if (newShifts.isNotEmpty) {
        // Add to current session
        _currentSessionSectionShifts.addAll(newShifts);

        // Update session provider with new count
        _sessionProvider.updateSectionShiftsProgress(_currentSessionSectionShifts.length);

        // Mark specialization as processed
        if (_selectedSpecialization != null) {
          _sessionProvider.addProcessedSpecialization(_selectedSpecialization!);
        }

        // Clear form data for next entry
        _clearFormData();

        _setSuccess('Successfully added ${newShifts.length} section shifts for ${doctor.name}');

        // Check if this step should be marked as completed
        _checkStepCompletion();

        return true;
      } else {
        _setError('Failed to save section shifts.');
        return false;
      }

    } catch (e) {
      _setError('Failed to save section shifts: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check for duplicate section shift


  /// Validate conditions before saving
  bool _validateSaveConditions() {
    if (_selectedDoctorId == null) {
      _setError('Please select a doctor.');
      return false;
    }

    if (_selectedDates.isEmpty) {
      _setError('Please add at least one date.');
      return false;
    }

    if (_selectedSpecialization == null) {
      _setError('Please select a specialization.');
      return false;
    }

    return true;
  }

  // ==================== BULK OPERATIONS ====================

  /// Clear current form data but keep session active
  void resetCurrentForm() {
    _clearFormData();
    _clearMessages();
    notifyListeners();
  }

  // ==================== DATA RETRIEVAL ====================

  /// Get section shifts for a specific doctor in current session
  List<SectionShift> getSectionShiftsForDoctor(int doctorId) {
    return _currentSessionSectionShifts
        .where((shift) => shift.doctorId == doctorId)
        .toList();
  }

  /// Get section shifts for a specific date in current session
  List<SectionShift> getSectionShiftsForDate(String date) {
    return _currentSessionSectionShifts
        .where((shift) => shift.date == date)
        .toList();
  }

  /// Get unique dates with section shifts
  List<String> getUniqueDatesWithShifts() {
    return _currentSessionSectionShifts
        .map((shift) => shift.date)
        .toSet()
        .toList()
      ..sort();
  }

  /// Get unique doctors with section shifts
  List<Doctor> getUniqueDoctorsWithShifts() {
    final doctorIds = _currentSessionSectionShifts
        .map((shift) => shift.doctorId)
        .toSet();

    return allDoctors
        .where((doctor) => doctorIds.contains(doctor.id))
        .toList();
  }

  // ==================== STATISTICS ====================

  /// Get statistics for current session
  Map<String, dynamic> getSessionStatistics() {
    final shiftsGroupedByDoctor = <int, List<SectionShift>>{};
    final shiftsGroupedByDate = <String, List<SectionShift>>{};
    final shiftsGroupedBySpecialization = <String, List<SectionShift>>{};

    for (final shift in _currentSessionSectionShifts) {
      // Group by doctor
      shiftsGroupedByDoctor.putIfAbsent(shift.doctorId, () => []).add(shift);

      // Group by date
      shiftsGroupedByDate.putIfAbsent(shift.date, () => []).add(shift);

      // Group by specialization
      final doctor = allDoctors.where((d) => d.id == shift.doctorId).firstOrNull;
      if (doctor?.specialization != null) {
        shiftsGroupedBySpecialization
            .putIfAbsent(doctor!.specialization!, () => [])
            .add(shift);
      }
    }

    return {
      'totalShifts': _currentSessionSectionShifts.length,
      'uniqueDoctors': shiftsGroupedByDoctor.keys.length,
      'uniqueDates': shiftsGroupedByDate.keys.length,
      'uniqueSpecializations': shiftsGroupedBySpecialization.keys.length,
      'currentMonth': currentMonth,
      'isSessionActive': isSessionActive,
      'shiftsPerDoctor': shiftsGroupedByDoctor.map(
            (doctorId, shifts) => MapEntry(doctorId, shifts.length),
      ),
      'shiftsPerSpecialization': shiftsGroupedBySpecialization.map(
            (spec, shifts) => MapEntry(spec, shifts.length),
      ),
    };
  }

  // ==================== VALIDATION ====================

  /// Validate session state


  // ==================== HELPER METHODS ====================

  /// Clear form data
  void _clearFormData() {
    _selectedSpecialization = null;
    _selectedDoctorId = null;
    _selectedDates.clear();
    _doctorsForSelectedSpecialization.clear();
  }

  /// Set loading state


  /// Clear all messages
  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }



  /// Clear all messages publicly
  void clearAllMessages() {
    _clearMessages();
    notifyListeners();
  }

  // ==================== DEBUG METHODS ====================

  /// Get provider state for debugging
  Map<String, dynamic> getProviderInfo() {
    return {
      'selectedSpecialization': _selectedSpecialization,
      'selectedDoctorId': _selectedDoctorId,
      'selectedDatesCount': _selectedDates.length,
      'doctorsForSpecialization': _doctorsForSelectedSpecialization.length,
      'currentSessionShifts': _currentSessionSectionShifts.length,
      'currentMonth': currentMonth,
      'isSessionActive': isSessionActive,
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
      'hasSuccess': _successMessage != null,
      'canSave': canSave,
    };
  }

  /// Print provider status
  void printProviderStatus() {
    print('SectionShift Provider Status: ${getProviderInfo()}');
  }
}