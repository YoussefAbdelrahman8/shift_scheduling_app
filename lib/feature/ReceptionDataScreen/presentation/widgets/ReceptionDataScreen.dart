import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../db/database_helper.dart';

class ReceptionDataScreen extends StatefulWidget {
  const ReceptionDataScreen({Key? key}) : super(key: key);

  @override
  State<ReceptionDataScreen> createState() => _ReceptionDataScreenState();
}

class _ReceptionDataScreenState extends State<ReceptionDataScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedDoctorId;
  List<Map<String, dynamic>> _doctors = [];
  final List<String> shifts = ['Morning', 'Evening', 'Full Day'];

  final TextEditingController _totalShiftsController = TextEditingController();
  final TextEditingController _morningShiftsController = TextEditingController();
  final TextEditingController _eveningShiftsController = TextEditingController();
  final TextEditingController _fullTimeShiftsController = TextEditingController();

  List<Map<String, dynamic>> _exceptionEntries = [];
  int _remainingShifts = 0;

  @override
  void initState() {
    super.initState();
    _loadAllDoctors();
    _addExceptionField(); // Start with one exception field
    _totalShiftsController.addListener(_updateRemainingShifts);
    _morningShiftsController.addListener(_updateRemainingShifts);
    _eveningShiftsController.addListener(_updateRemainingShifts);
    _fullTimeShiftsController.addListener(_updateRemainingShifts);
  }

  Future<void> _loadAllDoctors() async {
    // Fetch all doctors from the database and create a mutable list
    _doctors = (await DatabaseHelper.instance.getAllDoctors()).toList();

    // Fetch all doctors with existing constraints to filter them out
    final db = await DatabaseHelper.instance.database;
    final existingConstraints = await db.query('reception_constraints');
    final doctorsWithConstraints = existingConstraints.map((e) => e['doctor_id']).toList();

    // Remove doctors who already have constraints from the mutable list
    _doctors.removeWhere((doc) => doctorsWithConstraints.contains(doc['id']));

    setState(() {});
  }

  Future<void> _loadDataForDoctor(int doctorId) async {
    final constraints = await DatabaseHelper.instance.getReceptionConstraints(doctorId);
    if (constraints != null) {
      _totalShiftsController.text = constraints['totalShifts'].toString();
      _morningShiftsController.text = constraints['morningShifts'].toString();
      _eveningShiftsController.text = constraints['eveningShifts'].toString();
      _fullTimeShiftsController.text = constraints['fullTimeShifts'].toString();
    } else {
      _totalShiftsController.clear();
      _morningShiftsController.clear();
      _eveningShiftsController.clear();
      _fullTimeShiftsController.clear();
    }
    _updateRemainingShifts();
    _exceptionEntries.clear();
    _addExceptionField();
    setState(() {});
  }

  void _addExceptionField() {
    setState(() {
      _exceptionEntries.add({
        'dateController': TextEditingController(),
        'shift': null,
      });
    });
  }

  void _updateRemainingShifts() {
    final int total = int.tryParse(_totalShiftsController.text) ?? 0;
    final int morning = int.tryParse(_morningShiftsController.text) ?? 0;
    final int evening = int.tryParse(_eveningShiftsController.text) ?? 0;
    final int fullTime = int.tryParse(_fullTimeShiftsController.text) ?? 0;

    int calculatedRemaining = total - (morning + evening + fullTime);
    setState(() {
      _remainingShifts = calculatedRemaining;
    });
  }

  Future<void> _saveAllData() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDoctorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a doctor.')),
        );
        return;
      }

      final int total = int.tryParse(_totalShiftsController.text) ?? 0;
      final int morning = int.tryParse(_morningShiftsController.text) ?? 0;
      final int evening = int.tryParse(_eveningShiftsController.text) ?? 0;
      final int fullTime = int.tryParse(_fullTimeShiftsController.text) ?? 0;

      if ((morning + evening + fullTime) > total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The sum of morning, evening, and full-time shifts cannot exceed the total shifts.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save Constraints
      await DatabaseHelper.instance.insertOrUpdateReceptionConstraints(
        doctorId: _selectedDoctorId!,
        totalShifts: total,
        morningShifts: morning,
        eveningShifts: evening,
        fullTimeShifts: fullTime,
      );

      // Save Exceptions
      for (var exception in _exceptionEntries) {
        if ((exception['dateController'] as TextEditingController).text.isNotEmpty && exception['shift'] != null) {
          await DatabaseHelper.instance.insertDoctorExceptionDay(
            doctorId: _selectedDoctorId!,
            date: (exception['dateController'] as TextEditingController).text,
            shift: exception['shift']!,
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Remove the doctor from the list of available doctors
      _doctors.removeWhere((doc) => doc['id'] == _selectedDoctorId);

      _resetForm();
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _totalShiftsController.clear();
    _morningShiftsController.clear();
    _eveningShiftsController.clear();
    _fullTimeShiftsController.clear();
    _updateRemainingShifts();
    for (var exception in _exceptionEntries) {
      (exception['dateController'] as TextEditingController).dispose();
    }
    setState(() {
      _selectedDoctorId = null;
      _exceptionEntries = [];
    });
    _addExceptionField();
  }

  @override
  void dispose() {
    _totalShiftsController.removeListener(_updateRemainingShifts);
    _morningShiftsController.removeListener(_updateRemainingShifts);
    _eveningShiftsController.removeListener(_updateRemainingShifts);
    _fullTimeShiftsController.removeListener(_updateRemainingShifts);
    _totalShiftsController.dispose();
    _morningShiftsController.dispose();
    _eveningShiftsController.dispose();
    _fullTimeShiftsController.dispose();
    for (var exception in _exceptionEntries) {
      (exception['dateController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reception Schedule Data'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Select Doctor',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  value: _selectedDoctorId,
                  items: _doctors.map((doc) {
                    return DropdownMenuItem<int>(
                      value: doc['id'] as int,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDoctorId = val;
                      if (val != null) {
                        _loadDataForDoctor(val);
                      }
                    });
                  },
                  validator: (val) => val == null ? 'Please select a doctor' : null,
                ),
                const SizedBox(height: 30),
                if (_selectedDoctorId != null) ...[
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reception Constraints',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          _buildNumberField('Total Shifts', _totalShiftsController),
                          _buildNumberField('Morning Shifts', _morningShiftsController),
                          _buildNumberField('Evening Shifts', _eveningShiftsController),
                          _buildNumberField('Full-time Shifts', _fullTimeShiftsController),
                          const SizedBox(height: 10),
                          Text(
                            'Remaining Shifts: $_remainingShifts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _remainingShifts < 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Doctor Exceptions',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          ..._buildExceptionWidgets(),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addExceptionField,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Exception Day'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAllData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Save All Data', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Please enter a value';
          }
          if (int.tryParse(val) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  List<Widget> _buildExceptionWidgets() {
    return _exceptionEntries.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> exceptionData = entry.value;
      TextEditingController dateController = exceptionData['dateController'];

      return Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
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
                  labelText: 'Date #${index + 1}',
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
                value: exceptionData['shift'],
                items: shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  setState(() {
                    _exceptionEntries[index]['shift'] = val;
                  });
                },
                validator: (val) => val == null ? 'Required' : null,
              ),
            ),
            if (_exceptionEntries.length > 1)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    dateController.dispose();
                    _exceptionEntries.removeAt(index);
                  });
                },
              ),
          ],
        ),
      );
    }).toList();
  }
}