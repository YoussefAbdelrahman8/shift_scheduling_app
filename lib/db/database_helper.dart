// db/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
      version: 2, // Increased version for users table
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

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

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add users table for existing databases
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ------------------- USER AUTHENTICATION -------------------

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<int> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final db = await database;

    // Check if username already exists
    final existingUsername = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (existingUsername.isNotEmpty) {
      throw Exception('Username already exists');
    }

    // Check if email already exists
    final existingEmail = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (existingEmail.isNotEmpty) {
      throw Exception('Email already exists');
    }

    return await db.insert(
      'users',
      {
        'username': username,
        'email': email,
        'password': _hashPassword(password),
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>?> loginUser({
    required String username,
    required String password,
  }) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);

    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashedPassword],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<bool> userExists(String username) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty;
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

  // Add to database_helper.dart
  Future<Map<String, dynamic>> getDoctorSchedulingData(DateTime startDate, DateTime endDate) async {
    final db = await database;

    // Get all doctors
    final doctors = await db.query('doctor');

    // Get section shifts for the date range
    final sectionShifts = await db.query(
      'section_shifts',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // Get reception constraints
    final constraints = await db.query('reception_constraints');

    // Get doctor exceptions
    final exceptions = await db.query(
      'doctor_exceptions_days',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return {
      'doctors': doctors,
      'sectionShifts': sectionShifts,
      'constraints': constraints,
      'exceptions': exceptions,
    };
  }
}