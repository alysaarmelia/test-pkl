import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/calendar_event_repository.dart';

import '../../widgets/glass.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarEventRepository _repository = CalendarEventRepository();
  StreamSubscription<List<CalendarEvent>>? _eventsSubscription;
  List<CalendarEvent> _events = const [];
  Object? _loadError;
  bool _isLoading = true;
  late DateTime _focusedMonth;
  DateTime _today = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(_today.year, _today.month);
    _selectedDate = _today;
    _subscribeToMonth(_focusedMonth);
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMonth(DateTime month) {
    final start = DateTime(month.year, month.month - 1, 1);
    final end = DateTime(month.year, month.month + 2, 0, 23, 59, 59, 999);
    _eventsSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _eventsSubscription = _repository
        .watchEvents(from: start, until: end)
        .listen((items) {
      if (!mounted) return;
      setState(() {
        _events = items;
        _isLoading = false;
      });
    }, onError: (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    });
  }

  void _changeMonth(int delta) {
    final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    setState(() {
      _focusedMonth = newMonth;
    });
    _subscribeToMonth(newMonth);
  }

  Future<void> _goToToday() async {
    final today = DateTime.now();
    final newFocused = DateTime(today.year, today.month);
    setState(() {
      _today = today;
      _focusedMonth = newFocused;
      _selectedDate = today;
    });
    _subscribeToMonth(newFocused);
  }

  Future<void> _handleAddEvent() async {
    final selectedDate = _selectedDate ?? _today;
    final payload = await _showAddEventDialog(selectedDate);
    if (payload == null) return;
    try {
      await _repository.createEvent(payload);
      if (!mounted) return;
      _showGlassSnackBar('Acara berhasil ditambahkan.');
    } catch (error) {
      if (!mounted) return;
      _showGlassSnackBar('Gagal menambahkan acara: $error', isError: true);
    }
  }

  Future<CalendarEventPayload?> _showAddEventDialog(DateTime initialDate) {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    final timeController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedDivision = CalendarDivision.all;
    DateTime eventDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    TimeOfDay? timeOfDay;
    return showDialog<CalendarEventPayload>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
                    eventDate =
                        DateTime(picked.year, picked.month, picked.day);
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
                    timeController.text = picked.format(context);
                  });
                }
              }

              final theme = Theme.of(context);
              final canSubmit = titleController.text.trim().isNotEmpty;

              InputDecoration _fieldDecoration({
                required String label,
                String? hint,
              }) {
                return InputDecoration(
                  labelText: label,
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.20),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                );
              }

              return GlassContainer(
                borderRadius: 28,
                blur: 26,
                gradientColors: const [
                  Color.fromARGB(200, 14, 20, 40),
                  Color.fromARGB(150, 10, 14, 28),
                ],
                borderColor: Colors.white.withOpacity(0.18),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(60, 8, 12, 26),
                    offset: Offset(0, 28),
                    blurRadius: 46,
                    spreadRadius: -20,
                  ),
                ],
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tambah Acara',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: _fieldDecoration(
                                  label: 'Judul Acara',
                                  hint: 'Misalnya: Rapat Tim',
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setLocalState(() {}),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: categoryController,
                                decoration: _fieldDecoration(
                                  label: 'Kategori',
                                  hint: 'Misalnya: Rapat, Cuti, Izin',
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              FormField<String>(
                                initialValue: selectedDivision,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Pilih divisi tujuan.';
                                  }
                                  return null;
                                },
                                builder: (state) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: PopupMenuButton<String>(
                                      initialValue: selectedDivision,
                                      padding: EdgeInsets.zero,
                                      position: PopupMenuPosition.under,
                                      offset: const Offset(0, 6),
                                      color: Colors.black.withOpacity(0.82),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      onSelected: (value) {
                                        setLocalState(() {
                                          selectedDivision = value;
                                        });
                                        state.didChange(value);
                                      },
                                      itemBuilder: (context) => CalendarDivision.options
                                          .map(
                                            (opt) => PopupMenuItem<String>(
                                              value: opt.id,
                                              child: Text(
                                                opt.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      child: InputDecorator(
                                        decoration: _fieldDecoration(
                                          label: 'Divisi Tujuan',
                                          hint: 'Pilih divisi yang menerima agenda',
                                        ).copyWith(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(22),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(0.20),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(22),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(0.14),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(22),
                                            borderSide: BorderSide(
                                              color: theme.colorScheme.primary.withOpacity(0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          errorText: state.errorText,
                                          suffixIcon: const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                        isEmpty: selectedDivision.isEmpty,
                                        child: Text(
                                          CalendarDivision.labelFor(selectedDivision) ?? selectedDivision,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: pickDate,
                                      borderRadius: BorderRadius.circular(20),
                                      child: GlassContainer(
                                        borderRadius: 20,
                                        blur: 20,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        gradientColors: const [
                                          Color.fromARGB(140, 32, 44, 72),
                                          Color.fromARGB(90, 20, 28, 48),
                                        ],
                                        borderColor:
                                            Colors.white.withOpacity(0.22),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromARGB(36, 4, 10, 28),
                                            offset: Offset(0, 18),
                                            blurRadius: 32,
                                            spreadRadius: -16,
                                          ),
                                        ],
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 18,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.expand_more_rounded,
                                              size: 20,
                                              color: Colors.white60,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: InkWell(
                                      onTap: pickTime,
                                      borderRadius: BorderRadius.circular(20),
                                      child: GlassContainer(
                                        borderRadius: 20,
                                        blur: 20,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        gradientColors: const [
                                          Color.fromARGB(140, 32, 44, 72),
                                          Color.fromARGB(90, 20, 28, 48),
                                        ],
                                        borderColor:
                                            Colors.white.withOpacity(0.22),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromARGB(36, 4, 10, 28),
                                            offset: Offset(0, 18),
                                            blurRadius: 32,
                                            spreadRadius: -16,
                                          ),
                                        ],
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.schedule_rounded,
                                              size: 18,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                timeController.text.isEmpty
                                                    ? 'Pilih waktu'
                                                    : timeController.text,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          timeController.text
                                                                  .isEmpty
                                                              ? Colors.white70
                                                              : Colors.white,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.expand_more_rounded,
                                              size: 20,
                                              color: Colors.white60,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: locationController,
                                decoration: _fieldDecoration(
                                  label: 'Lokasi',
                                  hint: 'Misalnya: Ruang Meeting A',
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: descriptionController,
                                maxLines: 3,
                                decoration: _fieldDecoration(
                                  label: 'Deskripsi',
                                  hint: 'Catatan tambahan untuk peserta',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text(
                              'Batal',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: canSubmit
                                ? () {
                                    Navigator.of(dialogContext).pop(
                                      CalendarEventPayload(
                                        title: titleController.text.trim(),
                                        date: eventDate,
                                        category:
                                            categoryController.text.trim().isEmpty
                                                ? null
                                                : categoryController.text.trim(),
                                        location:
                                            locationController.text.trim().isEmpty
                                                ? null
                                                : locationController.text.trim(),
                                        timeText: timeController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : timeController.text.trim(),
                                        description: descriptionController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : descriptionController.text.trim(),
                                        divisions: [selectedDivision],
                                        createdBy:
                                            FirebaseAuth.instance.currentUser?.uid,
                                      ),
                                    );
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                            ),
                            child: const Text('Simpan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      categoryController.dispose();
      timeController.dispose();
      locationController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GlassContainer(
              borderRadius: 28,
              blur: 28,
              gradientColors: const [
                Color.fromARGB(220, 16, 20, 38),
                Color.fromARGB(180, 10, 14, 28),
              ],
              borderColor: Colors.white.withOpacity(0.2),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromARGB(70, 4, 8, 20),
                  offset: Offset(0, 32),
                  blurRadius: 50,
                  spreadRadius: -24,
                ),
              ],
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GlassContainer(
                          borderRadius: 16,
                          blur: 24,
                          gradientColors: const [
                            Color.fromARGB(200, 172, 39, 39),
                            Color.fromARGB(160, 110, 20, 28),
                          ],
                          borderColor: Colors.white.withOpacity(0.35),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hapus Acara?',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Acara "${event.title}" akan dihapus dari kalender.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.error.withOpacity(0.9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteEvent(event.id);
      if (!mounted) return;
      _showGlassSnackBar('Acara berhasil dihapus.');
    } catch (error) {
      if (!mounted) return;
      _showGlassSnackBar('Gagal menghapus acara: $error', isError: true);
    }
  }

  void _showGlassSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final theme = Theme.of(context);
    final colors = isError
        ? [
            const Color.fromARGB(170, 174, 31, 31),
            const Color.fromARGB(140, 100, 12, 21),
          ]
        : [
            const Color.fromARGB(170, 34, 149, 112),
            const Color.fromARGB(140, 21, 86, 66),
          ];
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 24,
        ),
        content: GlassContainer(
          borderRadius: 22,
          blur: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          gradientColors: colors,
          borderColor: Colors.white.withOpacity(0.35),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(70, 0, 0, 0),
              offset: Offset(0, 18),
              blurRadius: 32,
              spreadRadius: -16,
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: messenger.hideCurrentSnackBar,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _eventsForMonth(_focusedMonth);
    final dayEvents = _eventsForDay(_selectedDate ?? _today);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kalender Tim',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Atur jadwal shift, cuti, dan izin pada satu tampilan terpadu.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(16),
                gradientColors: const [
                  Color.fromARGB(120, 130, 26, 26),
                  Color.fromARGB(90, 60, 12, 12),
                ],
                borderColor: const Color.fromARGB(70, 255, 255, 255),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(40, 0, 0, 0),
                    offset: Offset(0, 12),
                    blurRadius: 28,
                    spreadRadius: -14,
                  ),
                ],
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tidak dapat memuat acara kalender: $_loadError',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _CalendarHeader(
            month: _focusedMonth,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onToday: _goToToday,
            onAddEvent: _handleAddEvent,
          ),
          const SizedBox(height: 18),
          _CalendarGrid(
            month: _focusedMonth,
            today: _today,
            selected: _selectedDate,
            events: events,
            onSelect: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 24),
          _EventList(
            date: _selectedDate,
            events: dayEvents,
            onDelete: _deleteEvent,
          ),
        ],
      ),
    );
  }

  List<CalendarEvent> _eventsForMonth(DateTime month) {
    return _events.where((event) {
      return event.date.year == month.year && event.date.month == month.month;
    }).toList(growable: false);
  }

  List<CalendarEvent> _eventsForDay(DateTime date) {
    return _events.where((event) {
      final localDate = event.date;
      return localDate.year == date.year &&
          localDate.month == date.month &&
          localDate.day == date.day;
    }).toList(growable: false);
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onAddEvent,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 22,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      gradientColors: const [
        Color.fromARGB(140, 18, 20, 36),
        Color.fromARGB(84, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(70, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(55, 6, 10, 30),
          offset: Offset(0, 20),
          blurRadius: 40,
          spreadRadius: -18,
        ),
      ],
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                _formatMonth(month),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(onPressed: onToday, child: const Text('Hari ini')),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAddEvent,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  String _formatMonth(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.events,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1; // Monday as first day
    final totalCells = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassContainer(
      borderRadius: 26,
      blur: 22,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      gradientColors: const [
        Color.fromARGB(150, 18, 20, 36),
        Color.fromARGB(92, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(70, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(55, 6, 10, 30),
          offset: Offset(0, 22),
          blurRadius: 44,
          spreadRadius: -20,
        ),
      ],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _WeekdayLabel('Sen'),
              _WeekdayLabel('Sel'),
              _WeekdayLabel('Rab'),
              _WeekdayLabel('Kam'),
              _WeekdayLabel('Jum'),
              _WeekdayLabel('Sab'),
              _WeekdayLabel('Min'),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmpty + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, dayNumber);
              final isToday = _isSameDay(date, today);
              final isSelected =
                  selected != null && _isSameDay(date, selected!);
              final dayEvents = events
                  .where((event) => _isSameDay(event.date, date))
                  .toList();
              return GestureDetector(
                onTap: () => onSelect(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : isToday
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayNumber',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final event in dayEvents.take(3))
                            _EventDot(
                              color: _eventColor(colorScheme, event.category),
                              label: event.category ?? 'Agenda',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _eventColor(ColorScheme scheme, String? category) {
    final lower = category?.toLowerCase() ?? '';
    if (lower.contains('cuti')) return scheme.primary;
    if (lower.contains('shift')) return scheme.tertiary;
    if (lower.contains('izin')) return scheme.secondary;
    if (lower.contains('rapat')) return scheme.secondaryContainer;
    if (lower.contains('pengingat') || lower.contains('deadline')) {
      return scheme.tertiaryContainer;
    }
    if (lower.isEmpty) return scheme.primary;
    return scheme.error;
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EventDot extends StatelessWidget {
  const _EventDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.date,
    required this.events,
    required this.onDelete,
  });

  final DateTime? date;
  final List<CalendarEvent> events;
  final Future<void> Function(CalendarEvent) onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassContainer(
        borderRadius: 26,
        blur: 22,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        gradientColors: const [
          Color.fromARGB(150, 18, 20, 36),
          Color.fromARGB(92, 11, 13, 28),
        ],
        borderColor: const Color.fromARGB(70, 255, 255, 255),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(55, 6, 10, 30),
            offset: Offset(0, 22),
            blurRadius: 44,
            spreadRadius: -20,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Tidak ada agenda pada hari ini.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Column(
                children: [
                  for (final event in events)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: GlassContainer(
                        borderRadius: 20,
                        blur: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        gradientColors: const [
                          Color.fromARGB(140, 24, 30, 52),
                          Color.fromARGB(88, 16, 20, 36),
                        ],
                        borderColor: const Color.fromARGB(60, 255, 255, 255),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromARGB(40, 6, 10, 30),
                            offset: Offset(0, 16),
                            blurRadius: 34,
                            spreadRadius: -18,
                          ),
                        ],
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _EventDot(
                                color: _eventColor(
                                  Theme.of(context).colorScheme,
                                  event.category,
                                ),
                                label: event.category ?? 'Agenda',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Builder(
                                    builder: (context) {
                                      final infoLine = _infoLine(event);
                                      if (infoLine == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        infoLine,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      );
                                    },
                                  ),
                                  if (event.description?.isNotEmpty ?? false)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        event.description!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          Theme(
                            data: Theme.of(context).copyWith(
                              popupMenuTheme: PopupMenuThemeData(
                                color: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            child: PopupMenuButton<_EventAction>(
                              tooltip: 'Aksi Acara',
                              offset: const Offset(0, 10),
                              onSelected: (value) {
                                if (value == _EventAction.delete) {
                                  unawaited(onDelete(event));
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<_EventAction>(
                                  value: _EventAction.delete,
                                  padding: EdgeInsets.zero,
                                  child: GlassContainer(
                                    borderRadius: 16,
                                    blur: 18,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    gradientColors: const [
                                      Color.fromARGB(160, 24, 28, 46),
                                      Color.fromARGB(120, 16, 20, 36),
                                    ],
                                    borderColor:
                                        Colors.white.withOpacity(0.24),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromARGB(35, 6, 10, 30),
                                        offset: Offset(0, 18),
                                        blurRadius: 32,
                                        spreadRadius: -18,
                                      ),
                                    ],
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Hapus Acara',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _title() {
    final date = this.date;
    if (date == null) return 'Agenda';
    return 'Agenda • ${date.day}/${date.month}/${date.year}';
  }

  String? _infoLine(CalendarEvent event) {
    final parts = <String>[];
    final divisionLabel = _divisionLabel(event.divisions);
    if (divisionLabel != null) {
      parts.add(divisionLabel);
    }
    if (event.category?.isNotEmpty ?? false) {
      parts.add(event.category!);
    }
    if (event.timeText?.isNotEmpty ?? false) {
      parts.add(event.timeText!);
    }
    if (event.location?.isNotEmpty ?? false) {
      parts.add(event.location!);
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String? _divisionLabel(List<String> divisions) {
    if (divisions.isEmpty || divisions.contains(CalendarDivision.all)) {
      return null;
    }
    final target = divisions.firstWhere(
      (id) => id != CalendarDivision.all,
      orElse: () => divisions.first,
    );
    return CalendarDivision.labelFor(target) ?? target;
  }

  Color _eventColor(ColorScheme scheme, String? category) {
    final lower = category?.toLowerCase() ?? '';
    if (lower.contains('cuti')) return scheme.primary;
    if (lower.contains('shift')) return scheme.tertiary;
    if (lower.contains('izin')) return scheme.secondary;
    if (lower.contains('rapat')) return scheme.secondaryContainer;
    if (lower.contains('pengingat') || lower.contains('deadline')) {
      return scheme.tertiaryContainer;
    }
    if (lower.isEmpty) return scheme.primary;
    return scheme.error;
  }
}

enum _EventAction { delete }
