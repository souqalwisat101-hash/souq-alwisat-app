
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/odoo_service.dart';
import 'home_screen.dart';
import '../widgets/cart_appbar.dart';

class PaymentScreen extends StatefulWidget{
  final double totalAmount;
  final double shippingCost;
  final int deliveryId;
  PaymentScreen({required this.totalAmount, required this.shippingCost, required this.deliveryId});
  @override
  _PaymentScreenState createState()=> _PaymentScreenState();
}
class _PaymentScreenState extends State<PaymentScreen>{
  final odoo=ApiService();
  bool loading=false;
  String selectedPay='cash';

  confirm() async {
    setState(()=> loading=true);
    var cart=context.read<CartProvider>();
    var auth=context.read<AuthProvider>();
    await odoo.createOrder(items: cart.items, deliveryId: widget.deliveryId, shippingCost: widget.shippingCost, total: widget.totalAmount, address: 'نزوى', partnerId: auth.partnerId);
    setState(()=> loading=false);
    cart.clear();
    showDialog(context: context, barrierDismissible:false, builder: (_)=> AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Column(children:[Icon(Icons.check_circle, color: Color(0xFF0FA76B), size:60), SizedBox(height:12), Text('تم الطلب بنجاح ✅', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))]), content: Text('شكرا لك من سوق الوساط\nرقم الطلب: #${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}\nسيتم التواصل معك على الواتساب 98518810', textAlign: TextAlign.center, style: GoogleFonts.cairo()), actions: [SizedBox(width: double.infinity, child: ElevatedButton(onPressed: ()=> Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=> HomeScreen()), (r)=> false), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B)), child: Text('العودة للرئيسية', style: GoogleFonts.cairo(color: Colors.white))))]));
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: CartAppBar(title: 'الدفع'),
      body: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text('اختر طريقة الدفع:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        SizedBox(height:12),
        Card(child: RadioListTile(value: 'cash', groupValue: selectedPay, onChanged: (v)=> setState(()=> selectedPay=v!), title: Text('الدفع عند الاستلام', style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.bold)), secondary: Icon(Icons.money, color: Color(0xFF0FA76B)), activeColor: Color(0xFF0FA76B))),
        Card(child: RadioListTile(value: 'transfer', groupValue: selectedPay, onChanged: (v)=> setState(()=> selectedPay=v!), title: Text('تحويل بنكي', style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.bold)), secondary: Icon(Icons.account_balance, color: Color(0xFF0FA76B)), activeColor: Color(0xFF0FA76B))),
        Spacer(),
        Card(child: Padding(padding: EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('الاجمالي للدفع:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:16)), Text('${widget.totalAmount.toStringAsFixed(2)} ر.ع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:20, color: Color(0xFF0FA76B)))]))),
        SizedBox(height:12),
        SizedBox(width: double.infinity, height:54, child: loading? Center(child: CircularProgressIndicator(color: Color(0xFF0FA76B))): ElevatedButton(onPressed: confirm, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0FA76B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('تأكيد الطلب', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize:16)))),
      ])),
    );
  }
}
