
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatelessWidget{
  final Map<String,dynamic> product;
  final List allProducts;
  ProductDetailScreen({required this.product, required this.allProducts});

  List getSimilar(){
    var catId = product['categ_id'] is List? product['categ_id'][0] : product['categ_id'];
    return allProducts.where((e){
      var c = e['categ_id'] is List? e['categ_id'][0] : e['categ_id'];
      return c==catId && e['id']!=product['id'];
    }).take(4).toList();
  }

  Widget buildImage(String url){
    if(url.isEmpty) return Container(color: Color(0xFFF1F5F3), height:320, child: Center(child: Icon(Icons.image, size:80, color: Colors.grey)));
    return Image.network(url, fit: BoxFit.contain, width: double.infinity, height:320,
      errorBuilder: (_,__,___)=> Container(height:320, color: Color(0xFFF1F5F3), child: Center(child: Icon(Icons.broken_image, size:60))),
    );
  }

  @override
  Widget build(BuildContext context){
    var similar=getSimilar();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation:0,
        iconTheme: IconThemeData(color: Colors.black),
        title: Text('تفاصيل المنتج', style: GoogleFonts.cairo(color: Colors.black, fontSize:16, fontWeight: FontWeight.bold)),
        actions: [
          Consumer<CartProvider>(builder: (_,c,__)=> Stack(children:[
            IconButton(icon: Icon(Icons.shopping_cart, color: Colors.black), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> CartScreen()))),
            if(c.count>0) Positioned(right:6,top:6,child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${c.count}', style: TextStyle(color: Colors.white, fontSize:9)))),
          ])),
        ],
      ),
      bottomNavigationBar: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius:8)]), child: SizedBox(height:52, child: ElevatedButton(onPressed: (){ context.read<CartProvider>().add(product); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت الاضافة للسلة ✅ ${product['name']}', style: GoogleFonts.cairo()), backgroundColor: Color(0xFF0FA76B))); }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('اضف للسلة - ${product['list_price']} ر.ع', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize:15))))),
      body: ListView(children:[
        buildImage(product['image_512_url']??product['image_512']??''),
        Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(product['name']??'', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:20, height:1.3)),
          SizedBox(height:8),
          Row(children:[
            Text('${product['list_price']} ر.ع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:22, color: Color(0xFF0FA76B))),
            SizedBox(width:12),
            if(product['qty_available']!=null) Container(padding: EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: (product['qty_available']>0?Color(0xFF0FA76B):Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(product['qty_available']>0?'متوفر: ${product['qty_available']}':'غير متوفر', style: GoogleFonts.cairo(fontSize:11, color: product['qty_available']>0?Color(0xFF0FA76B):Colors.red))),
          ]),
          SizedBox(height:12),
          if(product['weight']!=null) Row(children:[Icon(Icons.scale, size:16, color: Colors.grey), SizedBox(width:4), Text('الوزن: ${product['weight']} كجم', style: GoogleFonts.cairo(fontSize:12, color: Colors.grey))]),
          SizedBox(height:16),
          Text('الوصف الكامل:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:14)),
          SizedBox(height:6),
          Text(product['description_sale']??product['description']??'منتج أصلي بجودة عالية من سوق الوساط - نزوى الصقرية - متوفر مع الضمان وخدمة ما بعد البيع.\n\nالمواصفات:\n- جودة عالية\n- ضمان\n- توصيل لجميع مناطق السلطنة', style: GoogleFonts.cairo(fontSize:13, color: Colors.black87, height:1.6)),
          SizedBox(height:20),
          if(similar.isNotEmpty) ...[
            Text('منتجات مشابهة من نفس القسم:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:14)),
            SizedBox(height:10),
            Container(height:180, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: similar.length, itemBuilder: (_,i){
              var sp=similar[i];
              return InkWell(onTap: ()=> Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> ProductDetailScreen(product: Map<String,dynamic>.from(sp), allProducts: allProducts))), child: Container(width:130, margin: EdgeInsets.only(left:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)), child: Column(children:[
                Expanded(child: ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(10)), child: Image.network(sp['image_512_url']??sp['image_512']??'', fit: BoxFit.cover, width: double.infinity, errorBuilder: (_,__,___)=> Icon(Icons.image)))),
                Padding(padding: EdgeInsets.all(6), child: Column(children:[Text(sp['name']??'', maxLines:2, style: GoogleFonts.cairo(fontSize:10, fontWeight: FontWeight.bold)), Text('${sp['list_price']} ر.ع', style: GoogleFonts.cairo(fontSize:11, color: Color(0xFF0FA76B), fontWeight: FontWeight.bold))]))
              ])));
            })),
          ],
        ])),
      ]),
    );
  }
}
