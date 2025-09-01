import 'package:flutter/material.dart';
import '../../../../core/routes_manager/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, Routes.SignInRoute);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Hospital Management System',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.person_add,
                    title: 'Add Doctor',
                    subtitle: 'Add new doctors to the system',
                    onTap: () => Navigator.pushNamed(context, Routes.insertDoctorScreenRoute),
                  ),
                  const SizedBox(height: 15),
                  _buildMenuItem(
                    context,
                    icon: Icons.schedule,
                    title: 'Section Schedule',
                    subtitle: 'Manage section shifts and schedules',
                    onTap: () => Navigator.pushNamed(context, Routes.insertSectionScheduleScreenRoute),
                  ),
                  const SizedBox(height: 15),
                  _buildMenuItem(
                    context,
                    icon: Icons.assignment,
                    title: 'Reception Data',
                    subtitle: 'Set reception constraints and exceptions',
                    onTap: () => Navigator.pushNamed(context, Routes.ReceptionDataScreenRoute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue, size: 30),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}