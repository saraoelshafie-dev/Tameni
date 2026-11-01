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
        _card(primary, Icons.palette, widget.lang=='ar' ? 'المظهر واللغة' : 'Appearance', '${widget.themeColor}, ${widget.lang}', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceScreen(currentColor: widget.themeColor, isDark: widget.isDark, lang: widget.lang, onChanged: widget.onThemeChanged,)))),
      ],),
    ],),),),);
  }
  Widget _card(Color primary, IconData icon, String title, String subtitle, VoidCallback onTap){ return GestureDetector(onTap: onTap, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]), child: Column(children: [Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(color: primary.withOpacity(0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))), child: Icon(icon, color: primary, size: 36))), Padding(padding: const EdgeInsets.all(8), child: Column(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),])),]),),); }
}

class AppearanceScreen extends StatefulWidget { final String currentColor; final bool isDark; final String lang; final Function(String,bool,String) onChanged; const AppearanceScreen({super.key, required this.currentColor, required this.isDark, required this.lang, required this.onChanged}); @override State<AppearanceScreen> createState() => _AppearanceScreenState(); }
class _AppearanceScreenState extends State<AppearanceScreen> { late String color; late bool dark; late String lang; @override void initState(){ super.initState(); color=widget.currentColor; dark=widget.isDark; lang=widget.lang; } @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: Text(lang=='ar' ? 'غيث - المظهر واللغة' : 'Ghaith - Appearance'), backgroundColor: const Color(0xFFE91E63)), body: ListView(padding: const EdgeInsets.all(16), children: [Text(lang=='ar' ? 'اختاري اللون (4 الوان)' : 'Choose Theme Color', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10), Row(children: [_dot('pink', const Color(0xFFE91E63)), _dot('purple', const Color(0xFF7C4DFF)), _dot('teal', const Color(0xFF009688)), _dot('red', const Color(0xFFD32F2F)),]), const Divider(height: 30), SwitchListTile(title: Text(lang=='ar' ? 'الوضع الداكن' : 'Dark Mode'), value: dark, onChanged: (v){ setState(()=>dark=v); widget.onChanged(color,dark,lang); }), const Divider(height: 30), Text(lang=='ar' ? 'اللغة' : 'Language', style: const TextStyle(fontWeight: FontWeight.bold)), RadioListTile(value: 'ar', groupValue: lang, title: const Text('العربية - غيث'), onChanged: (v){ setState(()=>lang=v!); widget.onChanged(color,dark,lang); }), RadioListTile(value: 'en', groupValue: lang, title: const Text('English - Ghaith'), onChanged: (v){ setState(()=>lang=v!); widget.onChanged(color,dark,lang); }),]),); } Widget _dot(String name, Color c){ bool sel = color==name; return GestureDetector(onTap: (){ setState(()=>color=name); widget.onChanged(color,dark,lang); }, child: Container(margin: const EdgeInsets.only(right: 12), width: 50, height: 50, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: sel ? Border.all(color: Colors.black, width: 3) : null)),); } }

class MedsScreen extends StatefulWidget { final String lang; const MedsScreen({super.key, required this.lang}); @override State<MedsScreen> createState() => _MedsScreenState(); }
class _MedsScreenState extends State<MedsScreen> {
  List<Map<String,dynamic>> meds = [];
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); String jsonStr = p.getString('meds') ?? '[]'; setState(()=> meds = List<Map<String,dynamic>>.from(jsonDecode(jsonStr))); }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setString('meds', jsonEncode(meds)); setState((){}); }
  Future<void> _showNotif(String name) async { const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('meds_channel', 'غيث - تذكير الأدوية', importance: Importance.max, priority: Priority.high, playSound: true, enableVibration: true,); const NotificationDetails details = NotificationDetails(android: androidDetails); await notificationsPlugin.show(DateTime.now().millisecond, widget.lang=='ar' ? '💊 غيث - ميعاد الدواء' : '💊 Ghaith - Medication', widget.lang=='ar' ? 'ميعاد دواء $name الآن 🔊' : 'Time for $name now', details,); }
  void _addDialog(){ String name=''; String dose=''; TimeOfDay time = TimeOfDay.now(); showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setS)=> AlertDialog(title: Text(widget.lang=='ar' ? 'إضافة دواء' : 'Add Med'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(decoration: InputDecoration(labelText: widget.lang=='ar' ? 'اسم الدواء' : 'Medicine name'), onChanged: (v)=>name=v), TextField(decoration: InputDecoration(labelText: widget.lang=='ar' ? 'الجرعة' : 'Dose'), onChanged: (v)=>dose=v), ListTile(title: Text('${widget.lang=='ar' ? 'الوقت' : 'Time'}: ${time.format(context)}'), onTap: () async { TimeOfDay? t = await showTimePicker(context: context, initialTime: time); if(t!=null) setS(()=>time=t); })]), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text(widget.lang=='ar' ? 'إلغاء' : 'Cancel')), ElevatedButton(onPressed: (){ if(name.isNotEmpty){ meds.add({'name':name,'dose':dose,'hour':time.hour,'minute':time.minute,'taken':false}); _save(); _showNotif(name); Navigator.pop(context); } }, child: Text(widget.lang=='ar' ? 'حفظ + صوت 🔊' : 'Save + Sound'))],))); }
  @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: Text(widget.lang=='ar' ? 'أدويتي - غيث' : 'My Meds - Ghaith'), backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white), body: meds.isEmpty ? Center(child: Text(widget.lang=='ar' ? 'لا توجد أدوية' : 'No meds')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: meds.length, itemBuilder: (_, i){ var m = meds[i]; return Card(child: ListTile(leading: const Icon(Icons.medication, color: Color(0xFFE91E63)), title: Text('${m['name']} - ${m['dose']}'), subtitle: Text('${m['hour']}:${m['minute']}'), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: (){ meds.removeAt(i); _save(); }),)); },), floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFFE91E63), onPressed: _addDialog, child: const Icon(Icons.add, color: Colors.white)),); }
}

