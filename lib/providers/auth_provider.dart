
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/odoo_service.dart';

class AuthProvider extends ChangeNotifier{
  final ApiService odoo = ApiService();
  bool isLogged=false;
  String userName='';
  String email='';
  String phone='';
  int partnerId=0;

  Future<void> init() async {
    var prefs=await SharedPreferences.getInstance();
    isLogged=prefs.getBool('logged')??false;
    userName=prefs.getString('name')??'';
    email=prefs.getString('email')??'';
    phone=prefs.getString('phone')??'';
    partnerId=prefs.getInt('partner_id')??0;
    notifyListeners();
  }

  Future<bool> loginOrRegister({required String name, required String phoneNum, required String emailVal}) async {
    var partner = await odoo.findOrCreatePartner(name: name, phone: phoneNum, email: emailVal);
    if(partner!=null){
      var prefs=await SharedPreferences.getInstance();
      await prefs.setBool('logged', true);
      await prefs.setString('name', partner['name']??name);
      await prefs.setString('phone', phoneNum);
      await prefs.setString('email', emailVal);
      await prefs.setInt('partner_id', partner['id']??0);
      isLogged=true; userName=partner['name']??name; phone=phoneNum; email=emailVal; partnerId=partner['id']??0;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    var prefs=await SharedPreferences.getInstance();
    await prefs.clear();
    isLogged=false; userName=''; phone=''; email=''; partnerId=0;
    notifyListeners();
  }
}
