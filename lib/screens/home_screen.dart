
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/cart_provider.dart';
import '../services/odoo_service.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'about_screen.dart';
import 'return_policy_screen.dart';

class HomeScreen extends StatefulWidget{ @override _HomeScreenState createState()=> _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen>{
  final odoo=ApiService();
  List products=[], filtered=[], categories=[], banners=[];
  bool loading=true;
  final searchCtrl=TextEditingController();
  int currentBanner=0;
  final PageController bannerCtrl=PageController();

  @override
  void initState(){ super.initState(); loadAll(); }

  loadAll() async {
    var p=await odoo.getProducts();
    var c=await odoo.getCategories();
    var b=await odoo.getBanners();
    setState((){ products=p; filtered=p; categories=c; banners=b; loading=false; });
    // auto slider
    Future.delayed(Duration(seconds:3), autoSlide);
  }
  autoSlide(){
    if(!mounted) return;
    if(banners.isEmpty) return;
    setState(()=> currentBanner=(currentBanner+1)%banners.length);
    bannerCtrl.animateToPage(currentBanner, duration: Duration(milliseconds:400), curve: Curves.ease);
    Future.delayed(Duration(seconds:4), autoSlide);
  }

  void doSearch(String q){
    if(q.isEmpty){ setState(()=> filtered=products); return; }
    // بحث ذكي AI - يبحث في الاسم والوصف
    setState(()=> filtered=products.where((e){
      var name=(e['name']??'').toString().toLowerCase();
      var desc=(e['description_sale']??'').toString().toLowerCase();
      var qq=q.toLowerCase();
      return name.contains(qq) || desc.contains(qq);
    }).toList());
  }

