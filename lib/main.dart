import 'package:flutter/material.dart';
import 'core/routes_manager/route_generator.dart';
import 'core/routes_manager/routes.dart';
import 'db/database_helper.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  var db = DatabaseHelper.instance;
  await db.database; // This will create the database + tables if not exist

  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: RouteGenerator.getRoute,
      initialRoute: Routes.ReceptionDataScreenRoute,
      title: 'Flutter Demo',
    );
  }

}
