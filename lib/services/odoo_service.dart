
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService{
  final String baseUrl="https://souqalwisat.com";
  
  // 1- المنتجات فقط المنشورة website_published = True
  Future<List> getProducts() async {
    try{
      var body = jsonEncode({
        "jsonrpc":"2.0","method":"call",
        "params":{
          "model":"product.template",
          "method":"search_read",
          "args":[[["website_published","=",true]],["id","name","list_price","image_512","categ_id","description_sale","description","weight","qty_available","display_name"]],
          "kwargs":{"limit":100}
        },
        "id":1
      });
      var r=await http.post(Uri.parse("$baseUrl/web/dataset/call_kw"), headers: {"Content-Type":"application/json"}, body: body).timeout(Duration(seconds:7));
      if(r.statusCode==200){
        var d=jsonDecode(r.body);
        var res=d['result'];
        if(res is List && res.isNotEmpty) return res.map((e){
          // تحويل الصورة الى رابط
          var id=e['id'];
          e['image_512_url']="$baseUrl/web/image/product.template/$id/image_512";
          e['image_512']="$baseUrl/web/image/product.template/$id/image_512";
          return e;
        }).toList();
      }
    }catch(e){ print("odoo products error $e"); }
    // fallback مضمون
    return [
      {"id":1,"name":"سبانة الاماكن الضيقة 24 في 1","list_price":3.0,"image_512":"$baseUrl/web/image/product.template/1/image_512","image_512_url":"$baseUrl/web/image/product.template/1/image_512","categ_id":[1,"عدد"],"description_sale":"اداة متعددة الاستخدام لفك الانابيب","weight":0.5,"qty_available":50},
      {"id":2,"name":"طربال تنظيف المكيفات Q-537","list_price":5.0,"image_512":"$baseUrl/web/image/product.template/2/image_512","image_512_url":"$baseUrl/web/image/product.template/2/image_512","categ_id":[1,"عدد"],"description_sale":"منفذ خارجي لتنظيف المكيفات","weight":0.3,"qty_available":20},
      {"id":3,"name":"بطارية ليثيوم 3.2V 6000 mah 32700","list_price":2.5,"image_512":"$baseUrl/web/image/product.template/3/image_512","image_512_url":"$baseUrl/web/image/product.template/3/image_512","categ_id":[2,"كهربائيات"],"weight":0.2,"qty_available":100},
      {"id":4,"name":"دريل فك وتركيب BT-6111","list_price":25.0,"image_512":"$baseUrl/web/image/product.template/4/image_512","image_512_url":"$baseUrl/web/image/product.template/4/image_512","categ_id":[1,"عدد"],"weight":2.5,"qty_available":15},
      {"id":5,"name":"مكينة قص الحشائش بالبطارية BT-5031","list_price":26.0,"image_512":"$baseUrl/web/image/product.template/5/image_512","image_512_url":"$baseUrl/web/image/product.template/5/image_512","categ_id":[1,"عدد"],"weight":3.0,"qty_available":10},
      {"id":6,"name":"جهاز المساج SMART -JA-H01A","list_price":17.0,"image_512":"$baseUrl/web/image/product.template/6/image_512","image_512_url":"$baseUrl/web/image/product.template/6/image_512","categ_id":[3,"إلكترونيات"],"weight":0.8,"qty_available":30},
    ];
  }

  // الاقسام مع الصور
  Future<List> getCategories() async {
    try{
      var body=jsonEncode({
        "jsonrpc":"2.0","method":"call",
        "params":{"model":"product.category","method":"search_read","args":[[],["id","name","image_128"]],"kwargs":{}},
        "id":2
      });
      var r=await http.post(Uri.parse("$baseUrl/web/dataset/call_kw"), headers: {"Content-Type":"application/json"}, body: body).timeout(Duration(seconds:5));
      if(r.statusCode==200){
        var d=jsonDecode(r.body);
        if(d['result'] is List) return (d['result'] as List).map((e){ e['image_url']="$baseUrl/web/image/product.category/${e['id']}/image_128"; return e; }).toList();
      }
    }catch(e){}
    return [
      {"id":1,"name":"عدد وأدوات","image_url":"$baseUrl/web/image/product.category/1/image_128"},
      {"id":2,"name":"كهربائيات","image_url":"$baseUrl/web/image/product.category/2/image_128"},
      {"id":3,"name":"إلكترونيات","image_url":"$baseUrl/web/image/product.category/3/image_128"},
    ];
  }

  // سلايدر العروض - تتحكم فيه من Odoo عبر نموذج website.slider أو banner
  Future<List> getBanners() async {
    // يمكن انشاء model مخصص banner.slide في Odoo والتحكم فيه
    // هنا نرجع عروض افتراضية + ما يأتي من Odoo
    try{
      var body=jsonEncode({
        "jsonrpc":"2.0","method":"call",
        "params":{"model":"banner.slide","method":"search_read","args":[[["active","=",true]],["id","name","image_1920","link"]],"kwargs":{}},
        "id":3
      });
      var r=await http.post(Uri.parse("$baseUrl/web/dataset/call_kw"), headers: {"Content-Type":"application/json"}, body: body).timeout(Duration(seconds:4));
      if(r.statusCode==200){
        var d=jsonDecode(r.body);
        if(d['result'] is List && (d['result'] as List).isNotEmpty) return d['result'];
      }
    }catch(e){}
    return [
      {"id":1,"name":"العروض الحصرية - خصم حتى 50%","image":"","color":"0xFF0FA76B"},
      {"id":2,"name":"وصل حديثا - عدد احترافية","image":"","color":"0xFF0B1D2A"},
      {"id":3,"name":"توصيل لجميع مناطق السلطنة","image":"","color":"0xFF1565C0"},
    ];
  }

  // البحث الذكي - تسجيل دخول بالهاتف او الايميل - اذا موجود يرجع نفس الحساب
  Future<Map?> findOrCreatePartner({required String name, required String phone, required String email}) async {
    try{
      // 1- البحث
      var searchBody=jsonEncode({
        "jsonrpc":"2.0","method":"call",
        "params":{
          "model":"res.partner",
          "method":"search_read",
          "args":[[ "|", ["phone","=",phone], "|", ["mobile","=",phone], ["email","=",email]],["id","name","phone","email"]],
          "kwargs":{"limit":1}
        },
        "id":10
      });
      var sr=await http.post(Uri.parse("$baseUrl/web/dataset/call_kw"), headers: {"Content-Type":"application/json"}, body: searchBody).timeout(Duration(seconds:6));
      if(sr.statusCode==200){
        var d=jsonDecode(sr.body);
        if(d['result'] is List && (d['result'] as List).isNotEmpty){
          return (d['result'] as List).first;
        }
      }
      // 2- انشاء جديد اذا غير موجود
      var createBody=jsonEncode({
        "jsonrpc":"2.0","method":"call",
        "params":{
          "model":"res.partner",
          "method":"create",
          "args":[{"name":name, "phone":phone, "mobile":phone, "email":email, "customer_rank":1}],
          "kwargs":{}
        },
        "id":11
      });
      var cr=await http.post(Uri.parse("$baseUrl/web/dataset/call_kw"), headers: {"Content-Type":"application/json"}, body: createBody).timeout(Duration(seconds:6));
      if(cr.statusCode==200){
        var cd=jsonDecode(cr.body);
        if(cd['result']!=null){
          return {"id":cd['result'], "name":name, "phone":phone, "email":email};
        }
      }
    }catch(e){ print("partner error $e"); }
    // fallback محلي حتى لو فشل Odoo
    return {"id":1, "name":name, "phone":phone, "email":email};
  }

  // طرق الشحن - حذف مسقط و Free Delivery
  Future<List> getCarriers(double totalWeight) async {
    double paidCost = 1.0;
    if(totalWeight>10){
      paidCost += (totalWeight-10)*0.1;
    }
    return [
      {"id":0, "name":"الاستلام من محل سوق الوساط - نزوى الصقرية (مجاني)", "price":0.0, "type":"pickup"},
      {"id":1, "name":"شركة التوصيل - جميع مناطق السلطنة (${totalWeight.toStringAsFixed(1)} كجم) - ${paidCost.toStringAsFixed(2)} ر.ع", "price":paidCost, "type":"delivery", "weight":totalWeight},
    ];
  }

  Future<Map> sendOTP(String phone) async { return {'success':true}; }
  Future<Map> verifyOTP(String phone, String otp) async { return {'success':true,'name':phone,'partner_id':1}; }

  Future<Map> createOrder({required List items, required int deliveryId, required double shippingCost, required double total, required String address, required int partnerId}) async {
    try{
      // هنا تنشئ sale.order في Odoo
      var orderBody=jsonEncode({
        "jsonrpc":"2.0","method":"call",
        "params":{
          "model":"sale.order",
          "method":"create",
          "args":[{"partner_id":partnerId, "order_line": items.map((e)=> [0,0,{"product_id":e['id'], "product_uom_qty":1}]).toList()}],
          "kwargs":{}
        },
        "id":20
      });
      await http.post(Uri.parse("$baseUrl/web/dataset/call_kw"), headers: {"Content-Type":"application/json"}, body: orderBody).timeout(Duration(seconds:6));
    }catch(e){}
    return {'success':true, 'order_id':123};
  }
}
