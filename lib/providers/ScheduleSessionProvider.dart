import 'package:flutter/foundation.dart';
import '../core/models/Doctor.dart';
import 'CoreSessionProvider.dart';


enum ScheduleStep {
  insertSectionShifts,
  viewSectionShifts,
  enterDoctorConstraints,
  reviewDoctorConstraints,
  generateReceptionSchedule,
}

enum SessionStatus {
  inactive,
  active,
  paused,
  completed,
  cancelled,
}

class ScheduleSessionProvider with ChangeNotifier {
  final CoreSessionProvider _coreSessionProvider;

  ScheduleSessionProvider(this._coreSessionProvider);

  // ==================== SESSION STATE ====================
  SessionStatus _sessionStatus = SessionStatus.inactive;
  String? _currentMonth;
  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;

  // ==================== STEPPER STATE ====================
  int _currentStepIndex = 0;
  Map<ScheduleStep, bool> _stepCompletionStatus = {
    ScheduleStep.insertSectionShifts: false,
    ScheduleStep.viewSectionShifts: false,
    ScheduleStep.enterDoctorConstraints: false,
    ScheduleStep.reviewDoctorConstraints: false,
    ScheduleStep.generateReceptionSchedule: false,
  };

  // ==================== WORKFLOW DATA ====================
  Set<String> _processedSpecializations = {};

  // Progress tracking
  int _totalSectionShiftsAdded = 0;
  int _totalConstraintsEntered = 0;
  bool _scheduleGenerated = false;

  // ==================== ERROR & LOADING STATE ====================
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // ==================== GETTERS ====================

  // Session state getters
  SessionStatus get sessionStatus => _sessionStatus;
  String? get currentMonth => _currentMonth;
  bool get isSessionActive => _sessionStatus == SessionStatus.active;
  bool get isSessionCompleted => _sessionStatus == SessionStatus.completed;
  DateTime? get sessionStartTime => _sessionStartTime;
  DateTime? get sessionEndTime => _sessionEndTime;
  Duration? get sessionDuration => _sessionStartTime != null && _sessionEndTime != null
      ? _sessionEndTime!.difference(_sessionStartTime!)
      : null;

  // Stepper state getters
  int get currentStepIndex => _currentStepIndex;
  ScheduleStep get currentStep => ScheduleStep.values[_currentStepIndex];
  Map<ScheduleStep, bool> get stepCompletionStatus => Map.unmodifiable(_stepCompletionStatus);
  bool get canGoToNextStep => _currentStepIndex < ScheduleStep.values.length - 1;
  bool get canGoToPreviousStep => _currentStepIndex > 0;
  bool get isCurrentStepCompleted => _stepCompletionStatus[currentStep] ?? false;

  // Progress getters
  double get overallProgress => _stepCompletionStatus.values.where((completed) => completed).length / ScheduleStep.values.length;
  int get completedStepsCount => _stepCompletionStatus.values.where((completed) => completed).length;
  Set<String> get processedSpecializations => Set.unmodifiable(_processedSpecializations);

  // Data getters from CoreSessionProvider
  List<String> get availableSpecializations => _coreSessionProvider.specializations;
  List<Doctor> get allDoctors => _coreSessionProvider.allDoctors;
  Map<String, int> get specializationCounts => _coreSessionProvider.specializationCounts;
  bool get isCoreDataLoaded => _coreSessionProvider.isSharedDataLoaded;
  int get remainingSpecializations => availableSpecializations.length - _processedSpecializations.length;

  // Statistics getters
  int get totalSectionShiftsAdded => _totalSectionShiftsAdded;
  int get totalConstraintsEntered => _totalConstraintsEntered;
  bool get scheduleGenerated => _scheduleGenerated;

  // UI state getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // ==================== SESSION MANAGEMENT ====================

