import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/theme.dart';
import 'package:table_calendar/table_calendar.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _tripDates = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripDates();
  }

  Future<void> _loadTripDates() async {
    setState(() => isLoading = true);

    try {
      final dates = await LocalDb.getAllDates();
      
      Map<DateTime, List<String>> tripMap = {};
      for (var dateStr in dates) {
        try {
          final date = DateTime.parse(dateStr);
          final normalizedDate = DateTime(date.year, date.month, date.day);
          tripMap[normalizedDate] = [dateStr];
        } catch (e) {
          debugPrint('Error parsing date: $dateStr');
        }
      }

      if (mounted) {
        setState(() {
          _tripDates = tripMap;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trip dates: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<String> _getTripsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _tripDates[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.paddingLg,
              children: [
                Text('History',
                    style: context.textStyles.headlineLarge
                        ?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                Text('Select a date to view trip details.',
                    style: context.textStyles.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                
                // Calendar Widget
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.16),
                    ),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.now(),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    
                    // Event loader
                    eventLoader: _getTripsForDay,
                    
                    // Styling
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: scheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      outsideDaysVisible: false,
                    ),
                    
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: context.textStyles.titleLarge!
                          .copyWith(color: scheme.onSurface),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: scheme.onSurface,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: scheme.onSurface,
                      ),
                    ),
                    
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: context.textStyles.labelSmall!
                          .copyWith(color: scheme.onSurfaceVariant),
                      weekendStyle: context.textStyles.labelSmall!
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                    
                    onDaySelected: (selectedDay, focusedDay) {
                      if (_getTripsForDay(selectedDay).isNotEmpty) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        
                        // Navigate to trip details
                        final dateStr = selectedDay.toIso8601String().split('T').first;
                        context.push(AppRoutes.tripDetails(dateStr));
                      }
                    },
                    
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Legend
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Days with recorded trips',
                        style: context.textStyles.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}