import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

// Import your model classes
import '../core/models/Doctor.dart';
import '../core/models/DoctorConstraint.dart';
import '../core/models/DoctorRequest.dart';
import '../core/models/ReceptionDrop.dart';
import '../core/models/ReceptionShift.dart';
import '../core/models/SectionShift.dart';
import '../core/models/User.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hospital_schedule.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Doctors table
    await db.execute('''
      CREATE TABLE doctors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialization TEXT,
        seniority TEXT
      )
    ''');

    // Doctor constraints table
    await db.execute('''
      CREATE TABLE doctor_constraints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        totalShifts INTEGER DEFAULT 0,
        morningShifts INTEGER DEFAULT 0,
        eveningShifts INTEGER DEFAULT 0,
        seniority INTEGER DEFAULT 0,
        enforceWanted INTEGER DEFAULT 0,
        enforceExceptions INTEGER DEFAULT 0,
        avoidWeekends INTEGER DEFAULT 0,
        enforceAvoidWeekends INTEGER DEFAULT 0,
        firstWeekDaysPreference INTEGER DEFAULT 0,
        lastWeekDaysPreference INTEGER DEFAULT 0,
        firstMonthDaysPreference INTEGER DEFAULT 0,
        lastMonthDaysPreference INTEGER DEFAULT 0,
        avoidConsecutiveDays INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 0,
        FOREIGN KEY (doctor_id) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');

    // Doctor requests table
    await db.execute('''
      CREATE TABLE doctor_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        type TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');

    // Reception drops table
    await db.execute('''
      CREATE TABLE reception_drops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_doctor_id INTEGER NOT NULL,
        to_doctor_id INTEGER NOT NULL,
        shift TEXT NOT NULL,
        month TEXT NOT NULL,
        FOREIGN KEY (from_doctor_id) REFERENCES doctors (id) ON DELETE CASCADE,
        FOREIGN KEY (to_doctor_id) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');

    // Reception shifts table
    await db.execute('''
      CREATE TABLE reception_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');

    // Section shifts table
    await db.execute('''
      CREATE TABLE section_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_doctor_constraints_doctor_id ON doctor_constraints (doctor_id)');
    await db.execute('CREATE INDEX idx_doctor_requests_doctor_id ON doctor_requests (doctor_id)');
    await db.execute('CREATE INDEX idx_reception_shifts_doctor_id ON reception_shifts (doctor_id)');
    await db.execute('CREATE INDEX idx_section_shifts_doctor_id ON section_shifts (doctor_id)');
    await db.execute('CREATE INDEX idx_reception_shifts_date ON reception_shifts (date)');
    await db.execute('CREATE INDEX idx_section_shifts_date ON section_shifts (date)');
  }

  // ==================== SECURE PASSWORD METHODS ====================

  /// Generate a random salt for password hashing
  String _generateSalt([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (i) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Hash password with salt
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify password against hash
  bool _verifyPassword(String password, String salt, String hashedPassword) {
    return _hashPassword(password, salt) == hashedPassword;
  }

  /// Simple email validation helper
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Check password strength
  bool _isStrongPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number, 1 special char
    return RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(password);
  }

  // ==================== AUTHENTICATION METHODS ====================

  /// Sign up a new user with secure password hashing
  Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      // Validate input
      if (username.trim().isEmpty) {
        return {'success': false, 'message': 'Username cannot be empty'};
      }
      if (email.trim().isEmpty || !_isValidEmail(email)) {
        return {'success': false, 'message': 'Please enter a valid email'};
      }
      if (password.length < 8) {
        return {'success': false, 'message': 'Password must be at least 8 characters'};
      }

      // Add password strength validation
      if (!_isStrongPassword(password)) {
        return {
          'success': false,
          'message': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
        };
      }

      // Check if username already exists
      final existingUserByUsername = await _getUserByUsername(username);
      if (existingUserByUsername != null) {
        return {'success': false, 'message': 'Username already exists'};
      }

      // Check if email already exists
      final existingUserByEmail = await getUserByEmail(email);
      if (existingUserByEmail != null) {
        return {'success': false, 'message': 'Email already registered'};
      }

      // Generate salt and hash password
      final salt = _generateSalt();
      final hashedPassword = _hashPassword(password, salt);

      // Create new user with hashed password
      final user = User(
        username: username.trim(),
        email: email.trim().toLowerCase(),
        password: '$salt:$hashedPassword', // Store salt and hash together
        createdAt: DateTime.now().toIso8601String(),
      );

      final userId = await insertUser(user);

      return {
        'success': true,
        'message': 'Account created successfully',
        'userId': userId
      };

    } catch (e) {
      return {'success': false, 'message': 'Failed to create account: $e'};
    }
  }

  /// Sign in an existing user with secure password verification
  Future<Map<String, dynamic>> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      // Validate input
      if (emailOrUsername.trim().isEmpty) {
        return {'success': false, 'message': 'Email or username cannot be empty'};
      }
      if (password.isEmpty) {
        return {'success': false, 'message': 'Password cannot be empty'};
      }

      User? user;

      // Try to find user by email first, then by username
      if (_isValidEmail(emailOrUsername)) {
        user = await getUserByEmail(emailOrUsername.trim().toLowerCase());
      } else {
        user = await _getUserByUsername(emailOrUsername.trim());
      }

      // Check if user exists
      if (user == null) {
        return {'success': false, 'message': 'User not found'};
      }

      // Handle legacy users with plain text passwords (migration)
      if (!user.password.contains(':')) {
        // This is a plain text password, verify directly and then update to hashed
        if (user.password == password) {
          // Convert to hashed password
          final salt = _generateSalt();
          final hashedPassword = _hashPassword(password, salt);

          final updatedUser = User(
            id: user.id,
            username: user.username,
            email: user.email,
            password: '$salt:$hashedPassword',
            createdAt: user.createdAt,
          );

          await updateUser(updatedUser);

          return {
            'success': true,
            'message': 'Sign in successful (password upgraded to secure format)',
            'user': updatedUser
          };
        } else {
          return {'success': false, 'message': 'Invalid password'};
        }
      }

      // Extract salt and hash from stored password
      final passwordParts = user.password.split(':');
      if (passwordParts.length != 2) {
        return {'success': false, 'message': 'Invalid password format'};
      }

      final salt = passwordParts[0];
      final storedHash = passwordParts[1];

      // Verify password
      if (!_verifyPassword(password, salt, storedHash)) {
        return {'success': false, 'message': 'Invalid password'};
      }

      return {
        'success': true,
        'message': 'Sign in successful',
        'user': user
      };

    } catch (e) {
      return {'success': false, 'message': 'Sign in failed: $e'};
    }
  }
  Future<void> deleteDoctorRequestsByDoctorIdAndMonth(int doctorId, String month) async {
    final db = await database;
    await db.delete(
      'doctor_requests',
      where: 'doctor_id = ? AND date LIKE ?',
      whereArgs: [doctorId, '$month%'],  // e.g., "2025-02%"
    );
  }
  /// Check if user exists by email or username
  Future<bool> userExists(String emailOrUsername) async {
    try {
      if (_isValidEmail(emailOrUsername)) {
        final user = await getUserByEmail(emailOrUsername.trim().toLowerCase());
        return user != null;
      } else {
        final user = await _getUserByUsername(emailOrUsername.trim());
        return user != null;
      }
    } catch (e) {
      return false;
    }
  }

  /// Secure change password method
  Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Validate new password
      if (newPassword.length < 8) {
        return {'success': false, 'message': 'New password must be at least 8 characters'};
      }

      if (!_isStrongPassword(newPassword)) {
        return {
          'success': false,
          'message': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
        };
      }

      // Get current user
      final user = await getUserById(userId);
      if (user == null) {
        return {'success': false, 'message': 'User not found'};
      }

      // Handle legacy users with plain text passwords
      if (!user.password.contains(':')) {
        if (user.password != currentPassword) {
          return {'success': false, 'message': 'Current password is incorrect'};
        }
      } else {
        // Extract salt and hash from stored password
        final passwordParts = user.password.split(':');
        if (passwordParts.length != 2) {
          return {'success': false, 'message': 'Invalid password format'};
        }

        final salt = passwordParts[0];
        final storedHash = passwordParts[1];

        // Verify current password
        if (!_verifyPassword(currentPassword, salt, storedHash)) {
          return {'success': false, 'message': 'Current password is incorrect'};
        }
      }

      // Generate new salt and hash for new password
      final newSalt = _generateSalt();
      final newHashedPassword = _hashPassword(newPassword, newSalt);

      // Update user with new password
      final updatedUser = User(
        id: user.id,
        username: user.username,
        email: user.email,
        password: '$newSalt:$newHashedPassword',
        createdAt: user.createdAt,
      );

      await updateUser(updatedUser);

      return {'success': true, 'message': 'Password changed successfully'};

    } catch (e) {
      return {'success': false, 'message': 'Failed to change password: $e'};
    }
  }

  /// Reset password (for forgot password functionality)
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Validate new password
      if (newPassword.length < 8) {
        return {'success': false, 'message': 'New password must be at least 8 characters'};
      }

      if (!_isStrongPassword(newPassword)) {
        return {
          'success': false,
          'message': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
        };
      }

      // Get user by email
      final user = await getUserByEmail(email.trim().toLowerCase());
      if (user == null) {
        return {'success': false, 'message': 'No account found with this email'};
      }

      // Generate new salt and hash for new password
      final salt = _generateSalt();
      final hashedPassword = _hashPassword(newPassword, salt);

      // Update password
      final updatedUser = User(
        id: user.id,
        username: user.username,
        email: user.email,
        password: '$salt:$hashedPassword',
        createdAt: user.createdAt,
      );

      await updateUser(updatedUser);

      return {'success': true, 'message': 'Password reset successfully'};

    } catch (e) {
      return {'success': false, 'message': 'Failed to reset password: $e'};
    }
  }

  // ==================== USER CRUD OPERATIONS ====================

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// Get user by username (helper method)
  Future<User?> _getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all unique specializations from doctors table
  Future<List<String>> getSpecializations() async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT specialization 
      FROM doctors 
      WHERE specialization IS NOT NULL 
      AND specialization != '' 
      ORDER BY specialization ASC
    ''');

      return maps
          .map((map) => map['specialization'] as String)
          .where((specialization) => specialization.isNotEmpty)
          .toList();

    } catch (e) {
      print('Error getting specializations: $e');
      return [];
    }
  }

  /// Alternative method: Get specializations with doctor count
  Future<List<Map<String, dynamic>>> getSpecializationsWithCount() async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT specialization, COUNT(*) as doctor_count
      FROM doctors 
      WHERE specialization IS NOT NULL 
      AND specialization != '' 
      GROUP BY specialization
      ORDER BY specialization ASC
    ''');

      return maps.map((map) => {
        'specialization': map['specialization'] as String,
        'doctor_count': map['doctor_count'] as int,
      }).toList();

    } catch (e) {
      print('Error getting specializations with count: $e');
      return [];
    }
  }

  /// Get doctors count for a specific specialization
  Future<int> getDoctorCountBySpecialization(String specialization) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM doctors 
      WHERE specialization = ?
    ''', [specialization]);

      return result.isNotEmpty ? result.first['count'] as int : 0;

    } catch (e) {
      print('Error getting doctor count for specialization: $e');
      return 0;
    }
  }

  // ==================== DOCTOR CRUD OPERATIONS ====================

  Future<int> insertDoctor(Doctor doctor) async {
    final db = await database;
    return await db.insert('doctors', doctor.toMap());
  }

  Future<List<Doctor>> getAllDoctors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('doctors');
    return List.generate(maps.length, (i) => Doctor.fromMap(maps[i]));
  }

  Future<Doctor?> getDoctorById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Doctor.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Doctor>> getDoctorsBySpecialization(String specialization) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctors',
      where: 'specialization = ?',
      whereArgs: [specialization],
    );
    return List.generate(maps.length, (i) => Doctor.fromMap(maps[i]));
  }

  Future<int> updateDoctor(Doctor doctor) async {
    final db = await database;
    return await db.update(
      'doctors',
      doctor.toMap(),
      where: 'id = ?',
      whereArgs: [doctor.id],
    );
  }

  Future<int> deleteDoctor(int id) async {
    final db = await database;
    return await db.delete(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== DOCTOR CONSTRAINT CRUD OPERATIONS ====================

  Future<int> insertDoctorConstraint(DoctorConstraint constraint) async {
    final db = await database;
    return await db.insert('doctor_constraints', constraint.toMap());
  }

  Future<List<DoctorConstraint>> getAllDoctorConstraints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('doctor_constraints');
    List<DoctorConstraint> constraints = [];

    for (var map in maps) {
      // Get doctor requests for this constraint
      final requests = await getDoctorRequestsByDoctorId(map['doctor_id']);
      map['doctorRequests'] = requests.map((r) => r.toMap()).toList();
      constraints.add(DoctorConstraint.fromMap(map));
    }
    return constraints;
  }

  Future<DoctorConstraint?> getDoctorConstraintById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctor_constraints',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final requests = await getDoctorRequestsByDoctorId(map['doctor_id']);
      map['doctorRequests'] = requests.map((r) => r.toMap()).toList();
      return DoctorConstraint.fromMap(map);
    }
    return null;
  }

  Future<DoctorConstraint?> getDoctorConstraintByDoctorId(int doctorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctor_constraints',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final requests = await getDoctorRequestsByDoctorId(doctorId);
      map['doctorRequests'] = requests.map((r) => r.toMap()).toList();
      return DoctorConstraint.fromMap(map);
    }
    return null;
  }

  Future<int> updateDoctorConstraint(DoctorConstraint constraint) async {
    final db = await database;
    return await db.update(
      'doctor_constraints',
      constraint.toMap(),
      where: 'id = ?',
      whereArgs: [constraint.id],
    );
  }

  Future<int> deleteDoctorConstraint(int id) async {
    final db = await database;
    return await db.delete(
      'doctor_constraints',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== DOCTOR REQUEST CRUD OPERATIONS ====================

  Future<int> insertDoctorRequest(DoctorRequest request) async {
    final db = await database;
    return await db.insert('doctor_requests', request.toMap());
  }

  Future<List<DoctorRequest>> getAllDoctorRequests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('doctor_requests');
    return List.generate(maps.length, (i) => DoctorRequest.fromMap(maps[i]));
  }

  Future<DoctorRequest?> getDoctorRequestById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctor_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return DoctorRequest.fromMap(maps.first);
    }
    return null;
  }

  Future<List<DoctorRequest>> getDoctorRequestsByDoctorId(int doctorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctor_requests',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
    return List.generate(maps.length, (i) => DoctorRequest.fromMap(maps[i]));
  }

  Future<List<DoctorRequest>> getDoctorRequestsByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctor_requests',
      where: 'type = ?',
      whereArgs: [type],
    );
    return List.generate(maps.length, (i) => DoctorRequest.fromMap(maps[i]));
  }

  Future<int> updateDoctorRequest(DoctorRequest request) async {
    final db = await database;
    return await db.update(
      'doctor_requests',
      request.toMap(),
      where: 'id = ?',
      whereArgs: [request.id],
    );
  }

  Future<int> deleteDoctorRequest(int id) async {
    final db = await database;
    return await db.delete(
      'doctor_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== RECEPTION DROP CRUD OPERATIONS ====================

  Future<int> insertReceptionDrop(ReceptionDrop drop) async {
    final db = await database;
    return await db.insert('reception_drops', drop.toMap());
  }

  Future<List<ReceptionDrop>> getAllReceptionDrops() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reception_drops');
    return List.generate(maps.length, (i) => ReceptionDrop.fromMap(maps[i]));
  }

  Future<ReceptionDrop?> getReceptionDropById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reception_drops',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ReceptionDrop.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ReceptionDrop>> getReceptionDropsByMonth(String month) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reception_drops',
      where: 'month = ?',
      whereArgs: [month],
    );
    return List.generate(maps.length, (i) => ReceptionDrop.fromMap(maps[i]));
  }

  Future<int> updateReceptionDrop(ReceptionDrop drop) async {
    final db = await database;
    return await db.update(
      'reception_drops',
      drop.toMap(),
      where: 'id = ?',
      whereArgs: [drop.id],
    );
  }

  Future<int> deleteReceptionDrop(int id) async {
    final db = await database;
    return await db.delete(
      'reception_drops',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== RECEPTION SHIFT CRUD OPERATIONS ====================

  Future<int> insertReceptionShift(ReceptionShift shift) async {
    final db = await database;
    return await db.insert('reception_shifts', shift.toMap());
  }

  Future<List<ReceptionShift>> getAllReceptionShifts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reception_shifts');
    return List.generate(maps.length, (i) => ReceptionShift.fromMap(maps[i]));
  }

  Future<ReceptionShift?> getReceptionShiftById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reception_shifts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ReceptionShift.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ReceptionShift>> getReceptionShiftsByDoctorId(int doctorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reception_shifts',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
    return List.generate(maps.length, (i) => ReceptionShift.fromMap(maps[i]));
  }

  Future<List<ReceptionShift>> getReceptionShiftsByMonth(String month) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reception_shifts',
      where: 'date LIKE ?',
      whereArgs: ['$month%'],
    );
    return List.generate(maps.length, (i) => ReceptionShift.fromMap(maps[i]));
  }

  Future<List<ReceptionShift>> getReceptionShiftsByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reception_shifts',
      where: 'date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => ReceptionShift.fromMap(maps[i]));
  }

  Future<int> updateReceptionShift(ReceptionShift shift) async {
    final db = await database;
    return await db.update(
      'reception_shifts',
      shift.toMap(),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  Future<int> deleteReceptionShift(int id) async {
    final db = await database;
    return await db.delete(
      'reception_shifts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== SECTION SHIFT CRUD OPERATIONS ====================

  Future<int> insertSectionShift(SectionShift shift) async {
    final db = await database;
    return await db.insert('section_shifts', shift.toMap());
  }

  Future<List<SectionShift>> getAllSectionShifts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('section_shifts');
    return List.generate(maps.length, (i) => SectionShift.fromMap(maps[i]));
  }

  Future<SectionShift?> getSectionShiftById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'section_shifts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return SectionShift.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SectionShift>> getSectionShiftsByDoctorId(int doctorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'section_shifts',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
    return List.generate(maps.length, (i) => SectionShift.fromMap(maps[i]));
  }

  Future<List<SectionShift>> getSectionShiftsByMonth(String month) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'section_shifts',
      where: 'date LIKE ?',
      whereArgs: ['$month%'],
    );
    return List.generate(maps.length, (i) => SectionShift.fromMap(maps[i]));
  }

  Future<List<SectionShift>> getSectionShiftsByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'section_shifts',
      where: 'date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => SectionShift.fromMap(maps[i]));
  }

  Future<int> updateSectionShift(SectionShift shift) async {
    final db = await database;
    return await db.update(
      'section_shifts',
      shift.toMap(),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  Future<int> deleteSectionShift(int id) async {
    final db = await database;
    return await db.delete(
      'section_shifts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== BULK OPERATIONS ====================

  Future<void> insertMultipleReceptionShifts(List<ReceptionShift> shifts) async {
    final db = await database;
    final batch = db.batch();
    for (var shift in shifts) {
      batch.insert('reception_shifts', shift.toMap());
    }
    await batch.commit();
  }

  Future<void> insertMultipleSectionShifts(List<SectionShift> shifts) async {
    final db = await database;
    final batch = db.batch();
    for (var shift in shifts) {
      batch.insert('section_shifts', shift.toMap());
    }
    await batch.commit();
  }

  // ==================== UTILITY METHODS ====================

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('section_shifts');
    await db.delete('reception_shifts');
    await db.delete('reception_drops');
    await db.delete('doctor_requests');
    await db.delete('doctor_constraints');
    await db.delete('doctors');
    await db.delete('users');
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  // ==================== SCHEDULE HELPERS ====================

  // Helper method to get reception schedule for a month
  Future<List<ReceptionShift>> getReceptionScheduleForMonth(String month) async {
    return await getReceptionShiftsByMonth(month);
  }

  // Helper method to get section schedule for a month
  Future<List<SectionShift>> getSectionScheduleForMonth(String month) async {
    return await getSectionShiftsByMonth(month);
  }

  // Check if doctor has shift on a specific date
  Future<bool> doctorHasShiftOnDate(int doctorId, String date) async {
    final receptionShifts = await getReceptionShiftsByDate(date);
    final sectionShifts = await getSectionShiftsByDate(date);

    return receptionShifts.any((shift) => shift.doctorId == doctorId) ||
        sectionShifts.any((shift) => shift.doctorId == doctorId);
  }

  // Get all shifts for a doctor on a specific date
  Future<Map<String, List<dynamic>>> getDoctorShiftsOnDate(int doctorId, String date) async {
    final receptionShifts = await getReceptionShiftsByDate(date);
    final sectionShifts = await getSectionShiftsByDate(date);

    return {
      'reception': receptionShifts.where((shift) => shift.doctorId == doctorId).toList(),
      'section': sectionShifts.where((shift) => shift.doctorId == doctorId).toList(),
    };
  }
}