class SettingsScreen extends StatefulWidget { final String lang; const SettingsScreen({super.key, required this.lang}); @override State<SettingsScreen> createState() => _SettingsScreenState(); }
class _SettingsScreenState extends State<SettingsScreen> {
  List<String> contacts=[]; bool sendSMS=true; bool sendWA=true; bool sendMessenger=false;
  final TextEditingController _contactCtrl = TextEditingController(); final TextEditingController _msgCtrl = TextEditingController(text: 'غيث - ساعدوني! موقعي:');
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); setState((){ contacts = p.getStringList('trusted_contacts') ?? []; sendSMS = p.getBool('send_sms') ?? true; sendWA = p.getBool('send_whatsapp') ?? true; sendMessenger = p.getBool('send_messenger') ?? false; _msgCtrl.text = p.getString('custom_message') ?? _msgCtrl.text; }); }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setStringList('trusted_contacts', contacts); await p.setString('custom_message', _msgCtrl.text); await p.setBool('send_sms', sendSMS); await p.setBool('send_whatsapp', sendWA); await p.setBool('send_messenger', sendMessenger); }
  @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: Text(widget.lang=='ar' ? 'غيث - الاعدادات' : 'Ghaith - Settings'), backgroundColor: const Color(0xFFE91E63)), body: ListView(padding: const EdgeInsets.all(16), children: [Text(widget.lang=='ar' ? 'ارقامي الموثوقة (حتى 5)' : 'Trusted Contacts', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE91E63))), Row(children: [Expanded(child: TextField(controller: _contactCtrl, decoration: const InputDecoration(hintText: '01xxxxxxxxx', border: OutlineInputBorder()))), const SizedBox(width: 8), ElevatedButton(onPressed: (){ if(_contactCtrl.text.isNotEmpty && contacts.length<5){ setState((){ contacts.add(_contactCtrl.text); _contactCtrl.clear(); }); } }, child: Text(widget.lang=='ar' ? 'إضافة' : 'Add'))]), ...contacts.map((c)=>ListTile(title: Text(c), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=>setState(()=>contacts.remove(c))))), const Divider(), Text(widget.lang=='ar' ? 'طرق الارسال' : 'Sending Methods', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE91E63))), CheckboxListTile(title: const Text('SMS'), value: sendSMS, onChanged: (v)=>setState(()=>sendSMS=v!)), CheckboxListTile(title: const Text('WhatsApp'), value: sendWA, onChanged: (v)=>setState(()=>sendWA=v!)), CheckboxListTile(title: const Text('Messenger'), value: sendMessenger, onChanged: (v)=>setState(()=>sendMessenger=v!)), TextField(controller: _msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'نص رسالة غيث', border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () async { await _save(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.lang=='ar' ? 'تم حفظ اعدادات غيث' : 'Ghaith Saved'))); }, child: Text(widget.lang=='ar' ? 'حفظ كل اعدادات غيث' : 'Save Ghaith Settings', style: const TextStyle(color: Colors.white))),],),); }
}

class FakeCallScreen extends StatelessWidget { final String callerName; const FakeCallScreen({super.key, required this.callerName}); @override Widget build(BuildContext context){ return Scaffold(backgroundColor: Colors.black, body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.account_circle, size: 120, color: Colors.white), const SizedBox(height: 20), Text(callerName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), const Text('يتصل... - غيث', style: TextStyle(color: Colors.white70, fontSize: 18)), const SizedBox(height: 80), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [FloatingActionButton(backgroundColor: Colors.red, onPressed: ()=>Navigator.pop(context), child: const Icon(Icons.call_end)), FloatingActionButton(backgroundColor: Colors.green, onPressed: ()=>Navigator.pop(context), child: const Icon(Icons.call))])])); } }

class TipsScreen extends StatelessWidget { final String lang; const TipsScreen({super.key, required this.lang}); @override Widget build(BuildContext context){ List<String> tipsAr = ['شاركي موقعك دائما مع شخص تثقين به - غيث.', 'احتفظي برقم الطوارئ 122.', 'استخدمي المكالمة الوهمية للخروج من المواقف.']; List<String> tipsEn = ['Always share location - Ghaith.', 'Keep 122 emergency number.', 'Use fake call to exit.']; var tips = lang=='ar' ? tipsAr : tipsEn; return Scaffold(appBar: AppBar(title: Text(lang=='ar' ? 'نصائح غيث' : 'Ghaith Tips'), backgroundColor: const Color(0xFFE91E63)), body: ListView.builder(padding: const EdgeInsets.all(16), itemCount: tips.length, itemBuilder: (_, i)=>Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Color(0xFFE91E63)), title: Text(tips[i]))))); } }
