
// DOCTOR REQUESTS
class DoctorRequest {
  final int? id;
  final int doctorId;
  final String date;
  final String shift; // Day | Night
  final String type;  // wanted | exception

  DoctorRequest({
    this.id,
    required this.doctorId,
    required this.date,
    required this.shift,
    required this.type,
  });

  factory DoctorRequest.fromMap(Map<String, dynamic> map) {
    return DoctorRequest(
      id: map['id'],
      doctorId: map['doctor_id'],
      date: map['date'],
      shift: map['shift'],
      type: map['type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'date': date,
      'shift': shift,
      'type': type,
    };
  }
}
