import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/core/models/Doctor.dart';
import 'package:shift_scheduling_app/providers/SchedulingSessionProvider.dart';
import '../../db/DBHelper.dart';


class SectionScheduleScreen extends StatefulWidget {
  final VoidCallback? onSessionComplete;
  const SectionScheduleScreen({Key? key, this.onSessionComplete}) : super(key: key);

  @override
  State<SectionScheduleScreen> createState() => _SectionScheduleScreenState();
}

class _SectionScheduleScreenState extends State<SectionScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  List<TextEditingController> dateControllers = [];

  @override
  void initState() {
    super.initState();
    _addDateField();
  }

  Future<void> _loadDoctorsBySpecialization(
      BuildContext context, String specialization) async {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

    try {
      final doctors = await DatabaseHelper.instance.getDoctorsBySpecialization(specialization);
      provider.addDoctorsForSpecialization(doctors.cast<Doctor>());
    } catch (e) {
      _showError('Failed to load doctors: $e');
    }
  }

  void _addDateField() {
    setState(() {
      dateControllers.add(TextEditingController());
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveAllSchedules(BuildContext context) async {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

    if (_formKey.currentState?.validate() ?? false) {
      if (provider.selectedDoctorId != null && dateControllers.isNotEmpty) {
        bool allDatesValid = dateControllers.every((c) => c.text.isNotEmpty);

        if (allDatesValid) {
          try {
            // Collect all dates
            List<String> dates = dateControllers
                .map((controller) => controller.text)
                .where((date) => date.isNotEmpty)
                .toList();

            if (dates.isEmpty) {
              _showError('Please add at least one date.');
              return;
            }

            // Add section shifts for selected doctor
            provider.addSectionShiftsForSelectedDoctor(dates);

            // Reset date controllers
            for (var c in dateControllers) {
              c.dispose();
            }
            dateControllers = [];
            _addDateField();

            _showSuccess('Section shifts added successfully!');

            // Check if all specializations are completed
            if (provider.isAllSpecializationsCompleted && widget.onSessionComplete != null) {
              widget.onSessionComplete!();
            }

          } catch (e) {
            _showError('Failed to save schedules: $e');
          }
        } else {
          _showError('Please fill all date fields.');
        }
      } else {
        _showError('Please select a doctor and add at least one date.');
      }
    }
  }

  @override
  void dispose() {
    for (var controller in dateControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SchedulingSessionProvider>(
      builder: (context, provider, _) {
        // Check if session is active
        if (!provider.isSessionActive) {
          return const Center(
            child: Text('No active session. Please start a new schedule.'),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Creating Schedule for: ${provider.currentMonth}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Specializations remaining: ${provider.specializations.length}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Section shifts added: ${provider.sectionShifts.length}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  /// Specialization Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Specialization',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    value: provider.selectedSpecialization,
                    items: provider.specializations.map((spec) {
                      return DropdownMenuItem<String>(
                        value: spec,
                        child: Text(spec),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        await provider.setSelectedSpecialization(val);
                        await _loadDoctorsBySpecialization(context, val);
                      }
                    },
                    validator: (val) =>
                    val == null ? 'Please select a specialization' : null,
                  ),
                  const SizedBox(height: 20),

                  /// Doctor Dropdown
                  if (provider.selectedSpecialization != null)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Doctor',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      value: provider.selectedDoctorId,
                      items: provider.doctorsForSelectedSpecialization.map((doctor) {
                        return DropdownMenuItem<int>(
                          value: doctor.id,
                          child: Text(doctor.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        provider.setSelectedDoctorId(val);
                      },
                      validator: (val) =>
                      val == null ? 'Please select a doctor' : null,
                    ),
                  const SizedBox(height: 20),

                  /// Date fields
                  if (provider.selectedDoctorId != null) ..._buildDateFields(),

                  const SizedBox(height: 20),

                  /// Add another date button
                  if (provider.selectedDoctorId != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addDateField,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Date'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  /// Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: provider.selectedDoctorId != null
                          ? () => _saveAllSchedules(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: const Text(
                        'Save Section Shifts',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Progress indicator
                  if (provider.specializations.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remaining Specializations:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: provider.specializations.map((spec) {
                              final isSelected = spec == provider.selectedSpecialization;
                              return Chip(
                                label: Text(spec),
                                backgroundColor: isSelected
                                    ? Colors.blue
                                    : Colors.grey[200],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDateFields() {
    return dateControllers.asMap().entries.map((entry) {
      int index = entry.key;
      TextEditingController controller = entry.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    controller.text =
                        picked.toIso8601String().split('T').first;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Date #${index + 1}',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'Required' : null,
              ),
            ),
            if (dateControllers.length > 1)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    controller.dispose();
                    dateControllers.removeAt(index);
                  });
                },
              ),
          ],
        ),
      );
    }).toList();
  }
}