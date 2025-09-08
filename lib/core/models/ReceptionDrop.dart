
// RECEPTION DROPS
class ReceptionDrop {
  final int? id;
  final int fromDoctorId;
  final int toDoctorId;
  final String shift;
  final String month;

  ReceptionDrop({
    this.id,
    required this.fromDoctorId,
    required this.toDoctorId,
    required this.shift,
    required this.month,
  });

  factory ReceptionDrop.fromMap(Map<String, dynamic> map) {
    return ReceptionDrop(
      id: map['id'],
      fromDoctorId: map['from_doctor_id'],
      toDoctorId: map['to_doctor_id'],
      shift: map['shift'],
      month: map['month'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_doctor_id': fromDoctorId,
      'to_doctor_id': toDoctorId,
      'shift': shift,
      'month': month,
    };
  }
}