  Future<void> searchByImage() async {
    final picker=ImagePicker();
    final img=await picker.pickImage(source: ImageSource.gallery);
    if(img!=null){
      // هنا يمكن ربط AI image search - حاليا نعرض كل المنتجات كأنها نتيجة
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('البحث بالصورة قريبا - سيتم مطابقة الصورة مع منتجاتك بـ AI', style: GoogleFonts.cairo()), backgroundColor: Color(0xFF0FA76B)));
    }
  }

  Future<void> openMap() async {
    final url = Uri.parse("https://maps.app.goo.gl/CdUZhv34BuGpXsEf9");
    if(await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget buildImage(String url){
    if(url.isEmpty) return Container(color: Color(0xFFF1F5F3), child: Center(child: Icon(Icons.image, size:40, color: Colors.grey)));
    return Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
      errorBuilder: (_,__,___)=> Container(color: Color(0xFFF1F5F3), child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
      loadingBuilder: (_,child,prog)=> prog==null? child : Center(child: CircularProgressIndicator(strokeWidth:2, color: Color(0xFF0FA76B))),
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation:0,
        title: Row(children:[
          Image.asset('assets/logo.png', width:36, height:36, errorBuilder: (_,__,___)=> Container(width:36,height:36,decoration: BoxDecoration(color: Color(0xFF0FA76B), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.storefront, color: Colors.white, size:22))),
          SizedBox(width:8),
          Text('سوق الوساط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black, fontSize:18)),
        ]),
        actions: [
          Consumer<CartProvider>(builder: (_,c,__)=> Stack(children:[
            IconButton(icon: Icon(Icons.shopping_cart, color: Colors.black), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> CartScreen()))),
            if(c.count>0) Positioned(right:6,top:6,child: Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${c.count}', style: TextStyle(color: Colors.white, fontSize:10)))),
          ])),
        ],
      ),
      body: loading? Center(child: CircularProgressIndicator(color: Color(0xFF0FA76B))): ListView(children:[
        // البحث الذكي + بحث بالصورة
        Padding(padding: EdgeInsets.all(12), child: Row(children:[
          Expanded(child: TextField(controller: searchCtrl, onChanged: doSearch, decoration: InputDecoration(hintText: 'بحث ذكي - اكتب اي كلمة', hintStyle: GoogleFonts.cairo(fontSize:13), prefixIcon: Icon(Icons.search, color: Color(0xFF0FA76B)), filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
          SizedBox(width:8),
          InkWell(onTap: searchByImage, child: Container(width:48,height:48,decoration: BoxDecoration(color: Color(0xFF0FA76B), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.camera_alt, color: Colors.white))),
        ])),

        // سلايدر العروض الحصرية - تتحكم فيه من Odoo
        Container(height:160, margin: EdgeInsets.symmetric(horizontal:12), child: PageView.builder(
          controller: bannerCtrl,
          onPageChanged: (i)=> setState(()=> currentBanner=i),
          itemCount: banners.length,
          itemBuilder: (_,i){
            var b=banners[i];
            Color col=Color(0xFF0FA76B);
            try{ if(b['color']!=null) col=Color(int.parse(b['color'].toString().replaceAll('0x',''), radix:16)); }catch(e){}
            return Container(margin: EdgeInsets.only(right:4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [col, col.withOpacity(0.7)])), child: Center(child: Text(b['name']??'العروض الحصرية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize:18), textAlign: TextAlign.center)));
          },
        )),
        SizedBox(height:8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(banners.length, (i)=> Container(width: currentBanner==i?20:6, height:6, margin: EdgeInsets.symmetric(horizontal:3), decoration: BoxDecoration(color: currentBanner==i?Color(0xFF0FA76B):Colors.grey[300], borderRadius: BorderRadius.circular(10))))),

        // الاقسام مع لوجو
        Padding(padding: EdgeInsets.fromLTRB(12,16,12,8), child: Text('الأقسام', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:15))),
        Container(height:90, child: ListView.builder(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal:12), itemCount: categories.length, itemBuilder: (_,i){
          var cat=categories[i];
          return InkWell(onTap: (){ setState(()=> filtered=products.where((p)=> (p['categ_id'] is List? p['categ_id'][0]:p['categ_id'])==cat['id']).toList()); }, child: Container(width:75, margin: EdgeInsets.only(left:10), child: Column(children:[
            Container(width:60,height:60,decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius:5)]), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(cat['image_url']??'', fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.category, color: Color(0xFF0FA76B))))),
            SizedBox(height:4),
            Text(cat['name']??'', maxLines:1, style: GoogleFonts.cairo(fontSize:10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ])));
        })),

        // المنتجات - فقط المنشورة website_published=True
        Padding(padding: EdgeInsets.fromLTRB(12,16,12,8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          Text('جميع المنتجات (${filtered.length}) - منشورة فقط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:13)),
          TextButton(onPressed: ()=> setState(()=> filtered=products), child: Text('عرض الكل', style: GoogleFonts.cairo(fontSize:11, color: Color(0xFF0FA76B)))),
        ])),
        GridView.builder(shrinkWrap:true, physics: NeverScrollableScrollPhysics(), padding: EdgeInsets.symmetric(horizontal:12), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2, childAspectRatio:0.72, crossAxisSpacing:12, mainAxisSpacing:12), itemCount: filtered.length, itemBuilder: (_,i){
          var p=filtered[i];
          return InkWell(
            onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> ProductDetailScreen(product: Map<String,dynamic>.from(p), allProducts: products))),
            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius:6)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Expanded(child: ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(14)), child: buildImage(p['image_512_url']??p['image_512']??''))),
              Padding(padding: EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Text(p['name']??'', maxLines:2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize:11.5, fontWeight: FontWeight.bold, height:1.2)),
                SizedBox(height:4),
                Text('${p['list_price']} ر.ع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Color(0xFF0FA76B), fontSize:13)),
                if(p['qty_available']!=null) Text('المخزون: ${p['qty_available']}', style: GoogleFonts.cairo(fontSize:9, color: Colors.grey)),
              ])),
            ])),
          );
        }),
        SizedBox(height:20),
        // فوتر ثابت
        Container(
          color: Color(0xFF0B1D2A),
          padding: EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[Image.asset('assets/logo.png', width:32, height:32, errorBuilder: (_,__,___)=> Container(width:32,height:32,decoration: BoxDecoration(color: Color(0xFF0FA76B), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.storefront, color: Colors.white, size:18))), SizedBox(width:8), Text('سوق الوساط - نزوى الصقرية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize:15))]),
            SizedBox(height:12),
            InkWell(onTap: openMap, child: Row(children:[Icon(Icons.location_on, color: Color(0xFF0FA76B), size:18), SizedBox(width:6), Expanded(child: Text('ولاية نزوى - الصقرية بجوار مجلس الغنتق - اضغط لفتح الخريطة', style: GoogleFonts.cairo(color: Colors.white70, fontSize:12)))])),
            SizedBox(height:8),
            Text('للتواصل: 98518810 - 91705789 - 96057486 - 97322730', style: GoogleFonts.cairo(color: Colors.white70, fontSize:12)),
            SizedBox(height:8),
            Row(children:[Icon(Icons.camera_alt, color: Colors.pink[300], size:16), SizedBox(width:4), Text('@souq_alwisat', style: GoogleFonts.cairo(color: Colors.pink[200], fontSize:12))]),
            SizedBox(height:16),
            Row(children:[
              Expanded(child: InkWell(onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> AboutScreen())), child: Container(padding: EdgeInsets.symmetric(vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('من نحن', style: GoogleFonts.cairo(color: Colors.white, fontSize:12)))))),
              SizedBox(width:8),
              Expanded(child: InkWell(onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> ReturnPolicyScreen())), child: Container(padding: EdgeInsets.symmetric(vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('سياسة الاسترجاع', style: GoogleFonts.cairo(color: Colors.white, fontSize:12)))))),
            ]),
            SizedBox(height:12),
            Text('التوصيل لجميع مناطق السلطنة - الاستلام المجاني من المحل + الشحن المدفوع (1 ر.ع + 0.1 لكل كجم فوق 10 كجم)', style: GoogleFonts.cairo(color: Colors.white38, fontSize:10)),
          ]),
        ),
      ]),
    );
  }
}
