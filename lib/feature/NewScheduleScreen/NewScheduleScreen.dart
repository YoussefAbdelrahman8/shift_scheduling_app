import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/feature/ReceptionDataScreen/ReceptionDataScreen.dart';
import 'package:shift_scheduling_app/feature/insertSecSchedules/SectionScheduleScreen.dart';
import 'package:shift_scheduling_app/feature/SectionScheduleListScreen/SectionScheduleListScreen.dart';
import '../../ReceptionOverviewScreen.dart';
import '../../db/DBHelper.dart';
import '../../providers/SchedulingSessionProvider.dart';

import 'package:shift_scheduling_app/providers/SchedulingSessionProvider.dart';

class NewScheduleScreen extends StatefulWidget {
  const NewScheduleScreen({super.key});

  @override
  State<NewScheduleScreen> createState() => _NewScheduleScreenState();
}

class _NewScheduleScreenState extends State<NewScheduleScreen> {
  int _currentStep = 0;
  bool _isLoading = true;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeSession();
    });
  }

  Future<void> _initializeSession() async {
    try {
      final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

      // Get current month or let user select
      _selectedMonth = _getCurrentMonth();

      // Load specializations from database
      final specializations = await DatabaseHelper.instance.getSpecializations();

      // Start the scheduling session
      provider.startSessionWithSpecializations(_selectedMonth!, specializations);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to initialize session: $e');
    }
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _finishProcess() async {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

    try {
      // Save all data to database
      final success = await provider.saveSessionToDatabase();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Schedule saved successfully! ✅")),
        );

        // End the session
        provider.endSession();

        // Navigate back
        Navigator.of(context).pop();
      } else {
        _showError('Failed to save schedule to database');
      }
    } catch (e) {
      _showError('Error saving schedule: $e');
    }
  }

  void _cancelProcess() {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Schedule Creation'),
        content: const Text('Are you sure you want to cancel? All unsaved data will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              provider.cancelSession();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  bool _canProceedToNextStep() {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);
    return provider.canProceedToNextStep();
  }

  void _handleStepContinue() {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

    if (_currentStep < 3) {
      // Check if we can proceed
      if (_canProceedToNextStep()) {
        // Move to next step in both UI and provider
        provider.nextStep();
        setState(() => _currentStep++);
      } else {
        final errors = provider.getValidationErrors();
        _showError(errors.isNotEmpty ? errors.first : 'Cannot proceed to next step');
      }
    } else {
      // Final step - finish the process
      _finishProcess();
    }
  }

  void _handleStepCancel() {
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);

    if (_currentStep > 0) {
      // Move to previous step in both UI and provider
      provider.previousStep();
      setState(() => _currentStep--);
    } else {
      // First step - cancel the entire process
      _cancelProcess();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<SchedulingSessionProvider>(
      builder: (context, provider, child) {
        final steps = [
          Step(
            title: const Text("Section Shifts"),
            content: SectionScheduleScreen(
              onSessionComplete: () {
                if (provider.isAllSpecializationsCompleted) {
                  _handleStepContinue();
                }
              },
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Review Section"),
            content: const PendingSchedulesTable(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Doctor Constraints"),
            content: const ReceptionDataScreen(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Reception Schedule"),
            content: const ReceptionOverviewScreen(),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text("New Schedule - ${provider.currentMonth ?? ''}"),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelProcess,
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress indicator
              if (provider.isSessionActive)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / steps.length,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),

              // Session info
              if (provider.isSessionActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue.withOpacity(0.1),
                  child: Text(
                    'Step ${_currentStep + 1} of ${steps.length} - ${provider.currentStep.toString().split('.').last}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Stepper content
              Expanded(
                child: Stepper(
                  type: StepperType.horizontal,
                  currentStep: _currentStep,
                  onStepContinue: _handleStepContinue,
                  onStepCancel: _handleStepCancel,
                  controlsBuilder: (context, details) {
                    return Row(
                      children: [
                        if (details.onStepCancel != null)
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: Text(_currentStep == 0 ? 'Cancel' : 'Previous'),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == steps.length - 1 ? 'Finish' : 'Next'),
                        ),
                      ],
                    );
                  },
                  steps: steps,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up session if still active
    final provider = Provider.of<SchedulingSessionProvider>(context, listen: false);
    if (provider.isSessionActive) {
      provider.cancelSession();
    }
    super.dispose();
  }
}