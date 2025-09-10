import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/core/routes_manager/routes.dart';

import '../../providers/DoctorProvider.dart';


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
    "Dermatology",
    "Emergency Medicine",
    "Anesthesiology",
    "Radiology",
    "Psychiatry"
  ];
  String? selectedSpecialization;

  @override
  void initState() {
    super.initState();
    // Clear any previous messages when entering the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorProvider>().clearAllMessages();
    });
  }

  Future<void> _addDoctor() async {
    if (_formKey.currentState?.validate() ?? false) {
      final doctorProvider = context.read<DoctorProvider>();

      final success = await doctorProvider.addDoctor(
        name: _controllerName.text.trim(),
        seniority: selectedSeniority!,
        specialization: selectedSpecialization!,
      );

      if (success && mounted) {
        // Clear form after successful addition
        _formKey.currentState?.reset();
        setState(() {
          _controllerName.clear();
          selectedSeniority = null;
          selectedSpecialization = null;
        });

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(doctorProvider.successMessage ?? 'Doctor added successfully'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View All',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/doctors_table');
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DoctorProvider>(
        builder: (context, doctorProvider, child) {
          return Form(
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
                  const SizedBox(height: 10),
                  Text(
                    "Fill in the doctor's information",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (doctorProvider.allDoctors.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics_outlined, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                "Current Statistics",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Total Doctors: ${doctorProvider.allDoctors.length}"),
                          Text("Specializations: ${doctorProvider.availableSpecializations.length}"),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                  // Error Message Display
                  if (doctorProvider.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              doctorProvider.errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => doctorProvider.clearError(),
                            icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // Name Field
                  TextFormField(
                    controller: _controllerName,
                    enabled: !doctorProvider.isLoading,
                    decoration: InputDecoration(
                      labelText: "Doctor's Name",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      helperText: "Enter the full name of the doctor",
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter doctor's name.";
                      }
                      if (value.trim().length < 2) {
                        return "Name must be at least 2 characters.";
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
                      labelText: "Seniority Level",
                      prefixIcon: const Icon(Icons.star_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      helperText: "Select the doctor's experience level",
                    ),
                    onChanged: doctorProvider.isLoading ? null : (value) {
                      setState(() {
                        selectedSeniority = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? "Please select seniority level." : null,
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
                      labelText: "Medical Specialization",
                      prefixIcon: const Icon(Icons.medical_services_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      helperText: "Select the doctor's area of expertise",
                    ),
                    onChanged: doctorProvider.isLoading ? null : (value) {
                      setState(() {
                        selectedSpecialization = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? "Please select specialization." : null,
                  ),

                  const SizedBox(height: 40),

                  // Add Doctor Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: doctorProvider.isLoading ? null : _addDoctor,
                      child: doctorProvider.isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text("Add Doctor"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // View All Doctors Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: doctorProvider.isLoading ? null : () {
                        Navigator.pushNamed(context, Routes.DoctorsTableViewScreenRoute);
                      },
                      icon: const Icon(Icons.list),
                      label: const Text("View All Doctors"),
                    ),
                  ),



                  // Statistics Display

                ],
              ),
            ),
          );
        },
      );
  }

  @override
  void dispose() {
    _controllerName.dispose();
    super.dispose();
  }
}