import 'package:flutter/cupertino.dart';

import '../core/models/Doctor.dart';
import '../core/models/DoctorConstraint.dart';
import '../core/models/DoctorRequest.dart';
import '../core/models/ReceptionDrop.dart';
import '../db/DBHelper.dart';
import 'ScheduleSessionProvider.dart';

enum ConstraintEntryStage {
  selectDoctor,           // Select which doctor to configure
  basicConstraints,       // Enter total, morning, evening shifts
  dropDecision,          // Decide whether to drop shifts
  dropConfiguration,     // Configure drops if needed
  preferences,           // Enter constraint preferences (seniority, enforce options, etc.)
  wantedDays,           // Enter wanted days
  exceptionDays,        // Enter exception days
  completed,            // Doctor constraints fully configured
}

class DoctorConstraintProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ScheduleSessionProvider _sessionProvider;

  DoctorConstraintProvider(this._sessionProvider);

  // ==================== STATE VARIABLES ====================

  // Current workflow state
  int? _currentDoctorId;
  ConstraintEntryStage _currentStage = ConstraintEntryStage.selectDoctor;

  // Basic constraints (step 1)
  int _totalShifts = 0;
  int _morningShifts = 0;
  int _eveningShifts = 0;

  // Drop management
  List<Map<String, dynamic>> _pendingDrops = []; // Drops being configured
  Map<int, int> _calculatedShiftTotals = {}; // Final shift counts after drops

  // Preferences (after basic constraints)
  bool _seniority = false;
  bool _enforceWanted = false;
  bool _enforceExceptions = false;
  bool _avoidWeekends = false;
  bool _enforceAvoidWeekends = false;
  bool _firstWeekDaysPreference = false;
  bool _lastWeekDaysPreference = false;
  bool _firstMonthDaysPreference = false;
  bool _lastMonthDaysPreference = false;
  bool _avoidConsecutiveDays = false;
  int _priority = 0;

  // Wanted and exception days
  List<DoctorRequest> _wantedDays = [];
  List<DoctorRequest> _exceptionDays = [];

  // Data storage
  Map<int, DoctorConstraint> _doctorConstraints = {};
  Map<int, List<DoctorRequest>> _doctorRequests = {};
  List<ReceptionDrop> _allDrops = [];
  Map<int, int> _originalShiftCounts = {}; // From section shifts

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // ==================== GETTERS ====================

  // Workflow state
  int? get currentDoctorId => _currentDoctorId;
  ConstraintEntryStage get currentStage => _currentStage;

  // Session delegation
  bool get isSessionActive => _sessionProvider.isSessionActive;
  String? get currentMonth => _sessionProvider.currentMonth;
  List<Doctor> get allDoctors => _sessionProvider.allDoctors;

  // Basic constraints
  int get totalShifts => _totalShifts;
  int get morningShifts => _morningShifts;
  int get eveningShifts => _eveningShifts;
  int get remainingShifts => _totalShifts - _morningShifts - _eveningShifts;
  bool get canProceedFromBasicConstraints =>
      _totalShifts > 0 && remainingShifts >= 0;

  // Drop management
  List<Map<String, dynamic>> get pendingDrops => List.unmodifiable(_pendingDrops);
  bool get hasValidDropConfiguration => _validateAllDrops();
  bool get willDropAllShifts => _pendingDrops.isNotEmpty && _getTotalDropsForCurrentDoctor() >= _totalShifts;
  int get finalShiftsForCurrentDoctor => _totalShifts - _getTotalDropsForCurrentDoctor();
  bool get needsToCompleteConstraints => finalShiftsForCurrentDoctor > 0;

  // Preferences
  bool get seniority => _seniority;
  bool get enforceWanted => _enforceWanted;
  bool get enforceExceptions => _enforceExceptions;
  bool get avoidWeekends => _avoidWeekends;
  bool get enforceAvoidWeekends => _enforceAvoidWeekends;
  bool get firstWeekDaysPreference => _firstWeekDaysPreference;
  bool get lastWeekDaysPreference => _lastWeekDaysPreference;
  bool get firstMonthDaysPreference => _firstMonthDaysPreference;
  bool get lastMonthDaysPreference => _lastMonthDaysPreference;
  bool get avoidConsecutiveDays => _avoidConsecutiveDays;
  int get priority => _priority;

  // Requests
  List<DoctorRequest> get wantedDays => List.unmodifiable(_wantedDays);
  List<DoctorRequest> get exceptionDays => List.unmodifiable(_exceptionDays);

  // UI state
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // ==================== INITIALIZATION ====================

  /// Initialize provider for current session
  Future<void> initializeForSession() async {
    if (!isSessionActive) {
      _setError('No active session. Please start a session first.');
      return;
    }

    _setLoading(true);
    _clearMessages();

    try {
      await _loadExistingData();
      await _calculateOriginalShiftCounts();
      await _calculateFinalShiftCounts();
      resetCurrentForm();

      print('✅ DoctorConstraintProvider initialized');
      print('📊 Original shift counts: $_originalShiftCounts');
      print('📊 Doctors needing constraints: ${getDoctorsNeedingConstraints().length}');

    } catch (e) {
      _setError('Failed to initialize constraint provider: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load existing constraints, drops, and requests
  Future<void> _loadExistingData() async {
    try {
      // Load existing constraints
      final constraints = await _dbHelper.getAllDoctorConstraints();
      _doctorConstraints.clear();
      for (final constraint in constraints) {
        _doctorConstraints[constraint.doctorId] = constraint;
      }

      // Load existing drops for current month
      final drops = await _dbHelper.getReceptionDropsByMonth(currentMonth!);
      _allDrops = drops;

      // Load doctor requests
      _doctorRequests.clear();
      for (final doctor in allDoctors) {
        if (doctor.id != null) {
          final requests = await _dbHelper.getDoctorRequestsByDoctorId(doctor.id!);
          _doctorRequests[doctor.id!] = requests;
        }
      }

    } catch (e) {
      throw Exception('Failed to load existing data: $e');
    }
  }

  /// Calculate original shift counts from section shifts
  Future<void> _calculateOriginalShiftCounts() async {
    try {
      _originalShiftCounts.clear();

      if (currentMonth == null) return;

      final sectionShifts = await _dbHelper.getSectionShiftsByMonth(currentMonth!);

      for (final shift in sectionShifts) {
        _originalShiftCounts[shift.doctorId] =
            (_originalShiftCounts[shift.doctorId] ?? 0) + 1;
      }

    } catch (e) {
      throw Exception('Failed to calculate original shift counts: $e');
    }
  }

  /// Calculate final shift counts after applying drops
  Future<void> _calculateFinalShiftCounts() async {
    _calculatedShiftTotals.clear();

    // Start with original counts
    _calculatedShiftTotals.addAll(_originalShiftCounts);

    // Apply drops
    for (final drop in _allDrops) {
      // Subtract from source doctor
      _calculatedShiftTotals[drop.fromDoctorId] =
          (_calculatedShiftTotals[drop.fromDoctorId] ?? 0) - 1;

      // Add to target doctor
      _calculatedShiftTotals[drop.toDoctorId] =
          (_calculatedShiftTotals[drop.toDoctorId] ?? 0) + 1;
    }

    // Apply pending drops
    for (final pendingDrop in _pendingDrops) {
      final sourceId = pendingDrop['fromDoctorId'] as int;
      final targetId = pendingDrop['toDoctorId'] as int;

      _calculatedShiftTotals[sourceId] =
          (_calculatedShiftTotals[sourceId] ?? 0) - 1;
      _calculatedShiftTotals[targetId] =
          (_calculatedShiftTotals[targetId] ?? 0) + 1;
    }
  }

  // ==================== DOCTOR SELECTION ====================

  /// Get doctors who need constraint entry (have section shifts and final shifts > 0)
  List<Doctor> getDoctorsNeedingConstraints() {
    return allDoctors.where((doctor) {
      final originalShifts = _originalShiftCounts[doctor.id] ?? 0;
      final finalShifts = _calculatedShiftTotals[doctor.id] ?? originalShifts;
      final hasConstraints = _doctorConstraints.containsKey(doctor.id);

      return originalShifts > 0 && finalShifts > 0 && !hasConstraints;
    }).toList();
  }

  /// Get doctors who have completed constraints
  List<Doctor> getDoctorsWithCompletedConstraints() {
    return allDoctors.where((doctor) {
      return _doctorConstraints.containsKey(doctor.id);
    }).toList();
  }

  /// Select doctor to configure constraints
  void selectDoctor(int doctorId) {
    if (!_validateSession()) return;

    _currentDoctorId = doctorId;
    _currentStage = ConstraintEntryStage.basicConstraints;

    // Load existing data for this doctor if available
    _loadDoctorData(doctorId);

    _clearMessages();
    notifyListeners();
  }

  /// Load existing constraint data for doctor
  void _loadDoctorData(int doctorId) {
    // Load constraints
    final existingConstraint = _doctorConstraints[doctorId];
    if (existingConstraint != null) {
      _totalShifts = existingConstraint.totalShifts;
      _morningShifts = existingConstraint.morningShifts;
      _eveningShifts = existingConstraint.eveningShifts;
      _seniority = existingConstraint.seniority;
      _enforceWanted = existingConstraint.enforceWanted;
      _enforceExceptions = existingConstraint.enforceExceptions;
      _avoidWeekends = existingConstraint.avoidWeekends;
      _enforceAvoidWeekends = existingConstraint.enforceAvoidWeekends;
      _firstWeekDaysPreference = existingConstraint.firstWeekDaysPreference;
      _lastWeekDaysPreference = existingConstraint.lastWeekDaysPreference;
      _firstMonthDaysPreference = existingConstraint.firstMonthDaysPreference;
      _lastMonthDaysPreference = existingConstraint.lastMonthDaysPreference;
      _avoidConsecutiveDays = existingConstraint.avoidConsecutiveDays;
      _priority = existingConstraint.priority;
    } else {
      // Set defaults - suggest original shift count
      final originalShifts = _originalShiftCounts[doctorId] ?? 0;
      _totalShifts = originalShifts;
      _morningShifts = 0;
      _eveningShifts = 0;
    }

    // Load requests
    final requests = _doctorRequests[doctorId] ?? [];
    _wantedDays = requests.where((r) => r.type == 'wanted').toList();
    _exceptionDays = requests.where((r) => r.type == 'exception').toList();
  }

  // ==================== BASIC CONSTRAINTS MANAGEMENT ====================

  /// Set total shifts
  void setTotalShifts(int total) {
    _totalShifts = total;
    _clearMessages();
    notifyListeners();
  }

  /// Set morning shifts
  void setMorningShifts(int morning) {
    _morningShifts = morning;
    _clearMessages();
    notifyListeners();
  }

  /// Set evening shifts
  void setEveningShifts(int evening) {
    _eveningShifts = evening;
    _clearMessages();
    notifyListeners();
  }

  /// Proceed from basic constraints to drop decision
  void proceedToDropDecision() {
    if (!canProceedFromBasicConstraints) {
      _setError('Please enter valid shift numbers before proceeding.');
      return;
    }

    _currentStage = ConstraintEntryStage.dropDecision;
    _clearMessages();
    notifyListeners();
  }

  // ==================== DROP MANAGEMENT ====================

  /// Decide to configure drops
  void chooseToConfigureDrops() {
    _currentStage = ConstraintEntryStage.dropConfiguration;
    _pendingDrops.clear();
    _clearMessages();
    notifyListeners();
  }

  /// Skip drop configuration
  void skipDropConfiguration() {
    _pendingDrops.clear();
    _currentStage = ConstraintEntryStage.preferences;
    _clearMessages();
    notifyListeners();
  }

  /// Add a drop (from current doctor to target doctor)
  void addDrop({
    required int toDoctorId,
    required String shiftType, // 'Morning' or 'Evening'
    required int count,
  }) {
    if (_currentDoctorId == null) {
      _setError('No doctor selected');
      return;
    }

    // Validate drop
    if (!_validateDrop(shiftType, count)) return;

    // Add drops (one for each shift)
    for (int i = 0; i < count; i++) {
      _pendingDrops.add({
        'fromDoctorId': _currentDoctorId!,
        'toDoctorId': toDoctorId,
        'shift': shiftType,
        'month': currentMonth!,
      });
    }

    // Recalculate totals
    _calculateFinalShiftCounts();
    _clearMessages();
    notifyListeners();
  }

  /// Remove a pending drop
  void removePendingDrop(int index) {
    if (index >= 0 && index < _pendingDrops.length) {
      _pendingDrops.removeAt(index);
      _calculateFinalShiftCounts();
      _clearMessages();
      notifyListeners();
    }
  }

  /// Get total drops for current doctor
  int _getTotalDropsForCurrentDoctor() {
    if (_currentDoctorId == null) return 0;

    return _pendingDrops.where((drop) =>
    drop['fromDoctorId'] == _currentDoctorId).length;
  }

  /// Validate a drop operation
  bool _validateDrop(String shiftType, int count) {
    if (_currentDoctorId == null) {
      _setError('No doctor selected');
      return false;
    }

    final currentDrops = _getTotalDropsForCurrentDoctor();
    final morningDrops = _pendingDrops.where((drop) =>
    drop['fromDoctorId'] == _currentDoctorId && drop['shift'] == 'Morning').length;
    final eveningDrops = _pendingDrops.where((drop) =>
    drop['fromDoctorId'] == _currentDoctorId && drop['shift'] == 'Evening').length;

    // Check total capacity
    if (currentDrops + count > _totalShifts) {
      _setError('Cannot drop more shifts than total ($currentDrops + $count > $_totalShifts)');
      return false;
    }

    // Check shift type capacity
    if (shiftType == 'Morning') {
      if (morningDrops + count > _morningShifts) {
        _setError('Cannot drop more morning shifts than available ($morningDrops + $count > $_morningShifts)');
        return false;
      }
    } else if (shiftType == 'Evening') {
      if (eveningDrops + count > _eveningShifts) {
        _setError('Cannot drop more evening shifts than available ($eveningDrops + $count > $_eveningShifts)');
        return false;
      }
    }

    return true;
  }

  /// Validate all pending drops
  bool _validateAllDrops() {
    // Check if drops don't exceed available shifts
    final totalDrops = _getTotalDropsForCurrentDoctor();
    return totalDrops <= _totalShifts;
  }

  /// Apply pending drops and proceed
  Future<void> applyDropsAndProceed() async {
    if (!hasValidDropConfiguration) {
      _setError('Invalid drop configuration');
      return;
    }

    _setLoading(true);

    try {
      // Check if dropping all shifts BEFORE applying
      final droppingAllShifts = willDropAllShifts;

      // Save drops to database
      for (final dropData in _pendingDrops) {
        final drop = ReceptionDrop(
          fromDoctorId: dropData['fromDoctorId'],
          toDoctorId: dropData['toDoctorId'],
          shift: dropData['shift'],
          month: dropData['month'],
        );

        await _dbHelper.insertReceptionDrop(drop);
      }

      // Add to permanent drops list
      _allDrops.addAll(_pendingDrops.map((dropData) => ReceptionDrop(
        fromDoctorId: dropData['fromDoctorId'],
        toDoctorId: dropData['toDoctorId'],
        shift: dropData['shift'],
        month: dropData['month'],
      )));

      // Clear pending drops
      _pendingDrops.clear();

      // Recalculate final totals
      await _calculateFinalShiftCounts();

      // Decide next stage based on whether all shifts were dropped
      if (droppingAllShifts) {
        // Complete constraints immediately for doctors who dropped all shifts
        await _completeConstraintsForCurrentDoctor();
        _setSuccess('All shifts dropped - constraints completed automatically');
      } else {
        // Continue to preferences for doctors with remaining shifts
        _currentStage = ConstraintEntryStage.preferences;
        _setSuccess('Drops applied successfully');
      }

    } catch (e) {
      _setError('Failed to apply drops: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== PREFERENCES MANAGEMENT ====================

  /// Set seniority preference
  void setSeniority(bool value) {
    _seniority = value;
    notifyListeners();
  }

  /// Set enforce wanted days
  void setEnforceWanted(bool value) {
    _enforceWanted = value;
    notifyListeners();
  }

  /// Set enforce exceptions
  void setEnforceExceptions(bool value) {
    _enforceExceptions = value;
    notifyListeners();
  }

  /// Set avoid weekends
  void setAvoidWeekends(bool value) {
    _avoidWeekends = value;
    notifyListeners();
  }

  /// Set enforce avoid weekends
  void setEnforceAvoidWeekends(bool value) {
    _enforceAvoidWeekends = value;
    notifyListeners();
  }

  /// Set first week days preference
  void setFirstWeekDaysPreference(bool value) {
    _firstWeekDaysPreference = value;
    notifyListeners();
  }

  /// Set last week days preference
  void setLastWeekDaysPreference(bool value) {
    _lastWeekDaysPreference = value;
    notifyListeners();
  }

  /// Set first month days preference
  void setFirstMonthDaysPreference(bool value) {
    _firstMonthDaysPreference = value;
    notifyListeners();
  }

  /// Set last month days preference
  void setLastMonthDaysPreference(bool value) {
    _lastMonthDaysPreference = value;
    notifyListeners();
  }

  /// Set avoid consecutive days
  void setAvoidConsecutiveDays(bool value) {
    _avoidConsecutiveDays = value;
    notifyListeners();
  }

  /// Set priority level
  void setPriority(int value) {
    _priority = value;
    notifyListeners();
  }

  /// Proceed to wanted days
  void proceedToWantedDays() {
    _currentStage = ConstraintEntryStage.wantedDays;
    _clearMessages();
    notifyListeners();
  }

  // ==================== WANTED DAYS MANAGEMENT ====================

  /// Add wanted day
  void addWantedDay(String date, String shift) {
    if (_currentDoctorId == null) return;

    final request = DoctorRequest(
      doctorId: _currentDoctorId!,
      date: date,
      shift: shift,
      type: 'wanted',
    );

    _wantedDays.add(request);
    _clearMessages();
    notifyListeners();
  }

  /// Remove wanted day
  void removeWantedDay(int index) {
    if (index >= 0 && index < _wantedDays.length) {
      _wantedDays.removeAt(index);
      _clearMessages();
      notifyListeners();
    }
  }

  /// Proceed to exception days
  void proceedToExceptionDays() {
    _currentStage = ConstraintEntryStage.exceptionDays;
    _clearMessages();
    notifyListeners();
  }

  // ==================== EXCEPTION DAYS MANAGEMENT ====================

  /// Add exception day
  void addExceptionDay(String date, String shift) {
    if (_currentDoctorId == null) return;

    final request = DoctorRequest(
      doctorId: _currentDoctorId!,
      date: date,
      shift: shift,
      type: 'exception',
    );

    _exceptionDays.add(request);
    _clearMessages();
    notifyListeners();
  }

  /// Remove exception day
  void removeExceptionDay(int index) {
    if (index >= 0 && index < _exceptionDays.length) {
      _exceptionDays.removeAt(index);
      _clearMessages();
      notifyListeners();
    }
  }

  // ==================== COMPLETION ====================

  /// Save constraints for current doctor
  Future<void> completeConstraintsForCurrentDoctor() async {
    if (_currentDoctorId == null) {
      _setError('No doctor selected');
      return;
    }

    _setLoading(true);

    try {
      // Save constraint
      await _saveConstraintForCurrentDoctor();

      // Save requests
      await _saveRequestsForCurrentDoctor();

      _currentStage = ConstraintEntryStage.completed;
      _setSuccess('Constraints saved successfully!');

      _checkStepCompletion();

      // Auto-reset form after showing completion
      Future.delayed(const Duration(seconds: 2), () {
        resetCurrentForm();
      });

    } catch (e) {
      _setError('Failed to save constraints: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Save constraint for current doctor
  Future<void> _saveConstraintForCurrentDoctor() async {
    if (_currentDoctorId == null) return;

    final constraint = DoctorConstraint(
      doctorId: _currentDoctorId!,
      totalShifts: finalShiftsForCurrentDoctor,
      morningShifts: _morningShifts,
      eveningShifts: _eveningShifts,
      seniority: _seniority,
      enforceWanted: _enforceWanted,
      enforceExceptions: _enforceExceptions,
      avoidWeekends: _avoidWeekends,
      enforceAvoidWeekends: _enforceAvoidWeekends,
      firstWeekDaysPreference: _firstWeekDaysPreference,
      lastWeekDaysPreference: _lastWeekDaysPreference,
      firstMonthDaysPreference: _firstMonthDaysPreference,
      lastMonthDaysPreference: _lastMonthDaysPreference,
      avoidConsecutiveDays: _avoidConsecutiveDays,
      priority: _priority,
    );

    // Check if constraint already exists
    if (_doctorConstraints.containsKey(_currentDoctorId!)) {
      // Update existing
      final existingConstraint = _doctorConstraints[_currentDoctorId!]!;
      final updatedConstraint = DoctorConstraint(
        id: existingConstraint.id,
        doctorId: _currentDoctorId!,
        totalShifts: finalShiftsForCurrentDoctor,
        morningShifts: _morningShifts,
        eveningShifts: _eveningShifts,
        seniority: _seniority,
        enforceWanted: _enforceWanted,
        enforceExceptions: _enforceExceptions,
        avoidWeekends: _avoidWeekends,
        enforceAvoidWeekends: _enforceAvoidWeekends,
        firstWeekDaysPreference: _firstWeekDaysPreference,
        lastWeekDaysPreference: _lastWeekDaysPreference,
        firstMonthDaysPreference: _firstMonthDaysPreference,
        lastMonthDaysPreference: _lastMonthDaysPreference,
        avoidConsecutiveDays: _avoidConsecutiveDays,
        priority: _priority,
      );

      await _dbHelper.updateDoctorConstraint(updatedConstraint);
      _doctorConstraints[_currentDoctorId!] = updatedConstraint;
    } else {
      // Insert new
      final id = await _dbHelper.insertDoctorConstraint(constraint);
      final savedConstraint = DoctorConstraint(
        id: id,
        doctorId: _currentDoctorId!,
        totalShifts: finalShiftsForCurrentDoctor,
        morningShifts: _morningShifts,
        eveningShifts: _eveningShifts,
        seniority: _seniority,
        enforceWanted: _enforceWanted,
        enforceExceptions: _enforceExceptions,
        avoidWeekends: _avoidWeekends,
        enforceAvoidWeekends: _enforceAvoidWeekends,
        firstWeekDaysPreference: _firstWeekDaysPreference,
        lastWeekDaysPreference: _lastWeekDaysPreference,
        firstMonthDaysPreference: _firstMonthDaysPreference,
        lastMonthDaysPreference: _lastMonthDaysPreference,
        avoidConsecutiveDays: _avoidConsecutiveDays,
        priority: _priority,
      );
      _doctorConstraints[_currentDoctorId!] = savedConstraint;
    }
  }

  /// Save doctor requests to database
  Future<void> _saveRequestsForCurrentDoctor() async {
    if (_currentDoctorId == null || currentMonth == null) return;

    // ✅ Delete only current month's requests
    await _dbHelper.deleteDoctorRequestsByDoctorIdAndMonth(_currentDoctorId!, currentMonth!);

    // Insert new requests
    final allRequests = [..._wantedDays, ..._exceptionDays];
    for (final request in allRequests) {
      await _dbHelper.insertDoctorRequest(request);
    }
  }

  /// Complete constraints automatically (for doctors who dropped all shifts)
  Future<void> _completeConstraintsForCurrentDoctor() async {
    if (_currentDoctorId == null) return;

    // Create minimal constraint with 0 shifts
    final constraint = DoctorConstraint(
      doctorId: _currentDoctorId!,
      totalShifts: 0,
      morningShifts: 0,
      eveningShifts: 0,
    );

    final id = await _dbHelper.insertDoctorConstraint(constraint);
    _doctorConstraints[_currentDoctorId!] = DoctorConstraint(
      id: id,
      doctorId: _currentDoctorId!,
      totalShifts: 0,
      morningShifts: 0,
      eveningShifts: 0,
    );

    _setSuccess('Doctor dropped all shifts - constraints auto-completed');
    _checkStepCompletion();

    // Auto-reset form to go back to doctor selection
    Future.delayed(const Duration(milliseconds: 500), () {
      resetCurrentForm();
    });
  }

  /// Check if constraints step should be marked complete
  void _checkStepCompletion() {
    final doctorsNeedingConstraints = getDoctorsNeedingConstraints();
    final doctorsWithConstraints = getDoctorsWithCompletedConstraints();

    // Update session provider with progress
    _sessionProvider.updateConstraintsProgress(doctorsWithConstraints.length);

    // Mark step as completed if all doctors have constraints
    if (doctorsNeedingConstraints.isEmpty) {
      _sessionProvider.markStepCompleted(ScheduleStep.enterDoctorConstraints, true);
      _sessionProvider.markStepCompleted(ScheduleStep.reviewDoctorConstraints, true);
    }
  }

  // ==================== NAVIGATION ====================

  /// Reset current form and return to doctor selection
  void resetCurrentForm() {
    _currentDoctorId = null;
    _currentStage = ConstraintEntryStage.selectDoctor;
    _resetFormData();
    _clearMessages();
    notifyListeners();
  }

  /// Reset form data
  void _resetFormData() {
    _totalShifts = 0;
    _morningShifts = 0;
    _eveningShifts = 0;
    _pendingDrops.clear();
    _seniority = false;
    _enforceWanted = false;
    _enforceExceptions = false;
    _avoidWeekends = false;
    _enforceAvoidWeekends = false;
    _firstWeekDaysPreference = false;
    _lastWeekDaysPreference = false;
    _firstMonthDaysPreference = false;
    _lastMonthDaysPreference = false;
    _avoidConsecutiveDays = false;
    _priority = 0;
    _wantedDays.clear();
    _exceptionDays.clear();
  }

  /// Go back to previous stage
  void goToPreviousStage() {
    switch (_currentStage) {
      case ConstraintEntryStage.basicConstraints:
        _currentStage = ConstraintEntryStage.selectDoctor;
        _currentDoctorId = null;
        break;
      case ConstraintEntryStage.dropDecision:
        _currentStage = ConstraintEntryStage.basicConstraints;
        break;
      case ConstraintEntryStage.dropConfiguration:
        _currentStage = ConstraintEntryStage.dropDecision;
        _pendingDrops.clear();
        break;
      case ConstraintEntryStage.preferences:
        _currentStage = _pendingDrops.isEmpty
            ? ConstraintEntryStage.dropDecision
            : ConstraintEntryStage.dropConfiguration;
        break;
      case ConstraintEntryStage.wantedDays:
        _currentStage = ConstraintEntryStage.preferences;
        break;
      case ConstraintEntryStage.exceptionDays:
        _currentStage = ConstraintEntryStage.wantedDays;
        break;
      case ConstraintEntryStage.completed:
        _currentStage = ConstraintEntryStage.exceptionDays;
        break;
      default:
        break;
    }
    _clearMessages();
    notifyListeners();
  }

  // ==================== STATISTICS ====================

  /// Get constraint completion statistics
  Map<String, dynamic> getConstraintStatistics() {
    final doctorsNeedingConstraints = getDoctorsNeedingConstraints();
    final doctorsWithConstraints = getDoctorsWithCompletedConstraints();
    final totalDoctors = allDoctors.length;

    final completionPercentage = totalDoctors > 0
        ? ((doctorsWithConstraints.length / totalDoctors) * 100).round()
        : 0;

    return {
      'doctorsWithConstraints': doctorsWithConstraints.length,
      'doctorsNeedingConstraints': doctorsNeedingConstraints.length,
      'totalDoctors': totalDoctors,
      'completionPercentage': completionPercentage,
    };
  }

  // ==================== UTILITY METHODS ====================

  /// Validate that session is active
  bool _validateSession() {
    if (!isSessionActive) {
      _setError('No active session. Please start a session first.');
      return false;
    }
    return true;
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  /// Set success message
  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all messages
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
}