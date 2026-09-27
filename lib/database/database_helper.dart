import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // =====================================================
  // SINGLE DATABASE INSTANCE
  // =====================================================

  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  // =====================================================
  // DATABASE GETTER
  // =====================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('ankuram.db');

    return _database!;
  }

  // =====================================================
  // INITIALIZE DATABASE
  // =====================================================

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // =====================================================
  // CREATE DATABASE
  // =====================================================

  Future<void> _createDB(
    Database db,
    int version,
  ) async {
    // ===================================================
    // STUDENTS TABLE
    // ===================================================

    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        advance_paid INTEGER NOT NULL,
        fees_paid INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ===================================================
    // ATTENDANCE TABLE
    // ===================================================

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        attendance_date TEXT NOT NULL,
        status TEXT NOT NULL,

        UNIQUE(student_id, attendance_date),

        FOREIGN KEY (student_id)
          REFERENCES students(id)
          ON DELETE CASCADE
      )
    ''');

    // ===================================================
    // MONTHLY FEES TABLE
    // ===================================================

    await db.execute('''
      CREATE TABLE fee_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        fee_month TEXT NOT NULL,
        is_paid INTEGER NOT NULL,

        UNIQUE(student_id, fee_month),

        FOREIGN KEY (student_id)
          REFERENCES students(id)
          ON DELETE CASCADE
      )
    ''');
  }

  // =====================================================
  // DATABASE UPGRADES
  // =====================================================

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 1 -> Version 2
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          attendance_date TEXT NOT NULL,
          status TEXT NOT NULL,

          UNIQUE(student_id, attendance_date),

          FOREIGN KEY (student_id)
            REFERENCES students(id)
            ON DELETE CASCADE
        )
      ''');
    }

    // Version 2 -> Version 3
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE fee_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          fee_month TEXT NOT NULL,
          is_paid INTEGER NOT NULL,

          UNIQUE(student_id, fee_month),

          FOREIGN KEY (student_id)
            REFERENCES students(id)
            ON DELETE CASCADE
        )
      ''');
    }
  }

  // =====================================================
  // STUDENTS
  // =====================================================

  Future<int> insertStudent(
    Map<String, dynamic> student,
  ) async {
    final db = await database;

    // Insert student
    final int studentId = await db.insert(
      'students',
      student,
    );

    // ===================================================
    // CREATE CURRENT MONTH FEE RECORD
    // ===================================================

    final DateTime now = DateTime.now();

    final String currentMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    await db.insert(
      'fee_payments',
      {
        'student_id': studentId,
        'fee_month': currentMonth,
        'is_paid': student['fees_paid'] == 1 ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return studentId;
  }

  // =====================================================
  // GET ALL STUDENTS
  // =====================================================

  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;

    return await db.query(
      'students',
      orderBy: 'id DESC',
    );
  }

  // =====================================================
  // UPDATE STUDENT
  // =====================================================

  Future<int> updateStudent(
    int id,
    Map<String, dynamic> student,
  ) async {
    final db = await database;

    return await db.update(
      'students',
      student,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =====================================================
  // DELETE STUDENT
  // =====================================================

  Future<int> deleteStudent(int id) async {
    final db = await database;

    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =====================================================
  // ADVANCE PAYMENT
  // =====================================================

  Future<void> updateAdvancePayment({
    required int studentId,
    required bool isPaid,
  }) async {
    final db = await database;

    await db.update(
      'students',
      {
        'advance_paid': isPaid ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  // =====================================================
  // ATTENDANCE
  // =====================================================

  Future<void> saveAttendance({
    required int studentId,
    required String date,
    required bool isPresent,
  }) async {
    final db = await database;

    await db.insert(
      'attendance',
      {
        'student_id': studentId,
        'attendance_date': date,
        'status': isPresent ? 'present' : 'absent',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =====================================================
  // GET ATTENDANCE FOR DATE
  // =====================================================

  Future<List<Map<String, dynamic>>> getAttendanceForDate(
    String date,
  ) async {
    final db = await database;

    return await db.rawQuery(
      '''
      SELECT
        attendance.id,
        attendance.student_id,
        attendance.attendance_date,
        attendance.status

      FROM attendance

      INNER JOIN students
        ON students.id = attendance.student_id

      WHERE attendance.attendance_date = ?

      ORDER BY students.name COLLATE NOCASE ASC
      ''',
      [date],
    );
  }

  // =====================================================
  // CHECK WHETHER ATTENDANCE IS COMPLETE
  // =====================================================

  Future<bool> isAttendanceTaken(
    String date,
  ) async {
    final db = await database;

    // Total current students
    final studentResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM students
      ''',
    );

    final int totalStudents =
        (studentResult.first['total'] as num?)?.toInt() ?? 0;

    // No students
    if (totalStudents == 0) {
      return false;
    }

    // Students with attendance
    final attendanceResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT attendance.student_id) AS total

      FROM attendance

      INNER JOIN students
        ON students.id = attendance.student_id

      WHERE attendance.attendance_date = ?
      ''',
      [date],
    );

    final int markedStudents =
        (attendanceResult.first['total'] as num?)?.toInt() ?? 0;

    return markedStudents >= totalStudents;
  }

  // =====================================================
  // ATTENDANCE STATISTICS
  // =====================================================

  Future<Map<String, int>> getStudentAttendanceStats(
    int studentId,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total_classes,

        COALESCE(
          SUM(
            CASE
              WHEN status = 'present'
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS attended

      FROM attendance

      WHERE student_id = ?
      ''',
      [studentId],
    );

    final int totalClasses =
        (result.first['total_classes'] as num?)?.toInt() ?? 0;

    final int attended =
        (result.first['attended'] as num?)?.toInt() ?? 0;

    final int absent = totalClasses - attended;

    return {
      'total': totalClasses,
      'attended': attended,
      'absent': absent,
    };
  }

  // =====================================================
  // MONTHLY FEES
  // =====================================================

  Future<List<Map<String, dynamic>>> getStudentsWithFeeStatus(
    String month,
  ) async {
    final db = await database;

    return await db.rawQuery(
      '''
      SELECT
        students.id,
        students.name,
        students.phone,
        students.advance_paid,
        students.fees_paid,

        COALESCE(
          fee_payments.is_paid,
          0
        ) AS monthly_paid

      FROM students

      LEFT JOIN fee_payments
        ON students.id = fee_payments.student_id

        AND fee_payments.fee_month = ?

      ORDER BY students.name COLLATE NOCASE ASC
      ''',
      [month],
    );
  }

  // =====================================================
  // SAVE MONTHLY FEE
  // =====================================================

  Future<void> saveMonthlyFee({
    required int studentId,
    required String month,
    required bool isPaid,
  }) async {
    final db = await database;

    await db.insert(
      'fee_payments',
      {
        'student_id': studentId,
        'fee_month': month,
        'is_paid': isPaid ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =====================================================
  // CHECK MONTH LOCK
  // =====================================================

  Future<bool> isMonthlyFeeMarked(
    String month,
  ) async {
    final db = await database;

    // Total students
    final studentResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM students
      ''',
    );

    final int totalStudents =
        (studentResult.first['total'] as num?)?.toInt() ?? 0;

    if (totalStudents == 0) {
      return false;
    }

    // Students with fee record
    final feeResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT fee_payments.student_id) AS total

      FROM fee_payments

      INNER JOIN students
        ON students.id = fee_payments.student_id

      WHERE fee_payments.fee_month = ?
      ''',
      [month],
    );

    final int markedStudents =
        (feeResult.first['total'] as num?)?.toInt() ?? 0;

    return markedStudents >= totalStudents;
  }

  // =====================================================
  // GET MONTHLY FEES
  // =====================================================

  Future<List<Map<String, dynamic>>> getMonthlyFees(
    String month,
  ) async {
    final db = await database;

    return await db.query(
      'fee_payments',
      where: 'fee_month = ?',
      whereArgs: [month],
      orderBy: 'student_id ASC',
    );
  }

  // =====================================================
  // CLOSE DATABASE
  // =====================================================

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // =====================================================
  // BACKUP DATABASE
  // =====================================================

  Future<bool> backupDatabase() async {
    try {
      final db = await database;

      // Get all data
      final students = await db.query('students');
      final attendance = await db.query('attendance');
      final feePayments = await db.query('fee_payments');

      final Map<String, dynamic> backupData = {
        'backup_version': 1,
        'backup_date': DateTime.now().toIso8601String(),
        'students': students,
        'attendance': attendance,
        'fee_payments': feePayments,
      };

      final String jsonData = jsonEncode(backupData);

      // Ask user where to save
      final String? result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Ankuram Backup',
        fileName:
            'ankuram_backup_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // User cancelled
      if (result == null) {
        return false;
      }

      final File file = File(result);

      await file.writeAsString(
        jsonData,
        flush: true,
      );

      return true;
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  // =====================================================
  // RESTORE DATABASE
  // =====================================================

  Future<bool> restoreDatabase() async {
    try {
      // Ask user to select backup
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Ankuram Backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      // User cancelled
      if (result == null ||
          result.files.single.path == null) {
        return false;
      }

      final String filePath = result.files.single.path!;

      final File file = File(filePath);

      final String jsonString =
          await file.readAsString();

      final dynamic decodedData =
          jsonDecode(jsonString);

      if (decodedData is! Map<String, dynamic>) {
        return false;
      }

      final Map<String, dynamic> backupData =
          decodedData;

      // =================================================
      // CHECK BACKUP STRUCTURE
      // =================================================

      if (!backupData.containsKey('students') ||
          !backupData.containsKey('attendance') ||
          !backupData.containsKey('fee_payments')) {
        return false;
      }

      final db = await database;

      // =================================================
      // RESTORE EVERYTHING IN ONE TRANSACTION
      // =================================================

      await db.transaction((txn) async {
        // Delete existing data
        await txn.delete('attendance');
        await txn.delete('fee_payments');
        await txn.delete('students');

        // -----------------------------------------------
        // RESTORE STUDENTS
        // -----------------------------------------------

        final List<dynamic> students =
            backupData['students'] as List<dynamic>;

        for (final dynamic student in students) {
          await txn.insert(
            'students',
            Map<String, dynamic>.from(student as Map),
          );
        }

        // -----------------------------------------------
        // RESTORE ATTENDANCE
        // -----------------------------------------------

        final List<dynamic> attendance =
            backupData['attendance'] as List<dynamic>;

        for (final dynamic record in attendance) {
          await txn.insert(
            'attendance',
            Map<String, dynamic>.from(record as Map),
          );
        }

        // -----------------------------------------------
        // RESTORE FEE PAYMENTS
        // -----------------------------------------------

        final List<dynamic> feePayments =
            backupData['fee_payments'] as List<dynamic>;

        for (final dynamic fee in feePayments) {
          await txn.insert(
            'fee_payments',
            Map<String, dynamic>.from(fee as Map),
          );
        }
      });

      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }
}