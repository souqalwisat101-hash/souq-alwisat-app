
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';
import '../widgets/cart_appbar.dart';

class CartScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    var cart=context.watch<CartProvider>();
    return Scaffold(
      appBar: CartAppBar(title: 'سلة التسوق (${cart.count})'),
      body: cart.count==0? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.shopping_cart_outlined, size:80, color: Colors.grey[300]), SizedBox(height:12), Text('السلة فارغة', style: GoogleFonts.cairo(fontSize:16, color: Colors.grey)), SizedBox(height:8), ElevatedButton(onPressed: ()=> Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B)), child: Text('تسوق الآن', style: GoogleFonts.cairo(color: Colors.white)))])): Column(children:[
        Expanded(child: ListView.builder(padding: EdgeInsets.all(12), itemCount: cart.items.length, itemBuilder: (_,i){ var p=cart.items[i]; return Card(margin: EdgeInsets.only(bottom:10), child: ListTile(leading: Container(width:50,height:50, decoration: BoxDecoration(color: Color(0xFFF1F5F3), borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['image_512_url']??p['image_512']??'', fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.image, color: Colors.grey)))), title: Text(p['name']??'', maxLines:2, style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text('${p['list_price']} ر.ع', style: GoogleFonts.cairo(color: Color(0xFF0FA76B), fontWeight: FontWeight.bold)), if(p['weight']!=null) Text('الوزن: ${p['weight']} كجم', style: GoogleFonts.cairo(fontSize:10, color: Colors.grey))]), trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: ()=> cart.removeAt(i)))); })),
        Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius:10)]), child: Column(children:[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('الوزن الكلي:', style: GoogleFonts.cairo()), Text('${cart.totalWeight.toStringAsFixed(2)} كجم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))]),
          SizedBox(height:6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('الاجمالي:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:16)), Text('${cart.total} ر.ع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:18, color: Color(0xFF0FA76B)))]),
          SizedBox(height:12),
          SizedBox(width: double.infinity, height:52, child: ElevatedButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> CheckoutScreen())), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('متابعة للشحن', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)))),
        ])),
      ]),
    );
  }
}
