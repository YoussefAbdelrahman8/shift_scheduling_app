import 'package:flutter/material.dart';
import 'package:shift_scheduling_app/core/models/Doctor.dart';
import '../../db/DBHelper.dart';


class InsertDoctor extends StatefulWidget {
  const InsertDoctor({Key? key}) : super(key: key);

  @override
  State<InsertDoctor> createState() => _InsertDoctorState();
}

class _InsertDoctorState extends State<InsertDoctor> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final TextEditingController _controllerName = TextEditingController();

  // Drop-down values
  final List<String> seniorityList = [
    "Junior",
    "Mid-level",
    "Senior",
    "Consultant"
  ];
  String? selectedSeniority;

  final List<String> specializationList = [
    "Cardiology",
    "Neurology",
    "Pediatrics",
    "Orthopedics",
    "General Medicine",
    "Dermatology"
  ];
  String? selectedSpecialization;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        title: const Text("Insert Doctor"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Text(
                "Add New Doctor",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 30),
              // Name Field
              TextFormField(
                controller: _controllerName,
                decoration: InputDecoration(
                  labelText: "Name",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter doctor's name.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Seniority Drop-down
              DropdownButtonFormField<String>(
                value: selectedSeniority,
                items: seniorityList
                    .map((seniority) => DropdownMenuItem(
                  value: seniority,
                  child: Text(seniority),
                ))
                    .toList(),
                decoration: InputDecoration(
                  labelText: "Seniority",
                  prefixIcon: const Icon(Icons.star_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    selectedSeniority = value;
                  });
                },
                validator: (value) =>
                value == null ? "Please select seniority." : null,
              ),
              const SizedBox(height: 20),
              // Specialization Drop-down
              DropdownButtonFormField<String>(
                value: selectedSpecialization,
                items: specializationList
                    .map((specialization) => DropdownMenuItem(
                  value: specialization,
                  child: Text(specialization),
                ))
                    .toList(),
                decoration: InputDecoration(
                  labelText: "Specialization",
                  prefixIcon: const Icon(Icons.medical_services_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    selectedSpecialization = value;
                  });
                },
                validator: (value) =>
                value == null ? "Please select specialization." : null,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    // Here you will save the doctor to SQLite or any backend
                    final name = _controllerName.text.trim();
                    final seniority = selectedSeniority!;
                    final specialization = selectedSpecialization!;

                    // Insert into SQLite
                    int id = await DatabaseHelper.instance.insertDoctor(
                      Doctor(name: name,
                        seniority: seniority,
                        specialization: specialization,)

                    );


                    _formKey.currentState?.reset();
                    setState(() {
                      _controllerName.clear();
                      selectedSeniority = null;
                      selectedSpecialization = null;
                    });
                  }
                },
                child: const Text("Add Doctor"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controllerName.dispose();
    super.dispose();
  }
}
