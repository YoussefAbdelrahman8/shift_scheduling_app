import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

  // Add this method to your DatabaseHelper class

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