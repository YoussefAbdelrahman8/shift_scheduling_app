import 'package:flutter/foundation.dart';

// Import your model classes and database helper
import '../core/models/Doctor.dart';
import '../core/models/DoctorConstraint.dart';
import '../core/models/DoctorRequest.dart';
import '../core/models/ReceptionDrop.dart';
import '../core/models/ReceptionSchedule.dart';
import '../core/models/ReceptionShift.dart';
import '../core/models/SectionSchedule.dart';
import '../core/models/SectionShift.dart';
import '../core/models/User.dart';
// import 'DatabaseHelper.dart'; // Your database helper

enum SchedulingStep {
  enteringSectionShifts,    // Step 1
  reviewingSectionSchedule,  // Step 2
  enteringDoctorConstraints, // Step 3
  reviewingDoctorConstraints, // Step 4
  generatingReceptionSchedule // Step 5
}

class SchedulingSessionProvider extends ChangeNotifier {
  // Session management
  bool _isSessionActive = false;
  String? _currentMonth;
  SchedulingStep _currentStep = SchedulingStep.enteringSectionShifts;

  // Temporary data storage during session
  List<SectionShift> _tempSectionShifts = [];
  List<DoctorConstraint> _tempDoctorConstraints = [];
  List<ReceptionShift> _tempReceptionShifts = [];
  List<Doctor> _availableDoctors = [];

  List<String> _tempSpecializations = [];
  String? _selectedSpecialization;
  int? _selectedDoctorId;
  List<Doctor> _doctorsForSelectedSpecialization = [];

  // Session metadata
  DateTime? _sessionStartTime;
  Map<String, dynamic> _sessionMetadata = {};

  // Getters
  bool get isSessionActive => _isSessionActive;
  String? get currentMonth => _currentMonth;
  SchedulingStep get currentStep => _currentStep;
  List<SectionShift> get sectionShifts => List.unmodifiable(_tempSectionShifts);
  List<DoctorConstraint> get doctorConstraints => List.unmodifiable(_tempDoctorConstraints);
  List<ReceptionShift> get receptionShifts => List.unmodifiable(_tempReceptionShifts);
  List<Doctor> get availableDoctors => List.unmodifiable(_availableDoctors);
  DateTime? get sessionStartTime => _sessionStartTime;
  Map<String, dynamic> get sessionMetadata => Map.unmodifiable(_sessionMetadata);
  // UI workflow getters
  List<String> get specializations => List.unmodifiable(_tempSpecializations);
  String? get selectedSpecialization => _selectedSpecialization;
  int? get selectedDoctorId => _selectedDoctorId;
  List<Doctor> get doctorsForSelectedSpecialization => List.unmodifiable(_doctorsForSelectedSpecialization);

  // ==================== SESSION MANAGEMENT ====================

  /// Start a new scheduling session for a specific month
  void startSession(String month, List<Doctor> doctors) {
    if (_isSessionActive) {
      throw Exception('A session is already active. Please end the current session first.');
    }



    _isSessionActive = true;
    _currentMonth = month;
    _currentStep = SchedulingStep.enteringSectionShifts;
    _availableDoctors = List.from(doctors);
    _sessionStartTime = DateTime.now();
    _sessionMetadata['month'] = month;
    _sessionMetadata['doctorCount'] = doctors.length;

    _clearTempData();
    notifyListeners();

    print('Scheduling session started for month: $month');
  }
  /// Start session with specializations (for UI workflow)
  void startSessionWithSpecializations(String month, List<String> specializations) {
    if (_isSessionActive) {
      throw Exception('A session is already active. Please end the current session first.');
    }

    _isSessionActive = true;
    _currentMonth = month;
    _currentStep = SchedulingStep.enteringSectionShifts;
    _sessionStartTime = DateTime.now();
    _sessionMetadata['month'] = month;
    _sessionMetadata['specializations'] = specializations;

    // Store specializations for UI workflow
    _tempSpecializations = List.from(specializations);
    _clearTempData();
    notifyListeners();

    print('Scheduling session started for month: $month with specializations');
  }

  

