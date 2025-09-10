import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/feature/ReceptionDataScreen/ReceptionDataScreen.dart';
import 'package:shift_scheduling_app/feature/SectionScheduleListScreen/SectionScheduleListScreen.dart';
import '../../ReceptionOverviewScreen.dart';
import '../../providers/SchedulingSessionProvider.dart';
import '../insertSecSchedules/SectionScheduleScreen.dart';


class NewScheduleScreen extends StatefulWidget {
  const NewScheduleScreen({super.key});

  @override
  State<NewScheduleScreen> createState() => _NewScheduleScreenState();
}

class _NewScheduleScreenState extends State<NewScheduleScreen> {
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
      final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

      // Get current month or let user select
      _selectedMonth = _getCurrentMonth();

      // Start the scheduling session (this will load specializations automatically)
      final success = await provider.startSession(_selectedMonth!);

      if (!success) {
        _showError(provider.errorMessage ?? 'Failed to start session');
        Navigator.pop(context);
        return;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to initialize session: $e');
      Navigator.pop(context);
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _finishProcess() async {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    try {
      // Complete the session
      await provider.completeSession();

      _showSuccess("Schedule created successfully!");

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      _showError('Error completing schedule: $e');
    }
  }

  void _cancelProcess() {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Schedule Creation'),
        content: const Text('Are you sure you want to cancel? All progress will be lost.'),
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

  void _handleStepTap(int stepIndex) {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
    provider.goToStep(stepIndex);
  }

  void _handleStepContinue() {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    if (provider.canGoToNextStep) {
      provider.goToNextStep();
    } else {
      // Last step - finish the process
      _finishProcess();
    }
  }

  void _handleStepCancel() {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    if (provider.canGoToPreviousStep) {
      provider.goToPreviousStep();
    } else {
      // First step - cancel the entire process
      _cancelProcess();
    }
  }

  void _onStepCompleted(ScheduleStep step) {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
    provider.markStepCompleted(step, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing schedule session...'),
            ],
          ),
        ),
      );
    }

    return Consumer<ScheduleSessionProvider>(
      builder: (context, provider, child) {
        if (!provider.isSessionActive) {
          return Scaffold(
            appBar: AppBar(title: const Text('Schedule Creation')),
            body: const Center(
              child: Text('No active session. Please restart the process.'),
            ),
          );
        }

        final stepNames = provider.getStepNames();
        final stepDescriptions = provider.getStepDescriptions();

        final steps = [
          Step(
            title: Text(stepNames[0]),
            subtitle: Text(stepDescriptions[0]),
            content: InsertSectionShiftScreen(
              onSessionComplete: () => _onStepCompleted(ScheduleStep.insertSectionShifts),
            ),
            isActive: provider.currentStepIndex >= 0,
            state: _getStepState(ScheduleStep.insertSectionShifts, provider),
          ),
          Step(
            title: Text(stepNames[1]),
            subtitle: Text(stepDescriptions[1]),
            content: PendingSchedulesTable(
              onReviewComplete: () => _onStepCompleted(ScheduleStep.viewSectionShifts),
            ),
            isActive: provider.currentStepIndex >= 1,
            state: _getStepState(ScheduleStep.viewSectionShifts, provider),
          ),
          // Step(
          //   title: Text(stepNames[2]),
          //   subtitle: Text(stepDescriptions[2]),
          //   content: ReceptionDataScreen(
          //     onConstraintsComplete: () => _onStepCompleted(ScheduleStep.enterDoctorConstraints),
          //   ),
          //   isActive: provider.currentStepIndex >= 2,
          //   state: _getStepState(ScheduleStep.enterDoctorConstraints, provider),
          // ),
          // Step(
          //   title: Text(stepNames[3]),
          //   subtitle: Text(stepDescriptions[3]),
          //   content: ReceptionDataScreen(
          //     onReviewComplete: () => _onStepCompleted(ScheduleStep.reviewDoctorConstraints),
          //   ),
          //   isActive: provider.currentStepIndex >= 3,
          //   state: _getStepState(ScheduleStep.reviewDoctorConstraints, provider),
          // ),
          // Step(
          //   title: Text(stepNames[4]),
          //   subtitle: Text(stepDescriptions[4]),
          //   content: ReceptionOverviewScreen(
          //     onGenerationComplete: () => _onStepCompleted(ScheduleStep.generateReceptionSchedule),
          //   ),
          //   isActive: provider.currentStepIndex >= 4,
          //   state: _getStepState(ScheduleStep.generateReceptionSchedule, provider),
          // ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text("New Schedule - ${provider.currentMonth}"),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: provider.sessionStatus == SessionStatus.active
                    ? provider.pauseSession
                    : provider.resumeSession,
                tooltip: provider.sessionStatus == SessionStatus.active ? 'Pause' : 'Resume',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelProcess,
                tooltip: 'Cancel',
              ),
            ],
          ),
          body: Column(
            children: [
              // Session Status and Progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue.withOpacity(0.3)),
                  ),
                ),
                child: Column(
                  children: [
                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: provider.overallProgress,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(provider.overallProgress * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Session Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step ${provider.currentStepIndex + 1} of ${steps.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${provider.completedStepsCount} completed',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Current Step Info
                    Row(
                      children: [
                        Icon(
                          _getStepIcon(provider.currentStep),
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stepNames[provider.currentStepIndex],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Error/Success Messages
              if (provider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        onPressed: provider.clearError,
                        icon: Icon(Icons.close, color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),

              if (provider.successMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.green.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.successMessage!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                      IconButton(
                        onPressed: provider.clearSuccess,
                        icon: Icon(Icons.close, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),

              // Stepper Content
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: Colors.blue,
                    ),
                  ),
                  child: Stepper(
                    type: StepperType.vertical,
                    currentStep: provider.currentStepIndex,
                    onStepTapped: _handleStepTap,
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            // Previous/Cancel Button
                            if (details.onStepCancel != null)
                              OutlinedButton.icon(
                                onPressed: details.onStepCancel,
                                icon: Icon(provider.currentStepIndex == 0 ? Icons.close : Icons.arrow_back),
                                label: Text(provider.currentStepIndex == 0 ? 'Cancel' : 'Previous'),
                              ),

                            const SizedBox(width: 12),

                            // Next/Finish Button
                            ElevatedButton.icon(
                              onPressed: details.onStepContinue,
                              icon: Icon(
                                provider.currentStepIndex == steps.length - 1
                                    ? Icons.check
                                    : Icons.arrow_forward,
                              ),
                              label: Text(
                                provider.currentStepIndex == steps.length - 1
                                    ? 'Finish'
                                    : 'Next',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: provider.currentStepIndex == steps.length - 1
                                    ? Colors.green
                                    : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    steps: steps,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  StepState _getStepState(ScheduleStep step, ScheduleSessionProvider provider) {
    final isCompleted = provider.stepCompletionStatus[step] ?? false;
    final currentStep = provider.currentStep;

    if (isCompleted) {
      return StepState.complete;
    } else if (step == currentStep) {
      return StepState.indexed;
    } else {
      return StepState.disabled;
    }
  }

  IconData _getStepIcon(ScheduleStep step) {
    switch (step) {
      case ScheduleStep.insertSectionShifts:
        return Icons.add_circle_outline;
      case ScheduleStep.viewSectionShifts:
        return Icons.visibility;
      case ScheduleStep.enterDoctorConstraints:
        return Icons.person_add;
      case ScheduleStep.reviewDoctorConstraints:
        return Icons.rate_review;
      case ScheduleStep.generateReceptionSchedule:
        return Icons.auto_awesome;
    }
  }

  @override
  void dispose() {
    // Clean up session if still active
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
    if (provider.isSessionActive) {
      provider.cancelSession();
    }
    super.dispose();
  }
}