
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/cart_appbar.dart';

class ReturnPolicyScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: CartAppBar(title: 'سياسة الاسترجاع'), body: ListView(padding: EdgeInsets.all(20), children:[
      Text('سياسة الاسترجاع والاستبدال - سوق الوساط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:16)),
      SizedBox(height:12),
      Text('1. يمكن استرجاع المنتج خلال 7 أيام من الاستلام إذا كان به عيب مصنعي.\n2. يجب أن يكون المنتج في علبته الأصلية وغير مستخدم.\n3. لا يمكن استرجاع المنتجات الكهربائية بعد التركيب.\n4. تكاليف الشحن للاسترجاع يتحملها العميل إلا في حالة العيب المصنعي.\n5. للتواصل: 98518810 - 91705789\n\nنشكر ثقتكم في سوق الوساط - نزوى.', style: GoogleFonts.cairo(fontSize:13, height:1.6)),
    ]));
  }
}
