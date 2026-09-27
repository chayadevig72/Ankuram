import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new.dart';
import 'attend.dart';
import 'fees.dart';
import 'students.dart';
import 'database/database_helper.dart';
import 'event.dart';

void main() {
  runApp(const DanceAttendanceApp());
}

// =====================================================
// APP
// =====================================================

class DanceAttendanceApp extends StatefulWidget {
  const DanceAttendanceApp({super.key});

  @override
  State<DanceAttendanceApp> createState() =>
      _DanceAttendanceAppState();
}

class _DanceAttendanceAppState
    extends State<DanceAttendanceApp> {
  ThemeMode _themeMode = ThemeMode.light;

  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // =====================================================
  // LOAD SAVED THEME
  // =====================================================

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isDark =
        prefs.getBool('isDarkMode') ?? false;

    if (!mounted) return;

    setState(() {
      _themeMode =
          isDark ? ThemeMode.dark : ThemeMode.light;

      _themeLoaded = true;
    });
  }

  // =====================================================
  // CHANGE + SAVE THEME
  // =====================================================

  Future<void> _changeTheme(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      'isDarkMode',
      mode == ThemeMode.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wait until saved theme is loaded.
    if (!_themeLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Ankuram Bharatanatyam',

      themeMode: _themeMode,

      // =================================================
      // LIGHT THEME
      // =================================================

      theme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed: Colors.deepPurple,

        brightness: Brightness.light,

        scaffoldBackgroundColor:
            const Color(0xFFF8F6FA),

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      ),

      // =================================================
      // DARK THEME
      // =================================================

      darkTheme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed: Colors.deepPurple,

        brightness: Brightness.dark,

        scaffoldBackgroundColor:
            const Color(0xFF121014),

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      ),

      home: DashboardScreen(
        currentTheme: _themeMode,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

// =====================================================
// DASHBOARD
// =====================================================

class DashboardScreen extends StatefulWidget {
  final ThemeMode currentTheme;
  final Function(ThemeMode) onThemeChanged;

  const DashboardScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  int totalStudents = 0;
  int presentStudents = 0;
  int absentStudents = 0;
  int feesDueStudents = 0;

  bool loading = true;

  // =====================================================
  // SLIDESHOW
  // =====================================================

  final PageController _pageController =
      PageController(initialPage: 0);

  Timer? _slideTimer;

  int _currentSlide = 0;

  final List<String> _danceImages = [
    'images/dance/nataraja.png',
    'images/dance/bharatanatyam.png',
    'images/dance/mudra.png',
    'images/dance/dancer.png',
    'images/dance/temple_dance.png',
  ];

  // =====================================================
  // INITIALIZE
  // =====================================================

  @override
  void initState() {
    super.initState();

    _loadDashboardData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSlideshow();
    });
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  // =====================================================
  // START SLIDESHOW
  // =====================================================

  void _startSlideshow() {
    _slideTimer?.cancel();

    _slideTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        _nextSlide();
      },
    );
  }

  // =====================================================
  // NEXT SLIDE
  // =====================================================

  void _nextSlide() {
    if (!mounted) return;

    if (!_pageController.hasClients) {
      return;
    }

    if (_danceImages.isEmpty) {
      return;
    }

    int nextSlide = _currentSlide + 1;

    if (nextSlide >= _danceImages.length) {
      nextSlide = 0;
    }

    _pageController
        .animateToPage(
      nextSlide,
      duration: const Duration(
        milliseconds: 700,
      ),
      curve: Curves.easeInOut,
    )
        .then((_) {
      if (!mounted) return;

      setState(() {
        _currentSlide = nextSlide;
      });
    });
  }

  // =====================================================
  // LOAD DASHBOARD DATA
  // =====================================================

  Future<void> _loadDashboardData() async {
    try {
      final db = DatabaseHelper.instance;

      final students = await db.getStudents();

      final int total = students.length;

      final now = DateTime.now();

      final String today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final attendance =
          await db.getAttendanceForDate(today);

      int present = 0;
      int absent = 0;

      for (final record in attendance) {
        final status =
            record['status']?.toString();

        if (status == 'present') {
          present++;
        } else if (status == 'absent') {
          absent++;
        }
      }

      final String currentMonth =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';

      final feeStudents =
          await db.getStudentsWithFeeStatus(
        currentMonth,
      );

      int feesDue = 0;

      for (final student in feeStudents) {
        final int monthlyPaid =
            (student['monthly_paid'] as num?)
                    ?.toInt() ??
                0;

        if (monthlyPaid == 0) {
          feesDue++;
        }
      }

      if (!mounted) return;

      setState(() {
        totalStudents = total;
        presentStudents = present;
        absentStudents = absent;
        feesDueStudents = feesDue;
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
            'Failed to load dashboard data: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // TODAY DATE
  // =====================================================

  String _getTodayDate() {
    final now = DateTime.now();

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

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

    return '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // =====================================================
  // OPEN ATTENDANCE
  // =====================================================

  Future<void> _openAttendance(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AttendPage(),
      ),
    );

    await _loadDashboardData();
  }

  // =====================================================
  // OPEN EVENTS
  // =====================================================

  Future<void> _openEvents(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EventPage(),
      ),
    );

    await _loadDashboardData();
  }

  // =====================================================
  // OPEN STUDENTS
  // =====================================================

  Future<void> _openStudents(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentsPage(),
      ),
    );

    await _loadDashboardData();
  }

  // =====================================================
  // OPEN ADD STUDENT
  // =====================================================

  Future<void> _openAddStudent(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const NewStudentPage(),
      ),
    );

    await _loadDashboardData();
  }

  // =====================================================
  // OPEN FEES
  // =====================================================

  Future<void> _openFees(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeesPage(),
      ),
    );

    await _loadDashboardData();
  }

  // =====================================================
  // PROFESSIONAL MENU
  // =====================================================

  void _showMenu() {
    final theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFF4B185D,
                        ).withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color:
                            Color(0xFFB76BD1),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(
                                      0xFF30113B,
                                    ),
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            'Customize your dashboard',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // APPEARANCE
                _menuTile(
                  icon:
                      widget.currentTheme ==
                              ThemeMode.dark
                          ? Icons
                              .dark_mode_rounded
                          : Icons
                              .light_mode_rounded,

                  iconColor:
                      const Color(0xFF9C4DCC),

                  title: 'Appearance',

                  subtitle:
                      widget.currentTheme ==
                              ThemeMode.dark
                          ? 'Dark mode'
                          : 'Light mode',

                  trailing: Switch(
                    value:
                        widget.currentTheme ==
                            ThemeMode.dark,

                    onChanged: (value) async {
                      await widget
                          .onThemeChanged(
                        value
                            ? ThemeMode.dark
                            : ThemeMode.light,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // REFRESH
                _menuTile(
                  icon:
                      Icons.refresh_rounded,

                  iconColor:
                      const Color(0xFF238636),

                  title:
                      'Refresh Dashboard',

                  subtitle:
                      'Update students, attendance and fees',

                  onTap: () async {
                    Navigator.pop(context);

                    setState(() {
                      loading = true;
                    });

                    await _loadDashboardData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // MENU TILE
  // =====================================================

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),

        onTap: onTap,

        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),

            color: iconColor
                .withOpacity(0.05),
          ),

          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,

                decoration:
                    BoxDecoration(
                  color: iconColor
                      .withOpacity(0.10),

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(
                                0xFF30113B,
                              ),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : theme
                                .colorScheme
                                .onSurface
                                .withOpacity(
                                  0.55,
                                ),
                      ),
                    ),
                  ],
                ),
              ),

              if (trailing != null)
                trailing
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    _loadDashboardData,

                child:
                    SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),

                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    20,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w800,
                          color: theme
                              .colorScheme
                              .primary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _getTodayDate(),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme
                              .colorScheme
                              .onSurface
                              .withOpacity(0.60),
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildDanceSlideshow(),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w800,
                              color: theme
                                  .colorScheme
                                  .onSurface,
                            ),
                          ),

                          const Spacer(),

                          Icon(
                            Icons.insights_rounded,
                            size: 20,
                            color: theme
                                .colorScheme
                                .primary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (loading)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 30,
                          ),
                          child: Center(
                            child:
                                CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _statCard(
                                title:
                                    'Total Students',
                                value:
                                    totalStudents
                                        .toString(),
                                icon: Icons
                                    .groups_rounded,
                                iconColor:
                                    const Color(
                                  0xFF5E2A72,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child:
                                  _statCard(
                                title:
                                    'Present Today',
                                value:
                                    presentStudents
                                        .toString(),
                                icon: Icons
                                    .check_circle_rounded,
                                iconColor:
                                    const Color(
                                  0xFF238636,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  _statCard(
                                title:
                                    'Absent Today',
                                value:
                                    absentStudents
                                        .toString(),
                                icon: Icons
                                    .cancel_rounded,
                                iconColor:
                                    const Color(
                                  0xFFC62828,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child:
                                  _statCard(
                                title:
                                    'Fees Due',
                                value:
                                    feesDueStudents
                                        .toString(),
                                icon: Icons
                                    .currency_rupee_rounded,
                                iconColor:
                                    const Color(
                                  0xFFE08A00,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _buildAttendanceButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TAKE ATTENDANCE BUTTON
  // =====================================================

  Widget _buildAttendanceButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,

          child: FilledButton(
            onPressed: () {
              _openAttendance(context);
            },

            style: FilledButton.styleFrom(
              backgroundColor:
                  const Color(0xFF4B185D),

              foregroundColor:
                  Colors.white,

              elevation: 2,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(15),
              ),
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: const [
                Icon(
                  Icons.fact_check_rounded,
                  size: 22,
                ),

                SizedBox(width: 9),

                Text(
                  'TAKE ATTENDANCE',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Developed by RH Infotech',

          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,

            color: Theme.of(context)
                .brightness ==
                    Brightness.dark
                ? Colors.white
                    .withOpacity(0.70)
                : const Color(0xFF4B185D)
                    .withOpacity(0.65),

            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================

  Widget _buildBottomNavigation() {
    final theme =
        Theme.of(context);

    return NavigationBar(
      selectedIndex: 0,

      height: 72,

      backgroundColor:
          theme.colorScheme.surface,

      elevation: 10,

      indicatorColor:
          const Color(0xFF4B185D)
              .withOpacity(0.12),

      onDestinationSelected:
          (index) {
        if (index == 0) {
          _loadDashboardData();
          return;
        }

        if (index == 1) {
          _openStudents(context);
        }

        if (index == 2) {
          _openAddStudent(context);
        }

        if (index == 3) {
          _openEvents(context);
        }

        if (index == 4) {
          _openFees(context);
        }
      },

      destinations: const [
        NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
          ),
          selectedIcon: Icon(
            Icons.home_rounded,
          ),
          label: 'Home',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.people_outline_rounded,
          ),
          selectedIcon: Icon(
            Icons.people_rounded,
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
              size: 24,
            ),
          ),
          selectedIcon: CircleAvatar(
            radius: 19,
            backgroundColor:
                Color(0xFF30113B),
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 25,
            ),
          ),
          label: 'Add',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.video_library_outlined,
          ),
          selectedIcon: Icon(
            Icons.video_library_rounded,
          ),
          label: 'Events',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.currency_rupee_outlined,
          ),
          selectedIcon: Icon(
            Icons.currency_rupee_rounded,
          ),
          label: 'Fees',
        ),
      ],
    );
  }

  // =====================================================
  // HEADER
  // =====================================================

  Widget _buildHeader() {
    final theme =
        Theme.of(context);

    final bool isDark =
        theme.brightness ==
            Brightness.dark;

    // Header colors
    final Color nameColor = isDark
        ? Colors.white
        : const Color(0xFF30113B);

    final Color subtitleColor = isDark
        ? const Color(0xFFD8B9E5)
        : const Color(0xFF6B3A78);

    final Color menuIconColor = isDark
        ? Colors.white
        : Colors.black87;

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        8,
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,

        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black
                    .withOpacity(0.35)
                : const Color(
                    0x12000000,
                  ),

            blurRadius: 8,

            offset:
                const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        children: [
          // =================================================
          // LOGO
          // =================================================

          Container(
            width: 52,
            height: 52,

            decoration:
                BoxDecoration(
              color: isDark
                  ? const Color(
                      0xFF302438,
                    )
                  : const Color(
                      0xFFF0E7F4,
                    ),

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),

              child: Image.asset(
                'images/a/logo1.png',

                width: 52,
                height: 52,

                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // =================================================
          // COMPANY NAME
          // =================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'ANKURAM',

                  style: TextStyle(
                    fontSize: 18,

                    fontWeight:
                        FontWeight.w900,

                    letterSpacing: 1.1,

                    // DARK = WHITE
                    // LIGHT = DARK PURPLE
                    color: nameColor,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'BHARATANATYAM',

                  style: TextStyle(
                    fontSize: 12,

                    fontWeight:
                        FontWeight.w600,

                    letterSpacing: 1.8,

                    // DARK = LIGHT PURPLE
                    // LIGHT = DARKER PURPLE
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // MENU
          // =================================================

          Material(
            color:
                Colors.transparent,

            child: InkWell(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),

              onTap: _showMenu,

              child: Container(
                width: 46,
                height: 46,

                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.55),

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: Icon(
                  Icons
                      .more_horiz_rounded,

                  size: 25,

                  color:
                      menuIconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DANCE SLIDESHOW
  // =====================================================

  Widget _buildDanceSlideshow() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,

          height: 145,

          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(20),

            child: PageView.builder(
              controller:
                  _pageController,

              itemCount:
                  _danceImages.length,

              onPageChanged: (index) {
                if (!mounted) return;

                setState(() {
                  _currentSlide = index;
                });
              },

              itemBuilder:
                  (context, index) {
                return Stack(
                  fit: StackFit.expand,

                  children: [
                    Image.asset(
                      _danceImages[index],

                      fit: BoxFit.cover,

                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Container(
                          color:
                              const Color(
                            0xFFEDE7F1,
                          ),

                          child:
                              const Center(
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,

                              children: [
                                Icon(
                                  Icons
                                      .image_not_supported_outlined,

                                  size: 40,

                                  color:
                                      Color(
                                    0xFF4B185D,
                                  ),
                                ),

                                SizedBox(
                                  height: 8,
                                ),

                                Text(
                                  'Image not found',

                                  style:
                                      TextStyle(
                                    color:
                                        Color(
                                      0xFF4B185D,
                                    ),

                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    Container(
                      decoration:
                          const BoxDecoration(
                        gradient:
                            LinearGradient(
                          begin:
                              Alignment
                                  .bottomCenter,

                          end:
                              Alignment
                                  .topCenter,

                          colors: [
                            Color(
                              0x99000000,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const Positioned(
                      left: 16,
                      bottom: 14,

                      child: Text(
                        'Bharatanatyam',

                        style:
                            TextStyle(
                          color:
                              Colors.white,

                          fontSize: 18,

                          fontWeight:
                              FontWeight.w800,

                          letterSpacing:
                              0.4,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 9),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children:
              List.generate(
            _danceImages.length,
            (index) {
              final bool selected =
                  index ==
                      _currentSlide;

              return AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 300,
                ),

                curve:
                    Curves.easeInOut,

                margin:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 3,
                ),

                width:
                    selected ? 18 : 6,

                height: 6,

                decoration:
                    BoxDecoration(
                  color: selected
                      ? const Color(
                          0xFF4B185D,
                        )
                      : Colors.grey
                          .shade400,

                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =====================================================
  // STAT CARD
  // =====================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme =
        Theme.of(context);

    return Container(
      height: 112,

      padding:
          const EdgeInsets.all(13),

      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,

        borderRadius:
            BorderRadius.circular(17),

        border: Border.all(
          color: theme
              .colorScheme
              .outline
              .withOpacity(0.08),
        ),

        boxShadow: [
          BoxShadow(
            color:
                theme.brightness ==
                        Brightness.dark
                    ? Colors.black
                        .withOpacity(0.25)
                    : const Color(
                        0x0D000000,
                      ),

            blurRadius: 7,

            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 36,
            height: 36,

            decoration:
                BoxDecoration(
              color: iconColor
                  .withOpacity(0.10),

              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),

            child: Icon(
              icon,

              color: iconColor,

              size: 20,
            ),
          ),

          const Spacer(),

          Text(
            value,

            style: TextStyle(
              fontSize: 22,

              fontWeight:
                  FontWeight.w800,

              color: theme
                  .colorScheme
                  .onSurface,
            ),
          ),

          const SizedBox(height: 1),

          Text(
            title,

            maxLines: 1,

            overflow:
                TextOverflow.ellipsis,

            style: TextStyle(
              fontSize: 11.5,

              color: theme
                  .colorScheme
                  .onSurface
                  .withOpacity(0.60),

              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}