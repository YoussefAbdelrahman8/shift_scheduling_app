import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/SectionShiftProvider.dart';

class InsertSectionShiftScreen extends StatefulWidget {
  final VoidCallback? onSessionComplete;
  const InsertSectionShiftScreen({Key? key, this.onSessionComplete}) : super(key: key);

  @override
  State<InsertSectionShiftScreen> createState() => _InsertSectionShiftScreenState();
}

class _InsertSectionShiftScreenState extends State<InsertSectionShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  List<TextEditingController> dateControllers = [];

  // Responsive helper methods
  double _getScreenHeight() => MediaQuery.of(context).size.height;
  double _getScreenWidth() => MediaQuery.of(context).size.width;

  // Responsive padding
  double _getHorizontalPadding() => _getScreenWidth() * 0.06; // 6% of screen width
  double _getVerticalPadding() => _getScreenHeight() * 0.025; // 2.5% of screen height

  // Responsive spacing
  double _getSmallSpacing() => _getScreenHeight() * 0.015; // 1.5% of screen height
  double _getMediumSpacing() => _getScreenHeight() * 0.025; // 2.5% of screen height
  double _getLargeSpacing() => _getScreenHeight() * 0.037; // 3.7% of screen height

  // Responsive font sizes
  double _getHeadingFontSize() => _getScreenWidth() * 0.045; // 4.5% of screen width
  double _getTitleFontSize() => _getScreenWidth() * 0.04; // 4% of screen width
  double _getBodyFontSize() => _getScreenWidth() * 0.035; // 3.5% of screen width
  double _getSmallFontSize() => _getScreenWidth() * 0.03; // 3% of screen width

  // Responsive icon sizes
  double _getLargeIconSize() => _getScreenWidth() * 0.16; // 16% of screen width
  double _getMediumIconSize() => _getScreenWidth() * 0.08; // 8% of screen width
  double _getSmallIconSize() => _getScreenWidth() * 0.04; // 4% of screen width
  double _getExtraSmallIconSize() => _getScreenWidth() * 0.035; // 3.5% of screen width

  // Responsive border radius
  double _getBorderRadius() => _getScreenWidth() * 0.03; // 3% of screen width

  // Responsive container padding
  EdgeInsets _getContainerPadding() => EdgeInsets.all(_getScreenWidth() * 0.04); // 4% of screen width

  // Responsive button padding
  EdgeInsets _getButtonPadding() => EdgeInsets.symmetric(vertical: _getScreenHeight() * 0.015); // 1.5% of screen height

  @override
  void initState() {
    super.initState();
    _addDateField();

    // Initialize for current session instead of starting a new one
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SectionShiftProvider>();
      provider.initializeForSession();
      provider.clearAllMessages();
    });
  }

  void _addDateField() {
    setState(() {
      dateControllers.add(TextEditingController());
    });
  }

  void _removeDateField(int index) {
    if (dateControllers.length > 1) {
      setState(() {
        dateControllers[index].dispose();
        dateControllers.removeAt(index);
      });
    }
  }

  Future<void> _selectDate(int index) async {
    final provider = context.read<SectionShiftProvider>();

    // Get the current month from provider to restrict date selection
    final currentMonth = provider.currentMonth;
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime.now();
    DateTime lastDate = DateTime.now();

    if (currentMonth != null) {
      // Parse current month (YYYY-MM) and set date constraints
      final year = int.parse(currentMonth.substring(0, 4));
      final month = int.parse(currentMonth.substring(5, 7));

      firstDate = DateTime(year, month, 1);
      lastDate = DateTime(year, month + 1, 0); // Last day of the month

      // Set initial date to first day of the month if current date is outside range
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
      final dateString = picked.toIso8601String().split('T').first;
      dateControllers[index].text = dateString;

      // Update provider with selected dates
      _updateProviderDates();
    }
  }

  void _updateProviderDates() {
    final provider = context.read<SectionShiftProvider>();
    provider.clearDates();

    for (var controller in dateControllers) {
      if (controller.text.isNotEmpty) {
        provider.addDate(controller.text);
      }
    }
  }

  Future<void> _saveSchedules() async {
    if (_formKey.currentState?.validate() ?? false) {
      _updateProviderDates();

      final provider = context.read<SectionShiftProvider>();
      final success = await provider.saveSectionShifts();

      if (success) {
        // Clear date fields for next entry
        for (var controller in dateControllers) {
          controller.clear();
        }

        // Reset to one date field
        for (int i = dateControllers.length - 1; i > 0; i--) {
          dateControllers[i].dispose();
          dateControllers.removeAt(i);
        }

        // Call completion callback if provided
        if (widget.onSessionComplete != null) {
          widget.onSessionComplete!();
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.successMessage ?? 'Section shifts saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _resetForm() {
    final provider = context.read<SectionShiftProvider>();
    provider.resetCurrentForm();

    for (var controller in dateControllers) {
      controller.clear();
    }

    // Reset to one date field
    for (int i = dateControllers.length - 1; i > 0; i--) {
      dateControllers[i].dispose();
      dateControllers.removeAt(i);
    }

    setState(() {});
  }

  @override
  void dispose() {
    for (var controller in dateControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SectionShiftProvider>(
      builder: (context, provider, _) {
        // Check if session is active
        if (!provider.isSessionActive) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    Icons.calendar_month,
                    size: _getLargeIconSize(),
                    color: Colors.grey
                ),
                SizedBox(height: _getMediumSpacing()),
                Text(
                  'No active session.',
                  style: TextStyle(
                      fontSize: _getHeadingFontSize(),
                      fontWeight: FontWeight.w500
                  ),
                ),
                SizedBox(height: _getSmallSpacing()),
                Text(
                  'Please start a schedule session from the main screen.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: _getBodyFontSize(),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Get filtered lists for UX - only unassigned doctors and specializations
        final availableSpecializations = provider.getAvailableSpecializationsWithDoctors();
        final availableDoctors = provider.selectedSpecialization != null
            ? provider.getAvailableDoctorsForSpecialization(provider.selectedSpecialization!)
            : <dynamic>[];

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: _getHorizontalPadding(),
                vertical: _getVerticalPadding()
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Info Card
                  Container(
                    width: double.infinity,
                    padding: _getContainerPadding(),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(_getBorderRadius()),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.blue[700], size: _getSmallIconSize()),
                            SizedBox(width: _getSmallSpacing()),
                            Expanded(
                              child: Text(
                                'Schedule Session: ${provider.currentMonth}',
                                style: TextStyle(
                                  fontSize: _getHeadingFontSize(),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _getMediumSpacing()),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                'Specializations',
                                '${availableSpecializations.length}',
                                Icons.medical_services,
                              ),
                            ),
                            Expanded(
                              child: _buildInfoItem(
                                'Shifts Added',
                                '${provider.totalSectionShiftsCount}',
                                Icons.assignment_turned_in,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: _getLargeSpacing()),

                  // Error Message Display
                  if (provider.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(_getScreenWidth() * 0.03),
                      margin: EdgeInsets.only(bottom: _getMediumSpacing()),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(_getBorderRadius() * 0.7),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: _getExtraSmallIconSize()
                          ),
                          SizedBox(width: _getSmallSpacing()),
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: _getBodyFontSize(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => provider.clearError(),
                            icon: Icon(
                                Icons.close,
                                color: Colors.red.shade700,
                                size: _getExtraSmallIconSize()
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // Success Message Display
                  if (provider.successMessage != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(_getScreenWidth() * 0.03),
                      margin: EdgeInsets.only(bottom: _getMediumSpacing()),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(_getBorderRadius() * 0.7),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: _getExtraSmallIconSize()
                          ),
                          SizedBox(width: _getSmallSpacing()),
                          Expanded(
                            child: Text(
                              provider.successMessage!,
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: _getBodyFontSize(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => provider.clearSuccess(),
                            icon: Icon(
                                Icons.close,
                                color: Colors.green.shade700,
                                size: _getExtraSmallIconSize()
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // Loading Indicator
                  if (provider.isLoading)
                    const LinearProgressIndicator(),

                  SizedBox(height: _getMediumSpacing()),

                  // Specialization Dropdown - shows only specializations with unassigned doctors
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Medical Specialization',
                      labelStyle: TextStyle(fontSize: _getBodyFontSize()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_getBorderRadius())),
                      filled: true,
                      fillColor: Colors.grey[50],
                      prefixIcon: Icon(Icons.medical_services, size: _getSmallIconSize()),
                      helperText: availableSpecializations.isEmpty
                          ? 'All specializations completed!'
                          : '${availableSpecializations.length} specializations available',
                      helperStyle: TextStyle(fontSize: _getSmallFontSize()),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _getScreenWidth() * 0.04,
                        vertical: _getScreenHeight() * 0.02,
                      ),
                    ),
                    style: TextStyle(fontSize: _getBodyFontSize(), color: Colors.black),
                    value: availableSpecializations.contains(provider.selectedSpecialization)
                        ? provider.selectedSpecialization
                        : null,
                    items: availableSpecializations.map((spec) {
                      final availableCount = provider.getAvailableDoctorCountForSpecialization(spec);
                      return DropdownMenuItem<String>(
                        value: spec,
                        child: Text(
                          '$spec (# $availableCount)',
                          style: TextStyle(fontSize: _getBodyFontSize()),
                        ),
                      );
                    }).toList(),
                    onChanged: provider.isLoading ? null : (val) async {
                      await provider.setSelectedSpecialization(val);
                    },
                    validator: (val) => val == null ? 'Please select a specialization' : null,
                  ),

                  SizedBox(height: _getMediumSpacing()),

                  // Doctor Dropdown - shows only unassigned doctors
                  if (provider.selectedSpecialization != null && availableDoctors.isNotEmpty)
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Doctor',
                        labelStyle: TextStyle(fontSize: _getBodyFontSize()),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_getBorderRadius())),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: Icon(Icons.person, size: _getSmallIconSize()),
                        helperText: '${availableDoctors.length} doctors available in ${provider.selectedSpecialization}',
                        helperStyle: TextStyle(fontSize: _getSmallFontSize()),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: _getScreenWidth() * 0.04,
                          vertical: _getScreenHeight() * 0.02,
                        ),
                      ),
                      style: TextStyle(fontSize: _getBodyFontSize(), color: Colors.black),
                      value: availableDoctors.any((d) => d.id == provider.selectedDoctorId)
                          ? provider.selectedDoctorId
                          : null,
                      items: availableDoctors.map((doctor) {
                        return DropdownMenuItem<int>(
                          value: doctor.id,
                          child: Text(
                            '${doctor.name} • ${doctor.seniority}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: _getBodyFontSize(),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: provider.isLoading ? null : (val) {
                        provider.setSelectedDoctorId(val);
                      },
                      validator: (val) => val == null ? 'Please select a doctor' : null,
                    ),

                  // Message when no doctors available in selected specialization
                  if (provider.selectedSpecialization != null && availableDoctors.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: _getContainerPadding(),
                      margin: EdgeInsets.symmetric(vertical: _getSmallSpacing()),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(_getBorderRadius() * 0.7),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: _getSmallIconSize()),
                          SizedBox(width: _getSmallSpacing()),
                          Expanded(
                            child: Text(
                              'All doctors in ${provider.selectedSpecialization} have been assigned shifts. Please select another specialization.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: _getBodyFontSize(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: _getMediumSpacing()),

                  // Date Fields Section
                  if (provider.selectedDoctorId != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue[700], size: _getSmallIconSize()),
                        SizedBox(width: _getSmallSpacing()),
                        Expanded(
                          child: Text(
                            'Select Dates for Section Shifts',
                            style: TextStyle(
                              fontSize: _getTitleFontSize(),
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _getSmallSpacing() * 0.5),
                    Text(
                      'Add one or more dates when this doctor will work section shifts',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: _getSmallFontSize(),
                      ),
                    ),
                    SizedBox(height: _getMediumSpacing()),
                    ..._buildDateFields(),
                  ],

                  SizedBox(height: _getMediumSpacing()),

                  // Add Another Date Button
                  if (provider.selectedDoctorId != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: provider.isLoading ? null : _addDateField,
                        icon: Icon(Icons.add, size: _getExtraSmallIconSize()),
                        label: Text(
                          'Add Another Date',
                          style: TextStyle(fontSize: _getBodyFontSize()),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: _getButtonPadding(),
                          side: BorderSide(color: Colors.blue[300]!),
                        ),
                      ),
                    ),

                  SizedBox(height: _getLargeSpacing()),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Reset Button
                      if (provider.hasUnsavedData)
                        Expanded(
                          child: IconButton(
                            onPressed: provider.isLoading ? null : _resetForm,
                            icon: Icon(Icons.refresh, size: _getMediumIconSize()),
                            style: OutlinedButton.styleFrom(
                              padding: _getButtonPadding(),
                            ),
                          ),
                        ),

                      if (provider.hasUnsavedData) SizedBox(width: _getMediumSpacing()),

                      // Save Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: provider.canSave && !provider.isLoading ? _saveSchedules : null,
                          icon: provider.isLoading
                              ? SizedBox(
                            height: _getExtraSmallIconSize(),
                            width: _getExtraSmallIconSize(),
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Icon(Icons.save, size: _getExtraSmallIconSize()),
                          label: Text(
                            provider.isLoading ? 'Saving...' : 'Save Section Shifts',
                            style: TextStyle(fontSize: _getBodyFontSize()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: _getButtonPadding(),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius())),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: _getLargeSpacing()),
                  // Completion message when all specializations are done
                  if (availableSpecializations.isEmpty && provider.hasCompletedSectionShifts)
                    Container(
                      width: double.infinity,
                      padding: _getContainerPadding(),
                      margin: EdgeInsets.only(top: _getMediumSpacing()),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(_getBorderRadius()),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.celebration, color: Colors.blue[700], size: _getMediumIconSize()),
                          SizedBox(height: _getSmallSpacing()),
                          Text(
                            'All Specializations Completed!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: _getTitleFontSize(),
                            ),
                          ),
                          SizedBox(height: _getSmallSpacing()),
                          Text(
                            'You have successfully assigned section shifts to all doctors. Ready to proceed to the next step.',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: _getBodyFontSize(),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: _getExtraSmallIconSize(), color: Colors.blue[600]),
            SizedBox(width: _getSmallSpacing() * 0.5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: _getSmallFontSize(),
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: _getSmallSpacing() * 0.5),
        Text(
          value,
          style: TextStyle(
            fontSize: _getTitleFontSize(),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: _getSmallSpacing() * 0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
                fontSize: _getBodyFontSize(),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
              fontSize: _getBodyFontSize(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDateFields() {
    return dateControllers.asMap().entries.map((entry) {
      int index = entry.key;
      TextEditingController controller = entry.value;

      return Padding(
        padding: EdgeInsets.only(bottom: _getMediumSpacing()),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                readOnly: true,
                onTap: () => _selectDate(index),
                style: TextStyle(fontSize: _getBodyFontSize()),
                decoration: InputDecoration(
                  labelText: 'Date #${index + 1}',
                  labelStyle: TextStyle(fontSize: _getBodyFontSize()),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(_getBorderRadius())),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: Icon(Icons.calendar_today, size: _getSmallIconSize()),
                  helperText: controller.text.isNotEmpty
                      ? 'Selected: ${controller.text}'
                      : 'Tap to select date',
                  helperStyle: TextStyle(fontSize: _getSmallFontSize()),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: _getScreenWidth() * 0.04,
                    vertical: _getScreenHeight() * 0.02,
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please select a date' : null,
              ),
            ),
            if (dateControllers.length > 1)
              Padding(
                padding: EdgeInsets.only(left: _getSmallSpacing()),
                child: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: _getSmallIconSize()),
                  onPressed: () => _removeDateField(index),
                  tooltip: 'Remove this date',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_getBorderRadius() * 0.7),
                    ),
                    padding: EdgeInsets.all(_getScreenWidth() * 0.02),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }
}