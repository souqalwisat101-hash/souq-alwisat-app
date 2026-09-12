
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/odoo_service.dart';
import 'payment_screen.dart';
import '../widgets/cart_appbar.dart';

class CheckoutScreen extends StatefulWidget{ @override _CheckoutScreenState createState()=> _CheckoutScreenState(); }
class _CheckoutScreenState extends State<CheckoutScreen>{
  final odoo=ApiService();
  List carriers=[];
  int selectedId=0;
  double shippingCost=0;
  bool loading=true;

  @override
  void initState(){
    super.initState();
    loadCarriers();
  }
  loadCarriers() async {
    var cart=context.read<CartProvider>();
    var c=await odoo.getCarriers(cart.totalWeight);
    setState((){ carriers=c; selectedId=c.first['id']; shippingCost=c.first['price']?.toDouble()??0; loading=false; });
  }

  @override
  Widget build(BuildContext context){
    var cart=context.watch<CartProvider>();
    return Scaffold(
      appBar: CartAppBar(title: 'الشحن والتوصيل'),
      body: loading? Center(child: CircularProgressIndicator(color: Color(0xFF0FA76B))): Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text('اختر طريقة الشحن (تم حذف مسقط والمجاني - فقط هذين الخيارين):', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:13)),
        SizedBox(height:12),
        ...carriers.map((car){
          bool isSel=car['id']==selectedId;
          return Card(color: isSel?Color(0xFF0FA76B).withOpacity(0.08):Colors.white, shape: RoundedRectangleBorder(side: BorderSide(color: isSel?Color(0xFF0FA76B):Colors.grey[300]!), borderRadius: BorderRadius.circular(12)), child: RadioListTile(
            value: car['id'], groupValue: selectedId,
            onChanged: (v){ setState((){ selectedId=v!; shippingCost=(car['price'] as num).toDouble(); }); },
            title: Text(car['name'], style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.bold)),
            subtitle: car['price']==0? Text('مجاني - استلام من المحل', style: GoogleFonts.cairo(fontSize:11, color: Colors.green)): Text('التكلفة: ${car['price']} ر.ع (1 ر.ع + 0.1 لكل كجم فوق 10 كجم) - الوزن الحالي ${cart.totalWeight.toStringAsFixed(1)} كجم', style: GoogleFonts.cairo(fontSize:10)),
            secondary: Icon(car['type']=='pickup'?Icons.store:Icons.local_shipping, color: Color(0xFF0FA76B)),
            activeColor: Color(0xFF0FA76B),
          ));
        }).toList(),
        Spacer(),
        Card(child: Padding(padding: EdgeInsets.all(12), child: Column(children:[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('المجموع:', style: GoogleFonts.cairo()), Text('${cart.total} ر.ع', style: GoogleFonts.cairo())]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('الشحن:', style: GoogleFonts.cairo()), Text('${shippingCost.toStringAsFixed(2)} ر.ع', style: GoogleFonts.cairo())]),
          Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('الاجمالي النهائي:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), Text('${(cart.total+shippingCost).toStringAsFixed(2)} ر.ع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Color(0xFF0FA76B), fontSize:16))]),
        ]))),
        SizedBox(height:12),
        SizedBox(width: double.infinity, height:52, child: ElevatedButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> PaymentScreen(totalAmount: cart.total+shippingCost, shippingCost: shippingCost, deliveryId: selectedId))), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('متابعة للدفع', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}
