import 'package:flutter/foundation.dart';
import '../core/models/User.dart';
import '../core/models/Doctor.dart';
import '../db/DBHelper.dart';

enum SessionState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class CoreSessionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ==================== SESSION STATE ====================
  SessionState _sessionState = SessionState.initial;
  User? _currentUser;
  String? _errorMessage;
  DateTime? _sessionStartTime;

  // ==================== SHARED DATA ====================
  List<Doctor> _allDoctors = [];
  List<String> _specializations = [];
  Map<String, int> _specializationCounts = {};
  bool _sharedDataLoaded = false;

  // ==================== GETTERS ====================

  // Session getters
  SessionState get sessionState => _sessionState;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _sessionState == SessionState.authenticated;
  bool get isLoading => _sessionState == SessionState.loading;
  String? get errorMessage => _errorMessage;
  DateTime? get sessionStartTime => _sessionStartTime;

  // Shared data getters
  List<Doctor> get allDoctors => List.unmodifiable(_allDoctors);
  List<String> get specializations => List.unmodifiable(_specializations);
  Map<String, int> get specializationCounts => Map.unmodifiable(_specializationCounts);
  bool get isSharedDataLoaded => _sharedDataLoaded;
  int get totalDoctors => _allDoctors.length;

  // ==================== SESSION MANAGEMENT ====================

  /// Initialize session - call this when app starts
  Future<void> initializeSession() async {
    _sessionState = SessionState.loading;
    _clearError();
    notifyListeners();

    try {
      // You can add auto-login logic here if you store user session
      // For now, just set to unauthenticated
      _sessionState = SessionState.unauthenticated;
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize session: $e');
    }
  }

  /// Sign in user and start session
  Future<bool> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    _sessionState = SessionState.loading;
    _clearError();
    notifyListeners();

    try {
      // Authenticate user
      final result = await _dbHelper.signIn(
        emailOrUsername: emailOrUsername,
        password: password,
      );

      if (result['success']) {
        _currentUser = result['user'];
        _sessionStartTime = DateTime.now();
        _sessionState = SessionState.authenticated;

        print('✅ User signed in: ${_currentUser!.username}');

        // Load shared data after successful authentication
        await _loadSharedData();

        notifyListeners();
        return true;
      } else {
        _setError(result['message']);
        _sessionState = SessionState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Sign in failed: $e');
      _sessionState = SessionState.error;
      notifyListeners();
      return false;
    }
  }

  /// Sign up new user
  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    _sessionState = SessionState.loading;
    _clearError();
    notifyListeners();

    try {
      final result = await _dbHelper.signUp(
        username: username,
        email: email,
        password: password,
      );

      if (result['success']) {
        _sessionState = SessionState.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _setError(result['message']);
        _sessionState = SessionState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Sign up failed: $e');
      _sessionState = SessionState.error;
      notifyListeners();
      return false;
    }
  }

  /// Sign out user and end session
  void signOut() {
    print('🚪 User signed out: ${_currentUser?.username}');

    _currentUser = null;
    _sessionStartTime = null;
    _sessionState = SessionState.unauthenticated;
    _clearSharedData();
    _clearError();

    notifyListeners();
  }

  // ==================== SHARED DATA MANAGEMENT ====================

  /// Load all shared data needed across the app
  Future<void> _loadSharedData() async {
    try {
      print('📊 Loading shared data...');

      // Load doctors and specializations concurrently
      final results = await Future.wait([
        _dbHelper.getAllDoctors(),
        _dbHelper.getSpecializations(),
      ]);

      _allDoctors = results[0] as List<Doctor>;
      _specializations = results[1] as List<String>;

      // Calculate specialization counts
      _calculateSpecializationCounts();

      _sharedDataLoaded = true;

      print('✅ Shared data loaded: ${_allDoctors.length} doctors, ${_specializations.length} specializations');

    } catch (e) {
      print('❌ Failed to load shared data: $e');
      _setError('Failed to load application data: $e');
      _sharedDataLoaded = false;
    }
  }

  /// Refresh shared data from database
  Future<void> refreshSharedData() async {
    if (!isAuthenticated) return;

    _sharedDataLoaded = false;
    notifyListeners();

    await _loadSharedData();
    notifyListeners();
  }

  /// Calculate doctors count per specialization
  void _calculateSpecializationCounts() {
    _specializationCounts.clear();
    for (final doctor in _allDoctors) {
      if (doctor.specialization != null && doctor.specialization!.isNotEmpty) {
        _specializationCounts[doctor.specialization!] =
            (_specializationCounts[doctor.specialization!] ?? 0) + 1;
      }
    }
  }

  /// Clear all shared data
  void _clearSharedData() {
    _allDoctors.clear();
    _specializations.clear();
    _specializationCounts.clear();
    _sharedDataLoaded = false;
  }

  // ==================== SHARED DATA ACCESS METHODS ====================

  /// Get doctors by specialization
  List<Doctor> getDoctorsBySpecialization(String specialization) {
    return _allDoctors.where((doctor) =>
    doctor.specialization?.toLowerCase() == specialization.toLowerCase()
    ).toList();
  }

  /// Search doctors by name or specialization
  List<Doctor> searchDoctors(String query) {
    if (query.isEmpty) return _allDoctors;

    final searchQuery = query.toLowerCase();
    return _allDoctors.where((doctor) =>
    doctor.name.toLowerCase().contains(searchQuery) ||
        (doctor.specialization?.toLowerCase().contains(searchQuery) ?? false)
    ).toList();
  }

  /// Get doctor by ID
  Doctor? getDoctorById(int id) {
    try {
      return _allDoctors.firstWhere((doctor) => doctor.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if doctor exists in shared data
  bool doctorExists(int id) {
    return _allDoctors.any((doctor) => doctor.id == id);
  }

  // ==================== DATA MODIFICATION HOOKS ====================

  /// Call this when a doctor is added (to refresh shared data)
  Future<void> onDoctorAdded(Doctor doctor) async {
    _allDoctors.add(doctor);

    // Add specialization if new
    if (doctor.specialization != null &&
        doctor.specialization!.isNotEmpty &&
        !_specializations.contains(doctor.specialization!)) {
      _specializations.add(doctor.specialization!);
      _specializations.sort();
    }

    _calculateSpecializationCounts();
    notifyListeners();
  }

  /// Call this when a doctor is updated
  Future<void> onDoctorUpdated(Doctor updatedDoctor) async {
    final index = _allDoctors.indexWhere((doctor) => doctor.id == updatedDoctor.id);
    if (index != -1) {
      _allDoctors[index] = updatedDoctor;

      // Refresh specializations and counts
      await refreshSharedData();
    }
  }

  /// Call this when a doctor is deleted
  Future<void> onDoctorDeleted(int doctorId) async {
    _allDoctors.removeWhere((doctor) => doctor.id == doctorId);

    // Refresh specializations and counts
    await refreshSharedData();
  }

  // ==================== UTILITY METHODS ====================

  /// Get session duration
  Duration? getSessionDuration() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// Check if session is valid (you can add time-based validation here)
  bool isSessionValid() {
    if (!isAuthenticated || _sessionStartTime == null) return false;

    // Example: Session expires after 24 hours
    final sessionDuration = getSessionDuration();
    if (sessionDuration != null && sessionDuration.inHours > 24) {
      return false;
    }

    return true;
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    print('❌ Session Error: $error');
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  /// Clear error (public method)
  void clearError() {
    _clearError();
    notifyListeners();
  }

  // ==================== DEBUG METHODS ====================

  /// Get session info for debugging
  Map<String, dynamic> getSessionInfo() {
    return {
      'state': _sessionState.toString(),
      'user': _currentUser?.username,
      'sessionDuration': getSessionDuration()?.toString(),
      'doctorsLoaded': _allDoctors.length,
      'specializationsLoaded': _specializations.length,
      'sharedDataLoaded': _sharedDataLoaded,
    };
  }

  /// Print session status
  void printSessionStatus() {
    print('📊 Session Status: ${getSessionInfo()}');
  }
}