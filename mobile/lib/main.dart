import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lockly_app/core/config/connection_config.dart';
import 'package:lockly_app/core/services/connection_config_service.dart';
import 'ui/app.dart';
import 'firebase_options.dart'; // Zaimportuj wygenerowany plik


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // To łączy się z Twoim JSON-em
  await ConnectionConfigService.instance.init();
  runApp(MyApp());
}