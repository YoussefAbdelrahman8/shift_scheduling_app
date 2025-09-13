// Fixed SectionScheduleListScreen.dart DataTable implementation
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/Doctor.dart';
import '../../core/models/SectionShift.dart';
import '../../providers/SectionShiftProvider.dart';

class PendingSchedulesTable extends StatefulWidget {
  final VoidCallback? onReviewComplete;

  const PendingSchedulesTable({
    Key? key,
    this.onReviewComplete,
  }) : super(key: key);

  @override
  State<PendingSchedulesTable> createState() => _PendingSchedulesTableState();
}

class _PendingSchedulesTableState extends State<PendingSchedulesTable> {
  bool _isExpanded = false;
  final Map<String, bool> _specializationExpansion = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    try {
      final provider = Provider.of<SectionShiftProvider>(context, listen: false);
      provider.initializeForSession();

      // Mark step as completed if we have sufficient data
      if (provider.hasCompletedSectionShifts && widget.onReviewComplete != null) {
        widget.onReviewComplete!();
      }
    } catch (e) {
      print('Error initializing PendingSchedulesTable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SectionShiftProvider>(
      builder: (context, provider, _) {
        // Safe state checking
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.errorMessage != null) {
          return _buildErrorState(provider.errorMessage!);
        }

        if (!provider.isSessionActive) {
          return _buildEmptyState(
            icon: Icons.schedule,
            title: 'No Active Session',
            subtitle: 'Please start a schedule session first',
          );
        }

        final shifts = provider.currentSessionSectionShifts;
        final doctors = provider.allDoctors;

        if (shifts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_busy,
            title: 'No Section Shifts Added Yet',
            subtitle: 'Return to the previous step to add section shifts',
          );
        }

        if (doctors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'No Doctors Data Available',
            subtitle: 'Please check your doctor database',
          );
        }

