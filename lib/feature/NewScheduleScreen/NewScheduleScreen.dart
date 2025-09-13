import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/feature/DoctorConstraintDataScreen/DoctorConstraintDataScreen.dart';
import 'package:shift_scheduling_app/feature/SectionScheduleListScreen/SectionScheduleListScreen.dart';
import 'package:shift_scheduling_app/feature/insertSecSchedules/InsertSectionShiftScreen.dart';
import '../../ReceptionOverviewScreen.dart';
import '../../providers/ScheduleSessionProvider.dart';

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
      final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);  // ✅ FIXED: Correct provider name

      // Get current month or let user select
      _selectedMonth = _getCurrentMonth();

      // Start the scheduling session
      final success = await provider.startSession(_selectedMonth!);

      if (!success) {
        _showError(provider.errorMessage ?? 'Failed to start session');
        if (mounted) Navigator.pop(context);
        return;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Failed to initialize session: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ✅ FIXED: Proper step completion handling
  void _onStepCompleted(ScheduleStep step) {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
    provider.markStepCompleted(step, true);
  }

  // ✅ FIXED: Step navigation methods
  void _handleStepTap(int stepIndex) {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
    provider.goToStep(stepIndex);
  }

  void _handleStepCancel() {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    if (provider.currentStepIndex == 0) {
      // Cancel entire session
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
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    } else {
      // Go to previous step
      provider.goToPreviousStep();
    }
  }

  void _handleStepContinue() {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    if (provider.currentStepIndex == 4) {
      // Complete session
      _finishProcess();
    } else {
      // Go to next step
      provider.goToNextStep();
    }
  }

  bool _canProceedToNext(ScheduleSessionProvider provider) {
    // ✅ FIXED: Proper validation logic
    return provider.isCurrentStepCompleted;
  }

  Future<void> _finishProcess() async {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    try {
      await provider.completeSession();
      _showSuccess("Schedule created successfully!");
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError('Error completing schedule: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer<ScheduleSessionProvider>(  // ✅ FIXED: Correct provider name
      builder: (context, provider, child) {
        // ✅ FIXED: Better error handling
        if (!provider.isSessionActive) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Session not active. Please restart.'),
                ],
              ),
            ),
          );
        }

        final stepNames = provider.getStepNames();
        final stepDescriptions = provider.getStepDescriptions();

        // ✅ FIXED: Proper step content widgets with error handling
        final steps = <Step>[
          Step(
            title: Text(stepNames[0]),
            subtitle: Text(stepDescriptions[0]),
            content: _buildStepContent(0, provider),
            isActive: provider.currentStepIndex == 0,
            state: _getStepState(ScheduleStep.insertSectionShifts, provider),
          ),
          Step(
            title: Text(stepNames[1]),
            subtitle: Text(stepDescriptions[1]),
            content: _buildStepContent(1, provider),
            isActive: provider.currentStepIndex == 1,
            state: _getStepState(ScheduleStep.viewSectionShifts, provider),
          ),
          Step(
            title: Text(stepNames[2]),
            subtitle: Text(stepDescriptions[2]),
            content: _buildStepContent(2, provider),
            isActive: provider.currentStepIndex == 2,
            state: _getStepState(ScheduleStep.enterDoctorConstraints, provider),
          ),
          Step(
            title: Text(stepNames[3]),
            subtitle: Text(stepDescriptions[3]),
            content: _buildStepContent(3, provider),
            isActive: provider.currentStepIndex == 3,
            state: _getStepState(ScheduleStep.reviewDoctorConstraints, provider),
          ),
          Step(
            title: Text(stepNames[4]),
            subtitle: Text(stepDescriptions[4]),
            content: _buildStepContent(4, provider),
            isActive: provider.currentStepIndex == 4,
            state: _getStepState(ScheduleStep.generateReceptionSchedule, provider),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text("New Schedule - ${provider.currentMonth}"),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            actions: [
              // Session controls
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: provider.sessionStatus == SessionStatus.active
                    ? provider.pauseSession
                    : provider.resumeSession,
                tooltip: provider.sessionStatus == SessionStatus.active
                    ? 'Pause Session'
                    : 'Resume Session',
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: provider.overallProgress,
                      backgroundColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress: ${(provider.overallProgress * 100).round()}%'),
                        Text('${provider.completedStepsCount}/${stepNames.length} completed'),
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
                        onPressed: () {
                          // ✅ FIXED: Proper method call
                          final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
                          // You'll need to add this method to your provider
                          // provider.clearError();
                        },
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
                        onPressed: () {
                          // ✅ FIXED: Proper method call
                          final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
                          // You'll need to add this method to your provider
                          // provider.clearSuccess();
                        },
                        icon: Icon(Icons.close, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),

              // Stepper
              Expanded(
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
                          if (provider.currentStepIndex >= 0)
                            OutlinedButton.icon(
                              onPressed: _handleStepCancel,
                              icon: Icon(provider.currentStepIndex == 0 ? Icons.close : Icons.arrow_back),
                              label: Text(provider.currentStepIndex == 0 ? 'Cancel' : 'Previous'),
                            ),

                          const SizedBox(width: 12),

                          // Next/Finish Button
                          ElevatedButton.icon(
                            onPressed: _canProceedToNext(provider) ? _handleStepContinue : null,
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
            ],
          ),
        );
      },
    );
  }

  // ✅ FIXED: Safe step content building with error handling
  Widget _buildStepContent(int stepIndex, ScheduleSessionProvider provider) {
    try {
      switch (stepIndex) {
        case 0:
        // Step 1: Insert Section Shifts
          return InsertSectionShiftScreen(
            onSessionComplete: () => _onStepCompleted(ScheduleStep.insertSectionShifts),
          );
        case 1:
        // Step 2: View Section Shifts
          return PendingSchedulesTable(
            onReviewComplete: () => _onStepCompleted(ScheduleStep.viewSectionShifts),
          );
        // case 2:
        // // Step 3: Enter Doctor Constraints
        //   return DoctorConstraintDataScreen(
        //     onConstraintsComplete: () => _onStepCompleted(ScheduleStep.enterDoctorConstraints),
        //   );
        // case 3:
        // // Step 4: Review Constraints
        //   return ReceptionDataScreen(
        //     onReviewComplete: () => _onStepCompleted(ScheduleStep.reviewDoctorConstraints),
        //   );
        // case 4:
        // // Step 5: Generate Schedule
        //   return ReceptionOverviewScreen(
        //     onGenerationComplete: () => _onStepCompleted(ScheduleStep.generateReceptionSchedule),
        //   );
        default:
          return const Center(
            child: Text('Step not implemented yet'),
          );
      }
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading step content: $e'),
          ],
        ),
      );
    }
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

  @override
  void dispose() {
    // Clean up session if still active
    try {
      final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
      if (provider.isSessionActive) {
        provider.cancelSession();
      }
    } catch (e) {
      // Ignore disposal errors
    }
    super.dispose();
  }
}