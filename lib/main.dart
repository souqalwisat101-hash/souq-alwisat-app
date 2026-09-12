
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main(){
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_)=> CartProvider()),
    ChangeNotifierProvider(create: (_)=> AuthProvider()),
  ], child: MyApp()));
}
class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سوق الوساط',
      theme: ThemeData(primaryColor: Color(0xFF0FA76B), scaffoldBackgroundColor: Color(0xFFF8FAF9), appBarTheme: AppBarTheme(backgroundColor: Colors.white, elevation:0)),
      home: SplashScreen(),
    );
  }
}
