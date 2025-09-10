import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../core/models/Doctor.dart';
import '../../providers/DoctorConstraintProvider.dart';

class ReceptionDataScreen extends StatefulWidget {
  final VoidCallback? onConstraintsComplete;
  final VoidCallback? onReviewComplete;

  const ReceptionDataScreen({
    Key? key,
    this.onConstraintsComplete,
    this.onReviewComplete,
  }) : super(key: key);

  @override
  State<ReceptionDataScreen> createState() => _ReceptionDataScreenState();
}

class _ReceptionDataScreenState extends State<ReceptionDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalShiftsController = TextEditingController();
  final _morningShiftsController = TextEditingController();
  final _eveningShiftsController = TextEditingController();

  // Drop configuration controllers
  final _dropCountController = TextEditingController();
  int? _selectedDropTargetDoctor;
  String? _selectedDropShiftType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorConstraintProvider>().initializeForSession();
    });

    // Add listener to handle automatic navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorConstraintProvider>().addListener(_handleProviderChanges);
    });
  }

  void _handleProviderChanges() {
    final provider = context.read<DoctorConstraintProvider>();

    // If we just completed a doctor and they have a success message about auto-completion
    if (provider.currentStage == ConstraintEntryStage.selectDoctor &&
        provider.successMessage?.contains('auto-completed') == true) {
      // Show a snackbar to inform user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor completed - all shifts dropped!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    context.read<DoctorConstraintProvider>().removeListener(_handleProviderChanges);
    _totalShiftsController.dispose();
    _morningShiftsController.dispose();
    _eveningShiftsController.dispose();
    _dropCountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, Function(String) onDateSelected) async {
    final provider = context.read<DoctorConstraintProvider>();
    final currentMonth = provider.currentMonth;

    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime.now();
    DateTime lastDate = DateTime.now();

    if (currentMonth != null) {
      final year = int.parse(currentMonth.substring(0, 4));
      final month = int.parse(currentMonth.substring(5, 7));
      firstDate = DateTime(year, month, 1);
      lastDate = DateTime(year, month + 1, 0);

      if (DateTime.now().isBefore(firstDate) || DateTime.now().isAfter(lastDate)) {
        initialDate = firstDate;
      }
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select date for ${currentMonth ?? 'current month'}',
    );

    if (picked != null) {
      onDateSelected(picked.toIso8601String().split('T').first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DoctorConstraintProvider>(
      builder: (context, provider, child) {
        if (!provider.isSessionActive) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active session. Please start a session first.'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(provider),
              const SizedBox(height: 20),

              // Error/Success Messages
              if (provider.errorMessage != null) _buildErrorMessage(provider),
              if (provider.successMessage != null) _buildSuccessMessage(provider),

              // Loading Indicator
              if (provider.isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 16),

              // Stage-based Content
              _buildStageContent(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(DoctorConstraintProvider provider) {
    final stats = provider.getConstraintStatistics();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[600]!, Colors.teal[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reception Shift Constraints',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.currentMonth != null
                ? 'Month: ${provider.currentMonth}'
                : 'No active session',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure reception scheduling constraints for each doctor',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip('Completed', '${stats['doctorsWithConstraints']}', Colors.green),
              const SizedBox(width: 12),
              _buildStatChip('Remaining', '${stats['doctorsNeedingConstraints']}', Colors.orange),
              const SizedBox(width: 12),
              _buildStatChip('Progress', '${stats['completionPercentage']}%', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(DoctorConstraintProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(provider.errorMessage!)),
          IconButton(
            onPressed: provider.clearError,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(DoctorConstraintProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(provider.successMessage!)),
          IconButton(
            onPressed: provider.clearSuccess,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent(DoctorConstraintProvider provider) {
    switch (provider.currentStage) {
      case ConstraintEntryStage.selectDoctor:
        return _buildDoctorSelection(provider);
      case ConstraintEntryStage.basicConstraints:
        return _buildBasicConstraints(provider);
      case ConstraintEntryStage.dropDecision:
        return _buildDropDecision(provider);
      case ConstraintEntryStage.dropConfiguration:
        return _buildDropConfiguration(provider);
      case ConstraintEntryStage.preferences:
        return _buildPreferences(provider);
      case ConstraintEntryStage.wantedDays:
        return _buildWantedDays(provider);
      case ConstraintEntryStage.exceptionDays:
        return _buildExceptionDays(provider);
      case ConstraintEntryStage.completed:
        return _buildCompleted(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDoctorSelection(DoctorConstraintProvider provider) {
    final allDoctors = provider.allDoctors;
    final completedDoctors = provider.getDoctorsWithCompletedConstraints();
    final completedDoctorIds = completedDoctors.map((d) => d.id).toSet();

    // Available doctors are those who haven't completed constraints yet
    final availableDoctors = allDoctors.where((doctor) =>
    !completedDoctorIds.contains(doctor.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Doctor for Reception Constraints',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a doctor to configure their reception shift constraints.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 20),

        if (availableDoctors.isEmpty)
          _buildEmptyState(
            'All doctors have completed their reception constraints!',
            'Ready to proceed to the next step.',
            Icons.check_circle,
            Colors.green,
          )
        else ...[
          // Doctor Selection Dropdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Doctors',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Select Doctor',
                      helperText: '${availableDoctors.length} doctors available for configuration',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    isExpanded: true,
                    value: null,
                    items: availableDoctors.map((doctor) {
                      return DropdownMenuItem<int>(
                        value: doctor.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${doctor.specialization} • ${doctor.seniority}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        provider.selectDoctor(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Completed doctors summary
          if (completedDoctors.isNotEmpty)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Completed Doctors (${completedDoctors.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: completedDoctors.map((doctor) => Chip(
                        label: Text(
                          doctor.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.green.shade100,
                        side: BorderSide(color: Colors.green.shade300),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildBasicConstraints(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);

    // Sync controllers with provider
    if (_totalShiftsController.text != provider.totalShifts.toString()) {
      _totalShiftsController.text = provider.totalShifts.toString();
    }
    if (_morningShiftsController.text != provider.morningShifts.toString()) {
      _morningShiftsController.text = provider.morningShifts.toString();
    }
    if (_eveningShiftsController.text != provider.eveningShifts.toString()) {
      _eveningShiftsController.text = provider.eveningShifts.toString();
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageHeader(
              'Reception Shift Configuration',
              'Set reception shift numbers for ${doctor.name}'
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor Info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Text(
                          doctor.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${doctor.specialization} • ${doctor.seniority}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Reception Shift Configuration',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the number of reception shifts you want this doctor to work. This is separate from section shifts.',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildNumberField(
                    'Total Reception Shifts',
                    _totalShiftsController,
                    'Total number of reception shifts for this doctor',
                        (value) => provider.setTotalShifts(int.tryParse(value) ?? 0),
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    'Morning Reception Shifts',
                    _morningShiftsController,
                    'Number of morning reception shifts',
                        (value) => provider.setMorningShifts(int.tryParse(value) ?? 0),
                  ),
                  const SizedBox(height: 16),

                  _buildNumberField(
                    'Evening Reception Shifts',
                    _eveningShiftsController,
                    'Number of evening reception shifts',
                        (value) => provider.setEveningShifts(int.tryParse(value) ?? 0),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: provider.remainingShifts < 0 ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: provider.remainingShifts < 0 ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          provider.remainingShifts < 0 ? Icons.error : Icons.check_circle,
                          color: provider.remainingShifts < 0 ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unassigned Shifts: ${provider.remainingShifts}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: provider.remainingShifts < 0 ? Colors.red : Colors.green,
                                ),
                              ),
                              Text(
                                provider.remainingShifts < 0
                                    ? 'You have assigned more shifts than the total!'
                                    : provider.remainingShifts == 0
                                    ? 'All shifts are properly assigned'
                                    : 'These shifts can be assigned as needed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: provider.remainingShifts < 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _buildNavigationButtons(
            onBack: () => provider.goToPreviousStage(),
            onNext: provider.canProceedFromBasicConstraints
                ? () => provider.proceedToDropDecision()
                : null,
            nextLabel: 'Next: Drop Options',
          ),
        ],
      ),
    );
  }

  Widget _buildDropDecision(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader('Drop Options', 'Transfer reception shifts to other doctors?'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Reception Shifts:'),
                          Text(
                            '${provider.totalShifts}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Morning Shifts:'),
                          Text(
                            '${provider.morningShifts}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Evening Shifts:'),
                          Text(
                            '${provider.eveningShifts}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Would you like to drop any reception shifts to other doctors?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If you drop ALL shifts, this doctor won\'t need further constraint configuration.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => provider.skipDropConfiguration(),
                icon: const Icon(Icons.skip_next),
                label: const Text('No Drops'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => provider.chooseToConfigureDrops(),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Configure Drops'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        _buildNavigationButtons(
          onBack: () => provider.goToPreviousStage(),
          showNext: false,
        ),
      ],
    );
  }

  Widget _buildDropConfiguration(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);
    final availableDoctors = provider.allDoctors.where((d) => d.id != provider.currentDoctorId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader('Configure Drops', 'Transfer reception shifts to other doctors'),

        // Current shifts summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dropping from: ${doctor.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Available Morning Reception Shifts: ${provider.morningShifts}'),
                Text('Available Evening Reception Shifts: ${provider.eveningShifts}'),
                Text('Total Available Reception Shifts: ${provider.totalShifts}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Drop configuration form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Drop',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: _selectedDropTargetDoctor,
                  decoration: const InputDecoration(
                    labelText: 'Drop to Doctor',
                    border: OutlineInputBorder(),
                  ),
                  items: availableDoctors.map((d) => DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.name} (${d.specialization})'),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedDropTargetDoctor = value),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDropShiftType,
                        decoration: const InputDecoration(
                          labelText: 'Shift Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                          DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                        ],
                        onChanged: (value) => setState(() => _selectedDropShiftType = value),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _dropCountController,
                        decoration: const InputDecoration(
                          labelText: 'Count',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_selectedDropTargetDoctor != null &&
                        _selectedDropShiftType != null &&
                        _dropCountController.text.isNotEmpty)
                        ? () {
                      provider.addDrop(
                        toDoctorId: _selectedDropTargetDoctor!,
                        shiftType: _selectedDropShiftType!,
                        count: int.tryParse(_dropCountController.text) ?? 1,
                      );
                      setState(() {
                        _selectedDropTargetDoctor = null;
                        _selectedDropShiftType = null;
                        _dropCountController.clear();
                      });
                    }
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Drop'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Pending drops list
        if (provider.pendingDrops.isNotEmpty) ...[
          const Text(
            'Pending Drops',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.pendingDrops.length,
              itemBuilder: (context, index) {
                final drop = provider.pendingDrops[index];
                final targetDoctor = provider.allDoctors.firstWhere((d) => d.id == drop['toDoctorId']);

                return ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text('${drop['shift']} reception shift to ${targetDoctor.name}'),
                  subtitle: Text(targetDoctor.specialization ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => provider.removePendingDrop(index),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Information about final shifts
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Result:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Final reception shifts for ${doctor.name}: ${provider.finalShiftsForCurrentDoctor}'),
              if (provider.willDropAllShifts)
                const Text(
                  'You will drop ALL reception shifts - constraint entry will be auto-completed!',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildNavigationButtons(
          onBack: () => provider.goToPreviousStage(),
          onNext: provider.hasValidDropConfiguration
              ? () => provider.applyDropsAndProceed()
              : null,
          nextLabel: 'Apply Drops',
        ),
      ],
    );
  }

  Widget _buildPreferences(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader('Reception Preferences', 'Configure reception scheduling preferences for ${doctor.name}'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Reception Shifts: ${provider.finalShiftsForCurrentDoctor}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Reception Scheduling Preferences',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _buildSwitchTile(
                  'Consider Seniority',
                  'Prioritize based on doctor seniority level',
                  provider.seniority,
                  provider.setSeniority,
                ),
                _buildSwitchTile(
                  'Enforce Wanted Days',
                  'Must schedule on preferred days',
                  provider.enforceWanted,
                  provider.setEnforceWanted,
                ),
                _buildSwitchTile(
                  'Enforce Exception Days',
                  'Must avoid exception days',
                  provider.enforceExceptions,
                  provider.setEnforceExceptions,
                ),
                _buildSwitchTile(
                  'Avoid Weekends',
                  'Prefer weekday scheduling',
                  provider.avoidWeekends,
                  provider.setAvoidWeekends,
                ),
                _buildSwitchTile(
                  'Enforce Avoid Weekends',
                  'Strictly avoid weekend shifts',
                  provider.enforceAvoidWeekends,
                  provider.setEnforceAvoidWeekends,
                ),
                _buildSwitchTile(
                  'First Week Days Preference',
                  'Prefer early week days',
                  provider.firstWeekDaysPreference,
                  provider.setFirstWeekDaysPreference,
                ),
                _buildSwitchTile(
                  'Last Week Days Preference',
                  'Prefer late week days',
                  provider.lastWeekDaysPreference,
                  provider.setLastWeekDaysPreference,
                ),
                _buildSwitchTile(
                  'First Month Days Preference',
                  'Prefer early month days',
                  provider.firstMonthDaysPreference,
                  provider.setFirstMonthDaysPreference,
                ),
                _buildSwitchTile(
                  'Last Month Days Preference',
                  'Prefer late month days',
                  provider.lastMonthDaysPreference,
                  provider.setLastMonthDaysPreference,
                ),
                _buildSwitchTile(
                  'Avoid Consecutive Days',
                  'Avoid back-to-back shifts',
                  provider.avoidConsecutiveDays,
                  provider.setAvoidConsecutiveDays,
                ),

                const SizedBox(height: 16),
                Text(
                  'Priority Level (0-5)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: provider.priority.toDouble(),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: provider.priority.toString(),
                        onChanged: (value) => provider.setPriority(value.round()),
                      ),
                    ),
                    Container(
                      width: 40,
                      child: Text(
                        provider.priority.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildNavigationButtons(
          onBack: () => provider.goToPreviousStage(),
          onNext: () => provider.proceedToWantedDays(),
          nextLabel: 'Next: Wanted Days',
        ),
      ],
    );
  }

  Widget _buildWantedDays(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader('Wanted Days', 'Specify preferred reception working days for ${doctor.name}'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Reception Working Days',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add specific dates when this doctor prefers to work reception shifts.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                if (provider.wantedDays.isNotEmpty) ...[
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.wantedDays.length,
                    itemBuilder: (context, index) {
                      final request = provider.wantedDays[index];
                      return ListTile(
                        leading: Icon(
                          request.shift == 'Morning' ? Icons.wb_sunny : Icons.nights_stay,
                          color: request.shift == 'Morning' ? Colors.orange : Colors.indigo,
                        ),
                        title: Text(request.date),
                        subtitle: Text('${request.shift} Reception Shift'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => provider.removeWantedDay(index),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddWantedDayDialog(provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Wanted Day'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildNavigationButtons(
          onBack: () => provider.goToPreviousStage(),
          onNext: () => provider.proceedToExceptionDays(),
          nextLabel: 'Next: Exception Days',
        ),
      ],
    );
  }

  Widget _buildExceptionDays(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader('Exception Days', 'Specify reception days to avoid for ${doctor.name}'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reception Days to Avoid',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add specific dates when this doctor cannot work reception shifts.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                if (provider.exceptionDays.isNotEmpty) ...[
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.exceptionDays.length,
                    itemBuilder: (context, index) {
                      final request = provider.exceptionDays[index];
                      return ListTile(
                        leading: Icon(
                          request.shift == 'Morning' ? Icons.wb_sunny : Icons.nights_stay,
                          color: Colors.red,
                        ),
                        title: Text(request.date),
                        subtitle: Text('${request.shift} Reception Shift'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => provider.removeExceptionDay(index),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddExceptionDayDialog(provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exception Day'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildNavigationButtons(
          onBack: () => provider.goToPreviousStage(),
          onNext: () => provider.completeConstraintsForCurrentDoctor(),
          nextLabel: 'Save Constraints',
        ),
      ],
    );
  }

  Widget _buildCompleted(DoctorConstraintProvider provider) {
    final doctor = provider.allDoctors.firstWhere((d) => d.id == provider.currentDoctorId);

    // Auto-navigate back to doctor selection after a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          provider.resetCurrentForm();
        }
      });
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader('Completed', 'Reception constraints saved for ${doctor.name}'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'Reception constraints saved successfully for ${doctor.name}!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Final reception shifts: ${provider.finalShiftsForCurrentDoctor}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Returning to doctor selection...',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => provider.resetCurrentForm(),
            icon: const Icon(Icons.person_add),
            label: const Text('Configure Another Doctor'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumberField(
      String label,
      TextEditingController controller,
      String helper,
      Function(String) onChanged,
      ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a value';
        if (int.tryParse(value) == null) return 'Please enter a valid number';
        return null;
      },
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildNavigationButtons({
    VoidCallback? onBack,
    VoidCallback? onNext,
    String nextLabel = 'Next',
    bool showNext = true,
  }) {
    return Row(
      children: [
        if (onBack != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

        if (onBack != null && showNext) const SizedBox(width: 16),

        if (showNext)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              label: Text(nextLabel),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddWantedDayDialog(DoctorConstraintProvider provider) {
    String? selectedDate;
    String? selectedShift;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Wanted Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(selectedDate ?? 'Select Date'),
                leading: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, (date) {
                  setState(() => selectedDate = date);
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Shift Type',
                  border: OutlineInputBorder(),
                ),
                value: selectedShift,
                items: const [
                  DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                  DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                ],
                onChanged: (value) => setState(() => selectedShift = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedDate != null && selectedShift != null)
                  ? () {
                provider.addWantedDay(selectedDate!, selectedShift!);
                Navigator.pop(context);
              }
                  : null,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExceptionDayDialog(DoctorConstraintProvider provider) {
    String? selectedDate;
    String? selectedShift;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Exception Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(selectedDate ?? 'Select Date'),
                leading: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, (date) {
                  setState(() => selectedDate = date);
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Shift Type',
                  border: OutlineInputBorder(),
                ),
                value: selectedShift,
                items: const [
                  DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                  DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                ],
                onChanged: (value) => setState(() => selectedShift = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedDate != null && selectedShift != null)
                  ? () {
                provider.addExceptionDay(selectedDate!, selectedShift!);
                Navigator.pop(context);
              }
                  : null,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}