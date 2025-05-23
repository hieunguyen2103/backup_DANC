import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fire_guard/screens/DeviceSettingScreen.dart';
import 'package:fire_guard/screens/accountSettingScreen.dart';
import 'package:fire_guard/screens/mainDrawerScreen.dart';
import 'package:fire_guard/widget/SemiCircle.dart';
import 'package:fire_guard/widget/notifycationIconButton.dart';
import 'package:fire_guard/screens/streamVideo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() {
    return _MainSCreenState();
  }
}

class _MainSCreenState extends State<MainScreen> {
  bool _isAccountActivated = false;
  bool _isLoading = true;

  double? coLevel;
  double? smokeLevel;
  DateTime _lastUpdated = DateTime.now();
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  void _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Yêu cầu quyền nhận thông báo (Android 13+)
    await messaging.requestPermission();

    // Lấy token thiết bịư
    final fcmToken = await messaging.getToken();
    print('🟢 FCM Token: $fcmToken');

    // Gửi token về server
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && fcmToken != null) {
      await http.post(
        Uri.parse('http://103.69.97.153:5000/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.uid,
          'token': fcmToken,
        }),
      );
    }

    // Lắng nghe khi app đang mở
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Nhận thông báo: ${message.notification?.title}");

      if (message.notification != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(message.notification!.title ?? "Thông báo"),
            content: Text(message.notification!.body ?? "Không có nội dung"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Đóng"),
              )
            ],
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
    _initFCM();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      if (data != null && data['activated'] == true) {
        setState(() {
          _isAccountActivated = true;
        });

        final url = Uri.parse('http://103.69.97.153:5000/get-sensor-data?user_id=${user.uid}');
        final response = await http.get(url);
        if(response.statusCode == 200)
        {
          final jsonData = json.decode(response.body);
          setState(() {
            coLevel = (jsonData['co'] as num?)?.toDouble() ?? 0;
            smokeLevel = (jsonData['smokes'] as num?)?.toDouble() ?? 0;
            _lastUpdated = DateTime.now();
          });
        }
        else
        {
          print('Lỗi khi gọi API: ${response.statusCode}');
        }

        // final sensorDoc = await FirebaseFirestore.instance
        //     .collection('users')
        //     .doc(user.uid)
        //     .collection('data_sensor')
        //     .doc('00000000')
        //     .get();

        // final sensorData = sensorDoc.data();
        // if (sensorData != null) {
        //   setState(() {
        //     coLevel = (sensorData['Co_level'] as num).toDouble();
        //     smokeLevel = (sensorData['Smoke_level'] as num).toDouble();
        //     _lastUpdated = DateTime.now();
        //   });
        // }
      }
    } catch (e) {
      print('Error loading user or sensor data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _setScreen(BuildContext context, String identifier) {
    Navigator.of(context).pop();
    if (identifier == 'Account') {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => const AccountSettingScreen()));
    } else if (identifier == 'Device') {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => const DeviceSettingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home page'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => StreamVideoScreen()),
              );
            },
            icon: const Icon(Icons.videocam),
            tooltip: 'Camera',
          ),
          const NotificationIconButton(),
        ],
      ),
      drawer: MainDrawerScreen(
        onSelectScreen: _setScreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAccountActivated
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Fire Guard',
                        style: GoogleFonts.robotoSlab(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: buildGauge(
                                  'Smoke',
                                  smokeLevel ?? 0,
                                  0,
                                  100,
                                  [
                                    GaugeRange(startValue: 0, endValue: 20, color: Colors.green),
                                    GaugeRange(startValue: 21, endValue: 60, color: Colors.orange),
                                    GaugeRange(startValue: 61, endValue: 100, color: Colors.red),
                                  ],
                                  '',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: buildGauge(
                                  'CO',
                                  coLevel ?? 0,
                                  0,
                                  100,
                                  [
                                    GaugeRange(startValue: 0, endValue: 10, color: Colors.green),
                                    GaugeRange(startValue: 11, endValue: 35, color: Colors.orange),
                                    GaugeRange(startValue: 36, endValue: 100, color: Colors.red),
                                  ],
                                  '',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildStatusWarning(coLevel, smokeLevel),
                      const SizedBox(height: 16),
                      Text(
                        '⏱ Bây giờ là: ${DateFormat('HH:mm:ss dd/MM/yyyy').format(_currentTime)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      )
                    ],
                  ),
                )
              : const Center(
                  child: Text(
                    'Please activate your account to use features',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
    );
  }

  Widget buildGauge(
    String title,
    double value,
    double min,
    double max,
    List<GaugeRange> ranges,
    String unit,
  ) {
    return SfRadialGauge(
      title: GaugeTitle(
        text: title,
        textStyle: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        alignment: GaugeAlignment.center,
      ),
      axes: <RadialAxis>[
        RadialAxis(
          showTicks: false,
          showLabels: false,
          minimum: min,
          maximum: max,
          radiusFactor: 0.9,
          axisLineStyle: AxisLineStyle(
            thickness: 0.18,
            thicknessUnit: GaugeSizeUnit.factor,
            cornerStyle: CornerStyle.bothCurve,
            color: Colors.grey.shade300,
          ),
          ranges: ranges,
          pointers: <GaugePointer>[
            NeedlePointer(
              value: value,
              needleColor: Colors.deepPurple,
              knobStyle: KnobStyle(color: Colors.deepPurple),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.6,
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toStringAsFixed(1),
                    style: GoogleFonts.robotoMono(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    Text(
                      unit,
                      style: GoogleFonts.roboto(fontSize: 14),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusWarning(double? co, double? smoke) {
    String coStatus = 'Chưa có dữ liệu';
    String smokeStatus = 'Chưa có dữ liệu';

    if (co != null) {
      if (co > 35) {
        coStatus = '⚠️ Mức CO cao! Nguy hiểm!';
      } else if (co > 10) {
        coStatus = 'CO ở mức trung bình';
      } else {
        coStatus = '✅ Mức CO an toàn';
      }
    }

    if (smoke != null) {
      if (smoke > 60) {
        smokeStatus = '🚨 Phát hiện khói dày!';
      } else if (smoke > 20) {
        smokeStatus = '⚠️ Mức khói tăng cao';
      } else {
        smokeStatus = '✅ Mức khói ổn định';
      }
    }

    return Column(
      children: [
        Text(coStatus, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(smokeStatus, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}