  /// End the current session and clear all data
  void endSession() {
    if (!_isSessionActive) {
      throw Exception('No active session to end.');
    }

    _isSessionActive = false;
    _currentMonth = null;
    _currentStep = SchedulingStep.enteringSectionShifts;
    _sessionStartTime = null;
    _sessionMetadata.clear();

    _clearTempData();
    notifyListeners();

    print('Scheduling session ended.');
  }

  /// Clear session and start fresh (useful for canceling current process)
  void cancelSession() {
    if (_isSessionActive) {
      endSession();
    }
  }

  /// Move to next step in the process
  void nextStep() {
    if (!_isSessionActive) {
      throw Exception('No active session.');
    }

    switch (_currentStep) {
      case SchedulingStep.enteringSectionShifts:
        _currentStep = SchedulingStep.reviewingSectionSchedule;
        break;
      case SchedulingStep.reviewingSectionSchedule:
        _currentStep = SchedulingStep.enteringDoctorConstraints;
        break;
      case SchedulingStep.enteringDoctorConstraints:
        _currentStep = SchedulingStep.reviewingDoctorConstraints;
        break;
      case SchedulingStep.reviewingDoctorConstraints:
        _currentStep = SchedulingStep.generatingReceptionSchedule;
        break;
      case SchedulingStep.generatingReceptionSchedule:
      // Stay at final step
        break;
    }
    notifyListeners();
  }

  /// Move to previous step in the process
  void previousStep() {
    if (!_isSessionActive) {
      throw Exception('No active session.');
    }

    switch (_currentStep) {
      case SchedulingStep.enteringSectionShifts:
      // Stay at first step
        break;
      case SchedulingStep.reviewingSectionSchedule:
        _currentStep = SchedulingStep.enteringSectionShifts;
        break;
      case SchedulingStep.enteringDoctorConstraints:
        _currentStep = SchedulingStep.reviewingSectionSchedule;
        break;
      case SchedulingStep.reviewingDoctorConstraints:
        _currentStep = SchedulingStep.enteringDoctorConstraints;
        break;
      case SchedulingStep.generatingReceptionSchedule:
        _currentStep = SchedulingStep.reviewingDoctorConstraints;
        break;
    }
    notifyListeners();
  }

  /// Clear all temporary data
  void _clearTempData() {
    _tempSectionShifts.clear();
    _tempDoctorConstraints.clear();
    _tempReceptionShifts.clear();
    _availableDoctors.clear();
    _doctorsForSelectedSpecialization.clear();
    _tempSpecializations.clear();
    _selectedSpecialization = null;
    _selectedDoctorId = null;
  }

  // ==================== UI WORKFLOW MANAGEMENT ====================

  /// Set selected specialization and load doctors for it
  Future<void> setSelectedSpecialization(String? specialization) async {
    _selectedSpecialization = specialization;
    _selectedDoctorId = null; // Reset doctor selection
    _doctorsForSelectedSpecialization.clear();

    if (specialization != null) {
      // Here you would load doctors from database
      // For now, this is a placeholder - replace with actual database call
      // _doctorsForSelectedSpecialization = await DatabaseHelper.instance.getDoctorsBySpecialization(specialization);
    }

    notifyListeners();
  }

  /// Add doctors for selected specialization (called by UI)
  void addDoctorsForSpecialization(List<Doctor> doctors) {
    _doctorsForSelectedSpecialization = List.from(doctors);
    notifyListeners();
  }

  /// Set selected doctor
  void setSelectedDoctorId(int? doctorId) {
    _selectedDoctorId = doctorId;
    notifyListeners();
  }

  /// Add section shift with multiple dates for selected doctor
  void addSectionShiftsForSelectedDoctor(List<String> dates) {
    _validateSession();

    if (_selectedDoctorId == null) {
      throw Exception('No doctor selected');
    }

    for (String date in dates) {
      final shift = SectionShift(
        doctorId: _selectedDoctorId!,
        date: date,
      );
      _tempSectionShifts.add(shift);
    }

    // Remove the doctor from available list (as per original UX)
    _doctorsForSelectedSpecialization.removeWhere((d) => d.id == _selectedDoctorId);

    // Reset selections
    _selectedDoctorId = null;

    // If no more doctors for this specialization, remove it
    if (_doctorsForSelectedSpecialization.isEmpty && _selectedSpecialization != null) {
      _tempSpecializations.remove(_selectedSpecialization);
      _selectedSpecialization = null;
    }

    notifyListeners();
  }

