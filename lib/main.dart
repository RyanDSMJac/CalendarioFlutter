import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';

void main() {
  tz.initializeTimeZones();
  runApp(const CalendarApp());
}