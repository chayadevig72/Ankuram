import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'event.dart';
import 'fees.dart';
import 'new.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<Map<String, dynamic>> students = [];

  bool loading = true;

  // Which student is currently expanded.
  int? expandedStudentId;

  // Attendance information for each student.
  final Map<int, Map<String, int>> attendanceStats = {};

  // Current month's fee status.
  //
  // student id -> true = paid
  // student id -> false = not paid
  final Map<int, bool> monthlyFeeStatus = {};

  // Students whose attendance is currently loading.
  final Set<int> loadingAttendance = {};

  @override
  void initState() {
    super.initState();
    loadStudents();
  }

  // =====================================================
  // LOAD STUDENTS + CURRENT MONTH FEE STATUS
  // =====================================================

  Future<void> loadStudents() async {
    try {
      final data =
          await DatabaseHelper.instance.getStudents();

      // Convert database data to a normal list.
      final List<Map<String, dynamic>> loadedStudents =
          data
              .map(
                (student) =>
                    Map<String, dynamic>.from(student),
              )
              .toList();

      // =================================================
      // SORT STUDENTS ALPHABETICALLY BY NAME (A-Z)
      // =================================================
      loadedStudents.sort((a, b) {
        final String nameA =
            a['name']?.toString().trim().toLowerCase() ?? '';

        final String nameB =
            b['name']?.toString().trim().toLowerCase() ?? '';

        return nameA.compareTo(nameB);
      });

      // Current month in YYYY-MM format.
      final DateTime now = DateTime.now();

      final String currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Get the current month's fee status.
      final feeData =
          await DatabaseHelper.instance
              .getStudentsWithFeeStatus(currentMonth);

      final Map<int, bool> newMonthlyFeeStatus = {};

      for (final feeStudent in feeData) {
        final int studentId =
            (feeStudent['id'] as num).toInt();

        final dynamic paidValue =
            feeStudent['monthly_paid'];

        newMonthlyFeeStatus[studentId] =
            paidValue == 1 || paidValue == true;
      }

      if (!mounted) return;

      setState(() {
        students = loadedStudents;

        monthlyFeeStatus
          ..clear()
          ..addAll(newMonthlyFeeStatus);

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load students: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // LOAD ATTENDANCE FOR PARTICULAR STUDENT
  // =====================================================

  Future<void> loadAttendanceForStudent(
    int studentId,
  ) async {
    if (attendanceStats.containsKey(studentId)) {
      return;
    }

    if (loadingAttendance.contains(studentId)) {
      return;
    }

    setState(() {
      loadingAttendance.add(studentId);
    });

    try {
      final stats =
          await DatabaseHelper.instance
              .getStudentAttendanceStats(studentId);

      if (!mounted) return;

      setState(() {
        attendanceStats[studentId] = stats;
        loadingAttendance.remove(studentId);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingAttendance.remove(studentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load attendance: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // EXPAND / COLLAPSE STUDENT
  // =====================================================

  Future<void> toggleStudentInfo(
    Map<String, dynamic> student,
  ) async {
    final int id =
        (student['id'] as num).toInt();

    if (expandedStudentId == id) {
      setState(() {
        expandedStudentId = null;
      });

      return;
    }

    setState(() {
      expandedStudentId = id;
    });

    await loadAttendanceForStudent(id);
  }

  // =====================================================
  // EDIT STUDENT
  // =====================================================

  Future<void> editStudent(
    Map<String, dynamic> student,
  ) async {
    final int id =
        (student['id'] as num).toInt();

    final Map<String, String>? editedData =
        await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _EditStudentDialog(
          initialName:
              student['name']?.toString() ?? '',
          initialPhone:
              student['phone']?.toString() ?? '',
        );
      },
    );

    if (editedData == null) {
      return;
    }

    try {
      await DatabaseHelper.instance.updateStudent(
        id,
        {
          'name': editedData['name']!,
          'phone': editedData['phone']!,
        },
      );

      if (!mounted) return;

      await loadStudents();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student updated successfully.',
          ),
          backgroundColor: Color(0xFF238636),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update student: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // DELETE CONFIRMATION
  // =====================================================

  Future<void> confirmDelete(
    Map<String, dynamic> student,
  ) async {
    final String name =
        student['name']?.toString() ?? 'Student';

    final int id =
        (student['id'] as num).toInt();

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final bool isDark =
            Theme.of(dialogContext).brightness ==
                Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark
              ? const Color(0xFF1E1E1E)
              : Colors.white,

          title: Text(
            'Delete Student?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? Colors.white
                  : const Color(0xFF30113B),
            ),
          ),

          content: Text(
            'Are you sure you want to remove $name '
            'from the class?\n\n'
            'This will also remove the student\'s '
            'attendance and fee records.',
            style: TextStyle(
              color: isDark
                  ? Colors.white70
                  : Colors.black87,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF4B185D),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'DELETE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await deleteStudent(id, name);
  }

  // =====================================================
  // DELETE STUDENT
  // =====================================================

  Future<void> deleteStudent(
    int id,
    String name,
  ) async {
    try {
      await DatabaseHelper.instance
          .deleteStudent(id);

      if (!mounted) return;

      setState(() {
        students.removeWhere(
          (student) => student['id'] == id,
        );

        attendanceStats.remove(id);

        monthlyFeeStatus.remove(id);

        if (expandedStudentId == id) {
          expandedStudentId = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name removed successfully.',
          ),
          backgroundColor:
              const Color(0xFF238636),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete student: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // FORMAT JOINING DATE
  // =====================================================

  String formatJoiningDate(String? date) {
    if (date == null || date.isEmpty) {
      return 'Unknown';
    }

    try {
      final DateTime parsedDate =
          DateTime.parse(date);

      final String day =
          parsedDate.day
              .toString()
              .padLeft(2, '0');

      final String month =
          parsedDate.month
              .toString()
              .padLeft(2, '0');

      final String year =
          parsedDate.year.toString();

      return '$day-$month-$year';
    } catch (e) {
      return date;
    }
  }

  // =====================================================
  // PAYMENT STATUS
  // =====================================================

  String paymentStatus(dynamic value) {
    if (value == 1 || value == true) {
      return 'Paid';
    }

    return 'Not Paid';
  }

  // =====================================================
  // ATTENDANCE PERCENTAGE
  // =====================================================

  double attendancePercentage(
    int attended,
    int total,
  ) {
    if (total == 0) {
      return 0;
    }

    return (attended / total) * 100;
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Students',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFF4B185D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : students.isEmpty
              ? _emptyView()
              : _studentList(),

      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================

  Widget _buildBottomNavigationBar() {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return NavigationBar(
      selectedIndex: 1,

      backgroundColor:
          Theme.of(context)
              .colorScheme
              .surface,

      indicatorColor:
          const Color(0xFF4B185D)
              .withOpacity(
        isDark ? 0.35 : 0.12,
      ),

      onDestinationSelected:
          (index) async {
        switch (index) {
          case 0:
            Navigator.of(context).popUntil(
              (route) => route.isFirst,
            );
            break;

          case 1:
            break;

          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const NewStudentPage(),
              ),
            ).then((_) {
              if (mounted) {
                loadStudents();
              }
            });
            break;

          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const EventPage(),
              ),
            );
            break;

          case 4:
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const FeesPage(),
              ),
            );

            if (mounted) {
              await loadStudents();
            }

            break;
        }
      },

      destinations: const [
        NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
          ),
          selectedIcon: Icon(
            Icons.home,
          ),
          label: 'Home',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.people_outline,
          ),
          selectedIcon: Icon(
            Icons.people,
          ),
          label: 'Students',
        ),

        NavigationDestination(
          icon: CircleAvatar(
            radius: 18,
            backgroundColor:
                Color(0xFF4B185D),
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 25,
            ),
          ),
          selectedIcon: CircleAvatar(
            radius: 20,
            backgroundColor:
                Color(0xFF30113B),
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 27,
            ),
          ),
          label: 'Add',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.event_outlined,
          ),
          selectedIcon: Icon(
            Icons.event,
          ),
          label: 'Events',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.currency_rupee,
          ),
          selectedIcon: Icon(
            Icons.currency_rupee,
          ),
          label: 'Fees',
        ),
      ],
    );
  }

  // =====================================================
  // STUDENT LIST
  // =====================================================

  Widget _studentList() {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final Color studentNameColor =
        isDark
            ? Colors.white
            : const Color(0xFF30113B);

    return RefreshIndicator(
      onRefresh: loadStudents,

      child: ListView.builder(
        padding:
            const EdgeInsets.all(12),

        itemCount: students.length,

        itemBuilder:
            (context, index) {
          final Map<String, dynamic>
              student = students[index];

          final int id =
              (student['id'] as num).toInt();

          final String name =
              student['name']
                      ?.toString() ??
                  '';

          final bool isExpanded =
              expandedStudentId == id;

          return _buildStudentCard(
            student: student,
            index: index,
            id: id,
            name: name,
            isExpanded: isExpanded,
            isDark: isDark,
            studentNameColor:
                studentNameColor,
          );
        },
      ),
    );
  }

  // =====================================================
  // STUDENT CARD
  // =====================================================

  Widget _buildStudentCard({
    required Map<String, dynamic> student,
    required int index,
    required int id,
    required String name,
    required bool isExpanded,
    required bool isDark,
    required Color studentNameColor,
  }) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      elevation: 1,

      color: isDark
          ? const Color(0xFF242424)
          : Colors.white,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),

      clipBehavior:
          Clip.antiAlias,

      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              14,
              14,
              8,
              14,
            ),

            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,

                  decoration:
                      BoxDecoration(
                    color: isDark
                        ? const Color(
                            0xFF3A2940,
                          )
                        : const Color(
                            0xFFF0E8F3,
                          ),

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),

                  alignment:
                      Alignment.center,

                  child: Text(
                    '${index + 1}',

                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                      color: isDark
                          ? Colors.white
                          : const Color(
                              0xFF4B185D,
                            ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),

                    onTap: () {
                      toggleStudentInfo(
                        student,
                      );
                    },

                    child: Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 5,
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          Text(
                            name,

                            style: TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  studentNameColor,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            isExpanded
                                ? 'Tap to hide details'
                                : 'Tap to view details',

                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey
                                      .shade400
                                  : Colors.grey
                                      .shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    editStudent(
                      student,
                    );
                  },

                  tooltip:
                      'Edit student',

                  icon: Icon(
                    Icons.edit_outlined,
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF4B185D,
                          ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    confirmDelete(
                      student,
                    );
                  },

                  tooltip:
                      'Delete student',

                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),

          if (isExpanded)
            _buildStudentDetails(
              student: student,
              id: id,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // =====================================================
  // STUDENT DETAILS
  // =====================================================

  Widget _buildStudentDetails({
    required Map<String, dynamic> student,
    required int id,
    required bool isDark,
  }) {
    final String phone =
        student['phone']?.toString() ?? '';

    final String joiningDate =
        formatJoiningDate(
      student['created_at']?.toString(),
    );

    final String advanceStatus =
        paymentStatus(
      student['advance_paid'],
    );

    final bool isMonthlyFeePaid =
        monthlyFeeStatus[id] ?? false;

    final String feesStatus =
        isMonthlyFeePaid
            ? 'Paid'
            : 'Not Paid';

    final bool attendanceLoading =
        loadingAttendance.contains(id);

    final Map<String, int>? stats =
        attendanceStats[id];

    final int totalClasses =
        stats?['total'] ?? 0;

    final int attended =
        stats?['attended'] ?? 0;

    final int absent =
        stats?['absent'] ?? 0;

    final double percentage =
        attendancePercentage(
      attended,
      totalClasses,
    );

    final Color detailBackground =
        isDark
            ? const Color(0xFF1B1B1B)
            : const Color(0xFFF8F5FA);

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        18,
      ),

      decoration:
          BoxDecoration(
        color: detailBackground,

        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white12
                : Colors.black12,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const SizedBox(
            height: 12,
          ),

          Text(
            'Student Information',

            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
              color: isDark
                  ? Colors.white
                  : const Color(
                      0xFF30113B,
                    ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon:
                      Icons.phone_outlined,
                  title: 'Phone',
                  value: phone,
                  isDark: isDark,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: _infoItem(
                  icon: Icons
                      .calendar_today_outlined,
                  title: 'Joined',
                  value: joiningDate,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon:
                      Icons.payments_outlined,
                  title: 'Advance',
                  value: advanceStatus,
                  isDark: isDark,
                  valueColor:
                      advanceStatus ==
                              'Paid'
                          ? const Color(
                              0xFF238636,
                            )
                          : Colors.red,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: _infoItem(
                  icon: Icons
                      .receipt_long_outlined,
                  title: 'Fees',
                  value: feesStatus,
                  isDark: isDark,
                  valueColor:
                      feesStatus ==
                              'Paid'
                          ? const Color(
                              0xFF238636,
                            )
                          : Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Text(
            'Attendance',

            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
              color: isDark
                  ? Colors.white
                  : const Color(
                      0xFF30113B,
                    ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          if (attendanceLoading)
            const Center(
              child: Padding(
                padding:
                    EdgeInsets.all(16),
                child:
                    CircularProgressIndicator(),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _attendanceCard(
                    title:
                        'Total Classes',
                    value:
                        '$totalClasses',
                    icon: Icons
                        .class_outlined,
                    isDark: isDark,
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: _attendanceCard(
                    title: 'Attended',
                    value: '$attended',
                    icon: Icons
                        .check_circle_outline,
                    isDark: isDark,
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: _attendanceCard(
                    title: 'Absent',
                    value: '$absent',
                    icon: Icons
                        .cancel_outlined,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(
                14,
              ),

              decoration:
                  BoxDecoration(
                color: isDark
                    ? const Color(
                        0xFF2A2030,
                      )
                    : const Color(
                        0xFFF0E7F4,
                      ),

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [
                      Text(
                        'Attendance Percentage',

                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),

                      Text(
                        '${percentage.toStringAsFixed(1)}%',

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(
                                  0xFF4B185D,
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),

                    child:
                        LinearProgressIndicator(
                      minHeight: 9,

                      value:
                          percentage / 100,

                      backgroundColor:
                          isDark
                              ? Colors.white12
                              : Colors.black12,

                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        Color(0xFF4B185D),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            if (totalClasses == 0)
              Text(
                'No attendance has been recorded for this student yet.',

                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // INFO ITEM
  // =====================================================

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(12),

      decoration:
          BoxDecoration(
        color: isDark
            ? const Color(0xFF242424)
            : Colors.white,

        borderRadius:
            BorderRadius.circular(12),

        border: Border.all(
          color: isDark
              ? Colors.white10
              : Colors.black12,
        ),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                isDark
                    ? Colors.white70
                    : const Color(
                        0xFF4B185D,
                      ),
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  value,

                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        valueColor ??
                            (isDark
                                ? Colors.white
                                : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ATTENDANCE CARD
  // =====================================================

  Widget _attendanceCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 7,
      ),

      decoration:
          BoxDecoration(
        color: isDark
            ? const Color(0xFF242424)
            : Colors.white,

        borderRadius:
            BorderRadius.circular(12),

        border: Border.all(
          color: isDark
              ? Colors.white10
              : Colors.black12,
        ),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                isDark
                    ? Colors.white70
                    : const Color(
                        0xFF4B185D,
                      ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            value,

            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color: isDark
                  ? Colors.white
                  : const Color(
                      0xFF30113B,
                    ),
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            title,

            textAlign:
                TextAlign.center,

            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // EMPTY VIEW
  // =====================================================

  Widget _emptyView() {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return RefreshIndicator(
      onRefresh: loadStudents,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.65,

            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  24,
                ),

                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    Icon(
                      Icons
                          .people_outline,
                      size: 60,
                      color: isDark
                          ? Colors.white
                          : const Color(
                              0xFF4B185D,
                            ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    Text(
                      'No students added yet.',

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      'Students added from the New Student page '
                      'will appear here.',

                      textAlign:
                          TextAlign.center,

                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// EDIT STUDENT DIALOG
// =====================================================

class _EditStudentDialog extends StatefulWidget {
  final String initialName;
  final String initialPhone;

  const _EditStudentDialog({
    required this.initialName,
    required this.initialPhone,
  });

  @override
  State<_EditStudentDialog> createState() =>
      _EditStudentDialogState();
}

class _EditStudentDialogState
    extends State<_EditStudentDialog> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.initialName,
    );

    phoneController = TextEditingController(
      text: widget.initialPhone,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void save() {
    final String name =
        nameController.text.trim();

    final String phone =
        phoneController.text.trim();

    if (name.isEmpty) {
      setState(() {
        errorMessage =
            'Please enter student name.';
      });
      return;
    }

    if (phone.isEmpty) {
      setState(() {
        errorMessage =
            'Please enter phone number.';
      });
      return;
    }

    Navigator.of(context).pop(
      <String, String>{
        'name': name,
        'phone': phone,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.white,

      title: Text(
        'Edit Student',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark
              ? Colors.white
              : const Color(0xFF4B185D),
        ),
      ),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization:
                  TextCapitalization.words,
              style: TextStyle(
                color: isDark
                    ? Colors.white
                    : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Student Name',
                prefixIcon: const Icon(
                  Icons.person_outline,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: phoneController,
              keyboardType:
                  TextInputType.phone,
              style: TextStyle(
                color: isDark
                    ? Colors.white
                    : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 12),

              Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: isDark
                  ? Colors.white70
                  : const Color(0xFF4B185D),
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        ElevatedButton(
          onPressed: save,
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFF4B185D),
            foregroundColor:
                Colors.white,
          ),
          child: const Text(
            'SAVE',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
