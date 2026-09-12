
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget{ @override _SplashScreenState createState()=> _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen>{
  @override
  void initState(){
    super.initState();
    Future.delayed(Duration(seconds:2),() async {
      var auth=context.read<AuthProvider>();
      await auth.init();
      if(!mounted) return;
      if(auth.isLogged){
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomeScreen()));
      }else{
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> LoginScreen()));
      }
    });
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
        Image.asset('assets/logo.png', width:180, height:180, errorBuilder: (_,__,___)=> Container(width:140,height:140,decoration: BoxDecoration(color: Color(0xFF0FA76B), borderRadius: BorderRadius.circular(30)), child: Icon(Icons.storefront, size:80, color: Colors.white))),
        SizedBox(height:20),
        Text('سوق الوساط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:32, color: Color(0xFF0B1D2A))),
        Text('نزوى - الصقرية', style: GoogleFonts.cairo(fontSize:14, color: Colors.grey)),
        SizedBox(height:40),
        CircularProgressIndicator(color: Color(0xFF0FA76B)),
      ])),
    );
  }
}
