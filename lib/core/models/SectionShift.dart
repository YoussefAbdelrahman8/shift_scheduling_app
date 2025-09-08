
// SECTION SHIFTS
class SectionShift {
  final int? id;
  final int doctorId;
  final String date;

  SectionShift({
    this.id,
    required this.doctorId,
    required this.date,
  });

  factory SectionShift.fromMap(Map<String, dynamic> map) {
    return SectionShift(
      id: map['id'],
      doctorId: map['doctor_id'],
      date: map['date'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'date': date,
    };
  }
}
