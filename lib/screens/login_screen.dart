
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget{ @override _LoginScreenState createState()=> _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen>{
  final nameCtrl=TextEditingController();
  final phoneCtrl=TextEditingController();
  final emailCtrl=TextEditingController();
  bool loading=false;

  login() async {
    if(nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اكمل جميع الحقول', style: GoogleFonts.cairo())));
      return;
    }
    setState(()=> loading=true);
    var ok=await context.read<AuthProvider>().loginOrRegister(name: nameCtrl.text.trim(), phoneNum: phoneCtrl.text.trim(), emailVal: emailCtrl.text.trim());
    setState(()=> loading=false);
    if(ok){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomeScreen()));
    }else{
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تسجيل الدخول', style: GoogleFonts.cairo()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
      SizedBox(height:40),
      Image.asset('assets/logo.png', width:120, height:120, errorBuilder: (_,__,___)=> Container(width:90,height:90,decoration: BoxDecoration(color: Color(0xFF0FA76B), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.storefront, size:50, color: Colors.white))),
      SizedBox(height:16),
      Text('مرحبا بك في سوق الوساط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:22)),
      Text('ادخل بياناتك للدخول - اذا رقمك موجود ستدخل بحسابك القديم', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.grey, fontSize:12)),
      SizedBox(height:32),
      TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'الاسم الكامل', labelStyle: GoogleFonts.cairo(), prefixIcon: Icon(Icons.person, color: Color(0xFF0FA76B)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      SizedBox(height:12),
      TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', labelStyle: GoogleFonts.cairo(), hintText: '98518810', hintStyle: GoogleFonts.cairo(fontSize:13), prefixIcon: Icon(Icons.phone, color: Color(0xFF0FA76B)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      SizedBox(height:12),
      TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'البريد الالكتروني', labelStyle: GoogleFonts.cairo(), hintText: 'example@gmail.com', hintStyle: GoogleFonts.cairo(fontSize:13), prefixIcon: Icon(Icons.email, color: Color(0xFF0FA76B)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      SizedBox(height:24),
      SizedBox(width: double.infinity, height:52, child: loading? Center(child: CircularProgressIndicator(color: Color(0xFF0FA76B))): ElevatedButton(onPressed: login, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('دخول / تسجيل', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize:16)))),
      SizedBox(height:12),
      Text('بتسجيلك توافق على سياسة الاسترجاع وشروط الاستخدام', style: GoogleFonts.cairo(color: Colors.grey, fontSize:10), textAlign: TextAlign.center),
    ]))));
  }
}