        return _buildScheduleTable(provider, shifts, doctors);
      },
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Schedule',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await _initializeData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Section Shifts Review',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatMonthYear(provider.currentMonth ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Total Shifts', shifts.length.toString(), Icons.event),
                    _buildStatCard('Doctors', _getUniqueDoctorCount(shifts).toString(), Icons.people),
                    _buildStatCard('Specializations', sortedSpecializations.length.toString(), Icons.medical_services),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Specializations List
          ...sortedSpecializations.map((specialization) {
            final specializationShifts = groupedShifts[specialization]!;
            final isExpanded = _specializationExpansion[specialization] ?? false;

            return _buildSpecializationSection(
              specialization,
              specializationShifts,
              isExpanded,
              provider.allDoctors,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationSection(
      String specialization,
      List<SectionShift> shifts,
      bool isExpanded,
      List<Doctor> allDoctors,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Specialization Header
          InkWell(
            onTap: () {
              setState(() {
                _specializationExpansion[specialization] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medical_services,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          specialization,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${shifts.length} shifts assigned',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue[700],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildSpecializationTable(shifts, allDoctors),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecializationTable(List<SectionShift> shifts, List<Doctor> allDoctors) {
    // Group shifts by doctor
    final Map<int, List<SectionShift>> shiftsByDoctor = {};
    for (var shift in shifts) {
      shiftsByDoctor.putIfAbsent(shift.doctorId, () => []).add(shift);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
            columnSpacing: 20,
            dataRowHeight: 60,
            headingRowHeight: 50,
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
            rows: shiftsByDoctor.entries.map((entry) {
              final doctorId = entry.key;
              final doctorShifts = entry.value;
              final doctor = allDoctors.firstWhere(
                    (d) => d.id == doctorId,
                orElse: () => Doctor(
                    id: doctorId,
                    name: 'Unknown Doctor',
                    specialization: '',
                    seniority: 'Unknown'
                ),
              );

              return DataRow(
                cells: [
                  // Doctor Info Cell - FIXED STRUCTURE
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          doctor.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'ID: ${doctor.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Seniority Cell - FIXED STRUCTURE
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
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Dates Cell - FIXED STRUCTURE
                  DataCell(
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: doctorShifts.map((shift) {
                        final dayOfMonth = DateTime.parse(shift.date).day;
                        return Chip(
                          label: Text(
                            dayOfMonth.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue[100],
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ),

                  // Actions Cell - FIXED STRUCTURE
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          tooltip: 'Edit Doctor Shifts',
                          onPressed: () => _editDoctorShifts(context, doctor, doctorShifts),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          tooltip: 'Delete All Shifts',
                          onPressed: () => _deleteAllShiftsForDoctor(context, doctorId, doctorShifts),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Helper Methods
  Map<String, List<SectionShift>> _groupShiftsBySpecializationAndDoctor(
      List<SectionShift> shifts,
      List<Doctor> doctors
      ) {
    final Map<String, List<SectionShift>> grouped = {};

    for (var shift in shifts) {
      final doctor = doctors.firstWhere(
            (d) => d.id == shift.doctorId,
        orElse: () => Doctor(id: shift.doctorId, name: '', specialization: 'Unknown', seniority: ''),
      );

      final specialization = doctor.specialization?.isNotEmpty == true
          ? doctor.specialization!
          : 'Unknown Specialization';

      grouped.putIfAbsent(specialization, () => []).add(shift);
    }

    return grouped;
  }

  int _getUniqueDoctorCount(List<SectionShift> shifts) {
    return shifts.map((s) => s.doctorId).toSet().length;
  }

  String _formatMonthYear(String monthString) {
    try {
      if (monthString.isEmpty) return 'No Month Selected';

      final parts = monthString.split('-');
      if (parts.length != 2) return monthString;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];

      return '${monthNames[month - 1]} $year';
    } catch (e) {
      return monthString;
    }
  }

  Color _getSeniorityColor(String? seniority) {
    switch (seniority?.toLowerCase()) {
      case 'senior':
        return Colors.green;
      case 'middle':
        return Colors.orange;
      case 'junior':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
// Replace your _editDoctorShifts method with this fixed version

  void _editDoctorShifts(BuildContext context, Doctor doctor, List<SectionShift> shifts) {
    // Declare state variables outside the builder
    SectionShift? selectedShift;
    DateTime? selectedNewDate;
    bool isLoading = false;
    String? errorMessage;
    String? successMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Shifts for ${doctor.name}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error/Success messages
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          successMessage!,
                          style: TextStyle(color: Colors.green[700], fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Text('Select a shift to edit:'),
                    const SizedBox(height: 8),

                    // Shifts list
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: shifts.length,
                        itemBuilder: (context, index) {
                          final shift = shifts[index];
                          final date = DateTime.parse(shift.date);
                          final isSelected = selectedShift != null &&
                              selectedShift!.doctorId == shift.doctorId &&
                              selectedShift!.date == shift.date;

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: Colors.blue[50],
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected ? Colors.blue[100] : Colors.grey[200],
                              child: Text(
                                date.day.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.blue[700] : Colors.grey[700],
                                ),
                              ),
                            ),
                            title: Text(
                              _formatDialogDate(date),
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              _getDayName(date),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.blue[700] : Colors.grey,
                            ),
                            onTap: isLoading ? null : () {
                              print('Shift selected: ${shift.date}'); // Debug print
                              setDialogState(() {
                                selectedShift = shift;
                                selectedNewDate = null;
                                errorMessage = null;
                                successMessage = null;
                              });
                            },
                          );
                        },
                      ),
                    ),

                    // Date picker section
                    if (selectedShift != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editing shift for: ${_formatDialogDate(DateTime.parse(selectedShift!.date))}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            if (selectedNewDate != null)
                              Text(
                                'New date: ${_formatDialogDate(selectedNewDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange[700],
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isLoading ? null : () async {
                                  print('Date picker pressed'); // Debug print

                                  final provider = Provider.of<SectionShiftProvider>(context, listen: false);
                                  final currentMonth = provider.currentMonth;

                                  if (currentMonth == null) {
                                    setDialogState(() {
                                      errorMessage = 'No active session found';
                                    });
                                    return;
                                  }

                                  try {
                                    final parts = currentMonth.split('-');
                                    final year = int.parse(parts[0]);
                                    final month = int.parse(parts[1]);

                                    final firstDay = DateTime(year, month, 1);
                                    final lastDay = DateTime(year, month + 1, 0);

                                    final pickedDate = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: DateTime.parse(selectedShift!.date),
                                      firstDate: firstDay,
                                      lastDate: lastDay,
                                      helpText: 'Select new date',
                                    );

                                    print('Date picked: $pickedDate'); // Debug print

                                    if (pickedDate != null) {
                                      final dateString = pickedDate.toIso8601String().split('T')[0];

                                      // Check if date is already taken
                                      final isDateTaken = shifts.any((s) =>
                                      s.date == dateString &&
                                          !(s.doctorId == selectedShift!.doctorId && s.date == selectedShift!.date)
                                      );

                                      if (isDateTaken) {
                                        setDialogState(() {
                                          errorMessage = 'Doctor already has a shift on ${_formatDialogDate(pickedDate)}';
                                        });
                                      } else {
                                        setDialogState(() {
                                          selectedNewDate = pickedDate;
                                          errorMessage = null;
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      errorMessage = 'Error selecting date: $e';
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_month),
                                label: Text(selectedNewDate == null ? 'Select New Date' : 'Change Date'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: (selectedShift != null &&
                      selectedNewDate != null &&
                      selectedNewDate!.toIso8601String().split('T')[0] != selectedShift!.date &&
                      !isLoading)
                      ? () async {
                    print('Save button pressed'); // Debug print

                    setDialogState(() {
                      isLoading = true;
                      errorMessage = null;
                      successMessage = null;
                    });

                    try {
                      final newDateString = selectedNewDate!.toIso8601String().split('T')[0];

                      final success = await _updateShiftDate(selectedShift!, newDateString);

                      if (success) {
                        setDialogState(() {
                          successMessage = 'Shift updated successfully';
                        });

                        // Close dialog after showing success
                        Future.delayed(const Duration(milliseconds: 1000), () {
                          if (mounted) Navigator.of(dialogContext).pop();
                        });
                      } else {
                        final provider = Provider.of<SectionShiftProvider>(context, listen: false);
                        setDialogState(() {
                          errorMessage = provider.errorMessage ?? 'Failed to update shift';
                        });
                      }
                    } catch (e) {
                      print('Error saving: $e'); // Debug print
                      setDialogState(() {
                        errorMessage = 'Error: $e';
                      });
                    } finally {
                      setDialogState(() {
                        isLoading = false;
                      });
                    }
                  }
                      : null,
                  icon: isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.save),
                  label: Text(isLoading ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Keep these helper methods the same
  Future<bool> _updateShiftDate(SectionShift shift, String newDate) async {
    try {
      final provider = Provider.of<SectionShiftProvider>(context, listen: false);
      return await provider.updateSectionShiftDate(shift.id!, newDate);
    } catch (e) {
      print('Error updating shift date: $e');
      return false;
    }
  }

  String _formatDialogDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  void _deleteAllShiftsForDoctor(BuildContext context, int doctorId, List<SectionShift> shifts) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Shifts'),
          content: const Text('Are you sure you want to delete all shifts for this doctor?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final provider = Provider.of<SectionShiftProvider>(context, listen: false);
                  for (final shift in shifts) {
                    await provider.removeSectionShift(shift);
                  }
                  Navigator.of(context).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shifts deleted successfully')),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting shifts: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}