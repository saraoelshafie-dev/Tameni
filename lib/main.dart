import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);
  runApp(const GhaithApp());
}

class GhaithApp extends StatefulWidget { const GhaithApp({super.key}); @override State<GhaithApp> createState() => _GhaithAppState(); }

class _GhaithAppState extends State<GhaithApp> {
  String lang = 'ar'; String themeColor = 'pink'; bool isDark = false;
  @override void initState(){ super.initState(); _loadPrefs(); }
  Future<void> _loadPrefs() async { final p = await SharedPreferences.getInstance(); setState((){ lang = p.getString('lang') ?? 'ar'; themeColor = p.getString('theme_color') ?? 'pink'; isDark = p.getBool('is_dark') ?? false; }); }
  Color getPrimary(){ switch(themeColor){ case 'purple': return const Color(0xFF7C4DFF); case 'teal': return const Color(0xFF009688); case 'red': return const Color(0xFFD32F2F); default: return const Color(0xFFE91E63); } }
  @override Widget build(BuildContext context){
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(primaryColor: getPrimary(), brightness: isDark ? Brightness.dark : Brightness.light, scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF0F5), useMaterial3: true), home: HomeScreen(lang: lang, themeColor: themeColor, isDark: isDark, onThemeChanged: (c,d,l) async { setState((){ themeColor=c; isDark=d; lang=l; }); final p = await SharedPreferences.getInstance(); await p.setString('theme_color', c); await p.setBool('is_dark', d); await p.setString('lang', l); },),);
  }
}

class HomeScreen extends StatefulWidget { final String lang; final String themeColor; final bool isDark; final Function(String,bool,String) onThemeChanged; const HomeScreen({super.key, required this.lang, required this.themeColor, required this.isDark, required this.onThemeChanged}); @override State<HomeScreen> createState() => _HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  List<String> contacts = []; List<Map<String,dynamic>> meds = [];
  @override void initState(){ super.initState(); _loadData(); }
  Future<void> _loadData() async { final p = await SharedPreferences.getInstance(); setState((){ contacts = p.getStringList('trusted_contacts') ?? []; String medsJson = p.getString('meds') ?? '[]'; meds = List<Map<String,dynamic>>.from(jsonDecode(medsJson)); }); }
  Color getPrimary(){ switch(widget.themeColor){ case 'purple': return const Color(0xFF7C4DFF); case 'teal': return const Color(0xFF009688); case 'red': return const Color(0xFFD32F2F); default: return const Color(0xFFE91E63); } }
  
  Future<Position?> _getLocation() async { try { if (!await Geolocator.isLocationServiceEnabled()) return null; var perm = await Geolocator.checkPermission(); if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission(); if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null; return await Geolocator.getCurrentPosition(); } catch(e){ return null; } }
  
  Future<void> _sendSOS() async {
    final p = await SharedPreferences.getInstance();
    List<String> trusted = p.getStringList('trusted_contacts') ?? [];
    bool sendSMS = p.getBool('send_sms') ?? true;
    bool sendWA = p.getBool('send_whatsapp') ?? true;
    bool sendMessenger = p.getBool('send_messenger') ?? false;
    String customMsg = p.getString('custom_message') ?? (widget.lang=='ar' ? 'غيث - ساعدوني! تنبيه طوارئ. موقعي:' : 'Ghaith - Help! Emergency. My location:');
    Position? pos = await _getLocation();
    String link = pos != null ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}' : 'Location unavailable';
    String full = customMsg + '\n' + link;
    await p.setString('last_active', DateTime.now().toIso8601String());
    if(trusted.isEmpty){ final uri = Uri.parse('tel:122'); if (await canLaunchUrl(uri)) await launchUrl(uri); return; }
    if(sendSMS){ for(var num in trusted){ final sms = Uri.parse('sms:$num?body=${Uri.encodeComponent(full)}'); if (await canLaunchUrl(sms)) await launchUrl(sms); await Future.delayed(const Duration(milliseconds: 800)); } }
    if(sendWA){ for(var num in trusted){ String cleanNum = num.replaceAll(RegExp(r'[^0-9]'), ''); if(cleanNum.startsWith('0')) cleanNum = '2' + cleanNum; final waUri = Uri.parse('https://wa.me/$cleanNum?text=${Uri.encodeComponent(full)}'); if (await canLaunchUrl(waUri)){ await launchUrl(waUri, mode: LaunchMode.externalApplication); await Future.delayed(const Duration(seconds: 2)); } } }
    if(sendMessenger){ await Share.share(full); }
    if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.lang=='ar' ? 'تم ارسال غيث: SMS + واتساب + ماسنجر' : 'Ghaith alert sent!')));
  }

  @override Widget build(BuildContext context){
    final primary = getPrimary();
    return Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.lang=='ar' ? 'أهلا، غيث' : 'Hi, Ghaith', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primary)), Text(widget.lang=='ar' ? 'غيث • انتي في أمان' : 'Ghaith • You are safe', style: TextStyle(color: Colors.grey[600], fontSize: 12)),]), CircleAvatar(backgroundColor: primary.withOpacity(0.2), child: Icon(Icons.water_drop, color: primary)),]),
      const SizedBox(height: 20),
      GestureDetector(onLongPress: _sendSOS, child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(25)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.shield, color: primary)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.lang=='ar' ? 'زر الاستغاثة SOS' : 'SOS Emergency', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text(widget.lang=='ar' ? 'اضغطي مطولا لإرسال نداء فوري' : 'Long press to send instant alert', style: const TextStyle(color: Colors.white70, fontSize: 12)),])), const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),]),),),
      const SizedBox(height: 8), Text(widget.lang=='ar' ? 'يرسل: SMS + واتساب + ماسنجر' : 'Sends via: SMS + WhatsApp + Messenger', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      const SizedBox(height: 20),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1, mainAxisSpacing: 12, crossAxisSpacing: 12, children: [
        _card(primary, Icons.people, widget.lang=='ar' ? 'جهات الاتصال' : 'Trusted Contacts', '${contacts.length} جهات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(lang: widget.lang)))),
        _card(primary, Icons.access_time, widget.lang=='ar' ? 'مؤقت الوصول' : 'Check-in', 'مفعل - 30 د', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(lang: widget.lang)))),
        _card(primary, Icons.shield, widget.lang=='ar' ? 'مراقبة الخمول' : 'Inactivity', 'يراقب الآن', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(lang: widget.lang)))),
        _card(primary, Icons.call, widget.lang=='ar' ? 'مكالمة مزيفة' : 'Fake Call', 'اضغطي للتشغيل', () => Navigator.push(context, MaterialPageRoute(builder: (_) => FakeCallScreen(callerName: 'ماما')))),
        _card(primary, Icons.map, widget.lang=='ar' ? 'مشاركة الرحلة' : 'Share Trip', 'مشاركة مباشرة', () async { Position? pos = await _getLocation(); String l = pos != null ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}' : 'Follow my trip - Ghaith'; await Share.share(l); }),
        _card(primary, Icons.lightbulb, widget.lang=='ar' ? 'نصائح السلامة' : 'Safety Tips', '7 نصائح', () => Navigator.push(context, MaterialPageRoute(builder: (_) => TipsScreen(lang: widget.lang)))),
        _card(primary, Icons.medication, widget.lang=='ar' ? 'أدويتي' : 'My Meds', '${meds.length} أدوية • صوت', () => Navigator.push(context, MaterialPageRoute(builder: (_) => MedsScreen(lang: widget.lang)))),
        _card(primary, Icons.palette, widget.lang=='ar' ? 'المظهر وال
