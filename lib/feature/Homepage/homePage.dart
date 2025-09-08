import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shift_scheduling_app/core/routes_manager/routes.dart';
import 'package:shift_scheduling_app/feature/insertDoctor/insertDoctorScreen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  final tabs = [
    const Center(child: Text("My Home Screen", style: TextStyle(fontSize: 18))),
    const InsertDoctor(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: const Text(
          "Welcome Back 👋",
          style: TextStyle(color: Colors.white, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              setState(() => index = 1);
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, Routes.SignInRoute);
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          )
        ],
      ),

      // 👇 Square Floating Action Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // 👈 makes it square
        ),
        child: const Icon(Icons.add_shopping_cart, color: Colors.white,size: 30,),
        onPressed: () {
          Navigator.pushNamed(context, Routes.NewScheduleScreenRoute);
        },
      ),

      // 👇 Custom Notched App Bar to match square FAB
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 5),
        color: Colors.green,
        elevation: 0,
        notchMargin: 8,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(100)) ), // outer shape
          RoundedRectangleBorder( // 👈 makes notch rectangular
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        child: BottomNavigationBar(
          iconSize: 30,
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: index,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          onTap: (i) => setState(() => index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_reaction_rounded),
              label: "Add Doctor",
            ),
          ],
        ),
      ),

      // 👇 Body
      body: tabs[index],
    );
  }

}