  /// Start a new scheduling session
  Future<bool> startSession(String month) async {
    _setLoading(true);
    _clearMessages();

    try {
      // Validate month format
      if (!_isValidMonthFormat(month)) {
        _setError('Invalid month format. Use YYYY-MM format.');
        return false;
      }

      // Check if core session provider is authenticated and has data
      if (!_coreSessionProvider.isAuthenticated) {
        _setError('User not authenticated. Please sign in first.');
        return false;
      }

      if (!_coreSessionProvider.isSharedDataLoaded) {
        _setError('Core data not loaded. Please wait for initialization.');
        return false;
      }

      // Check if we have doctors available
      if (availableSpecializations.isEmpty) {
        _setError('No doctors found. Please add doctors before creating a schedule.');
        return false;
      }

      // Initialize session
      _currentMonth = month;
      _sessionStartTime = DateTime.now();
      _sessionEndTime = null;
      _sessionStatus = SessionStatus.active;
      _currentStepIndex = 0;
      _resetProgress();

      _setSuccess('Schedule session started for $month');
      return true;

    } catch (e) {
      _setError('Failed to start session: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Complete the current session
  Future<void> completeSession() async {
    if (_sessionStatus != SessionStatus.active) return;

    _sessionEndTime = DateTime.now();
    _sessionStatus = SessionStatus.completed;
    _setSuccess('Schedule generation completed successfully!');
    notifyListeners();
  }

  /// Cancel the current session
  void cancelSession() {
    if (_sessionStatus != SessionStatus.active) return;

    _sessionEndTime = DateTime.now();
    _sessionStatus = SessionStatus.cancelled;
    _resetProgress();
    _clearMessages();
    notifyListeners();
  }

  /// Pause the current session
  void pauseSession() {
    if (_sessionStatus == SessionStatus.active) {
      _sessionStatus = SessionStatus.paused;
      notifyListeners();
    }
  }

  /// Resume a paused session
  void resumeSession() {
    if (_sessionStatus == SessionStatus.paused) {
      _sessionStatus = SessionStatus.active;
      notifyListeners();
    }
  }

  // ==================== STEP NAVIGATION ====================

  /// Go to next step
  bool goToNextStep() {
    if (!canGoToNextStep) return false;

    _currentStepIndex++;
    _clearMessages();
    notifyListeners();
    return true;
  }

  /// Go to previous step
  bool goToPreviousStep() {
    if (!canGoToPreviousStep) return false;

    _currentStepIndex--;
    _clearMessages();
    notifyListeners();
    return true;
  }

  /// Jump to specific step (if allowed)
  bool goToStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= ScheduleStep.values.length) return false;

    // Check if we can jump to this step (all previous steps should be completed)
    for (int i = 0; i < stepIndex; i++) {
      if (!(_stepCompletionStatus[ScheduleStep.values[i]] ?? false)) {
        _setError('Complete previous steps before accessing this step.');
        return false;
      }
    }

    _currentStepIndex = stepIndex;
    _clearMessages();
    notifyListeners();
    return true;
  }

  /// Mark current step as completed
  void markCurrentStepCompleted() {
    _stepCompletionStatus[currentStep] = true;

    // Auto-advance to next step if not the last step
    if (canGoToNextStep) {
      goToNextStep();
    } else {
      // All steps completed
      completeSession();
    }

    notifyListeners();
  }

  /// Mark specific step as completed
  void markStepCompleted(ScheduleStep step, bool completed) {
    _stepCompletionStatus[step] = completed;
    notifyListeners();
  }

  // ==================== STEP-SPECIFIC PROGRESS TRACKING ====================

  /// Update section shifts progress
  void updateSectionShiftsProgress(int count) {
    _totalSectionShiftsAdded = count;

    // Mark step as completed if we have section shifts
    if (count > 0) {
      markStepCompleted(ScheduleStep.insertSectionShifts, true);
      markStepCompleted(ScheduleStep.viewSectionShifts, true);
    }

    notifyListeners();
  }

  /// Update constraints progress
  void updateConstraintsProgress(int count) {
    _totalConstraintsEntered = count;

    // Mark steps as completed based on constraints
    if (count > 0) {
      markStepCompleted(ScheduleStep.enterDoctorConstraints, true);
      markStepCompleted(ScheduleStep.reviewDoctorConstraints, true);
    }

    notifyListeners();
  }

  /// Mark schedule as generated
  void markScheduleGenerated() {
    _scheduleGenerated = true;
    markStepCompleted(ScheduleStep.generateReceptionSchedule, true);
    notifyListeners();
  }

  /// Add processed specialization
  void addProcessedSpecialization(String specialization) {
    _processedSpecializations.add(specialization);
    notifyListeners();
  }

  /// Remove processed specialization
  void removeProcessedSpecialization(String specialization) {
    _processedSpecializations.remove(specialization);
    notifyListeners();
  }

  // ==================== DATA ACCESS METHODS ====================

  /// Get doctors for a specific specialization (from CoreSessionProvider)
  List<Doctor> getDoctorsForSpecialization(String specialization) {
    return _coreSessionProvider.getDoctorsBySpecialization(specialization);
  }

  /// Get all doctors involved in the session (from CoreSessionProvider)
  List<Doctor> getAllSessionDoctors() {
    return _coreSessionProvider.allDoctors;
  }

  /// Get doctor by ID (from CoreSessionProvider)
  Doctor? getDoctorById(int id) {
    return _coreSessionProvider.getDoctorById(id);
  }

  /// Search doctors (from CoreSessionProvider)
  List<Doctor> searchDoctors(String query) {
    return _coreSessionProvider.searchDoctors(query);
  }

  /// Check if specialization is processed
  bool isSpecializationProcessed(String specialization) {
    return _processedSpecializations.contains(specialization);
  }

  /// Refresh core data if needed
  Future<void> refreshCoreData() async {
    await _coreSessionProvider.refreshSharedData();
    notifyListeners();
  }

  // ==================== VALIDATION ====================

  /// Validate session prerequisites
  bool validateSessionPrerequisites() {
    if (!_coreSessionProvider.isAuthenticated) {
      _setError('User not authenticated.');
      return false;
    }

    if (!_coreSessionProvider.isSharedDataLoaded) {
      _setError('Core data not loaded.');
      return false;
    }

    if (availableSpecializations.isEmpty) {
      _setError('No specializations available.');
      return false;
    }

    if (allDoctors.isEmpty) {
      _setError('No doctors available.');
      return false;
    }

    return true;
  }

  /// Validate month format (YYYY-MM)
  bool _isValidMonthFormat(String month) {
    final regex = RegExp(r'^\d{4}-\d{2}$');
    return regex.hasMatch(month);
  }

  /// Reset all progress tracking
  void _resetProgress() {
    _stepCompletionStatus = {
      ScheduleStep.insertSectionShifts: false,
      ScheduleStep.viewSectionShifts: false,
      ScheduleStep.enterDoctorConstraints: false,
      ScheduleStep.reviewDoctorConstraints: false,
      ScheduleStep.generateReceptionSchedule: false,
    };
    _processedSpecializations.clear();
    _totalSectionShiftsAdded = 0;
    _totalConstraintsEntered = 0;
    _scheduleGenerated = false;
    _currentStepIndex = 0;
  }

  // ==================== STATE MANAGEMENT HELPERS ====================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    print('Schedule Session Error: $error');
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    print('Schedule Session Success: $message');
    notifyListeners();
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

  // ==================== SESSION INFO & ANALYTICS ====================

  /// Get session summary
  Map<String, dynamic> getSessionSummary() {
    return {
      'month': _currentMonth,
      'status': _sessionStatus.toString(),
      'currentStep': currentStep.toString(),
      'overallProgress': overallProgress,
      'completedSteps': completedStepsCount,
      'totalSteps': ScheduleStep.values.length,
      'sectionShiftsAdded': _totalSectionShiftsAdded,
      'constraintsEntered': _totalConstraintsEntered,
      'specializations': availableSpecializations.length,
      'processedSpecializations': _processedSpecializations.length,
      'sessionDuration': sessionDuration?.toString(),
      'scheduleGenerated': _scheduleGenerated,
      'coreDataLoaded': isCoreDataLoaded,
      'totalDoctors': allDoctors.length,
    };
  }

  /// Get step names for UI
  List<String> getStepNames() {
    return [
      'Insert Section Shifts',
      'View Section Shifts',
      'Enter Doctor Constraints',
      'Review Constraints',
      'Generate Schedule',
    ];
  }

  /// Get step descriptions for UI
  List<String> getStepDescriptions() {
    return [
      'Add section shifts for each specialization',
      'Review and verify section shifts',
      'Enter constraints for each doctor',
      'Review all doctor constraints',
      'Generate final reception schedule',
    ];
  }

  /// Get detailed workflow statistics
  Map<String, dynamic> getWorkflowStatistics() {
    return {
      'sessionInfo': {
        'month': _currentMonth,
        'status': _sessionStatus.toString(),
        'duration': sessionDuration?.toString(),
      },
      'stepProgress': {
        'currentStep': _currentStepIndex,
        'currentStepName': getStepNames()[_currentStepIndex],
        'completedSteps': completedStepsCount,
        'totalSteps': ScheduleStep.values.length,
        'progressPercentage': (overallProgress * 100).round(),
      },
      'dataStatistics': {
        'totalDoctors': allDoctors.length,
        'totalSpecializations': availableSpecializations.length,
        'processedSpecializations': _processedSpecializations.length,
        'remainingSpecializations': remainingSpecializations,
        'sectionShiftsAdded': _totalSectionShiftsAdded,
        'constraintsEntered': _totalConstraintsEntered,
        'scheduleGenerated': _scheduleGenerated,
      },
      'specializationBreakdown': specializationCounts,
    };
  }

  // ==================== DEBUG METHODS ====================

  /// Print session status for debugging
  void printSessionStatus() {
    print('Schedule Session Status: ${getSessionSummary()}');
  }

  /// Print workflow statistics
  void printWorkflowStatistics() {
    print('Workflow Statistics: ${getWorkflowStatistics()}');
  }
}