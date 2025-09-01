import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shift_scheduling_app/core/routes_manager/routes.dart';
import 'package:shift_scheduling_app/feature/addDoctor/presentation/widgets/addDoctorScreen.dart';
import 'package:shift_scheduling_app/feature/signup/presentation/pages/signup.dart';

import '../../feature/Login/presentation/pages/login.dart';
import '../../feature/ReceptionDataScreen/presentation/widgets/ReceptionDataScreen.dart';
import '../../feature/insertSecSchedules/presentation/widgets/SectionScheduleScreen.dart';


class RouteGenerator {
  static Route<dynamic>? getRoute(RouteSettings settings) {
    final args = settings.arguments;
    switch (settings.name) {

        case Routes.SignInRoute:
        return MaterialPageRoute(builder: (_) =>  Login());
        case Routes.SignUpRoute:
        return MaterialPageRoute(builder: (_) =>  Signup());
        case Routes.insertDoctorScreenRoute:
        return MaterialPageRoute(builder: (_) =>  InsertDoctor());
        case Routes.insertSectionScheduleScreenRoute:
        return MaterialPageRoute(builder: (_) =>  SectionScheduleScreen());
        case Routes.ReceptionDataScreenRoute:
        return MaterialPageRoute(builder: (_) =>  ReceptionDataScreen());

    }
    return null;
  }
}
