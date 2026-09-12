
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/cart_appbar.dart';

class AboutScreen extends StatelessWidget{
  Future<void> openMap() async {
    final url = Uri.parse("https://maps.app.goo.gl/CdUZhv34BuGpXsEf9");
    if(await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: CartAppBar(title: 'من نحن'), body: ListView(padding: EdgeInsets.all(20), children:[
      Center(child: Image.asset('assets/logo.png', width:120, height:120, errorBuilder: (_,__,___)=> Icon(Icons.store, size:80, color: Color(0xFF0FA76B)))),
      SizedBox(height:12),
      Text('سوق الوساط - نزوى الصقرية', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:18)),
      SizedBox(height:16),
      Text('مرحبا بكم في سوق الوساط، متجركم المتكامل للأدوات، الكهربائيات، والإلكترونيات في ولاية نزوى - الصقرية بجوار مجلس الغنتق. نوفر منتجات بجودة عالية مع توصيل لجميع مناطق السلطنة وطرق دفع متعددة.\n\nعنواننا: ولاية نزوى - الصقرية بجوار مجلس الغنتق\nالتوصيل: جميع مناطق السلطنة\nالدفع: نقدا عند الاستلام، تحويل بنكي\nالجودة: منتجات أصلية بضمان', style: GoogleFonts.cairo(fontSize:13, height:1.6)),
      SizedBox(height:20),
      ElevatedButton.icon(onPressed: openMap, icon: Icon(Icons.map, color: Colors.white), label: Text('فتح موقع المحل على الخريطة', style: GoogleFonts.cairo(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B))),
    ]));
  }
}
