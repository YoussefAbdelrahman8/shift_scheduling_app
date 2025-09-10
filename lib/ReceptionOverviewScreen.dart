// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
//
// // Import your ScheduleSession provider
// // import 'path/to/schedule_session.dart';
//
// class ReceptionOverviewScreen extends StatefulWidget {
//   const ReceptionOverviewScreen({Key? key}) : super(key: key);
//
//   @override
//   State<ReceptionOverviewScreen> createState() => _ReceptionOverviewScreenState();
// }
//
// class _ReceptionOverviewScreenState extends State<ReceptionOverviewScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<ScheduleSession>(
//         builder: (context, session, child) {
//           // Get all doctors with reception data
//           final doctorsWithData = session.doctorsWithReceptionData.toList();
//
//           if (doctorsWithData.isEmpty) {
//             return const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.inbox, size: 64, color: Colors.grey),
//                   SizedBox(height: 16),
//                   Text(
//                     'No reception data available',
//                     style: TextStyle(fontSize: 18, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             );
//           }
//
//           return SingleChildScrollView(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Reception Schedule Overview',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 20),
//                 _buildReceptionTable(context, session, doctorsWithData),
//               ],
//             ),
//           );
//         },
//       );
//   }
//
//   Widget _buildReceptionTable(BuildContext context, ScheduleSession session, List<int> doctorIds) {
//     return Card(
//       elevation: 4,
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: DataTable(
//           columnSpacing: 20,
//           headingRowColor: MaterialStateProperty.all(Colors.teal.shade50),
//           columns: const [
//             DataColumn(label: Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Total\nShifts', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Morning\nShifts', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Evening\nShifts', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Remaining\nShifts', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Wanted\nDays', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Exception\nDays', style: TextStyle(fontWeight: FontWeight.bold))),
//             DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
//           ],
//           rows: doctorIds.map((doctorId) {
//             final doctor = session.doctors.firstWhere(
//                   (doc) => doc['id'] == doctorId,
//               orElse: () => {'id': doctorId, 'name': 'Unknown Doctor'},
//             );
//             final constraints = session.getReceptionConstraints(doctorId) ?? {};
//             final wantedDays = session.getWantedDays(doctorId);
//             final exceptionDays = session.getExceptionDays(doctorId);
//
//             final totalShifts = constraints['totalShifts'] ?? 0;
//             final morningShifts = constraints['morningShifts'] ?? 0;
//             final eveningShifts = constraints['eveningShifts'] ?? 0;
//             final remainingShifts = totalShifts - (morningShifts + eveningShifts);
//
//             return DataRow(
//               cells: [
//                 DataCell(Text(doctor['name'] ?? 'Unknown')),
//                 DataCell(Text(totalShifts.toString())),
//                 DataCell(Text(morningShifts.toString())),
//                 DataCell(Text(eveningShifts.toString())),
//                 DataCell(
//                   Text(
//                     remainingShifts.toString(),
//                     style: TextStyle(
//                       color: remainingShifts < 0 ? Colors.red : Colors.green,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//                 DataCell(
//                   InkWell(
//                     onTap: () => _showDaysDialog(context, session, doctorId, doctor['name'], 'wanted', wantedDays),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.blue.shade100,
//                         borderRadius: BorderRadius.circular(15),
//                       ),
//                       child: Text(
//                         '${wantedDays.length}',
//                         style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ),
//                 ),
//                 DataCell(
//                   InkWell(
//                     onTap: () => _showDaysDialog(context, session, doctorId, doctor['name'], 'exception', exceptionDays),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.shade100,
//                         borderRadius: BorderRadius.circular(15),
//                       ),
//                       child: Text(
//                         '${exceptionDays.length}',
//                         style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ),
//                 ),
//                 DataCell(
//                   Row(
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.edit, color: Colors.blue),
//                         onPressed: () => _showEditConstraintsDialog(context, session, doctorId, doctor['name'], constraints),
//                         tooltip: 'Edit Constraints',
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.delete, color: Colors.red),
//                         onPressed: () => _confirmDelete(context, session, doctorId, doctor['name']),
//                         tooltip: 'Delete',
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }
//
//   void _showEditConstraintsDialog(BuildContext context, ScheduleSession session, int doctorId, String doctorName, Map<String, dynamic> currentConstraints) {
//     final totalController = TextEditingController(text: (currentConstraints['totalShifts'] ?? 0).toString());
//     final morningController = TextEditingController(text: (currentConstraints['morningShifts'] ?? 0).toString());
//     final eveningController = TextEditingController(text: (currentConstraints['eveningShifts'] ?? 0).toString());
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Edit Constraints - $doctorName'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextField(
//                   controller: totalController,
//                   decoration: const InputDecoration(
//                     labelText: 'Total Shifts',
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.number,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 ),
//                 const SizedBox(height: 16),
//                 TextField(
//                   controller: morningController,
//                   decoration: const InputDecoration(
//                     labelText: 'Morning Shifts',
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.number,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 ),
//                 const SizedBox(height: 16),
//                 TextField(
//                   controller: eveningController,
//                   decoration: const InputDecoration(
//                     labelText: 'Evening Shifts',
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.number,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final total = int.tryParse(totalController.text) ?? 0;
//                 final morning = int.tryParse(morningController.text) ?? 0;
//                 final evening = int.tryParse(eveningController.text) ?? 0;
//
//                 if ((morning + evening) > total) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Morning + Evening shifts cannot exceed Total shifts'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                   return;
//                 }
//
//                 session.saveReceptionConstraints(
//                   doctorId: doctorId,
//                   totalShifts: total,
//                   morningShifts: morning,
//                   eveningShifts: evening,
//                 );
//
//                 Navigator.of(context).pop();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Constraints updated for $doctorName'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
//               child: const Text('Save'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _showDaysDialog(BuildContext context, ScheduleSession session, int doctorId, String doctorName, String type, List<Map<String, dynamic>> days) {
//     final shifts = ['Morning', 'Evening'];
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('${type == 'wanted' ? 'Wanted' : 'Exception'} Days - $doctorName'),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     if (days.isEmpty)
//                       const Padding(
//                         padding: EdgeInsets.all(20.0),
//                         child: Text('No days configured'),
//                       )
//                     else
//                       Flexible(
//                         child: ListView.builder(
//                           shrinkWrap: true,
//                           itemCount: days.length,
//                           itemBuilder: (context, index) {
//                             final day = days[index];
//                             return Card(
//                               child: ListTile(
//                                 leading: CircleAvatar(
//                                   backgroundColor: day['shift'] == 'Morning' ? Colors.amber : Colors.indigo,
//                                   child: Icon(
//                                     day['shift'] == 'Morning' ? Icons.wb_sunny : Icons.nights_stay,
//                                     color: Colors.white,
//                                     size: 20,
//                                   ),
//                                 ),
//                                 title: Text(day['date'] ?? 'Unknown date'),
//                                 subtitle: Text(day['shift'] ?? 'Unknown shift'),
//                                 trailing: IconButton(
//                                   icon: const Icon(Icons.delete, color: Colors.red),
//                                   onPressed: () {
//                                     setState(() {
//                                       days.removeAt(index);
//                                     });
//
//                                     // Update provider
//                                     final wantedDays = type == 'wanted' ? List<Map<String, dynamic>>.from(days) : session.getWantedDays(doctorId);
//                                     final exceptionDays = type == 'exception' ? List<Map<String, dynamic>>.from(days) : session.getExceptionDays(doctorId);
//
//                                     session.saveDoctorRequests(
//                                       doctorId: doctorId,
//                                       wantedDays: wantedDays,
//                                       exceptionDays: exceptionDays,
//                                     );
//                                   },
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     const Divider(),
//                     ElevatedButton.icon(
//                       onPressed: () {
//                         _showAddDayDialog(context, session, doctorId, type, () {
//                           Navigator.of(context).pop();
//                           // Refresh the dialog
//                           final updatedDays = type == 'wanted' ? session.getWantedDays(doctorId) : session.getExceptionDays(doctorId);
//                           _showDaysDialog(context, session, doctorId, doctorName, type, updatedDays);
//                         });
//                       },
//                       icon: const Icon(Icons.add),
//                       label: Text('Add ${type == 'wanted' ? 'Wanted' : 'Exception'} Day'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: type == 'wanted' ? Colors.blue : Colors.orange,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(),
//                   child: const Text('Close'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _showAddDayDialog(BuildContext context, ScheduleSession session, int doctorId, String type, VoidCallback onSuccess) {
//     final dateController = TextEditingController();
//     String? selectedShift;
//     final shifts = ['Morning', 'Evening'];
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Add ${type == 'wanted' ? 'Wanted' : 'Exception'} Day'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField(
//                     controller: dateController,
//                     readOnly: true,
//                     decoration: InputDecoration(
//                       labelText: 'Date',
//                       border: const OutlineInputBorder(),
//                       suffixIcon: const Icon(Icons.calendar_today),
//                       fillColor: Colors.grey[100],
//                       filled: true,
//                     ),
//                     onTap: () async {
//                       DateTime? picked = await showDatePicker(
//                         context: context,
//                         initialDate: DateTime.now(),
//                         firstDate: DateTime(2020),
//                         lastDate: DateTime(2100),
//                       );
//                       if (picked != null) {
//                         dateController.text = picked.toIso8601String().split('T').first;
//                       }
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   DropdownButtonFormField<String>(
//                     decoration: InputDecoration(
//                       labelText: 'Shift',
//                       border: const OutlineInputBorder(),
//                       fillColor: Colors.grey[100],
//                       filled: true,
//                     ),
//                     value: selectedShift,
//                     items: shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
//                     onChanged: (val) {
//                       setState(() {
//                         selectedShift = val;
//                       });
//                     },
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(),
//                   child: const Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (dateController.text.isEmpty || selectedShift == null) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('Please select both date and shift'),
//                           backgroundColor: Colors.red,
//                         ),
//                       );
//                       return;
//                     }
//
//                     final wantedDays = List<Map<String, dynamic>>.from(session.getWantedDays(doctorId));
//                     final exceptionDays = List<Map<String, dynamic>>.from(session.getExceptionDays(doctorId));
//
//                     if (type == 'wanted') {
//                       wantedDays.add({
//                         'date': dateController.text,
//                         'shift': selectedShift,
//                       });
//                     } else {
//                       exceptionDays.add({
//                         'date': dateController.text,
//                         'shift': selectedShift,
//                       });
//                     }
//
//                     session.saveDoctorRequests(
//                       doctorId: doctorId,
//                       wantedDays: wantedDays,
//                       exceptionDays: exceptionDays,
//                     );
//
//                     Navigator.of(context).pop();
//                     onSuccess();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: type == 'wanted' ? Colors.blue : Colors.orange,
//                   ),
//                   child: const Text('Add'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _confirmDelete(BuildContext context, ScheduleSession session, int doctorId, String doctorName) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Confirm Delete'),
//           content: Text('Are you sure you want to delete all reception data for $doctorName?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 // Remove from provider
//                 session.receptionConstraints.remove(doctorId);
//                 session.doctorRequests.remove(doctorId);
//                 session.doctorsWithReceptionData.remove(doctorId);
//                 session.notifyListeners();
//
//                 Navigator.of(context).pop();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Reception data deleted for $doctorName'),
//                     backgroundColor: Colors.orange,
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               child: const Text('Delete'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }