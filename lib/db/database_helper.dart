// db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'hospital_schedule.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE doctor (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialization TEXT,
        seniority TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE section_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
  CREATE TABLE reception_constraints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id INTEGER NOT NULL,
    totalShifts INTEGER DEFAULT 0,
    morningShifts INTEGER DEFAULT 0,
    eveningShifts INTEGER DEFAULT 0,
    fullTimeShifts INTEGER DEFAULT 0,
    FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
  )
''');
    await db.execute('''
      CREATE TABLE doctor_exceptions_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reception_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');
  }

  // ------------------- INSERT DOCTOR -------------------
  Future<int> insertDoctor({
    required String name,
    required String specialization,
    required String seniority,
  }) async {
    final db = await database;
    return await db.insert(
      'doctor',
      {
        'name': name,
        'specialization': specialization,
        'seniority': seniority,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ------------------- GET ALL DOCTORS -------------------
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    final db = await database;
    return await db.query('doctor');
  }

  // ------------------- GET DOCTORS BY SPECIALIZATION -------------------
  Future<List<Map<String, dynamic>>> getDoctorsBySpecialization(String specialization) async {
    final db = await database;
    return await db.query(
      'doctor',
      where: 'specialization = ?',
      whereArgs: [specialization],
    );
  }

  Future<int> insertSectionSchedule({
    required int doctorId,
    required String date,
    required String shift,
  }) async {
    final db = await database;
    return await db.insert(
      'section_shifts',
      {
        'doctor_id': doctorId,
        'date': date,
        'shift': shift,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllSectionSchedules() async {
    final db = await database;
    return await db.query('section_shifts');
  }

  // ------------------- RECEPTION CONSTRAINTS -------------------
  Future<int> insertOrUpdateReceptionConstraints({
    required int doctorId,
    required int totalShifts,
    required int morningShifts,
    required int eveningShifts,
    required int fullTimeShifts,
  }) async {
    final db = await database;
    final existing = await db.query(
      'reception_constraints',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'reception_constraints',
        {
          'totalShifts': totalShifts,
          'morningShifts': morningShifts,
          'eveningShifts': eveningShifts,
          'fullTimeShifts': fullTimeShifts,
        },
        where: 'doctor_id = ?',
        whereArgs: [doctorId],
      );
    } else {
      return await db.insert(
        'reception_constraints',
        {
          'doctor_id': doctorId,
          'totalShifts': totalShifts,
          'morningShifts': morningShifts,
          'eveningShifts': eveningShifts,
          'fullTimeShifts': fullTimeShifts,
        },
      );
    }
  }
  Future<Map<String, dynamic>?> getReceptionConstraints(int doctorId) async {
    final db = await database;
    final result = await db.query(
      'reception_constraints',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
  // ------------------- DOCTOR EXCEPTIONS -------------------
  Future<int> insertDoctorExceptionDay({
    required int doctorId,
    required String date,
    required String shift,
  }) async {
    final db = await database;
    return await db.insert(
      'doctor_exceptions_days',
      {
        'doctor_id': doctorId,
        'date': date,
        'shift': shift,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDoctorExceptions(int doctorId) async {
    final db = await database;
    return await db.query(
      'doctor_exceptions_days',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
  }
}