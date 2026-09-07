import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const FogSafetyApp());
}

class FogSafetyApp extends StatelessWidget {
  const FogSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'INSPIRE Fog Safety System',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _positionSub;

  bool _isMonitoring = false;
  String _statusMessage = "System Offline";
  String _locationInfo = "Location: Not Tracking";
  double _currentSpeed = 0.0;

  final double _impactThreshold = 25.0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _startSafetySystem() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _statusMessage = "Location Permission Denied");
        return;
      }
    }

    setState(() {
      _isMonitoring = true;
      _statusMessage = "System Active & Monitoring";
    });

    _speak("Safety Monitoring System Activated");

    _accelSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      double gForce = (event.x * event.x + event.y * event.y + event.z * event.z);
      if (gForce > _impactThreshold * _impactThreshold) {
        _triggerAccidentAlert();
      }
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentSpeed = position.speed * 3.6;
        _locationInfo = "Lat: ${position.latitude.toStringAsFixed(4)}, Long: ${position.longitude.toStringAsFixed(4)}";
      });

      if (_currentSpeed > 50.0) {
        _speak("Warning! Heavy Fog Area. Please slow down.");
      }
    });
  }

  void _stopSafetySystem() {
    _accelSub?.cancel();
    _positionSub?.cancel();
    setState(() {
      _isMonitoring = false;
      _statusMessage = "System Offline";
      _currentSpeed = 0.0;
    });
    _speak("Safety System Deactivated");
  }

  void _triggerAccidentAlert() {
    setState(() {
      _statusMessage = "CRITICAL: ACCIDENT DETECTED!";
    });
    _speak("Emergency Warning! Impact detected. Sending SOS Location.");
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _positionSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("INSPIRE Safety System"),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isMonitoring ? Icons.verified_user : Icons.gpp_maybe,
              size: 90,
              color: _isMonitoring ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isMonitoring ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("Current Speed: ${_currentSpeed.toStringAsFixed(1)} km/h",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text(_locationInfo, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () {
                if (_isMonitoring) {
                  _stopSafetySystem();
                } else {
                  _startSafetySystem();
                }
              },
              child: Text(
                _isMonitoring ? "STOP SYSTEM" : "START SAFETY SYSTEM",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
