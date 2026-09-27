import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database/database_helper.dart';

class AttendPage extends StatefulWidget {
  const AttendPage({super.key});

  @override
  State<AttendPage> createState() => _AttendPageState();
}

class _AttendPageState extends State<AttendPage> {
  List<Map<String, dynamic>> students = [];

  // student ID -> true = Present, false = Absent
  Map<int, bool> attendance = {};

  bool loading = true;

  // True when today's attendance has already been saved
  bool attendanceAlreadyTaken = false;

  bool editing = false;
  bool saving = false;
  bool markingAllPresent = false;

  // =====================================================
  // COLORS
  // =====================================================

  static const Color headerPurple =
      Color(0xFF53176B);

  static const Color buttonPurple =
      Color(0xFF4B185D);

  static const Color presentGreen =
      Color(0xFF238636);

  // =====================================================
  // TODAY
  // =====================================================

  String get today {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    loadStudents();
  }

  // =====================================================
  // LOAD STUDENTS + ATTENDANCE
  // =====================================================

  Future<void> loadStudents() async {
    try {
      final rawData =
          await DatabaseHelper.instance.getStudents();

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(rawData);

      // Sort A-Z
      data.sort((a, b) {
        final String nameA =
            (a['name']?.toString() ?? '')
                .trim()
                .toLowerCase();

        final String nameB =
            (b['name']?.toString() ?? '')
                .trim()
                .toLowerCase();

        return nameA.compareTo(nameB);
      });

      // Check whether attendance has already been taken
      final bool alreadyTaken =
          await DatabaseHelper.instance
              .isAttendanceTaken(today);

      // Get today's saved attendance
      final savedAttendance =
          await DatabaseHelper.instance
              .getAttendanceForDate(today);

      final Map<int, bool> tempAttendance = {};

      // ===================================================
      // CURRENT STUDENTS
      // ===================================================

      final Set<int> currentStudentIds = {};

      for (final student in data) {
        final int id =
            (student['id'] as num).toInt();

        currentStudentIds.add(id);

        // New/unmarked students default to Present
        tempAttendance[id] = true;
      }

      // ===================================================
      // LOAD SAVED ATTENDANCE
      // ===================================================

      for (final record in savedAttendance) {
        final int studentId =
            (record['student_id'] as num).toInt();

        // Extra protection
        if (!currentStudentIds.contains(studentId)) {
          continue;
        }

        tempAttendance[studentId] =
            record['status'] == 'present';
      }

      if (!mounted) return;

      setState(() {
        students = data;

        attendance = tempAttendance;

        attendanceAlreadyTaken =
            alreadyTaken;

        // Start locked if today's attendance exists
        editing = false;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error loading attendance: $e'),
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .error,
        ),
      );
    }
  }

  // =====================================================
  // REFRESH
  // =====================================================

