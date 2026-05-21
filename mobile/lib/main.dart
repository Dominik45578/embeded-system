import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lockly_app/core/services/connection_config_service.dart';

import 'firebase_options.dart';
import 'ui/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ConnectionConfigService.instance.init();
  runApp(const MyApp());
}
