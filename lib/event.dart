import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'new.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'students.dart';
import 'fees.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // =====================================================
  // LOAD EVENTS
  // =====================================================

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString('ankuram_events');

    if (data == null) {
      return;
    }

    try {
      final List decoded = jsonDecode(data);

      if (!mounted) return;

      setState(() {
        events = decoded
            .map(
              (event) => Map<String, dynamic>.from(event),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load events: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // SAVE EVENTS
  // =====================================================

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'ankuram_events',
      jsonEncode(events),
    );
  }

  //// =====================================================
// CREATE EVENT
// =====================================================

  Future<void> _createEvent() async {
    final String? eventName =
        await showDialog<String>(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {
        return _CreateEventDialog();
      },
    );

    if (!mounted) return;

    if (eventName == null ||
        eventName.trim().isEmpty) {
      return;
    }

    final newEvent = <String, dynamic>{
      'id': DateTime.now()
          .millisecondsSinceEpoch
          .toString(),

      'name': eventName.trim(),

      'photos': <String>[],

      'videos': <String>[],
    };

    setState(() {
      events.add(newEvent);
    });

    await _saveEvents();
  }
    // =====================================================
    // OPEN EVENT
    // =====================================================

    Future<void> _openEvent(int index) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailsPage(
            event: events[index],

            onChanged: () async {
              await _saveEvents();

              if (mounted) {
                setState(() {});
              }
            },
          ),
        ),
      );

      await _loadEvents();
    }

  // =====================================================
  // DELETE EVENT
  // =====================================================

  Future<void> _deleteEvent(int index) async {
    final event = events[index];

    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        final dialogTheme =
            Theme.of(dialogContext);

        return AlertDialog(
          backgroundColor:
              dialogTheme.colorScheme.surface,

          title: Text(
            'Delete Event?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  dialogTheme.colorScheme.onSurface,
            ),
          ),

          content: Text(
            'Delete "${event['name']}" and all its media?',

            style: TextStyle(
              color:
                  dialogTheme.colorScheme.onSurface,
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

              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final photos =
        List<String>.from(
      event['photos'] ?? [],
    );

    final videos =
        List<String>.from(
      event['videos'] ?? [],
    );

    for (final path in [
      ...photos,
      ...videos,
    ]) {
      try {
        final file = File(path);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      events.removeAt(index);
    });

    await _saveEvents();
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================
Widget _buildBottomNavigationBar() {
  final theme = Theme.of(context);

  return NavigationBar(
    selectedIndex: 3,

    backgroundColor:
        theme.colorScheme.surface,

    indicatorColor:
        theme.colorScheme.primary.withOpacity(0.14),

    onDestinationSelected: (index) {
      switch (index) {

        // HOME
        case 0:
          Navigator.of(context).popUntil(
            (route) => route.isFirst,
          );
          break;

        // STUDENTS
        case 1:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentsPage(),
            ),
          );
          break;

        // ADD STUDENT
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const NewStudentPage(),
            ),
          );
          break;

        // EVENTS
        case 3:
          // Already on Event page
          break;

        // FEES
        case 4:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const FeesPage(),
            ),
          );
          break;
      }
    },

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
              theme.brightness == Brightness.dark
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
              theme.brightness == Brightness.dark
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

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

          appBar: AppBar(
        backgroundColor: const Color(0xFF53176B),
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF53176B),
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      body: events.isEmpty
          ? _emptyView()
          : ListView.builder(
              padding:
                  const EdgeInsets.all(18),

              itemCount: events.length,

              itemBuilder: (
                context,
                index,
              ) {
                final event =
                    events[index];

                final photos =
                    List<String>.from(
                  event['photos'] ?? [],
                );

                final videos =
                    List<String>.from(
                  event['videos'] ?? [],
                );

                return _eventCard(
                  index,
                  event,
                  photos.length,
                  videos.length,
                );
              },
            ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _createEvent,

        backgroundColor:
            const Color(0xFF4B185D),

        foregroundColor:
            Colors.white,

        icon: const Icon(
          Icons.add,
        ),

        label: const Text(
          'Add Event',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  // =====================================================
  // EMPTY VIEW
  // =====================================================

  Widget _emptyView() {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 90,
              height: 90,

              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2030)
                    : const Color(0xFFF0E7F4),

                borderRadius:
                    BorderRadius.circular(25),
              ),

              child: Icon(
                Icons.photo_library_rounded,

                size: 45,

                color:
                    theme.colorScheme.primary,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'No Events Yet',

              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,

                color:
                    theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Create an event to save photos and\n'
              'performance videos.',

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                color: theme
                    .colorScheme
                    .onSurface
                    .withOpacity(0.60),

                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // EVENT CARD
  // =====================================================

  Widget _eventCard(
    int index,
    Map<String, dynamic> event,
    int photoCount,
    int videoCount,
  ) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 15,
      ),

      color:
          theme.colorScheme.surface,

      elevation: isDark ? 1 : 2,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),

        onTap: () {
          _openEvent(index);
        },

        child: Padding(
          padding:
              const EdgeInsets.all(17),

          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,

                decoration:
                    BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2030)
                      : const Color(0xFFF0E7F4),

                  borderRadius:
                      BorderRadius.circular(15),
                ),

                child: Icon(
                  Icons.event_rounded,

                  color:
                      theme.colorScheme.primary,

                  size: 30,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      event['name'] ??
                          'Event',

                      maxLines: 2,

                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 18,

                        fontWeight:
                            FontWeight.bold,

                        color: theme
                            .colorScheme
                            .onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        Icon(
                          Icons.photo_outlined,

                          size: 17,

                          color: theme
                              .colorScheme
                              .onSurface
                              .withOpacity(
                            0.55,
                          ),
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Text(
                          '$photoCount photos',

                          style: TextStyle(
                            color: theme
                                .colorScheme
                                .onSurface
                                .withOpacity(
                              0.65,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 15,
                        ),

                        Icon(
                          Icons
                              .videocam_outlined,

                          size: 17,

                          color: theme
                              .colorScheme
                              .onSurface
                              .withOpacity(
                            0.55,
                          ),
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Text(
                          '$videoCount videos',

                          style: TextStyle(
                            color: theme
                                .colorScheme
                                .onSurface
                                .withOpacity(
                              0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value ==
                      'delete') {
                    _deleteEvent(index);
                  }
                },

                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'delete',

                      child: Text(
                        'Delete Event',
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// EVENT DETAILS PAGE
// =====================================================

class EventDetailsPage
    extends StatefulWidget {
  final Map<String, dynamic> event;

  final Future<void> Function()
      onChanged;

  const EventDetailsPage({
    super.key,
    required this.event,
    required this.onChanged,
  });

  @override
  State<EventDetailsPage> createState() =>
      _EventDetailsPageState();
}

class _EventDetailsPageState
    extends State<EventDetailsPage> {
  final ImagePicker _picker =
      ImagePicker();

  late List<String> photos;
  late List<String> videos;

  @override
  void initState() {
    super.initState();

    photos = List<String>.from(
      widget.event['photos'] ?? [],
    );

    videos = List<String>.from(
      widget.event['videos'] ?? [],
    );
  }

  // =====================================================
  // COPY FILE INTO APP STORAGE
  // =====================================================

  Future<String> _copyToAppStorage(
    XFile source,
    String extension,
  ) async {
    final directory =
        await getApplicationDocumentsDirectory();

    final mediaDirectory = Directory(
      '${directory.path}/events/'
      '${widget.event['id']}',
    );

    if (!await mediaDirectory.exists()) {
      await mediaDirectory.create(
        recursive: true,
      );
    }

    final filename =
        '${DateTime.now().millisecondsSinceEpoch}'
        '.$extension';

    final destination =
        File(
      '${mediaDirectory.path}/$filename',
    );

    await File(source.path)
        .copy(destination.path);

    return destination.path;
  }

  // =====================================================
  // TAKE PHOTO
  // =====================================================

  Future<void> _takePhoto() async {
    final image =
        await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (image == null) {
      return;
    }

    final path =
        await _copyToAppStorage(
      image,
      'jpg',
    );

    if (!mounted) return;

    setState(() {
      photos.add(path);
    });

    widget.event['photos'] =
        photos;

    await widget.onChanged();
  }

  // =====================================================
  // CHOOSE PHOTO
  // =====================================================

  Future<void>
      _choosePhotoFromGallery() async {
    final image =
        await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) {
      return;
    }

    final extension =
        image.path.split('.').last;

    final path =
        await _copyToAppStorage(
      image,
      extension,
    );

    if (!mounted) return;

    setState(() {
      photos.add(path);
    });

    widget.event['photos'] =
        photos;

    await widget.onChanged();
  }

  // =====================================================
  // RECORD VIDEO
  // =====================================================

  Future<void> _recordVideo() async {
    final video =
        await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration:
          const Duration(minutes: 10),
    );

    if (video == null) {
      return;
    }

    final path =
        await _copyToAppStorage(
      video,
      'mp4',
    );

    if (!mounted) return;

    setState(() {
      videos.add(path);
    });

    widget.event['videos'] =
        videos;

    await widget.onChanged();
  }

  // =====================================================
  // CHOOSE VIDEO
  // =====================================================

  Future<void>
      _chooseVideoFromGallery() async {
    final video =
        await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) {
      return;
    }

    final extension =
        video.path.split('.').last;

    final path =
        await _copyToAppStorage(
      video,
      extension,
    );

    if (!mounted) return;

    setState(() {
      videos.add(path);
    });

    widget.event['videos'] =
        videos;

    await widget.onChanged();
  }

  // =====================================================
  // PHOTO OPTIONS
  // =====================================================

  void _showPhotoOptions() {
    final theme =
        Theme.of(context);

    showModalBottomSheet(
      context: context,

      backgroundColor:
          theme.colorScheme.surface,

      builder: (sheetContext) {
        final sheetTheme =
            Theme.of(sheetContext);

        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding:
                    const EdgeInsets.all(18),

                child: Text(
                  'Add Photo',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                    color: sheetTheme
                        .colorScheme
                        .onSurface,
                  ),
                ),
              ),

              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: sheetTheme
                      .colorScheme
                      .primary,
                ),

                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: sheetTheme
                        .colorScheme
                        .onSurface,
                  ),
                ),

                subtitle: Text(
                  'Open phone camera',
                  style: TextStyle(
                    color: sheetTheme
                        .colorScheme
                        .onSurface
                        .withOpacity(
                      0.60,
                    ),
                  ),
                ),

                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _takePhoto();
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: sheetTheme
                      .colorScheme
                      .primary,
                ),

                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: sheetTheme
                        .colorScheme
                        .onSurface,
                  ),
                ),

                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _choosePhotoFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // VIDEO OPTIONS
  // =====================================================

  void _showVideoOptions() {
    final theme =
        Theme.of(context);

    showModalBottomSheet(
      context: context,

      backgroundColor:
          theme.colorScheme.surface,

      builder: (sheetContext) {
        final sheetTheme =
            Theme.of(sheetContext);

        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding:
                    const EdgeInsets.all(18),

                child: Text(
                  'Add Video',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                    color: sheetTheme
                        .colorScheme
                        .onSurface,
                  ),
                ),
              ),

              ListTile(
                leading: Icon(
                  Icons.videocam,
                  color: sheetTheme
                      .colorScheme
                      .primary,
                ),

                title: Text(
                  'Record Video',
                  style: TextStyle(
                    color: sheetTheme
                        .colorScheme
                        .onSurface,
                  ),
                ),

                subtitle: Text(
                  'Open phone camera',
                  style: TextStyle(
                    color: sheetTheme
                        .colorScheme
                        .onSurface
                        .withOpacity(
                      0.60,
                    ),
                  ),
                ),

                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _recordVideo();
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.video_library,
                  color: sheetTheme
                      .colorScheme
                      .primary,
                ),

                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: sheetTheme
                        .colorScheme
                        .onSurface,
                  ),
                ),

                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _chooseVideoFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // DELETE PHOTO
  // =====================================================

  Future<void> _deletePhoto(
    int index,
  ) async {
    final path = photos[index];

    final confirm =
        await _showDeleteDialog(
      title: 'Delete Photo?',
      message:
          'This photo will be permanently deleted.',
    );

    if (confirm != true) {
      return;
    }

    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      photos.removeAt(index);
    });

    widget.event['photos'] =
        photos;

    await widget.onChanged();
  }

  // =====================================================
  // DELETE VIDEO
  // =====================================================

  Future<void> _deleteVideo(
    int index,
  ) async {
    final path = videos[index];

    final confirm =
        await _showDeleteDialog(
      title: 'Delete Video?',
      message:
          'This video will be permanently deleted.',
    );

    if (confirm != true) {
      return;
    }

    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      videos.removeAt(index);
    });

    widget.event['videos'] =
        videos;

    await widget.onChanged();
  }

  // =====================================================
  // DELETE DIALOG
  // =====================================================

  Future<bool?> _showDeleteDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        final theme =
            Theme.of(dialogContext);

        return AlertDialog(
          backgroundColor:
              theme.colorScheme.surface,

          title: Text(
            title,

            style: TextStyle(
              fontWeight:
                  FontWeight.bold,

              color: theme
                  .colorScheme
                  .onSurface,
            ),
          ),

          content: Text(
            message,

            style: TextStyle(
              color: theme
                  .colorScheme
                  .onSurface,
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

              child:
                  const Text('Cancel'),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // BOTTOM NAVIGATION
  // =====================================================

  Widget _buildBottomNavigationBar() {
    final theme =
        Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    return NavigationBar(
      selectedIndex: 2,

      backgroundColor:
          theme.colorScheme.surface,

      indicatorColor:
          const Color(0xFF4B185D)
              .withOpacity(
        isDark ? 0.35 : 0.12,
      ),

      onDestinationSelected: (
        index,
      ) {
        switch (index) {
          case 0:
            Navigator.of(context)
                .popUntil(
              (route) => route.isFirst,
            );
            break;

          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const StudentsPage(),
              ),
            );
            break;

          case 2:
            // Already on Event details.
            break;

          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const FeesPage(),
              ),
            );
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
          icon: Icon(
            Icons.event_outlined,
          ),
          selectedIcon: Icon(
            Icons.event,
          ),
          label: 'Event',
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
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final eventName =
        widget.event['name'] ??
            'Event';

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor:
            theme.colorScheme.surface,

        foregroundColor:
            theme.colorScheme.onSurface,

        elevation: 0,

        title: Text(
          eventName,

          style: TextStyle(
            fontWeight:
                FontWeight.bold,

            color: theme
                .colorScheme
                .onSurface,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // =================================================
            // EVENT TITLE
            // =================================================

            Text(
              eventName,

              style: TextStyle(
                fontSize: 28,

                fontWeight:
                    FontWeight.w900,

                color: theme
                    .colorScheme
                    .onSurface,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Event memories & performances',

              style: TextStyle(
                fontSize: 15,

                color: theme
                    .colorScheme
                    .onSurface
                    .withOpacity(
                  0.60,
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            // =================================================
            // PHOTO / VIDEO BUTTONS
            // =================================================

            Row(
              children: [
                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed:
                        _showPhotoOptions,

                    icon: const Icon(
                      Icons.camera_alt,
                    ),

                    label:
                        const Text(
                      'Photo',
                    ),

                    style:
                        FilledButton
                            .styleFrom(
                      backgroundColor:
                          const Color(
                              0xFF4B185D),

                      foregroundColor:
                          Colors.white,

                      minimumSize:
                          const Size(
                        0,
                        52,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed:
                        _showVideoOptions,

                    icon: const Icon(
                      Icons.videocam,
                    ),

                    label:
                        const Text(
                      'Video',
                    ),

                    style:
                        FilledButton
                            .styleFrom(
                      backgroundColor:
                          const Color(
                              0xFF30113B),

                      foregroundColor:
                          Colors.white,

                      minimumSize:
                          const Size(
                        0,
                        52,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 30,
            ),

            // =================================================
            // PHOTOS
            // =================================================

            Row(
              children: [
                Icon(
                  Icons.photo_library,

                  color: theme
                      .colorScheme
                      .primary,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  'Photos (${photos.length})',

                  style: TextStyle(
                    fontSize: 20,

                    fontWeight:
                        FontWeight.bold,

                    color: theme
                        .colorScheme
                        .onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            if (photos.isEmpty)
              _emptyMedia(
                'No photos yet',
                Icons.photo_outlined,
              )
            else
              GridView.builder(
                shrinkWrap: true,

                physics:
                    const NeverScrollableScrollPhysics(),

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),

                itemCount:
                    photos.length,

                itemBuilder:
                    (context, index) {
                  return _photoItem(
                    photos[index],
                    index,
                  );
                },
              ),

            const SizedBox(
              height: 32,
            ),

            // =================================================
            // VIDEOS
            // =================================================

            Row(
              children: [
                Icon(
                  Icons.video_library,

                  color: theme
                      .colorScheme
                      .primary,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  'Videos (${videos.length})',

                  style: TextStyle(
                    fontSize: 20,

                    fontWeight:
                        FontWeight.bold,

                    color: theme
                        .colorScheme
                        .onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            if (videos.isEmpty)
              _emptyMedia(
                'No videos yet',
                Icons.video_library_outlined,
              )
            else
              Column(
                children:
                    List.generate(
                  videos.length,
                  (index) {
                    return _videoItem(
                      videos[index],
                      index,
                    );
                  },
                ),
              ),

            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),

      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  // =====================================================
  // EMPTY MEDIA
  // =====================================================

  Widget _emptyMedia(
    String text,
    IconData icon,
  ) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        vertical: 35,
      ),

      decoration:
          BoxDecoration(
        color:
            theme.colorScheme.surface,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: theme
              .colorScheme
              .onSurface
              .withOpacity(0.08),
        ),
      ),

      child: Column(
        children: [
          Icon(
            icon,

            size: 40,

            color: theme
                .colorScheme
                .onSurface
                .withOpacity(0.35),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            text,

            style: TextStyle(
              color: theme
                  .colorScheme
                  .onSurface
                  .withOpacity(0.60),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PHOTO ITEM
  // =====================================================

  Widget _photoItem(
    String path,
    int index,
  ) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FullImagePage(
                  path: path,
                ),
              ),
            );
          },

          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(14),

            child: Image.file(
              File(path),

              width:
                  double.infinity,

              height:
                  double.infinity,

              fit: BoxFit.cover,

              errorBuilder:
                  (context, error,
                      stackTrace) {
                return Container(
                  color: Colors.grey
                      .shade200,

                  child: const Icon(
                    Icons.broken_image,
                  ),
                );
              },
            ),
          ),
        ),

        // DELETE BUTTON

        Positioned(
          top: 8,
          right: 8,

          child: Material(
            color: Colors.black
                .withOpacity(0.65),

            shape:
                const CircleBorder(),

            child: InkWell(
              customBorder:
                  const CircleBorder(),

              onTap: () {
                _deletePhoto(index);
              },

              child: const Padding(
                padding:
                    EdgeInsets.all(8),

                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // VIDEO ITEM
  // =====================================================

  Widget _videoItem(
    String path,
    int index,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      color:
          theme.colorScheme.surface,

      child: ListTile(
        leading: Container(
          width: 55,
          height: 55,

          decoration:
              BoxDecoration(
            color: theme
                .colorScheme
                .primary
                .withOpacity(0.10),

            borderRadius:
                BorderRadius.circular(12),
          ),

          child: Icon(
            Icons.play_circle_fill,

            color:
                theme.colorScheme.primary,

            size: 32,
          ),
        ),

        title: Text(
          'Performance Video ${index + 1}',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,

            color: theme
                .colorScheme
                .onSurface,
          ),
        ),

        subtitle: Text(
          'Tap to play',

          style: TextStyle(
            color: theme
                .colorScheme
                .onSurface
                .withOpacity(0.60),
          ),
        ),

        trailing:
            IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.red,
          ),

          onPressed: () {
            _deleteVideo(index);
          },
        ),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VideoPlayerPage(
                path: path,
              ),
            ),
          );
        },
      ),
    );
  }
}

// =====================================================
// FULL IMAGE
// =====================================================

class FullImagePage
    extends StatelessWidget {
  final String path;

  const FullImagePage({
    super.key,
    required this.path,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        backgroundColor:
            Colors.black,

        foregroundColor:
            Colors.white,
      ),

      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(path),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// VIDEO PLAYER
// =====================================================

class VideoPlayerPage
    extends StatefulWidget {
  final String path;

  const VideoPlayerPage({
    super.key,
    required this.path,
  });

  @override
  State<VideoPlayerPage> createState() =>
      _VideoPlayerPageState();
}

class _VideoPlayerPageState
    extends State<VideoPlayerPage> {
  late VideoPlayerController
      controller;

  @override
  void initState() {
    super.initState();

    controller =
        VideoPlayerController.file(
      File(widget.path),
    )
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        backgroundColor:
            Colors.black,

        foregroundColor:
            Colors.white,
      ),

      body: Center(
        child: controller
                .value.isInitialized
            ? Column(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                children: [
                  AspectRatio(
                    aspectRatio:
                        controller
                            .value
                            .aspectRatio,

                    child: VideoPlayer(
                      controller,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  IconButton(
                    iconSize: 55,

                    color:
                        Colors.white,

                    icon: Icon(
                      controller
                              .value
                              .isPlaying
                          ? Icons
                              .pause_circle
                          : Icons
                              .play_circle,
                    ),

                    onPressed: () {
                      setState(() {
                        if (controller
                            .value
                            .isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                      });
                    },
                  ),
                ],
              )
            : const CircularProgressIndicator(
                color: Colors.white,
              ),
      ),
    );
  }
}
// =====================================================
// CREATE EVENT DIALOG
// =====================================================

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() =>
      _CreateEventDialogState();
}

class _CreateEventDialogState
    extends State<_CreateEventDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  void createEvent() {
    final String name =
        controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final Color textColor =
        theme.colorScheme.onSurface;

    final bool isDark =
        theme.brightness ==
            Brightness.dark;

    return AlertDialog(
      backgroundColor:
          theme.colorScheme.surface,

      title: Text(
        'Create Event',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),

      content: TextField(
        controller: controller,

        autofocus: true,

        textCapitalization:
            TextCapitalization.words,

        style: TextStyle(
          color: textColor,
        ),

        onSubmitted: (_) {
          createEvent();
        },

        decoration: InputDecoration(
          labelText: 'Event name',

          hintText:
              'Example: Annual Day 2026',

          labelStyle: TextStyle(
            color: isDark
                ? Colors.grey.shade400
                : Colors.grey.shade700,
          ),

          hintStyle: TextStyle(
            color: isDark
                ? Colors.grey.shade600
                : Colors.grey.shade500,
          ),

          prefixIcon: const Icon(
            Icons.event_outlined,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),

            borderSide: BorderSide(
              color:
                  theme.colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },

          child: const Text(
            'CANCEL',
          ),
        ),

        FilledButton(
          onPressed: createEvent,

          style: FilledButton.styleFrom(
            backgroundColor:
                const Color(0xFF53176B),

            foregroundColor:
                Colors.white,
          ),

          child: const Text(
            'CREATE',
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