import 'package:flutter/material.dart';
import '../../../../db/database_helper.dart';

class SectionScheduleScreen extends StatefulWidget {
  const SectionScheduleScreen({Key? key}) : super(key: key);

  @override
  State<SectionScheduleScreen> createState() => _SectionSchedulePageState();
}

class _SectionSchedulePageState extends State<SectionScheduleScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSpecialization;
  int? _selectedDoctorId;
  final List<String> shifts = ['Morning', 'Evening', 'Full Day'];

  List<String> specializations = [];
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> shiftsToAdd = [];

  @override
  void initState() {
    super.initState();
    _loadSpecializations();
    _addShiftField(); // Start with one shift field by default
  }

  Future<void> _loadSpecializations() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT DISTINCT specialization FROM doctor');
    specializations = result.map((row) => row['specialization'] as String).toList();
    setState(() {});
  }

  Future<void> _loadDoctorsBySpecialization(String specialization) async {
    doctors = await DatabaseHelper.instance.getDoctorsBySpecialization(specialization);
    setState(() {
      _selectedDoctorId = null;
    });
  }

  void _addShiftField() {
    setState(() {
      shiftsToAdd.add({
        'dateController': TextEditingController(),
        'shift': null,
      });
    });
  }

  Future<void> _saveAllSchedules() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDoctorId != null && shiftsToAdd.isNotEmpty) {
        bool allShiftsValid = true;
        for (var shift in shiftsToAdd) {
          if ((shift['dateController'] as TextEditingController).text.isEmpty || shift['shift'] == null) {
            allShiftsValid = false;
            break;
          }
        }

        if (allShiftsValid) {
          try {
            for (var shift in shiftsToAdd) {
              await DatabaseHelper.instance.insertSectionSchedule(
                doctorId: _selectedDoctorId!,
                date: (shift['dateController'] as TextEditingController).text,
                shift: shift['shift']!,
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All shifts saved successfully!')),
            );
            _resetForm();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save shifts: $e')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill all date and shift fields.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a doctor and add at least one shift.')),
        );
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (var shift in shiftsToAdd) {
      (shift['dateController'] as TextEditingController).dispose();
    }
    setState(() {
      _selectedSpecialization = null;
      _selectedDoctorId = null;
      shiftsToAdd = [];
    });
    _addShiftField();
  }

  @override
  void dispose() {
    for (var shift in shiftsToAdd) {
      (shift['dateController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Section Schedule')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Specialization',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  value: _selectedSpecialization,
                  items: specializations.map((spec) {
                    return DropdownMenuItem<String>(
                      value: spec,
                      child: Text(spec),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSpecialization = val;
                      _loadDoctorsBySpecialization(val!);
                    });
                  },
                  validator: (val) => val == null ? 'Please select a specialization' : null,
                ),
                const SizedBox(height: 20),
                if (_selectedSpecialization != null)
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Select Doctor',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    value: _selectedDoctorId,
                    items: doctors.map((doc) {
                      return DropdownMenuItem<int>(
                        value: doc['id'] as int,
                        child: Text(doc['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDoctorId = val;
                      });
                    },
                    validator: (val) => val == null ? 'Please select a doctor' : null,
                  ),
                const SizedBox(height: 20),
                if (_selectedDoctorId != null) ..._buildShiftWidgets(),
                const SizedBox(height: 20),
                if (_selectedDoctorId != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addShiftField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Shift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveAllSchedules,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Save Schedules',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildShiftWidgets() {
    return shiftsToAdd.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> shiftData = entry.value;
      TextEditingController dateController = shiftData['dateController'];

      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: dateController,
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    dateController.text = picked.toIso8601String().split('T').first;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Shift Date #${index + 1}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Shift #${index + 1}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                value: shiftData['shift'],
                items: shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  setState(() {
                    shiftsToAdd[index]['shift'] = val;
                  });
                },
                validator: (val) => val == null ? 'Required' : null,
              ),
            ),
            if (shiftsToAdd.length > 1)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    dateController.dispose();
                    shiftsToAdd.removeAt(index);
                  });
                },
              ),
          ],
        ),
      );
    }).toList();
  }
}