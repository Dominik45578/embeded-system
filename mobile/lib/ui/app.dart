import 'package:flutter/material.dart';
import 'package:lockly_app/core/services/ble/ble_device_manger.dart';
import 'package:lockly_app/core/services/iot_device_service.dart';
import 'package:lockly_app/ui/screens/main_screen.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: BleDeviceManager()),
        Provider(create: (_) => IotDeviceService()),
      ],
      child: MaterialApp(
        title: 'Lockly',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}
