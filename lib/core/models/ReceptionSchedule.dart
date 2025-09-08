
// RECEPTION SCHEDULE (Aggregation of shifts)
import 'ReceptionShift.dart';

class ReceptionSchedule {
  final String month; // e.g., "2025-09"
  final List<ReceptionShift> shifts;

  ReceptionSchedule({
    required this.month,
    required this.shifts,
  });

  factory ReceptionSchedule.fromMap(Map<String, dynamic> map) {
    return ReceptionSchedule(
      month: map['month'],
      shifts: map['shifts'] != null
          ? List<ReceptionShift>.from(
        (map['shifts'] as List).map((e) => ReceptionShift.fromMap(e)),
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