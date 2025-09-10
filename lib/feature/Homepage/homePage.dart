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
      resizeToAvoidBottomInset: false, // Prevents FAB from moving with keyboard

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

      // Fixed FAB positioning
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 30),
        onPressed: () {
          Navigator.pushNamed(context, Routes.NewScheduleScreenRoute);
        },
      ),

      // Simplified BottomAppBar with manual navigation
      bottomNavigationBar: BottomAppBar(
        color: Colors.green,
        elevation: 0,
        notchMargin: 8,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(20)) ), // outer shape
          RoundedRectangleBorder( // 👈 makes notch rectangular
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home button
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => index = 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home,
                        color: index == 0 ? Colors.white : Colors.white70,
                        size: 30,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Home",
                        style: TextStyle(
                          color: index == 0 ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Space for FAB
              const SizedBox(width: 80),

              // Add Doctor button
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => index = 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_reaction_rounded,
                        color: index == 1 ? Colors.white : Colors.white70,
                        size: 30,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Add Doctor",
                        style: TextStyle(
                          color: index == 1 ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Body with proper overflow handling
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: tabs,
        ),
      ),
    );
  }
}