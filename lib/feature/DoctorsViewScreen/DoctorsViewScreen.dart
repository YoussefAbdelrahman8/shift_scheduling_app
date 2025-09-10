import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/core/routes_manager/routes.dart';
import '../../core/models/Doctor.dart';
import '../../providers/DoctorProvider.dart';

class DoctorsTableView extends StatefulWidget {
  const DoctorsTableView({super.key});

  @override
  State<DoctorsTableView> createState() => _DoctorsTableViewState();
}

class _DoctorsTableViewState extends State<DoctorsTableView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear any previous messages and refresh data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doctorProvider = context.read<DoctorProvider>();
      doctorProvider.clearAllMessages();
      doctorProvider.refreshData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditDialog(Doctor doctor) {
    final nameController = TextEditingController(text: doctor.name);
    String? selectedSpecialization = doctor.specialization;
    String? selectedSeniority = doctor.seniority;

    final specializations = ["Cardiology", "Neurology", "Pediatrics", "Orthopedics", "General Medicine", "Dermatology", "Emergency Medicine", "Anesthesiology", "Radiology", "Psychiatry"];
    final seniorities = ["Junior", "Mid-level", "Senior", "Consultant"];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Doctor'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSpecialization,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    border: OutlineInputBorder(),
                  ),
                  items: specializations.map((spec) => DropdownMenuItem(
                    value: spec,
                    child: Text(spec),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedSpecialization = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSeniority,
                  decoration: const InputDecoration(
                    labelText: 'Seniority',
                    border: OutlineInputBorder(),
                  ),
                  items: seniorities.map((sen) => DropdownMenuItem(
                    value: sen,
                    child: Text(sen),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedSeniority = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty &&
                    selectedSpecialization != null &&
                    selectedSeniority != null) {
                  final success = await context.read<DoctorProvider>().updateDoctor(
                    doctorId: doctor.id!,
                    name: nameController.text.trim(),
                    specialization: selectedSpecialization!,
                    seniority: selectedSeniority!,
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Doctor updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(List<Doctor> doctors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doctors.length == 1 ? 'Delete Doctor' : 'Delete Doctors'),
        content: Text(
          doctors.length == 1
              ? 'Are you sure you want to delete "${doctors.first.name}"?'
              : 'Are you sure you want to delete ${doctors.length} selected doctors?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final doctorIds = doctors.map((d) => d.id!).toList();
              final success = await context.read<DoctorProvider>().deleteDoctors(doctorIds);

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      doctors.length == 1
                          ? 'Doctor deleted successfully'
                          : '${doctors.length} doctors deleted successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Doctors Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DoctorProvider>().refreshData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<DoctorProvider>(
        builder: (context, doctorProvider, child) {
          return Column(
            children: [
              // Search and Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search doctors by name, specialization, or seniority...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            doctorProvider.setSearchQuery('');
                          },
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) => doctorProvider.setSearchQuery(value),
                    ),

                    const SizedBox(height: 12),

                    // Filter Row
                    Row(
                      children: [
                        // Specialization Filter
                        Expanded(
                          flex: 2,

                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: doctorProvider.selectedSpecializationFilter.isEmpty
                                ? null
                                : doctorProvider.selectedSpecializationFilter,
                            decoration: InputDecoration(
                              labelText: 'Filter by Specialization',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Specializations'),
                              ),
                              ...doctorProvider.availableSpecializations.map(
                                    (spec) => DropdownMenuItem<String>(
                                  value: spec,
                                  child: Text('$spec (${doctorProvider.specializationCounts[spec] ?? 0})'),
                                ),
                              ),
                            ],
                            onChanged: (value) => doctorProvider.setSpecializationFilter(value ?? ''),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Seniority Filter
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: doctorProvider.selectedSeniorityFilter.isEmpty
                                ? null
                                : doctorProvider.selectedSeniorityFilter,
                            decoration: InputDecoration(
                              labelText: 'Filter by Seniority',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Seniorities'),
                              ),
                              ...doctorProvider.getAvailableSeniorities().map(
                                    (sen) => DropdownMenuItem<String>(
                                  value: sen,
                                  child: Text(sen),
                                ),
                              ),
                            ],
                            onChanged: (value) => doctorProvider.setSeniorityFilter(value ?? ''),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Clear Filters Button
                        if (doctorProvider.hasActiveFilters)
                          ElevatedButton.icon(
                            onPressed: doctorProvider.clearFilters,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Statistics and Selection Bar
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Showing ${doctorProvider.displayedDoctors.length} of ${doctorProvider.allDoctors.length} doctors',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (doctorProvider.hasSelection)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                             Row(children: [
                               Text('${doctorProvider.selectionCount} selected'),
                               IconButton(
                                 iconSize: 25,
                                 onPressed: () {
                                   final selectedDoctors = doctorProvider.displayedDoctors
                                       .where((doctor) => doctorProvider.isDoctorSelected(doctor.id!))
                                       .toList();
                                   _showDeleteConfirmation(selectedDoctors);
                                 },
                                 color: Colors.red,
                                 icon: const Icon(Icons.delete,),
                               ),
                             ],),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: doctorProvider.clearSelection,
                                child: const Text('Clear Selection'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Error/Success Messages
              if (doctorProvider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(doctorProvider.errorMessage!)),
                      IconButton(
                        onPressed: doctorProvider.clearError,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

              // Loading Indicator
              if (doctorProvider.isLoading)
                const LinearProgressIndicator(),

              // Data Table
              Expanded(
                child: doctorProvider.displayedDoctors.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        doctorProvider.allDoctors.isEmpty
                            ? 'No doctors added yet'
                            : 'No doctors match your search criteria',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Doctor'),
                      ),
                    ],
                  ),
                )
                    : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width,
                    ),
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.primaryContainer,
                      ),
                      columns: [
                        DataColumn(
                          label: InkWell(
                            onTap: () => doctorProvider.toggleSort('id'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('ID'),
                                if (doctorProvider.sortColumn == 'id')
                                  Icon(
                                    doctorProvider.sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataColumn(
                          label: InkWell(
                            onTap: () => doctorProvider.toggleSort('name'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Name'),
                                if (doctorProvider.sortColumn == 'name')
                                  Icon(
                                    doctorProvider.sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataColumn(
                          label: InkWell(
                            onTap: () => doctorProvider.toggleSort('specialization'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Specialization'),
                                if (doctorProvider.sortColumn == 'specialization')
                                  Icon(
                                    doctorProvider.sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataColumn(
                          label: InkWell(
                            onTap: () => doctorProvider.toggleSort('seniority'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Seniority'),
                                if (doctorProvider.sortColumn == 'seniority')
                                  Icon(
                                    doctorProvider.sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const DataColumn(
                          label: Text('Actions'),
                        ),
                      ],
                      rows: doctorProvider.displayedDoctors.map((doctor) {
                        final isSelected = doctorProvider.isDoctorSelected(doctor.id!);
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (selected) {
                            doctorProvider.toggleDoctorSelection(doctor.id!);
                          },
                          cells: [
                            DataCell(Text(doctor.id.toString())),
                            DataCell(
                              Text(
                                doctor.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doctor.specialization ?? '',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getSeniorityColor(doctor.seniority ?? ''),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doctor.seniority ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _showEditDialog(doctor),
                                    tooltip: 'Edit Doctor',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    onPressed: () => _showDeleteConfirmation([doctor]),
                                    tooltip: 'Delete Doctor',
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
              ),
            ],
          );
        },
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