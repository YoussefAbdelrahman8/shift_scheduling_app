import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../db/database_helper.dart';

class ReceptionDataScreen extends StatefulWidget {
  const ReceptionDataScreen({Key? key}) : super(key: key);

  @override
  State<ReceptionDataScreen> createState() => _ReceptionDataScreenState();
}

class _ReceptionDataScreenState extends State<ReceptionDataScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedDoctorId;
  List<Map<String, dynamic>> _doctors = [];
  final List<String> shifts = ['Morning', 'Evening'];

  final TextEditingController _totalShiftsController = TextEditingController();
  final TextEditingController _morningShiftsController = TextEditingController();
  final TextEditingController _eveningShiftsController = TextEditingController();

  int _remainingShifts = 0;

  // Separate lists for wanted + exception days
  List<Map<String, dynamic>> _wantedEntries = [];
  List<Map<String, dynamic>> _exceptionEntries = [];

  @override
  void initState() {
    super.initState();
    _loadAllDoctors();
    _totalShiftsController.addListener(_updateRemainingShifts);
    _morningShiftsController.addListener(_updateRemainingShifts);
    _eveningShiftsController.addListener(_updateRemainingShifts);
  }

  Future<void> _loadAllDoctors() async {
    _doctors = (await DatabaseHelper.instance.getAllDoctors()).toList();

    final db = await DatabaseHelper.instance.database;
    final existingConstraints = await db.query('reception_constraints');
    final doctorsWithConstraints = existingConstraints.map((e) => e['doctor_id']).toList();

    _doctors.removeWhere((doc) => doctorsWithConstraints.contains(doc['id']));
    setState(() {});
  }

  Future<void> _loadDataForDoctor(int doctorId) async {
    final constraints = await DatabaseHelper.instance.getReceptionConstraints(doctorId);
    if (constraints != null) {
      _totalShiftsController.text = constraints['totalShifts'].toString();
      _morningShiftsController.text = constraints['morningShifts'].toString();
      _eveningShiftsController.text = constraints['eveningShifts'].toString();
    } else {
      _totalShiftsController.clear();
      _morningShiftsController.clear();
      _eveningShiftsController.clear();
    }
    _updateRemainingShifts();

    _wantedEntries.clear();
    _exceptionEntries.clear();
    setState(() {});
  }

  void _addWantedField() {
    setState(() {
      _wantedEntries.add({
        'dateController': TextEditingController(),
        'shift': null,
      });
    });
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

    int calculatedRemaining = total - (morning + evening);
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

      if ((morning + evening) > total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The sum of morning and evening shifts cannot exceed the total shifts.'),
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
      );

      // Save Wanted Days
      for (var wanted in _wantedEntries) {
        final date = (wanted['dateController'] as TextEditingController).text;
        final shift = wanted['shift'];
        if (date.isNotEmpty && shift != null) {
          await DatabaseHelper.instance.insertDoctorRequest(
            doctorId: _selectedDoctorId!,
            date: date,
            shift: shift,
            type: "wanted",
          );
        }
      }

      // Save Exception Days
      for (var exception in _exceptionEntries) {
        final date = (exception['dateController'] as TextEditingController).text;
        final shift = exception['shift'];
        if (date.isNotEmpty && shift != null) {
          await DatabaseHelper.instance.insertDoctorRequest(
            doctorId: _selectedDoctorId!,
            date: date,
            shift: shift,
            type: "exception",
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _doctors.removeWhere((doc) => doc['id'] == _selectedDoctorId);
      _resetForm();
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _totalShiftsController.clear();
    _morningShiftsController.clear();
    _eveningShiftsController.clear();
    _updateRemainingShifts();

    for (var wanted in _wantedEntries) {
      (wanted['dateController'] as TextEditingController).dispose();
    }
    for (var exception in _exceptionEntries) {
      (exception['dateController'] as TextEditingController).dispose();
    }

    setState(() {
      _selectedDoctorId = null;
      _wantedEntries = [];
      _exceptionEntries = [];
    });
  }

  @override
  void dispose() {
    _totalShiftsController.dispose();
    _morningShiftsController.dispose();
    _eveningShiftsController.dispose();
    for (var wanted in _wantedEntries) {
      (wanted['dateController'] as TextEditingController).dispose();
    }
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
                      if (val != null) _loadDataForDoctor(val);
                    });
                  },
                  validator: (val) => val == null ? 'Please select a doctor' : null,
                ),
                const SizedBox(height: 30),

                if (_selectedDoctorId != null) ...[
                  _buildConstraintsCard(),
                  const SizedBox(height: 30),
                  _buildRequestCard("Doctor Wanted Days", _wantedEntries, _addWantedField),
                  const SizedBox(height: 30),
                  _buildRequestCard("Doctor Exception Days", _exceptionEntries, _addExceptionField),
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

  Widget _buildConstraintsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Reception Constraints", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildNumberField('Total Shifts', _totalShiftsController),
            _buildNumberField('Morning Shifts', _morningShiftsController),
            _buildNumberField('Evening Shifts', _eveningShiftsController),
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
    );
  }

  Widget _buildRequestCard(String title, List<Map<String, dynamic>> entries, VoidCallback onAdd) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ..._buildRequestWidgets(entries),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text('Add ${title.split(" ").last}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
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
          if (val == null || val.isEmpty) return 'Please enter a value';
          if (int.tryParse(val) == null) return 'Please enter a valid number';
          return null;
        },
      ),
    );
  }

  List<Widget> _buildRequestWidgets(List<Map<String, dynamic>> entries) {
    return entries.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> requestData = entry.value;
      TextEditingController dateController = requestData['dateController'];

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
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Shift #${index + 1}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                value: requestData['shift'],
                items: shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  setState(() {
                    entries[index]['shift'] = val;
                  });
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  dateController.dispose();
                  entries.removeAt(index);
                });
              },
            ),
          ],
        ),
      );
    }).toList();
  }
}
