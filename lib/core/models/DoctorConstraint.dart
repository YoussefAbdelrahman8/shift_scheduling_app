// DOCTOR CONSTRAINTS
import 'DoctorRequest.dart';

class DoctorConstraint {
  final int? id;
  final int doctorId;
  final int totalShifts;
  final int morningShifts;
  final int eveningShifts;
  final List<DoctorRequest>? doctorRequests;

  final bool seniority; // to take seniority as a factor or not
  final bool enforceWanted; // to enforce doctors wanted days
  final bool enforceExceptions; // to enforce doctors exceptional days
  final bool avoidWeekends;
  final bool enforceAvoidWeekends;
  final bool firstWeekDaysPreference; // Ex: (Saturday, Sunday,...)
  final bool lastWeekDaysPreference; // Ex: (Tuesday, Wednesday,...)
  final bool firstMonthDaysPreference;
  final bool lastMonthDaysPreference;
  final bool avoidConsecutiveDays; // do not have two shifts in a row either section or reception
  final int priority; // 0–5

  DoctorConstraint({
    this.id,
    required this.doctorId,
    this.totalShifts = 0,
    this.morningShifts = 0,
    this.eveningShifts = 0,
    this.doctorRequests,
    this.seniority = false,
    this.enforceWanted = false,
    this.enforceExceptions = false,
    this.avoidWeekends = false,
    this.enforceAvoidWeekends = false,
    this.firstWeekDaysPreference = false,
    this.lastWeekDaysPreference = false,
    this.firstMonthDaysPreference = false,
    this.lastMonthDaysPreference = false,
    this.avoidConsecutiveDays = false, // default false
    this.priority = 0,
  });

  /// fromMap works like fromJson
  factory DoctorConstraint.fromMap(Map<String, dynamic> map) {
    return DoctorConstraint(
      id: map['id'],
      doctorId: map['doctor_id'],
      totalShifts: map['totalShifts'] ?? 0,
      morningShifts: map['morningShifts'] ?? 0,
      eveningShifts: map['eveningShifts'] ?? 0,
      doctorRequests: map['doctorRequests'] != null
          ? List<DoctorRequest>.from(
        (map['doctorRequests'] as List)
            .map((e) => DoctorRequest.fromMap(e)),
      )
          : null,
      seniority: map['seniority'] == 1,
      enforceWanted: map['enforceWanted'] == 1,
      enforceExceptions: map['enforceExceptions'] == 1,
      avoidWeekends: map['avoidWeekends'] == 1,
      enforceAvoidWeekends: map['enforceAvoidWeekends'] == 1,
      firstWeekDaysPreference: map['firstWeekDaysPreference'] == 1,
      lastWeekDaysPreference: map['lastWeekDaysPreference'] == 1,
      firstMonthDaysPreference: map['firstMonthDaysPreference'] == 1,
      lastMonthDaysPreference: map['lastMonthDaysPreference'] == 1,
      avoidConsecutiveDays: map['avoidConsecutiveDays'] == 1, // NEW
      priority: map['priority'] ?? 0,
    );
  }

  /// toMap works like toJson
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'totalShifts': totalShifts,
      'morningShifts': morningShifts,
      'eveningShifts': eveningShifts,
      'doctorRequests': doctorRequests?.map((e) => e.toMap()).toList(),
      'seniority': seniority ? 1 : 0,
      'enforceWanted': enforceWanted ? 1 : 0,
      'enforceExceptions': enforceExceptions ? 1 : 0,
      'avoidWeekends': avoidWeekends ? 1 : 0,
      'enforceAvoidWeekends': enforceAvoidWeekends ? 1 : 0,
      'firstWeekDaysPreference': firstWeekDaysPreference ? 1 : 0,
      'lastWeekDaysPreference': lastWeekDaysPreference ? 1 : 0,
      'firstMonthDaysPreference': firstMonthDaysPreference ? 1 : 0,
      'lastMonthDaysPreference': lastMonthDaysPreference ? 1 : 0,
      'avoidConsecutiveDays': avoidConsecutiveDays ? 1 : 0, // NEW
      'priority': priority,
    };
  }
}
