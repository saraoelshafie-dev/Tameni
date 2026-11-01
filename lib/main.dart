import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(TameniApp());
}

class TameniApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'طمني',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: 'Cairo',
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String emergencyNumber = "122";

  @override
  void initState() {
    super.initState();
    loadNumber();
  }

  loadNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      emergencyNumber = prefs.getString('emergency') ?? "122";
    });
  }

  makeCall() async {
    final Uri url = Uri(scheme: 'tel', path: emergencyNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF0F3),
      appBar: AppBar(
        backgroundColor: Color(0xFFE91E63),
        title: Text('طمني - Tameni', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 120, color: Color(0xFFE91E63)),
            SizedBox(height: 20),
            Text('انتي في أمان', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
            SizedBox(height: 10),
            Text('اضغطي للطوارئ', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            SizedBox(height: 50),
            GestureDetector(
              onTap: makeCall,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, color: Colors.white, size: 50),
                      SizedBox(height: 10),
                      Text('SOS', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 50),
            Text('رقم الطوارئ: $emergencyNumber', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
