
import 'package:flutter/material.dart';
class CartProvider extends ChangeNotifier{
  List<Map<String, dynamic>> _items=[];
  List<Map<String, dynamic>> get items=> _items;
  int get count=> _items.length;
  double get total=> _items.fold(0.0, (s,e){
    var p=e['list_price'];
    if(p is num) return s+p.toDouble();
    return s+(double.tryParse(p?.toString()??'0')??0);
  });
  double get totalWeight{
    double w=0;
    for(var e in _items){
      var we=e['weight']??0.5;
      if(we is num) w+=we.toDouble();
      else w+=double.tryParse(we.toString())??0.5;
    }
    return w==0?0.5:w;
  }
  void add(Map<String, dynamic> p){ _items.add(Map<String,dynamic>.from(p)); notifyListeners(); }
  void clear(){ _items.clear(); notifyListeners(); }
  void removeAt(int i){ _items.removeAt(i); notifyListeners(); }
}
