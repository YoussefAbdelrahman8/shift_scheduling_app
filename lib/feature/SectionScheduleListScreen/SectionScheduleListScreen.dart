import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class PendingSchedulesTable extends StatelessWidget {
  const PendingSchedulesTable({Key? key}) : super(key: key);

  Future<void> _editDate(
      BuildContext context, int index, Map<String, dynamic> record) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(record['date']) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['date'] = picked.toIso8601String().split('T').first;

      Provider.of<ScheduleSession>(context, listen: false)
          .updatePendingSchedule(index, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleSession>(
      builder: (context, session, _) {
        if (session.pendingSchedules.isEmpty) {
          return const Center(
            child: Text("No schedules added yet."),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text("Doctor")),
              DataColumn(label: Text("Specialization")),
              DataColumn(label: Text("Date")),
              DataColumn(label: Text("Actions")),
            ],
            rows: session.pendingSchedules.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> record = entry.value;

              return DataRow(
                cells: [
                  DataCell(Text(record['doctorName'] ?? '')),
                  DataCell(Text(record['specialization'] ?? '')),
                  DataCell(Text(record['date'] ?? '')),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editDate(context, index, record),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Provider.of<ScheduleSession>(context,
                                listen: false)
                                .removePendingSchedule(index);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
