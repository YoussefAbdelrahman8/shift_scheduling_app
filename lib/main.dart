import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shift_scheduling_app/providers/CoreSessionProvider.dart';
import 'package:shift_scheduling_app/providers/DoctorConstraintProvider.dart';
import 'package:shift_scheduling_app/providers/DoctorProvider.dart';

import 'package:shift_scheduling_app/providers/SchedulingSessionProvider.dart';
import 'package:shift_scheduling_app/providers/SectionShiftProvider.dart';
import 'core/routes_manager/route_generator.dart';
import 'core/routes_manager/routes.dart';
import 'db/DBHelper.dart';


void main() async{

  WidgetsFlutterBinding.ensureInitialized();

  var db = DatabaseHelper.instance;
  await db.database;

  runApp(
      MultiProvider(
          providers: [
            // First create CoreSessionProvider
            ChangeNotifierProvider(
              create: (_) => CoreSessionProvider(),
            ),
            // Then create DoctorProvider that depends on CoreSessionProvider
            ChangeNotifierProxyProvider<CoreSessionProvider, DoctorProvider>(
              create: (context) => DoctorProvider(
                Provider.of<CoreSessionProvider>(context, listen: false),
              ),
              update: (context, sessionProvider, previousDoctorProvider) =>
              previousDoctorProvider ?? DoctorProvider(sessionProvider),
            ),
            // Schedule session provider depends on core
            ChangeNotifierProxyProvider<CoreSessionProvider, ScheduleSessionProvider>(
              create: (context) => ScheduleSessionProvider(
                Provider.of<CoreSessionProvider>(context, listen: false),
              ),
              update: (context, coreProvider, previousScheduleProvider) =>
              previousScheduleProvider ?? ScheduleSessionProvider(coreProvider),
            ),

            // Section shift provider depends on schedule session
            ChangeNotifierProxyProvider<ScheduleSessionProvider, SectionShiftProvider>(
              create: (context) => SectionShiftProvider(
                Provider.of<ScheduleSessionProvider>(context, listen: false),
              ),
              update: (context, scheduleProvider, previousSectionProvider) =>
              previousSectionProvider ?? SectionShiftProvider(scheduleProvider),
            ),
            ChangeNotifierProxyProvider<ScheduleSessionProvider, DoctorConstraintProvider>(
              create: (context) => DoctorConstraintProvider(
                Provider.of<ScheduleSessionProvider>(context, listen: false),
              ),
              update: (context, scheduleProvider, previousDoctorConstraintProvider) =>
              previousDoctorConstraintProvider ?? DoctorConstraintProvider(scheduleProvider),
            ),

          ],
      child: const MyApp()));

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: RouteGenerator.getRoute,
      initialRoute: Routes.SignInRoute,
      title: 'Hospital Shift Scheduling',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

}