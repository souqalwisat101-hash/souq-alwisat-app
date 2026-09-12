
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';

class CartAppBar extends StatelessWidget implements PreferredSizeWidget{
  final String title;
  CartAppBar({required this.title});
  @override
  Widget build(BuildContext context){
    return AppBar(
      backgroundColor: Colors.white, elevation:0,
      iconTheme: IconThemeData(color: Colors.black),
      title: Text(title, style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold, fontSize:18)),
      actions: [
        Consumer<CartProvider>(builder: (_,c,__)=> Stack(children:[
          IconButton(icon: Icon(Icons.shopping_cart, color: Colors.black), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> CartScreen()))),
          if(c.count>0) Positioned(right:6,top:6,child: Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${c.count}', style: TextStyle(color: Colors.white, fontSize:10)))),
        ])),
      ],
    );
  }
  @override
  Size get preferredSize=> Size.fromHeight(kToolbarHeight);
}