  Future<void> refreshAttendance() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    await loadStudents();
  }

  // =====================================================
  // MARK ALL PRESENT
  // =====================================================

  Future<void> markAllPresent() async {
    if (markingAllPresent) return;

    if (attendanceAlreadyTaken && !editing) {
      return;
    }

    if (students.isEmpty) {
      return;
    }

    setState(() {
      markingAllPresent = true;
    });

    // Make every student Present
    final Map<int, bool> updatedAttendance =
        Map<int, bool>.from(attendance);

    for (final student in students) {
      final int id =
          (student['id'] as num).toInt();

      updatedAttendance[id] = true;
    }

    if (!mounted) return;

    setState(() {
      attendance = updatedAttendance;
      markingAllPresent = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'All students marked as Present.',
        ),
        backgroundColor:
            presentGreen,
      ),
    );
  }

  // =====================================================
  // SAVE ATTENDANCE
  // =====================================================

  Future<void> saveAttendance() async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      for (final student in students) {
        final int id =
            (student['id'] as num).toInt();

        await DatabaseHelper.instance.saveAttendance(
          studentId: id,
          date: today,
          isPresent:
              attendance[id] ?? true,
        );
      }

      // Reload from database after saving
      await loadStudents();

      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Attendance saved successfully.'),
          backgroundColor:
              presentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error saving attendance: $e'),
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .error,
        ),
      );
    }
  }

  // =====================================================
  // EDIT
  // =====================================================

  void editAttendance() {
    setState(() {
      editing = true;
    });
  }

  // =====================================================
  // PRESENT COUNT
  // =====================================================

  int get presentCount {
    int count = 0;

    for (final student in students) {
      final int id =
          (student['id'] as num).toInt();

      if (attendance[id] ?? true) {
        count++;
      }
    }

    return count;
  }

  // =====================================================
  // ABSENT COUNT
  // =====================================================

  int get absentCount {
    int count = 0;

    for (final student in students) {
      final int id =
          (student['id'] as num).toInt();

      if (!(attendance[id] ?? true)) {
        count++;
      }
    }

    return count;
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      // =================================================
      // HEADER
      // =================================================

      appBar: AppBar(
        backgroundColor:
            headerPurple,

        foregroundColor:
            Colors.white,

        elevation: 0,

        systemOverlayStyle:
            const SystemUiOverlayStyle(
          statusBarColor:
              headerPurple,
          statusBarIconBrightness:
              Brightness.light,
        ),

        title: const Text(
          'Take Attendance',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            color: Colors.white,
          ),
        ),

        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),

        actions: [
          IconButton(
            onPressed:
                loading
                    ? null
                    : refreshAttendance,

            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),

            tooltip: 'Refresh',
          ),
        ],
      ),

      // =================================================
      // BODY
      // =================================================

      body: loading
          ? Center(
              child:
                  CircularProgressIndicator(
                color:
                    buttonPurple,
              ),
            )
          : students.isEmpty
              ? Center(
                  child: Text(
                    'No students added yet.',
                    style: theme
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                )
              : _attendanceScreen(),
    );
  }

  // =====================================================
  // ATTENDANCE SCREEN
  // =====================================================

  Widget _attendanceScreen() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final bool canEdit =
        !attendanceAlreadyTaken || editing;

    return Column(
      children: [

        // =================================================
        // DATE + ALL PRESENT BUTTON
        // =================================================

        Container(
          width: double.infinity,

          padding:
              const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            14,
          ),

          color:
              colors.surface,

          child: Row(
            children: [

              // DATE
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: buttonPurple,
                    ),

                    const SizedBox(width: 10),

                    Flexible(
                      child: Text(
                        'Date: $today',
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // =================================================
              // ALL PRESENT BUTTON
              // =================================================

              SizedBox(
                height: 42,

                child: ElevatedButton.icon(
                  onPressed:
                      (!canEdit ||
                              markingAllPresent)
                          ? null
                          : markAllPresent,

                  icon:
                      markingAllPresent
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .done_all,
                              size: 19,
                            ),

                  label: const Text(
                    'ALL PRESENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        presentGreen,

                    foregroundColor:
                        Colors.white,

                    disabledBackgroundColor:
                        Colors.grey.shade400,

                    disabledForegroundColor:
                        Colors.white,

                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // =================================================
        // COUNTS
        // =================================================

        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            4,
          ),

          child: Row(
            children: [
              _countCard(
                title: 'Present',
                count: presentCount,
                color:
                    Colors.green,
              ),

              const SizedBox(width: 10),

              _countCard(
                title: 'Absent',
                count: absentCount,
                color:
                    colors.error,
              ),
            ],
          ),
        ),

        // =================================================
        // LOCK MESSAGE
        // =================================================

        if (attendanceAlreadyTaken &&
            !editing)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              4,
            ),

            child: Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(12),

              decoration:
                  BoxDecoration(
                color:
                    colors.primaryContainer,

                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),

              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 19,
                    color:
                        colors
                            .onPrimaryContainer,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Today\'s attendance is locked.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            colors
                                .onPrimaryContainer,
                      ),
                    ),
                  ),

                  Text(
                    'LOCKED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          colors
                              .onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // =================================================
        // EDIT MESSAGE
        // =================================================

        if (editing)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              4,
            ),

            child: Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(12),

              decoration:
                  BoxDecoration(
                color:
                    theme.brightness ==
                            Brightness.dark
                        ? Colors.orange
                            .withValues(
                            alpha: 0.16,
                          )
                        : const Color(
                            0xFFFFF4DD,
                          ),

                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),

              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 19,
                    color:
                        theme.brightness ==
                                Brightness.dark
                            ? Colors
                                .orange
                                .shade300
                            : const Color(
                                0xFFE08A00,
                              ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Edit mode is ON. Change attendance and save.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            theme.brightness ==
                                    Brightness.dark
                                ? Colors
                                    .orange
                                    .shade300
                                : const Color(
                                    0xFF8A5A00,
                                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // =================================================
        // INFO
        // =================================================

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),

          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color:
                    colors
                        .onSurfaceVariant,
              ),

              const SizedBox(width: 6),

              Text(
                'ON = Present     OFF = Absent',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      colors
                          .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // =================================================
        // STUDENTS
        // =================================================

        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              4,
              12,
              12,
            ),

            itemCount:
                students.length,

            itemBuilder:
                (context, index) {
              final student =
                  students[index];

              final int id =
                  (student['id'] as num)
                      .toInt();

              final String name =
                  student['name']
                          ?.toString() ??
                      '';

              final bool isPresent =
                  attendance[id] ?? true;

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 8,
                ),

                elevation: 1,

                color:
                    colors.surface,

                surfaceTintColor:
                    colors.surfaceTint,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),

                  side: BorderSide(
                    color:
                        colors
                            .outlineVariant,
                  ),
                ),

                child: ListTile(
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),

                  title: Text(
                    '${index + 1}. $name',

                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  trailing:
                      Switch(
                    value:
                        isPresent,

                    activeThumbColor:
                        buttonPurple,

                    activeTrackColor:
                        const Color(
                      0xFFE8D7EF,
                    ),

                    inactiveThumbColor:
                        colors
                            .onSurfaceVariant,

                    inactiveTrackColor:
                        colors
                            .surfaceContainerHighest,

                    onChanged: canEdit
                        ? (value) {
                            setState(() {
                              attendance[
                                  id] = value;
                            });
                          }
                        : null,
                  ),
                ),
              );
            },
          ),
        ),

        // =================================================
        // BOTTOM BUTTON
        // =================================================

        SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(14),

            child: SizedBox(
              width: double.infinity,
              height: 52,

              child:
                  ElevatedButton(
                onPressed:
                    saving
                        ? null
                        : canEdit
                            ? saveAttendance
                            : editAttendance,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      buttonPurple,

                  foregroundColor:
                      Colors.white,

                  disabledBackgroundColor:
                      Colors.grey.shade500,

                  disabledForegroundColor:
                      Colors.white,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,

                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.white,
                        ),
                      )
                    : Text(
                        canEdit
                            ? 'SAVE ATTENDANCE'
                            : 'EDIT ATTENDANCE',

                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // COUNT CARD
  // =====================================================

  Widget _countCard({
    required String title,
    required int count,
    required Color color,
  }) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),

        decoration:
            BoxDecoration(
          color:
              colors.surface,

          borderRadius:
              BorderRadius.circular(
            12,
          ),

          border: Border.all(
            color:
                colors.outlineVariant,
          ),
        ),

        child: Row(
          children: [
            Icon(
              title == 'Present'
                  ? Icons.check_circle
                  : Icons.cancel,

              color: color,
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    fontSize: 12,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                Text(
                  '$count',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
