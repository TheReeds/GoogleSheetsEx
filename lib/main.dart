import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googlesheetsexa/screens/home_screen.dart';
import 'package:googlesheetsexa/services/gsheet_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final credentials = await rootBundle.loadString('assets/keys/google_service_key.json');
  final gsheetsService = GSheetsService(credentials);
  await gsheetsService.init();

  runApp(MyApp(gsheetsService));
}

class MyApp extends StatelessWidget {
  final GSheetsService gsheetsService;

  MyApp(this.gsheetsService);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(gsheetsService),
    );
  }
}
