import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shift_scheduling_app/core/routes_manager/routes.dart';
import 'package:shift_scheduling_app/feature/Homepage/homePage.dart';
import 'package:shift_scheduling_app/feature/signup/signup.dart';

import '../../feature/Login/login.dart';
import '../../feature/NewScheduleScreen/NewScheduleScreen.dart';
import '../../feature/ReceptionDataScreen/ReceptionDataScreen.dart';

import '../../feature/insertDoctor/insertDoctorScreen.dart';
import '../../feature/insertSecSchedules/SectionScheduleScreen.dart';


class RouteGenerator {
  static Route<dynamic>? getRoute(RouteSettings settings) {
    final args = settings.arguments;
    switch (settings.name) {

        // case Routes.SignInRoute:
        // return MaterialPageRoute(builder: (_) =>  Login());
        // case Routes.SignUpRoute:
        // return MaterialPageRoute(builder: (_) =>  Signup());
        case Routes.insertDoctorScreenRoute:
        return MaterialPageRoute(builder: (_) =>  InsertDoctor());
        case Routes.insertSectionScheduleScreenRoute:
        return MaterialPageRoute(builder: (_) =>  SectionScheduleScreen());
        case Routes.ReceptionDataScreenRoute:
        return MaterialPageRoute(builder: (_) =>  ReceptionDataScreen());
        case Routes.HomePageRoute:
        return MaterialPageRoute(builder: (_) =>  HomePage());
        case Routes.NewScheduleScreenRoute:
        return MaterialPageRoute(builder: (_) =>  NewScheduleScreen());

    }
    return null;
  }
}
