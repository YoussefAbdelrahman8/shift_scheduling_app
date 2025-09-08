
// SECTION SCHEDULE (Aggregation of shifts)

import 'SectionShift.dart';

class SectionSchedule {
  final String month; // e.g., "2025-09"
  final List<SectionShift> shifts;

  SectionSchedule({
    required this.month,
    required this.shifts,
  });

  factory SectionSchedule.fromMap(Map<String, dynamic> map) {
    return SectionSchedule(
      month: map['month'],
      shifts: map['shifts'] != null
          ? List<SectionShift>.from(
        (map['shifts'] as List).map((e) => SectionShift.fromMap(e)),
      )
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'shifts': shifts.map((e) => e.toMap()).toList(),
    };
  }
}