
// DOCTORS
class Doctor {
  final int? id;
  final String name;
  final String? specialization;
  final String? seniority;

  Doctor({
    this.id,
    required this.name,
    this.specialization,
    this.seniority,
  });

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: map['id'],
      name: map['name'],
      specialization: map['specialization'],
      seniority: map['seniority'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'seniority': seniority,
    };
  }
}