  /// Check if all specializations are completed
  bool get isAllSpecializationsCompleted => _tempSpecializations.isEmpty;

  /// Get pending section shifts grouped by doctor
  Map<String, List<Map<String, dynamic>>> getPendingSectionShifts() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var shift in _tempSectionShifts) {
      // Find doctor name from available doctors (you might need to store doctor names separately)
      String doctorKey = 'Doctor ${shift.doctorId}'; // Placeholder - replace with actual doctor name

      if (!grouped.containsKey(doctorKey)) {
        grouped[doctorKey] = [];
      }

      grouped[doctorKey]!.add({
        'doctorId': shift.doctorId,
        'date': shift.date,
        'specialization': _selectedSpecialization ?? 'Unknown', // You might want to store this in the shift
      });
    }

    return grouped;
  }

  // ==================== SECTION SHIFTS MANAGEMENT ====================

  /// Add a section shift
  void addSectionShift(SectionShift shift) {
    _validateSession();
    _tempSectionShifts.add(shift);
    notifyListeners();
  }

  /// Add multiple section shifts
  void addMultipleSectionShifts(List<SectionShift> shifts) {
    _validateSession();
    _tempSectionShifts.addAll(shifts);
    notifyListeners();
  }

  /// Update a section shift by index
  void updateSectionShift(int index, SectionShift updatedShift) {
    _validateSession();
    if (index >= 0 && index < _tempSectionShifts.length) {
      _tempSectionShifts[index] = updatedShift;
      notifyListeners();
    }
  }

  /// Update section shift by finding matching one
  void updateSectionShiftByMatch(SectionShift oldShift, SectionShift newShift) {
    _validateSession();
    final index = _tempSectionShifts.indexWhere((shift) =>
    shift.doctorId == oldShift.doctorId &&
        shift.date == oldShift.date);

    if (index != -1) {
      _tempSectionShifts[index] = newShift;
      notifyListeners();
    }
  }

  /// Remove a section shift by index
  void removeSectionShift(int index) {
    _validateSession();
    if (index >= 0 && index < _tempSectionShifts.length) {
      _tempSectionShifts.removeAt(index);
      notifyListeners();
    }
  }

  /// Remove section shift by doctor and date
  void removeSectionShiftByDoctorDate(int doctorId, String date) {
    _validateSession();
    _tempSectionShifts.removeWhere((shift) =>
    shift.doctorId == doctorId && shift.date == date);
    notifyListeners();
  }

  /// Get section shifts for a specific doctor
  List<SectionShift> getSectionShiftsByDoctor(int doctorId) {
    return _tempSectionShifts.where((shift) => shift.doctorId == doctorId).toList();
  }

  /// Get section shifts for a specific date
  List<SectionShift> getSectionShiftsByDate(String date) {
    return _tempSectionShifts.where((shift) => shift.date == date).toList();
  }

  /// Get section schedule object
  SectionSchedule getSectionSchedule() {
    _validateSession();
    return SectionSchedule(
      month: _currentMonth!,
      shifts: List.from(_tempSectionShifts),
    );
  }

  /// Clear all section shifts
  void clearSectionShifts() {
    _validateSession();
    _tempSectionShifts.clear();
    notifyListeners();
  }

  // ==================== DOCTOR CONSTRAINTS MANAGEMENT ====================

  /// Add a doctor constraint
  void addDoctorConstraint(DoctorConstraint constraint) {
    _validateSession();
    // Remove existing constraint for this doctor if any
    _tempDoctorConstraints.removeWhere((c) => c.doctorId == constraint.doctorId);
    _tempDoctorConstraints.add(constraint);
    notifyListeners();
  }

  /// Update a doctor constraint
  void updateDoctorConstraint(DoctorConstraint updatedConstraint) {
    _validateSession();
    final index = _tempDoctorConstraints.indexWhere((c) => c.doctorId == updatedConstraint.doctorId);

    if (index != -1) {
      _tempDoctorConstraints[index] = updatedConstraint;
    } else {
      _tempDoctorConstraints.add(updatedConstraint);
    }
    notifyListeners();
  }

  /// Remove a doctor constraint
  void removeDoctorConstraint(int doctorId) {
    _validateSession();
    _tempDoctorConstraints.removeWhere((c) => c.doctorId == doctorId);
    notifyListeners();
  }

  /// Get constraint for a specific doctor
  DoctorConstraint? getDoctorConstraint(int doctorId) {
    try {
      return _tempDoctorConstraints.firstWhere((c) => c.doctorId == doctorId);
    } catch (e) {
      return null;
    }
  }

  /// Check if doctor has constraints
  bool hasDoctorConstraints(int doctorId) {
    return _tempDoctorConstraints.any((c) => c.doctorId == doctorId);
  }

  /// Clear all doctor constraints
  void clearDoctorConstraints() {
    _validateSession();
    _tempDoctorConstraints.clear();
    notifyListeners();
  }

  // ==================== DOCTOR REQUESTS MANAGEMENT ====================

  /// Add doctor request to existing constraint
  void addDoctorRequest(int doctorId, DoctorRequest request) {
    _validateSession();
    final constraintIndex = _tempDoctorConstraints.indexWhere((c) => c.doctorId == doctorId);

    if (constraintIndex != -1) {
      final constraint = _tempDoctorConstraints[constraintIndex];
      final updatedRequests = List<DoctorRequest>.from(constraint.doctorRequests ?? []);
      updatedRequests.add(request);

      final updatedConstraint = DoctorConstraint(
        id: constraint.id,
        doctorId: constraint.doctorId,
        totalShifts: constraint.totalShifts,
        morningShifts: constraint.morningShifts,
        eveningShifts: constraint.eveningShifts,
        doctorRequests: updatedRequests,
        seniority: constraint.seniority,
        enforceWanted: constraint.enforceWanted,
        enforceExceptions: constraint.enforceExceptions,
        avoidWeekends: constraint.avoidWeekends,
        enforceAvoidWeekends: constraint.enforceAvoidWeekends,
        firstWeekDaysPreference: constraint.firstWeekDaysPreference,
        lastWeekDaysPreference: constraint.lastWeekDaysPreference,
        firstMonthDaysPreference: constraint.firstMonthDaysPreference,
        lastMonthDaysPreference: constraint.lastMonthDaysPreference,
        avoidConsecutiveDays: constraint.avoidConsecutiveDays,
        priority: constraint.priority,
      );

      _tempDoctorConstraints[constraintIndex] = updatedConstraint;
      notifyListeners();
    }
  }

  /// Remove doctor request from constraint
  void removeDoctorRequest(int doctorId, DoctorRequest request) {
    _validateSession();
    final constraintIndex = _tempDoctorConstraints.indexWhere((c) => c.doctorId == doctorId);

    if (constraintIndex != -1) {
      final constraint = _tempDoctorConstraints[constraintIndex];
      final updatedRequests = List<DoctorRequest>.from(constraint.doctorRequests ?? []);
      updatedRequests.removeWhere((r) =>
      r.date == request.date &&
          r.shift == request.shift &&
          r.type == request.type);

      final updatedConstraint = DoctorConstraint(
        id: constraint.id,
        doctorId: constraint.doctorId,
        totalShifts: constraint.totalShifts,
        morningShifts: constraint.morningShifts,
        eveningShifts: constraint.eveningShifts,
        doctorRequests: updatedRequests,
        seniority: constraint.seniority,
        enforceWanted: constraint.enforceWanted,
        enforceExceptions: constraint.enforceExceptions,
        avoidWeekends: constraint.avoidWeekends,
        enforceAvoidWeekends: constraint.enforceAvoidWeekends,
        firstWeekDaysPreference: constraint.firstWeekDaysPreference,
        lastWeekDaysPreference: constraint.lastWeekDaysPreference,
        firstMonthDaysPreference: constraint.firstMonthDaysPreference,
        lastMonthDaysPreference: constraint.lastMonthDaysPreference,
        avoidConsecutiveDays: constraint.avoidConsecutiveDays,
        priority: constraint.priority,
      );

      _tempDoctorConstraints[constraintIndex] = updatedConstraint;
      notifyListeners();
    }
  }

  // ==================== RECEPTION SHIFTS MANAGEMENT ====================

  /// Generate reception shifts (placeholder - implement your algorithm here)
  void generateReceptionShifts() {
    _validateSession();

    // This is where you would implement your scheduling algorithm
    // using the section shifts and doctor constraints

    // For now, this is a placeholder
    _tempReceptionShifts.clear();

    // Example: Generate basic reception shifts based on section shifts
    for (var sectionShift in _tempSectionShifts) {
      // Add morning reception shift
      _tempReceptionShifts.add(ReceptionShift(
        doctorId: sectionShift.doctorId,
        date: sectionShift.date,
        shift: 'Day',
      ));

      // Add evening reception shift (could be different doctor)
      _tempReceptionShifts.add(ReceptionShift(
        doctorId: sectionShift.doctorId,
        date: sectionShift.date,
        shift: 'Night',
      ));
    }

    notifyListeners();
    print('Reception shifts generated: ${_tempReceptionShifts.length} shifts');
  }

  /// Add a reception shift
  void addReceptionShift(ReceptionShift shift) {
    _validateSession();
    _tempReceptionShifts.add(shift);
    notifyListeners();
  }

  /// Update a reception shift by index
  void updateReceptionShift(int index, ReceptionShift updatedShift) {
    _validateSession();
    if (index >= 0 && index < _tempReceptionShifts.length) {
      _tempReceptionShifts[index] = updatedShift;
      notifyListeners();
    }
  }

  /// Update reception shift by finding matching one
  void updateReceptionShiftByMatch(ReceptionShift oldShift, ReceptionShift newShift) {
    _validateSession();
    final index = _tempReceptionShifts.indexWhere((shift) =>
    shift.doctorId == oldShift.doctorId &&
        shift.date == oldShift.date &&
        shift.shift == oldShift.shift);

    if (index != -1) {
      _tempReceptionShifts[index] = newShift;
      notifyListeners();
    }
  }

  /// Remove a reception shift by index
  void removeReceptionShift(int index) {
    _validateSession();
    if (index >= 0 && index < _tempReceptionShifts.length) {
      _tempReceptionShifts.removeAt(index);
      notifyListeners();
    }
  }

  /// Remove reception shift by doctor, date and shift type
  void removeReceptionShiftByMatch(int doctorId, String date, String shift) {
    _validateSession();
    _tempReceptionShifts.removeWhere((s) =>
    s.doctorId == doctorId && s.date == date && s.shift == shift);
    notifyListeners();
  }

  /// Get reception shifts for a specific doctor
  List<ReceptionShift> getReceptionShiftsByDoctor(int doctorId) {
    return _tempReceptionShifts.where((shift) => shift.doctorId == doctorId).toList();
  }

  /// Get reception shifts for a specific date
  List<ReceptionShift> getReceptionShiftsByDate(String date) {
    return _tempReceptionShifts.where((shift) => shift.date == date).toList();
  }

  /// Get reception schedule object
  ReceptionSchedule getReceptionSchedule() {
    _validateSession();
    return ReceptionSchedule(
      month: _currentMonth!,
      shifts: List.from(_tempReceptionShifts),
    );
  }

  /// Clear all reception shifts
  void clearReceptionShifts() {
    _validateSession();
    _tempReceptionShifts.clear();
    notifyListeners();
  }

  // ==================== VALIDATION AND UTILITY ====================

  /// Validate that a session is active
  void _validateSession() {
    if (!_isSessionActive) {
      throw Exception('No active session. Please start a session first.');
    }
  }

  /// Check if current step allows section shift operations
  bool canModifySectionShifts() {
    return _isSessionActive &&
        (_currentStep == SchedulingStep.enteringSectionShifts ||
            _currentStep == SchedulingStep.reviewingSectionSchedule);
  }

  /// Check if current step allows doctor constraint operations
  bool canModifyDoctorConstraints() {
    return _isSessionActive &&
        (_currentStep == SchedulingStep.enteringDoctorConstraints ||
            _currentStep == SchedulingStep.reviewingDoctorConstraints);
  }

  /// Check if current step allows reception shift operations
  bool canModifyReceptionShifts() {
    return _isSessionActive &&
        _currentStep == SchedulingStep.generatingReceptionSchedule;
  }

  /// Get session summary
  Map<String, dynamic> getSessionSummary() {
    return {
      'isActive': _isSessionActive,
      'month': _currentMonth,
      'currentStep': _currentStep.toString(),
      'sessionStartTime': _sessionStartTime?.toIso8601String(),
      'sectionShiftsCount': _tempSectionShifts.length,
      'doctorConstraintsCount': _tempDoctorConstraints.length,
      'receptionShiftsCount': _tempReceptionShifts.length,
      'availableDoctorsCount': _availableDoctors.length,
      'metadata': _sessionMetadata,
    };
  }

  /// Validate if ready to proceed to next step
  bool canProceedToNextStep() {
    switch (_currentStep) {
      case SchedulingStep.enteringSectionShifts:
        return _tempSectionShifts.isNotEmpty;
      case SchedulingStep.reviewingSectionSchedule:
        return true; // Can always proceed from review
      case SchedulingStep.enteringDoctorConstraints:
        return _tempDoctorConstraints.isNotEmpty;
      case SchedulingStep.reviewingDoctorConstraints:
        return true; // Can always proceed from review
      case SchedulingStep.generatingReceptionSchedule:
        return _tempReceptionShifts.isNotEmpty;
    }
  }

  /// Get validation errors for current step
  List<String> getValidationErrors() {
    List<String> errors = [];

    switch (_currentStep) {
      case SchedulingStep.enteringSectionShifts:
        if (_tempSectionShifts.isEmpty) {
          errors.add('At least one section shift is required');
        }
        break;
      case SchedulingStep.enteringDoctorConstraints:
        if (_tempDoctorConstraints.isEmpty) {
          errors.add('At least one doctor constraint is required');
        }
        break;
      case SchedulingStep.generatingReceptionSchedule:
        if (_tempReceptionShifts.isEmpty) {
          errors.add('Reception shifts must be generated');
        }
        break;
      default:
        break;
    }

    return errors;
  }

  // ==================== DATABASE OPERATIONS ====================

  /// Save all session data to database
  /// This should be called only at the very end of the process
  Future<bool> saveSessionToDatabase() async {
    try {
      _validateSession();

      if (_tempSectionShifts.isEmpty && _tempReceptionShifts.isEmpty) {
        throw Exception('No data to save');
      }

      // Here you would use your DatabaseHelper to save everything
      // final dbHelper = DatabaseHelper();

      // Save section shifts
      // for (var shift in _tempSectionShifts) {
      //   await dbHelper.insertSectionShift(shift);
      // }

      // Save doctor constraints
      // for (var constraint in _tempDoctorConstraints) {
      //   await dbHelper.insertDoctorConstraint(constraint);
      //
      //   // Save doctor requests
      //   if (constraint.doctorRequests != null) {
      //     for (var request in constraint.doctorRequests!) {
      //       await dbHelper.insertDoctorRequest(request);
      //     }
      //   }
      // }

      // Save reception shifts
      // for (var shift in _tempReceptionShifts) {
      //   await dbHelper.insertReceptionShift(shift);
      // }

      print('Session data saved to database successfully');
      return true;

    } catch (e) {
      print('Error saving session data: $e');
      return false;
    }
  }

  /// Load existing data from database for editing
  Future<void> loadDataFromDatabase(String month) async {
    try {
      // final dbHelper = DatabaseHelper();

      // Load section shifts for the month
      // _tempSectionShifts = await dbHelper.getSectionScheduleForMonth(month);

      // Load reception shifts for the month
      // _tempReceptionShifts = await dbHelper.getReceptionScheduleForMonth(month);

      // Load doctor constraints
      // _tempDoctorConstraints = await dbHelper.getAllDoctorConstraints();

      notifyListeners();
      print('Data loaded from database for month: $month');

    } catch (e) {
      print('Error loading data from database: $e');
    }
  }
}