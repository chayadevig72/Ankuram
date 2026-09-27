import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database/database_helper.dart';
import 'attend.dart';
import 'event.dart';
import 'students.dart';
import 'new.dart';

class FeesPage extends StatefulWidget {
  const FeesPage({super.key});

  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  static const int monthlyFee = 1000;

  List<Map<String, dynamic>> students = [];

  bool loading = true;
  bool monthLocked = false;
  bool editing = false;
  bool saving = false;
  bool markingAllPaid = false;

  // =====================================================
  // CURRENT MONTH
  // =====================================================

  String get currentMonth {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // MONTH NAME
  // =====================================================

  String get monthName {
    final now = DateTime.now();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[now.month - 1]} ${now.year}';
  }

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    loadFees();
  }

  // =====================================================
  // LOAD FEES
  // =====================================================

  Future<void> loadFees() async {
    try {
      final data =
          await DatabaseHelper.instance.getStudentsWithFeeStatus(
        currentMonth,
      );

      final locked =
          await DatabaseHelper.instance.isMonthlyFeeMarked(
        currentMonth,
      );

      final List<Map<String, dynamic>> mutableStudents =
          data
              .map(
                (student) =>
                    Map<String, dynamic>.from(student),
              )
              .toList();

      for (final student in mutableStudents) {
        student['monthly_paid'] =
            student['monthly_paid'] == 1 ? 1 : 0;
      }

      if (!mounted) return;

      setState(() {
        students = mutableStudents;
        monthLocked = locked;
        editing = !locked;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load fees: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // PAID COUNT
  // =====================================================

  int get paidCount {
    return students.where((student) {
      return student['monthly_paid'] == 1;
    }).length;
  }

  // =====================================================
  // REMAINING COUNT
  // =====================================================

  int get remainingCount {
    return students.length - paidCount;
  }

  // =====================================================
  // EDIT FEES
  // =====================================================

  void editFees() {
    setState(() {
      editing = true;
    });
  }

  // =====================================================
  // CHANGE INDIVIDUAL FEE STATUS
  // =====================================================

  void changeFeeStatus(
    int index,
    bool value,
  ) {
    if (!editing) {
      return;
    }

    final Map<String, dynamic> updatedStudent =
        Map<String, dynamic>.from(
      students[index],
    );

    updatedStudent['monthly_paid'] =
        value ? 1 : 0;

    setState(() {
      students[index] = updatedStudent;
    });
  }

  // =====================================================
  // MARK ALL STUDENTS AS PAID
  // =====================================================

  Future<void> markAllPaid() async {
    if (markingAllPaid || students.isEmpty) {
      return;
    }

    setState(() {
      markingAllPaid = true;
    });

    try {
      // First update the screen
      setState(() {
        for (int i = 0; i < students.length; i++) {
          final updatedStudent =
              Map<String, dynamic>.from(students[i]);

          updatedStudent['monthly_paid'] = 1;

          students[i] = updatedStudent;
        }
      });

      // Save every student to SQLite
      for (final student in students) {
        final int id = student['id'] as int;

        await DatabaseHelper.instance.saveMonthlyFee(
          studentId: id,
          month: currentMonth,
          isPaid: true,
        );
      }

      final bool allStudentsMarked =
          await DatabaseHelper.instance.isMonthlyFeeMarked(
        currentMonth,
      );

      if (!mounted) return;

      setState(() {
        monthLocked = allStudentsMarked;
        editing = !allStudentsMarked;
        markingAllPaid = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allStudentsMarked
                ? 'All students marked as paid for $monthName.'
                : 'All student fees marked as paid.',
          ),
          backgroundColor: const Color(0xFF238636),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        markingAllPaid = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to mark all students as paid: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // SAVE FEES
  // =====================================================

  Future<void> saveFees() async {
    if (!editing || saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      for (final student in students) {
        final int id = student['id'] as int;

        final bool isPaid =
            student['monthly_paid'] == 1;

        await DatabaseHelper.instance.saveMonthlyFee(
          studentId: id,
          month: currentMonth,
          isPaid: isPaid,
        );
      }

      final bool allStudentsMarked =
          await DatabaseHelper.instance.isMonthlyFeeMarked(
        currentMonth,
      );

      if (!mounted) return;

      setState(() {
        monthLocked = allStudentsMarked;
        editing = !allStudentsMarked;
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allStudentsMarked
                ? '$monthName fees marked successfully. Month is now locked.'
                : '$monthName fees saved.',
          ),
          backgroundColor: const Color(0xFF238636),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save fee status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // ADVANCE PAYMENT DIALOG
  // =====================================================

  Future<void> showAdvanceDialog(
    Map<String, dynamic> student,
  ) async {
    final theme = Theme.of(context);

    final int studentId =
        student['id'] as int;

    final String name =
        student['name']?.toString() ?? '';

    bool isPaid =
        student['advance_paid'] == 1;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            final dialogTheme =
                Theme.of(dialogContext);

            return AlertDialog(
              backgroundColor:
                  dialogTheme.colorScheme.surface,

              title: Text(
                'Advance Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      dialogTheme.colorScheme.onSurface,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: dialogTheme
                          .colorScheme
                          .onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Advance amount: ₹$monthlyFee',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dialogTheme
                          .colorScheme
                          .onSurface,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Icon(
                        isPaid
                            ? Icons.check_circle
                            : Icons.warning_rounded,
                        color: isPaid
                            ? const Color(0xFF238636)
                            : Colors.amber.shade700,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        isPaid
                            ? 'Advance Paid'
                            : 'Advance Not Paid',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          color: isPaid
                              ? const Color(0xFF238636)
                              : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: dialogTheme
                          .colorScheme
                          .primary,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final bool newStatus =
                        !isPaid;

                    try {
                      await DatabaseHelper.instance
                          .updateAdvancePayment(
                        studentId: studentId,
                        isPaid: newStatus,
                      );

                      isPaid = newStatus;

                      setDialogState(() {});

                      final int index =
                          students.indexWhere(
                        (item) =>
                            item['id'] ==
                            studentId,
                      );

                      if (index != -1) {
                        final updatedStudent =
                            Map<String, dynamic>.from(
                          students[index],
                        );

                        updatedStudent[
                                'advance_paid'] =
                            newStatus ? 1 : 0;

                        setState(() {
                          students[index] =
                              updatedStudent;
                        });
                      }

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            newStatus
                                ? '$name advance marked as paid.'
                                : '$name advance marked as unpaid.',
                          ),
                          backgroundColor:
                              newStatus
                                  ? const Color(0xFF238636)
                                  : Colors.red,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to update advance: $e',
                          ),
                          backgroundColor:
                              Colors.red,
                        ),
                      );
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid
                        ? Colors.red
                        : const Color(0xFF238636),
                    foregroundColor:
                        Colors.white,
                  ),

                  child: Text(
                    isPaid
                        ? 'MARK UNPAID'
                        : 'MARK PAID',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================

  void _onNavigationTap(int index) {
    if (index == 4) {
      return;
    }

    switch (index) {
      case 0:
        Navigator.popUntil(
          context,
          (route) => route.isFirst,
        );
        break;

      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const StudentsPage(),
          ),
        );
        break;

      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const NewStudentPage(),
          ),
        );
        break;

      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const EventPage(),
          ),
        );
        break;
    }
  }

  // =====================================================
  // BOTTOM NAVIGATION BAR
  // =====================================================

  Widget _bottomNavigationBar() {
    final theme = Theme.of(context);

    return NavigationBar(
      selectedIndex: 4,
      onDestinationSelected:
          _onNavigationTap,

      backgroundColor:
          theme.colorScheme.surface,

      indicatorColor:
          theme.colorScheme.primary
              .withOpacity(0.14),

      destinations: [
        const NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
          ),
          selectedIcon: Icon(
            Icons.home,
          ),
          label: 'Home',
        ),

        const NavigationDestination(
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
                theme.brightness ==
                        Brightness.dark
                    ? const Color(0xFF6B2A78)
                    : const Color(0xFF4B185D),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 25,
            ),
          ),
          selectedIcon: CircleAvatar(
            radius: 20,
            backgroundColor:
                theme.brightness ==
                        Brightness.dark
                    ? const Color(0xFF8A3FA0)
                    : const Color(0xFF30113B),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 27,
            ),
          ),
          label: 'Add',
        ),

        const NavigationDestination(
          icon: Icon(
            Icons.event_outlined,
          ),
          selectedIcon: Icon(
            Icons.event,
          ),
          label: 'Events',
        ),

        const NavigationDestination(
          icon: Icon(
            Icons.payments_outlined,
          ),
          selectedIcon: Icon(
            Icons.payments,
          ),
          label: 'Fees',
        ),
      ],
    );
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
          colors.surface,

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF53176B),
        foregroundColor:
            Colors.white,
        elevation: 0,

        systemOverlayStyle:
            const SystemUiOverlayStyle(
          statusBarColor:
              Color(0xFF53176B),
          statusBarIconBrightness:
              Brightness.light,
        ),

        title: const Text(
          'Student Fees',
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
            tooltip:
                'Advance payment information',

            onPressed: students.isEmpty
                ? null
                : () {
                    _showAdvanceList();
                  },

            icon: const Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
          ),
        ],
      ),

      body: loading
          ? Center(
              child:
                  CircularProgressIndicator(
                color:
                    colors.primary,
              ),
            )
          : students.isEmpty
              ? _emptyView()
              : _feePage(),

      bottomNavigationBar:
          _bottomNavigationBar(),
    );
  }

  // =====================================================
  // ADVANCE LIST
  // =====================================================

  Future<void> _showAdvanceList() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogTheme =
            Theme.of(dialogContext);

        return AlertDialog(
          backgroundColor:
              dialogTheme
                  .colorScheme
                  .surface,

          title: Text(
            'Advance Payments',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              color: dialogTheme
                  .colorScheme
                  .onSurface,
            ),
          ),

          content: SizedBox(
            width: double.maxFinite,

            child: ListView.builder(
              shrinkWrap: true,

              itemCount:
                  students.length,

              itemBuilder:
                  (context, index) {
                final student =
                    students[index];

                final String name =
                    student['name']
                            ?.toString() ??
                        '';

                final bool paid =
                    student[
                            'advance_paid'] ==
                        1;

                return ListTile(
                  dense: true,

                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color: dialogTheme
                          .colorScheme
                          .onSurface,
                    ),
                  ),

                  trailing: Icon(
                    paid
                        ? Icons.check_circle
                        : Icons.warning_rounded,
                    color: paid
                        ? const Color(
                            0xFF238636,
                          )
                        : Colors.amber
                            .shade700,
                  ),
                );
              },
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child: Text(
                'CLOSE',
                style: TextStyle(
                  color: dialogTheme
                      .colorScheme
                      .primary,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // MAIN FEE PAGE
  // =====================================================

  Widget _feePage() {
    return Column(
      children: [
        _topSection(),

        const SizedBox(height: 8),

        _statusMessage(),

        const SizedBox(height: 4),

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
              return _studentCard(
                students[index],
                index,
              );
            },
          ),
        ),

        _bottomButton(),
      ],
    );
  }

  // =====================================================
  // TOP SECTION
  // =====================================================

  Widget _topSection() {
    final theme = Theme.of(context);
    final colors =
        theme.colorScheme;

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        16,
      ),

      color: colors.surface,

      child: Column(
        children: [
          Text(
            monthName,

            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
              color:
                  colors.onSurface,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Monthly Fee: ₹$monthlyFee',

            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w600,
              color:
                  colors.primary,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _countCard(
                title: 'Fees Paid',
                count: paidCount,
                icon:
                    Icons.check_circle,
                color:
                    const Color(
                  0xFF238636,
                ),
              ),

              const SizedBox(width: 10),

              _countCard(
                title: 'Remaining',
                count:
                    remainingCount,
                icon:
                    Icons.pending,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // COUNT CARD
  // =====================================================

  Widget _countCard({
    required String title,
    required int count,
    required IconData icon,
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
          horizontal: 14,
          vertical: 13,
        ),

        decoration:
            BoxDecoration(
          color:
              theme.brightness ==
                      Brightness.dark
                  ? colors
                      .surfaceContainerHighest
                  : const Color(
                      0xFFF8F6FA,
                    ),

          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),

        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),

            const SizedBox(width: 9),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors
                          .onSurface
                          .withOpacity(
                        0.65,
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

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
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // STATUS MESSAGE
  // =====================================================

  Widget _statusMessage() {
    final theme =
        Theme.of(context);
    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),

      child: Row(
        children: [
          Icon(
            monthLocked && !editing
                ? Icons.lock_outline
                : Icons.edit_note,
            size: 18,
            color: colors.primary,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              monthLocked && !editing
                  ? '$monthName fee status is locked because all students have been entered.'
                  : 'Mark the monthly fee status for every student.',

              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color:
                    colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // STUDENT CARD
  // =====================================================

  Widget _studentCard(
    Map<String, dynamic> student,
    int index,
  ) {
    final theme =
        Theme.of(context);
    final colors =
        theme.colorScheme;

    final String name =
        student['name']
                ?.toString() ??
            '';

    final bool monthlyPaid =
        student['monthly_paid'] == 1;

    final bool advancePaid =
        student['advance_paid'] == 1;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),

      elevation: 1,

      color:
          colors.surface,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),

      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),

        child: Row(
          children: [
            // NUMBER
            SizedBox(
              width: 28,

              child: Text(
                '${index + 1}',

                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.bold,
                  color: colors
                      .onSurface
                      .withOpacity(
                    0.60,
                  ),
                ),
              ),
            ),

            // NAME
            Expanded(
              child: Text(
                name,

                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      colors.onSurface,
                ),
              ),
            ),

            // ADVANCE NOT PAID
            if (!advancePaid)
              Tooltip(
                message:
                    'Advance not paid',

                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    right: 5,
                  ),

                  child: Icon(
                    Icons.warning_rounded,
                    size: 19,
                    color: Colors
                        .amber
                        .shade700,
                  ),
                ),
              ),

            // MONTHLY FEE STATUS ICON
            Icon(
              monthlyPaid
                  ? Icons.check_circle
                  : Icons.cancel,

              size: 19,

              color: monthlyPaid
                  ? const Color(
                      0xFF238636,
                    )
                  : Colors.red,
            ),

            const SizedBox(width: 5),

            // INDIVIDUAL SWITCH
            Switch(
              value: monthlyPaid,

              onChanged: editing
                  ? (value) {
                      changeFeeStatus(
                        index,
                        value,
                      );
                    }
                  : null,

              activeColor:
                  Colors.white,

              activeTrackColor:
                  const Color(
                0xFF238636,
              ),

              inactiveThumbColor:
                  Colors.white,

              inactiveTrackColor:
                  theme.brightness ==
                          Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade400,
            ),

            // ADVANCE BUTTON
            IconButton(
              tooltip:
                  'View advance payment',

              onPressed: () {
                showAdvanceDialog(
                  student,
                );
              },

              icon: Icon(
                Icons
                    .account_balance_wallet_outlined,
                size: 21,
                color:
                    colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BOTTOM BUTTONS
  // =====================================================

  Widget _bottomButton() {
    final theme =
        Theme.of(context);
    final colors =
        theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.all(14),

        child: Column(
          children: [
            // =================================================
            // ALL PAID BUTTON
            // =================================================

            SizedBox(
              width: double.infinity,
              height: 52,

              child: ElevatedButton.icon(
                onPressed:
                    (!editing ||
                            markingAllPaid ||
                            saving ||
                            paidCount ==
                                students.length)
                        ? null
                        : markAllPaid,

                icon: markingAllPaid
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .done_all,
                      ),

                label: Text(
                  markingAllPaid
                      ? 'MARKING ALL PAID...'
                      : paidCount ==
                              students.length
                          ? 'ALL PAID'
                          : 'ALL PAID',

                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF238636,
                  ),

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
              ),
            ),

            const SizedBox(height: 10),

            // =================================================
            // SAVE / MARK FEE BUTTON
            // =================================================

            SizedBox(
              width: double.infinity,
              height: 52,

              child:
                  ElevatedButton.icon(
                onPressed:
                    saving
                        ? null
                        : editing
                            ? saveFees
                            : editFees,

                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.white,
                        ),
                      )
                    : Icon(
                        editing
                            ? Icons.save
                            : Icons.edit,
                      ),

                label: Text(
                  saving
                      ? 'SAVING...'
                      : editing
                          ? 'SAVE FEE'
                          : 'MARK FEE',

                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF4B185D,
                  ),

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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // EMPTY
  // =====================================================

  Widget _emptyView() {
    final theme =
        Theme.of(context);
    final colors =
        theme.colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),

        child: Text(
          'No students added yet.',

          style: TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w600,
            color:
                colors.onSurface,
          ),
        ),
      ),
    );
  }
}
