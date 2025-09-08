
// RECEPTION SHIFT
class ReceptionShift{
  final int? id;
  final int doctorId;
  final String date;
  final String shift; // Day | Night

  ReceptionShift({
    this.id,
    required this.doctorId,
    required this.date,
    required this.shift,
  });

  factory ReceptionShift.fromMap(Map<String, dynamic> map) {
    return ReceptionShift(
      id: map['id'],
      doctorId: map['doctor_id'],
      date: map['date'],
      shift: map['shift'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'date': date,
      'shift': shift,
    };
  }
}
