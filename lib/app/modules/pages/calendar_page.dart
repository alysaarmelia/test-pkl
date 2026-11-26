import 'dart:async';
import 'dart:ui';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/calendar_page_event.dart';
import 'package:cipta_vera_mandiri_digital/view_models/calendar_page_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final String _calendarViewModelTag;
  late final CalendarPageViewModel _viewModel;
  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  CalendarFormat _calendarFormat = CalendarFormat.month;

  Widget _glassPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
    double borderRadius = 18,
    Color? background,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: background ?? HomeGlassTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: HomeGlassTheme.surfaceBorder),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _calendarViewModelTag = 'calendar-page-${identityHashCode(this)}';
    _viewModel = Get.put(CalendarPageViewModel(), tag: _calendarViewModelTag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<CalendarPageViewModel>(tag: _calendarViewModelTag)) {
      Get.delete<CalendarPageViewModel>(
        tag: _calendarViewModelTag,
        force: true,
      );
    }
    _eventController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _monthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  Future<void> _showAddEventDialog() async {
    _eventController.clear();
    _timeController.clear();
    _locationController.clear();
    DateTime eventDate = _viewModel.normalizeDate(_viewModel.selectedDay.value);
    TimeOfDay? timeOfDay;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.0),
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Tambah Acara',
                style: TextStyle(color: Colors.white),
              ),
              content: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: StatefulBuilder(
                      builder: (context, setLocalState) {
                        Future<void> pickDate() async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: eventDate,
                            firstDate: DateTime(DateTime.now().year - 5),
                            lastDate: DateTime(DateTime.now().year + 5),
                          );
                          if (picked != null) {
                            setLocalState(() {
                              eventDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                              );
                              if (timeOfDay != null) {
                                eventDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  timeOfDay!.hour,
                                  timeOfDay!.minute,
                                );
                              }
                            });
                          }
                        }

                        Future<void> pickTime() async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: timeOfDay ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setLocalState(() {
                              timeOfDay = picked;
                              eventDate = DateTime(
                                eventDate.year,
                                eventDate.month,
                                eventDate.day,
                                picked.hour,
                                picked.minute,
                              );
                              _timeController.text = picked.format(context);
                            });
                          }
                        }

                        final theme = Theme.of(context);
                        final titleText = _eventController.text.trim();
                        final timeText = _timeController.text.trim();
                        final isFormValid =
                            titleText.isNotEmpty && timeText.isNotEmpty;

                        InputDecoration glassInputDecoration({
                          required String label,
                          String? hint,
                        }) {
                          return InputDecoration(
                            labelText: label,
                            hintText: hint,
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.22),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.blueAccent.withOpacity(0.55),
                                width: 1.6,
                              ),
                            ),
                            labelStyle: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          );
                        }

                        Widget buildGlassPicker({
                          required VoidCallback onTap,
                          required IconData icon,
                          required String label,
                          bool isPlaceholder = false,
                        }) {
                          return InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(18),
                            splashColor: Colors.white.withOpacity(0.08),
                            highlightColor: Colors.white.withOpacity(0.04),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.26),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        icon,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: isPlaceholder
                                                    ? Colors.white70
                                                    : Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.expand_more_rounded,
                                        color: Colors.white60,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _eventController,
                                decoration: glassInputDecoration(
                                  label: 'Judul Acara',
                                  hint: 'Misalnya: Rapat Tim',
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setLocalState(() {}),
                              ),
                              const SizedBox(height: 12),
                              buildGlassPicker(
                                onTap: pickDate,
                                icon: Icons.calendar_today_rounded,
                                label:
                                    '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                              ),
                              const SizedBox(height: 12),
                              buildGlassPicker(
                                onTap: pickTime,
                                icon: Icons.schedule_rounded,
                                label: timeText.isEmpty
                                    ? 'Pilih waktu'
                                    : timeText,
                                isPlaceholder: timeText.isEmpty,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _locationController,
                                decoration: glassInputDecoration(
                                  label: 'Lokasi',
                                  hint: 'Misalnya: Ruang Meeting A',
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'Batal',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed:
                                        !_viewModel.isSubmitting.value &&
                                            isFormValid
                                        ? () async {
                                            final title = _eventController.text
                                                .trim();
                                            final timeValue = _timeController
                                                .text
                                                .trim();
                                            if (title.isEmpty ||
                                                timeValue.isEmpty) {
                                              return;
                                            }
                                            setLocalState(() {});
                                            try {
                                              await _viewModel.createEvent(
                                                date: eventDate,
                                                title: title,
                                                time: timeValue,
                                                location: _locationController
                                                    .text
                                                    .trim(),
                                              );
                                              if (!mounted) return;
                                              Navigator.of(dialogContext).pop();
                                              showGlassSnackBar(
                                                context,
                                                message:
                                                    'Acara berhasil ditambahkan.',
                                                tone: GlassSnackTone.success,
                                              );
                                            } catch (error) {
                                              if (!mounted) return;
                                              showGlassSnackBar(
                                                context,
                                                message:
                                                    'Gagal menambahkan acara: $error',
                                                tone: GlassSnackTone.error,
                                              );
                                            } finally {
                                              setLocalState(() {});
                                            }
                                          }
                                        : null,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _viewModel.isSubmitting.value
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Text('Simpan'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteEvent(CalendarPageEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Acara'),
          content: Text('Hapus "${event.title}" dari kalender?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await _viewModel.deleteEvent(event.id);
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Acara dihapus.',
        tone: GlassSnackTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal menghapus acara: $error',
        tone: GlassSnackTone.error,
      );
    }
  }

  Widget _buildSelectedEventsSection(
    BuildContext context, {
    required DateTime selectedDay,
    required List<CalendarPageEvent> selectedEvents,
    required List<String> holidays,
  }) {
    final theme = Theme.of(context);
    final dateLabel =
        '${selectedDay.day} ${_monthName(selectedDay.month)} ${selectedDay.year}';

    Widget buildEventCard(CalendarPageEvent event) {
      final eventDate = event.date;
      final canDelete =
          event.id.startsWith('local-') || event.id.startsWith('legacy-');
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              Color.fromRGBO(59, 130, 246, 0.28),
              Color.fromRGBO(59, 130, 246, 0.14),
            ],
          ),
          border: Border.all(color: HomeGlassTheme.surfaceBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${eventDate.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    _monthName(eventDate.month),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HomeGlassTheme.textPrimary,
                    ),
                  ),
                  if (event.time.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        event.time.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: HomeGlassTheme.textSecondary,
                        ),
                      ),
                    ),
                  if (event.location.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        event.location.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: HomeGlassTheme.textSecondary,
                        ),
                      ),
                    ),
                  if ((event.description ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        event.description!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: HomeGlassTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                splashRadius: 20,
                onPressed: () => _deleteEvent(event),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agenda $dateLabel',
          style: theme.textTheme.titleMedium?.copyWith(
            color: HomeGlassTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (holidays.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(239, 68, 68, 0.32),
                  Color.fromRGBO(239, 68, 68, 0.18),
                ],
              ),
              border: Border.all(color: HomeGlassTheme.surfaceBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.celebration_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: holidays
                        .map(
                          (holiday) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              holiday,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HomeGlassTheme.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        if (selectedEvents.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color.fromRGBO(148, 163, 184, 0.18),
              border: Border.all(color: HomeGlassTheme.surfaceBorder),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Belum ada acara pada tanggal ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: HomeGlassTheme.textSecondary,
              ),
            ),
          )
        else
          ...selectedEvents.map(buildEventCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 30,
        iconTheme: const IconThemeData(color: HomeGlassTheme.textPrimary),
        title: const Text(
          'Kalender',
          style: TextStyle(
            color: HomeGlassTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _glassPanel(
                borderRadius: 16,
                padding: EdgeInsets.zero,
                child: IconButton(
                  iconSize: 22,
                  splashRadius: 22,
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _viewModel.isSubmitting.value
                      ? null
                      : _showAddEventDialog,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: HomeGlassTheme.backgroundGradient,
              ),
            ),
          ),
          HomeGlassTheme.orb(
            top: -220,
            left: -160,
            diameter: 420,
            colors: HomeGlassTheme.orbBlue,
          ),
          HomeGlassTheme.orb(
            top: 240,
            right: -200,
            diameter: 500,
            colors: HomeGlassTheme.orbPurple,
          ),
          HomeGlassTheme.orb(
            bottom: -260,
            left: 140,
            diameter: 520,
            colors: HomeGlassTheme.orbMint,
          ),
          SafeArea(
            bottom: false,
            child: Obx(() {
              final selectedDay = _viewModel.selectedDay.value;
              final events = _viewModel.events.toList(growable: false);
              final holidays = _viewModel.holidays;
              final groupedEvents = _viewModel.groupEvents(events);
              final selectedEvents =
                  groupedEvents[_viewModel.normalizeDate(selectedDay)] ??
                  const <CalendarPageEvent>[];
              final upcomingHolidays =
                  holidays.entries
                      .where((entry) => entry.key.isAfter(selectedDay))
                      .toList()
                    ..sort((a, b) => a.key.compareTo(b.key));
              final selectedHolidays =
                  holidays[_viewModel.normalizeDate(selectedDay)] ??
                  const <String>[];

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_viewModel.isSubmitting.value)
                      _glassPanel(
                        padding: const EdgeInsets.all(12),
                        child: const LinearProgressIndicator(),
                      ),
                    _glassPanel(
                      borderRadius: 24,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 12,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 420,
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: selectedDay,
                            calendarFormat: _calendarFormat,
                            availableCalendarFormats: const {
                              CalendarFormat.month: 'Bulan',
                              CalendarFormat.twoWeeks: '2 Minggu',
                              CalendarFormat.week: 'Minggu',
                            },
                            eventLoader: (day) =>
                                groupedEvents[_viewModel.normalizeDate(day)] ??
                                const [],
                            selectedDayPredicate: (day) =>
                                _viewModel.normalizeDate(day) ==
                                _viewModel.normalizeDate(selectedDay),
                            onDaySelected: (selectedDay, focusedDay) {
                              _viewModel.selectDay(selectedDay);
                            },
                            onPageChanged: (focusedDay) {
                              unawaited(_viewModel.onPageChanged(focusedDay));
                            },
                            onFormatChanged: (format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            },
                            headerStyle: HeaderStyle(
                              titleCentered: true,
                              titleTextStyle: const TextStyle(
                                color: HomeGlassTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              formatButtonVisible: true,
                              formatButtonShowsNext: true,
                              formatButtonTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              formatButtonDecoration: BoxDecoration(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.14,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: HomeGlassTheme.surfaceBorder,
                                ),
                              ),
                              leftChevronIcon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                              ),
                              rightChevronIcon: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ),
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(
                                color: HomeGlassTheme.textSecondary,
                              ),
                              weekendStyle: TextStyle(color: Color(0xFFFFA7A7)),
                            ),
                            calendarStyle: CalendarStyle(
                              defaultTextStyle: const TextStyle(
                                color: HomeGlassTheme.textPrimary,
                              ),
                              weekendTextStyle: const TextStyle(
                                color: Colors.white,
                              ),
                              disabledTextStyle: const TextStyle(
                                color: Color.fromRGBO(255, 255, 255, 0.25),
                              ),
                              todayDecoration: const BoxDecoration(
                                color: Color.fromRGBO(59, 130, 246, 0.45),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: Color.fromRGBO(139, 92, 246, 0.6),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: const TextStyle(
                                color: Colors.white,
                              ),
                              selectedTextStyle: const TextStyle(
                                color: Colors.white,
                              ),
                              outsideDaysVisible: false,
                              holidayTextStyle: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontWeight: FontWeight.bold,
                              ),
                              holidayDecoration: const BoxDecoration(
                                color: Color.fromRGBO(255, 107, 107, 0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, dayEvents) {
                                if (dayEvents.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final typedEvents = dayEvents
                                    .whereType<CalendarPageEvent>()
                                    .toList(growable: false);
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: typedEvents.take(3).map((_) {
                                        return Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF38BDF8),
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            holidayPredicate: (date) => holidays.containsKey(
                              _viewModel.normalizeDate(date),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (upcomingHolidays.isNotEmpty)
                      _glassPanel(
                        borderRadius: 22,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Libur Nasional Mendatang',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: HomeGlassTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...upcomingHolidays.take(5).map((entry) {
                              final date = entry.key;
                              final names = entry.value.join(', ');
                              final daysRemaining = date
                                  .difference(
                                    _viewModel.normalizeDate(DateTime.now()),
                                  )
                                  .inDays;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _glassPanel(
                                  borderRadius: 18,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  background: const Color.fromRGBO(
                                    239,
                                    68,
                                    68,
                                    0.22,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF7A7A),
                                              Color(0xFFFF4D6D),
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${date.day}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            Text(
                                              _monthName(date.month),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              names,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    HomeGlassTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$daysRemaining hari lagi',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: HomeGlassTheme
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),
                    _glassPanel(
                      borderRadius: 22,
                      padding: const EdgeInsets.all(20),
                      child: _buildSelectedEventsSection(
                        context,
                        selectedDay: selectedDay,
                        selectedEvents: selectedEvents,
                        holidays: selectedHolidays,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
