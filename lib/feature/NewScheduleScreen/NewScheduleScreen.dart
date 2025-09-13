// Fixed NewScheduleScreen.dart with comprehensive error handling
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ScheduleSessionProvider.dart';
import '../SectionScheduleListScreen/SectionScheduleListScreen.dart';
import '../insertSecSchedules/InsertSectionShiftScreen.dart';

class NewScheduleScreen extends StatefulWidget {
  const NewScheduleScreen({Key? key}) : super(key: key);

  @override
  State<NewScheduleScreen> createState() => _NewScheduleScreenState();
}

class _NewScheduleScreenState extends State<NewScheduleScreen> {
  bool _isLoading = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  Future<void> _initializeSession() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _initError = null;
      });

      final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);
      final currentMonth = _getCurrentMonth();

      final success = await provider.startSession(currentMonth);

      if (!success && mounted) {
        setState(() {
          _initError = provider.errorMessage ?? 'Failed to start session';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Failed to initialize session: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading state
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("New Schedule"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        body: const Center(
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

    // Handle initialization error
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("New Schedule"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Initialization Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _initializeSession,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Main content with error boundary
    return Consumer<ScheduleSessionProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text("New Schedule - ${provider.currentMonth ?? 'Unknown'}"),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showSessionInfo(context, provider),
                tooltip: 'Session Info',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Progress indicator
                if (provider.isSessionActive) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress: Step ${provider.currentStepIndex + 1} of ${_getStepCount()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (provider.currentStepIndex + 1) / _getStepCount(),
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        ),
                      ],
                    ),
                  ),
                ],

                // Error display
                if (provider.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red[50],
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                        IconButton(
                          onPressed: provider.clearError,
                          icon: Icon(Icons.close, color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],

                // Main stepper content
                Expanded(
                  child: _buildStepperContent(provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepperContent(ScheduleSessionProvider provider) {
    try {
      // Safe step building with proper error handling
      final steps = _buildSteps(provider);

      return Stepper(
        type: StepperType.vertical,
        currentStep: provider.currentStepIndex,
        onStepTapped: (index) => _handleStepTap(index, provider),
        controlsBuilder: (context, details) => _buildControls(context, details, provider),
        steps: steps,
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error building stepper: $e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}), // Trigger rebuild
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  List<Step> _buildSteps(ScheduleSessionProvider provider) {
    return [
      Step(
        title: const Text('Insert Section Shifts'),
        content: _buildStepContent(0, provider),
        isActive: provider.currentStepIndex == 0,
        state: _getStepState(0, provider),
      ),
      Step(
        title: const Text('Review Section Shifts'),
        content: _buildStepContent(1, provider),
        isActive: provider.currentStepIndex == 1,
        state: _getStepState(1, provider),
      ),
      // Add more steps as needed
    ];
  }

  Widget _buildStepContent(int stepIndex, ScheduleSessionProvider provider) {
    try {
      switch (stepIndex) {
        case 0:
          return SizedBox(
            height: 400, // Fixed height to prevent render issues
            child: InsertSectionShiftScreen(
              key: const ValueKey('insert_section_shifts'), // Add key for stability
              onSessionComplete: () => _onStepCompleted(stepIndex),
            ),
          );
        case 1:
          return SizedBox(
            height: 400, // Fixed height to prevent render issues
            child: PendingSchedulesTable(
              key: const ValueKey('pending_schedules'), // Add key for stability
              onReviewComplete: () => _onStepCompleted(stepIndex),
            ),
          );
        default:
          return const SizedBox(
            height: 200,
            child: Center(
              child: Text('Step not implemented yet'),
            ),
          );
      }
    } catch (e) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 32, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error loading step: $e'),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildControls(BuildContext context, ControlsDetails details, ScheduleSessionProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          // Previous/Cancel Button
          if (provider.currentStepIndex > 0)
            OutlinedButton.icon(
              onPressed: details.onStepCancel,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _handleCancel(context, provider),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),

          const SizedBox(width: 12),

          // Next/Finish Button
          ElevatedButton.icon(
            onPressed: _canProceedToNext(provider) ? details.onStepContinue : null,
            icon: Icon(
              provider.currentStepIndex == _getStepCount() - 1
                  ? Icons.check
                  : Icons.arrow_forward,
            ),
            label: Text(
              provider.currentStepIndex == _getStepCount() - 1
                  ? 'Finish'
                  : 'Next',
            ),
          ),
        ],
      ),
    );
  }

  StepState _getStepState(int stepIndex, ScheduleSessionProvider provider) {
    if (stepIndex < provider.currentStepIndex) {
      return StepState.complete;
    } else if (stepIndex == provider.currentStepIndex) {
      return StepState.indexed;
    } else {
      return StepState.disabled;
    }
  }

  int _getStepCount() => 2; // Adjust based on your actual step count

  bool _canProceedToNext(ScheduleSessionProvider provider) {
    // Add your step completion validation logic here
    switch (provider.currentStepIndex) {
      case 0:
      // Check if section shifts have been added
        return true; // Implement your validation
      case 1:
      // Check if review is complete
        return true; // Implement your validation
      default:
        return false;
    }
  }

  void _handleStepTap(int index, ScheduleSessionProvider provider) {
    // Only allow tapping to completed steps or current step
    if (index <= provider.currentStepIndex) {
      provider.goToStep(index);
    }
  }

  void _onStepCompleted(int stepIndex) {
    final provider = Provider.of<ScheduleSessionProvider>(context, listen: false);

    // Mark step as completed and move to next step if applicable
    if (stepIndex < _getStepCount() - 1) {
      provider.goToStep(stepIndex + 1);
    }
  }

  void _handleCancel(BuildContext context, ScheduleSessionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Schedule Creation'),
        content: const Text('Are you sure you want to cancel? All progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              provider.cancelSession();
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSessionInfo(BuildContext context, ScheduleSessionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Month: ${provider.currentMonth ?? 'Unknown'}'),
            Text('Current Step: ${provider.currentStepIndex + 1}'),
            Text('Status: ${provider.sessionStatus.toString().split('.').last}'),
            Text('Active: ${provider.isSessionActive}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}