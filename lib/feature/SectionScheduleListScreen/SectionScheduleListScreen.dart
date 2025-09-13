import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ScheduleSessionProvider.dart';
import '../../providers/SectionShiftProvider.dart';

import '../../core/models/SectionShift.dart';
import '../../core/models/Doctor.dart';

class PendingSchedulesTable extends StatefulWidget {
  final VoidCallback? onReviewComplete;

  const PendingSchedulesTable({Key? key, this.onReviewComplete}) : super(key: key);

  @override
  State<PendingSchedulesTable> createState() => _PendingSchedulesTableState();
}

class _PendingSchedulesTableState extends State<PendingSchedulesTable> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    // Initialize the provider when entering this step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SectionShiftProvider>();
      provider.initializeForSession();
    });
  }

  Future<void> _editShiftDate(BuildContext context, SectionShift shift) async {
    if (shift.id == null) return;

    final provider = context.read<SectionShiftProvider>();
    final sessionProvider = context.read<ScheduleSessionProvider>();

    // Get current month for date constraints
    final currentMonth = sessionProvider.currentMonth;
    if (currentMonth == null) return;

    final currentDate = DateTime.tryParse(shift.date) ?? DateTime.now();
    final monthParts = currentMonth.split('-');
    final year = int.parse(monthParts[0]);
    final month = int.parse(monthParts[1]);

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(year, month, 1),
      lastDate: DateTime(year, month + 1, 0), // Last day of month
      helpText: 'Select new date for shift',
      confirmText: 'UPDATE',
      cancelText: 'CANCEL',
    );

    if (picked != null) {
      final newDate = picked.toIso8601String().split('T').first;

      try {
        // You'll need to implement this method in SectionShiftProvider
        await provider.updateSectionShiftDate(shift.id!, newDate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift date updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update shift: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteShift(BuildContext context, SectionShift shift) async {
    if (shift.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to delete the shift on ${shift.date}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = context.read<SectionShiftProvider>();
        await provider.deleteSectionShift(shift.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete shift: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getDoctorName(int doctorId, List<Doctor> doctors) {
    try {
      final doctor = doctors.firstWhere((d) => d.id == doctorId);
      return doctor.name;
    } catch (e) {
      return 'Unknown Doctor ($doctorId)';
    }
  }

  String _getDoctorSpecialization(int doctorId, List<Doctor> doctors) {
    try {
      final doctor = doctors.firstWhere((d) => d.id == doctorId);
      return doctor.specialization ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getSeniorityColor(String? seniority) {
    switch (seniority?.toLowerCase()) {
      case 'junior':
        return Colors.blue.shade100;
      case 'mid-level':
        return Colors.orange.shade100;
      case 'senior':
        return Colors.green.shade100;
      case 'consultant':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Map<String, List<SectionShift>> _groupShiftsBySpecialization(
      List<SectionShift> shifts, List<Doctor> doctors) {
    final grouped = <String, List<SectionShift>>{};

    for (final shift in shifts) {
      final specialization = _getDoctorSpecialization(shift.doctorId, doctors);
      if (!grouped.containsKey(specialization)) {
        grouped[specialization] = [];
      }
      grouped[specialization]!.add(shift);
    }

    // Sort shifts within each specialization by date
    grouped.forEach((key, value) {
      value.sort((a, b) => a.date.compareTo(b.date));
    });

    return grouped;
  }

  Map<int, List<String>> _consolidateDoctorShifts(List<SectionShift> shifts) {
    final consolidated = <int, List<String>>{};

    for (final shift in shifts) {
      if (!consolidated.containsKey(shift.doctorId)) {
        consolidated[shift.doctorId] = [];
      }
      consolidated[shift.doctorId]!.add(shift.date);
    }

    // Sort dates for each doctor
    consolidated.forEach((key, value) {
      value.sort();
    });

    return consolidated;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SectionShiftProvider, ScheduleSessionProvider>(
      builder: (context, sectionProvider, sessionProvider, child) {
        final shifts = sectionProvider.currentSessionSectionShifts;
        final allDoctors = sessionProvider.getAllSessionDoctors();
        final currentMonth = sessionProvider.currentMonth;

        // Handle loading state
        if (sectionProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading section shifts...'),
              ],
            ),
          );
        }

        // Handle empty state
        if (shifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  "No Section Shifts Created Yet",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Go back to the previous step to add section shifts",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    sessionProvider.goToPreviousStep();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Section Shifts"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Group shifts by specialization
        final groupedShifts = _groupShiftsBySpecialization(shifts, allDoctors);
        final uniqueDoctors = shifts.map((s) => s.doctorId).toSet().length;

        return Column(
          children: [
            // Header with statistics
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Section Shifts Review',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currentMonth ?? '',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${shifts.length} Total Shifts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$uniqueDoctors Doctors',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error message display
            if (sectionProvider.errorMessage != null)
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
                        sectionProvider.errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      onPressed: sectionProvider.clearError,
                      icon: Icon(Icons.close, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),

            // Success message display
            if (sectionProvider.successMessage != null)
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
                        sectionProvider.successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                    IconButton(
                      onPressed: sectionProvider.clearSuccess,
                      icon: Icon(Icons.close, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Expand/Collapse all button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${groupedShifts.length} Specializations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                          label: Text(_isExpanded ? 'Collapse All' : 'Expand All'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Specialization sections
                    ...groupedShifts.entries.map((entry) {
                      final specialization = entry.key;
                      final specializationShifts = entry.value;
                      final consolidatedShifts = _consolidateDoctorShifts(specializationShifts);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Specialization header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.medical_services, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      specialization.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${specializationShifts.length} shifts',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Shifts table for this specialization
                            if (_isExpanded)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                                  columns: const [
                                    DataColumn(
                                      label: Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    DataColumn(
                                      label: Text('Seniority', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    DataColumn(
                                      label: Text('Assigned Dates', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    DataColumn(
                                      label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  rows: consolidatedShifts.entries.map((doctorEntry) {
                                    final doctorId = doctorEntry.key;
                                    final dates = doctorEntry.value;
                                    final doctorName = _getDoctorName(doctorId, allDoctors);
                                    final doctor = allDoctors.firstWhere(
                                          (d) => d.id == doctorId,
                                      orElse: () => Doctor(id: doctorId, name: 'Unknown', specialization: '', seniority: ''),
                                    );

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                doctorName,
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                'ID: $doctorId',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getSeniorityColor(doctor.seniority),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              doctor.seniority ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: dates.map((date) {
                                              final dayOfMonth = DateTime.parse(date).day;
                                              return Chip(
                                                label: Text(
                                                  dayOfMonth.toString(),
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                backgroundColor: Colors.blue.shade100,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                padding: EdgeInsets.zero,
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: dates.map((date) {
                                              final shift = specializationShifts.firstWhere(
                                                    (s) => s.doctorId == doctorId && s.date == date,
                                              );
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                    tooltip: 'Edit $date',
                                                    onPressed: () => _editShiftDate(context, shift),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                    tooltip: 'Delete $date',
                                                    onPressed: () => _deleteShift(context, shift),
                                                  ),
                                                ],
                                              );
                                            }).toList(), // Only show actions for consolidated row
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              sessionProvider.goToPreviousStep();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add More Shifts'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: shifts.isNotEmpty ? () {
                              // Mark review as complete and trigger callback
                              widget.onReviewComplete?.call();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Section shifts review completed!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } : null,
                            icon: const Icon(Icons.check),
                            label: const Text('Complete Review'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}