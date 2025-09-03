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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // ---------------- USERS ----------------
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------------- DOCTORS ----------------
    await db.execute('''
      CREATE TABLE doctor (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialization TEXT,
        seniority TEXT
      )
    ''');

    // ---------------- SECTION SHIFTS ----------------
    await db.execute('''
      CREATE TABLE section_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');

    // ---------------- RECEPTION CONSTRAINTS ----------------
    await db.execute('''
      CREATE TABLE reception_constraints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        totalShifts INTEGER DEFAULT 0,
        morningShifts INTEGER DEFAULT 0,
        eveningShifts INTEGER DEFAULT 0,
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');

    // ---------------- DOCTOR REQUESTS ----------------
    await db.execute('''
      CREATE TABLE doctor_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL CHECK (shift IN ('Morning', 'Evening')),
        type TEXT NOT NULL CHECK (type IN ('wanted', 'exception')),
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');

    // ---------------- RECEPTION SCHEDULE ----------------
    await db.execute('''
      CREATE TABLE reception_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL CHECK (shift IN ('Morning', 'Evening')),
        FOREIGN KEY (doctor_id) REFERENCES doctor(id) ON DELETE CASCADE
      )
    ''');
  }

  // ------------------- PASSWORD HASHING -------------------
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ------------------- USER AUTH -------------------
  Future<int> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final db = await database;

    final existingUsername = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (existingUsername.isNotEmpty) throw Exception('Username already exists');

    final existingEmail = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (existingEmail.isNotEmpty) throw Exception('Email already exists');

    return await db.insert('users', {
      'username': username,
      'email': email,
      'password': _hashPassword(password),
      'created_at': DateTime.now().toIso8601String(),
    });
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

  // ------------------- DOCTOR CRUD -------------------
  Future<int> insertDoctor({
    required String name,
    required String specialization,
    required String seniority,
  }) async {
    final db = await database;
    return await db.insert('doctor', {
      'name': name,
      'specialization': specialization,
      'seniority': seniority,
    });
  }

  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    final db = await database;
    return await db.query('doctor');
  }

  Future<List<Map<String, dynamic>>> getDoctorsBySpecialization(String specialization) async {
    final db = await database;
    return await db.query(
      'doctor',
      where: 'specialization = ?',
      whereArgs: [specialization],
    );
  }

  // ------------------- SECTION SHIFTS -------------------
  Future<int> insertSectionSchedule({
    required int doctorId,
    required String date,
  }) async {
    final db = await database;
    return await db.insert('section_shifts', {
      'doctor_id': doctorId,
      'date': date,
    });
  }

  Future<List<Map<String, dynamic>>> getAllSectionSchedules() async {
    final db = await database;
    return await db.query('section_shifts');
  }

  // ------------------- RECEPTION CONSTRAINTS -------------------
  Future<Map<String, dynamic>?> getReceptionConstraints(int doctorId) async {
    final db = await database;
    final result = await db.query(
      'reception_constraints',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertOrUpdateReceptionConstraints({
    required int doctorId,
    required int totalShifts,
    required int morningShifts,
    required int eveningShifts,
  }) async {
    final db = await database;
    final existing = await db.query('reception_constraints', where: 'doctor_id = ?', whereArgs: [doctorId]);

    if (existing.isNotEmpty) {
      return await db.update(
        'reception_constraints',
        {
          'totalShifts': totalShifts,
          'morningShifts': morningShifts,
          'eveningShifts': eveningShifts,
        },
        where: 'doctor_id = ?',
        whereArgs: [doctorId],
      );
    } else {
      return await db.insert('reception_constraints', {
        'doctor_id': doctorId,
        'totalShifts': totalShifts,
        'morningShifts': morningShifts,
        'eveningShifts': eveningShifts,
      });
    }
  }

  // ------------------- DOCTOR REQUESTS -------------------
  Future<int> insertDoctorRequest({
    required int doctorId,
    required String date,
    required String shift,
    required String type, // "wanted" or "exception"
  }) async {
    final db = await database;
    if (!['Morning', 'Evening'].contains(shift)) throw Exception('Invalid shift');
    if (!['wanted', 'exception'].contains(type)) throw Exception('Invalid request type');

    return await db.insert('doctor_requests', {
      'doctor_id': doctorId,
      'date': date,
      'shift': shift,
      'type': type,
    });
  }

  Future<List<Map<String, dynamic>>> getDoctorRequests(int doctorId, {String? type}) async {
    final db = await database;
    if (type != null) {
      return await db.query('doctor_requests', where: 'doctor_id = ? AND type = ?', whereArgs: [doctorId, type]);
    }
    return await db.query('doctor_requests', where: 'doctor_id = ?', whereArgs: [doctorId]);
  }

  // New method to get only wanted days
  Future<List<Map<String, dynamic>>> getDoctorWantedDays(int doctorId) async {
    return await getDoctorRequests(doctorId, type: 'wanted');
  }

  // New method to get only exception days
  Future<List<Map<String, dynamic>>> getDoctorExceptionDays(int doctorId) async {
    return await getDoctorRequests(doctorId, type: 'exception');
  }

  // New method to delete specific requests
  Future<int> deleteDoctorRequest(int requestId) async {
    final db = await database;
    return await db.delete(
      'doctor_requests',
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  // New method to delete all requests for a doctor (optional)
  Future<int> deleteAllDoctorRequests(int doctorId, {String? type}) async {
    final db = await database;
    if (type != null) {
      return await db.delete(
        'doctor_requests',
        where: 'doctor_id = ? AND type = ?',
        whereArgs: [doctorId, type],
      );
    }
    return await db.delete(
      'doctor_requests',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
    );
  }

  // ------------------- SCHEDULING DATA -------------------
  Future<Map<String, dynamic>> getDoctorSchedulingData(DateTime startDate, DateTime endDate) async {
    final db = await database;

    final doctors = await db.query('doctor');
    final sectionShifts = await db.query(
      'section_shifts',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );
    final constraints = await db.query('reception_constraints');
    final requests = await db.query(
      'doctor_requests',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return {
      'doctors': doctors,
      'sectionShifts': sectionShifts,
      'constraints': constraints,
      'requests': requests,
    };
  }
}