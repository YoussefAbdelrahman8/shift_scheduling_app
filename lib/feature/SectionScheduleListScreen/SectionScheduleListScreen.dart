import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/Doctor.dart';
import '../../core/models/SectionShift.dart';
import '../../providers/SectionShiftProvider.dart';

class PendingSchedulesTable extends StatefulWidget {
  final VoidCallback? onReviewComplete;

  const PendingSchedulesTable({Key? key, this.onReviewComplete}) : super(key: key);

  @override
  State<PendingSchedulesTable> createState() => _PendingSchedulesTableState();
}

class _PendingSchedulesTableState extends State<PendingSchedulesTable> {
  bool _isExpanded = true;
  bool _debugMode = false; // Set to true for debugging

  @override
  void initState() {
    super.initState();
    // Initialize for current session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    try {
      final provider = context.read<SectionShiftProvider>();
      print('🔄 Initializing PendingSchedulesTable...');
      print('📊 Provider session active: ${provider.isSessionActive}');
      print('📅 Current month: ${provider.currentMonth}');

      await Future.delayed(const Duration(milliseconds: 100));
      provider.initializeForSession();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error initializing data: $e');
    }
  }

  Future<void> _editShiftDate(SectionShift shift, Doctor doctor) async {
    final provider = context.read<SectionShiftProvider>();

    DateTime currentDate = DateTime.parse(shift.date);
    final currentMonth = provider.currentMonth;

    DateTime firstDate = DateTime.now();
    DateTime lastDate = DateTime.now();

    if (currentMonth != null) {
      final year = int.parse(currentMonth.substring(0, 4));
      final month = int.parse(currentMonth.substring(5, 7));
      firstDate = DateTime(year, month, 1);
      lastDate = DateTime(year, month + 1, 0);
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Edit shift date for ${doctor.name}',
    );

    if (picked != null) {
      final newDateString = picked.toIso8601String().split('T').first;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Shift Date'),
          content: Text(
              'Change ${doctor.name}\'s shift from ${shift.date} to $newDateString?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await provider.deleteSectionShift(shift.id!);
        provider.clearDates();
        provider.addDate(newDateString);
        provider.setSelectedDoctorId(doctor.id);
        await provider.saveSectionShifts();
      }
    }
  }

  Future<void> _deleteShift(SectionShift shift, Doctor doctor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text(
            'Are you sure you want to delete ${doctor.name}\'s shift on ${shift.date}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<SectionShiftProvider>();
      await provider.deleteSectionShift(shift.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted shift for ${doctor.name} on ${shift.date}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _completeReview() {
    if (widget.onReviewComplete != null) {
      widget.onReviewComplete!();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Section shifts review completed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatMonthYear(String monthString) {
    try {
      final parts = monthString.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        const monthNames = [
          '', 'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        if (month >= 1 && month <= 12) {
          return '${monthNames[month]} $year';
        }
      }
    } catch (e) {
      print('❌ Error formatting month: $e');
    }
    return monthString;
  }

  Map<String, Map<Doctor, List<SectionShift>>> _groupShiftsBySpecializationAndDoctor(
      List<SectionShift> shifts,
      List<Doctor> doctors,
      ) {
    final grouped = <String, Map<Doctor, List<SectionShift>>>{};

    if (shifts.isEmpty) {
      print('⚠️ No shifts to group');
      return grouped;
    }

    if (doctors.isEmpty) {
      print('⚠️ No doctors available for grouping');
      return grouped;
    }

    print('📊 Grouping ${shifts.length} shifts with ${doctors.length} doctors');

    for (final shift in shifts) {
      Doctor? doctor;
      try {
        doctor = doctors.firstWhere((d) => d.id == shift.doctorId);
      } catch (e) {
        print('⚠️ Doctor not found for shift: doctorId=${shift.doctorId}');
        // Skip shifts with missing doctors instead of creating placeholder
        continue;
      }

      final specialization = doctor.specialization ?? 'Unknown';

      grouped.putIfAbsent(specialization, () => {});
      grouped[specialization]!.putIfAbsent(doctor, () => []);
      grouped[specialization]![doctor]!.add(shift);
    }

    // Sort dates within each doctor's shifts
    for (final specialization in grouped.keys) {
      for (final doctor in grouped[specialization]!.keys) {
        grouped[specialization]![doctor]!.sort((a, b) => a.date.compareTo(b.date));
      }
    }

    print('✅ Grouped into ${grouped.length} specializations');
    return grouped;
  }

  Widget _buildDebugInfo(SectionShiftProvider provider) {
    if (!_debugMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        border: Border.all(color: Colors.yellow[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Debug Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 8),
          Text('Session Active: ${provider.isSessionActive}'),
          Text('Current Month: ${provider.currentMonth}'),
          Text('Shifts Count: ${provider.currentSessionSectionShifts.length}'),
          Text('Doctors Count: ${provider.allDoctors.length}'),
          Text('Available Specializations: ${provider.availableSpecializations.length}'),
          Text('Is Loading: ${provider.isLoading}'),
          Text('Error Message: ${provider.errorMessage ?? 'None'}'),
          Text('Success Message: ${provider.successMessage ?? 'None'}'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              print('🔄 Manual refresh triggered');
              await _initializeData();
            },
            child: const Text('Refresh Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SectionShiftProvider>(
      builder: (context, provider, _) {
        print('🔄 Building PendingSchedulesTable...');
        print('📊 Session active: ${provider.isSessionActive}');
        print('📅 Current month: ${provider.currentMonth}');
        print('📋 Shifts: ${provider.currentSessionSectionShifts.length}');
        print('👥 Doctors: ${provider.allDoctors.length}');

        // FIXED: Don't use Column with Expanded - use a simple Column with constrained height
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 200,
            maxHeight: 600, // Set a reasonable max height for the stepper
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important: Use min size
            children: [
              // Debug Info (only in debug mode)
              _buildDebugInfo(provider),

              // Error Messages
              if (provider.errorMessage != null)
                Container(
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

              // Loading indicator
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),

              // Main content - FIXED: Use Flexible instead of Expanded
              Flexible(
                child: _buildMainContent(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(SectionShiftProvider provider) {
    if (!provider.isSessionActive) {
      return _buildEmptyState(
        icon: Icons.schedule,
        title: 'No Active Session',
        subtitle: 'Please start a schedule session first',
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      );
    }

    final shifts = provider.currentSessionSectionShifts;
    final doctors = provider.allDoctors;

    if (shifts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_busy,
        title: 'No Section Shifts Added Yet',
        subtitle: 'Return to the previous step to add section shifts',
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Add Shifts'),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _completeReview,
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip to Next Step'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    if (doctors.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Doctors Data Available',
        subtitle: 'Please check your doctor database',
        actions: [
          ElevatedButton(
            onPressed: () async {
              await _initializeData();
            },
            child: const Text('Refresh'),
          ),
        ],
      );
    }

    return _buildScheduleTable(provider, shifts, doctors);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable(SectionShiftProvider provider, List<SectionShift> shifts, List<Doctor> doctors) {
    final groupedShifts = _groupShiftsBySpecializationAndDoctor(shifts, doctors);
    final sortedSpecializations = groupedShifts.keys.toList()..sort();

    if (groupedShifts.isEmpty) {
      return const Center(
        child: Text('Unable to group shifts by specialization'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Section Shifts Review',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatMonthYear(provider.currentMonth ?? ''),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_turned_in, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${shifts.length} Total Shifts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.people, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${provider.getUniqueDoctorsWithShifts().length} Doctors',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content Section
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expand/Collapse Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                      icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                      label: Text(_isExpanded ? 'Collapse All' : 'Expand All'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Specializations
              ...sortedSpecializations.map((specialization) {
                final doctorShifts = groupedShifts[specialization]!;
                final totalShiftsInSpec = doctorShifts.values
                    .map((shifts) => shifts.length)
                    .fold(0, (sum, count) => sum + count);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Specialization Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.medical_services, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  specialization,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalShiftsInSpec shifts',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Doctors Table
                        if (_isExpanded)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                              columnSpacing: 20,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Doctor',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Seniority',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Shift Dates (Click to Edit/Delete)',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Removed Actions column since dates are now clickable
                              ],
                              rows: doctorShifts.entries.map((entry) {
                                final doctor = entry.key;
                                final doctorShiftsList = entry.value;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            doctor.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${doctorShiftsList.length} shifts',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getSeniorityColor(doctor.seniority ?? ''),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          doctor.seniority ?? 'Unknown',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // New clickable dates implementation
                                    DataCell(
                                      Container(
                                        width: 400,
                                        height: 50, // Fixed height to prevent row expansion
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal, // Allow horizontal scrolling
                                          child: Row( // Use Row instead of Wrap to keep everything in one line
                                            children: doctorShiftsList.asMap().entries.map((entry) {
                                              final index = entry.key;
                                              final shift = entry.value;
                                              return Container(
                                                margin: EdgeInsets.only(
                                                  right: index < doctorShiftsList.length - 1 ? 8 : 0, // Space between chips
                                                ),
                                                child: GestureDetector(
                                                  onTap: () => _showShiftActionDialog(context, shift, doctor),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[100],
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.green[300]!),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.green.withOpacity(0.1),
                                                          blurRadius: 2,
                                                          offset: const Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.event,
                                                          size: 14,
                                                          color: Colors.green[700],
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          shift.date,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: Colors.green[700],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(
                                                          Icons.touch_app,
                                                          size: 12,
                                                          color: Colors.green[600],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            )
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _completeReview,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

// Add this new method to handle the shift action dialog:
  void _showShiftActionDialog(BuildContext context, SectionShift shift, Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor: ${doctor.name}'),
            const SizedBox(height: 8),
            Text('Date: ${shift.date}'),
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editShiftDate(shift, doctor);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Date'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deleteShift(shift, doctor);
            },
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  Color _getSeniorityColor(String seniority) {
    switch (seniority.toLowerCase()) {
      case 'junior':
        return Colors.green;
      case 'mid-level':
        return Colors.orange;
      case 'senior':
        return Colors.blue;
      case 'consultant':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}