<?php
/**
 * سوق الوساط - Odoo API Proxy v5
 * نظام تسجيل دخول بالهاتف/الإيميل + كود تحقق OTP
 * يمنع تكرار جهات الاتصال - يربط بالحساب القديم تلقائياً
 * يدعم: المنتجات المنشورة فقط، صور إضافية (product_template_image_ids فقط)،
 * قوائم أسعار، طرق شحن، بوابات دفع، منتجات مشابهة
 * يجب رفعه على نفس سيرفر Odoo (souqalwisat.com)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// ═══════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════
$ODOO_URL    = 'https://souqalwisat.com';
$ODOO_DB     = 'souq10';
$ODOO_USER   = 'nazwani22.3.6@hotmail.com';
$ODOO_APIKEY = '5a0d6f03c6f706596795341209b5814981543d64';
$DEVELOPMENT_MODE = false;  // true = إظهار OTP في الرد | false = وضع الإنتاج
// ═══════════════════════════════════════════════

$input = json_decode(file_get_contents('php://input'), true);
if (!$input || !isset($input['action'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing action parameter']);
    exit;
}

$action = $input['action'];

// ═══════════════════════════════════════════════
// XML-RPC HELPERS
// ═══════════════════════════════════════════════
function odoo_call($model, $method, $args = [], $kwargs = []) {
    global $ODOO_URL, $ODOO_DB, $uid, $ODOO_APIKEY;
    $payload = xmlrpc_encode_request('execute_kw', [
        $ODOO_DB, $uid, $ODOO_APIKEY, $model, $method, $args, $kwargs
    ]);
    $ch = curl_init($ODOO_URL . '/xmlrpc/2/object');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS    => $payload,
        CURLOPT_HTTPHEADER     => ['Content-Type: text/xml'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_TIMEOUT         => 30
    ]);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($code !== 200) return ['error' => "HTTP $code"];
    $dec = xmlrpc_decode($resp);
    if (xmlrpc_is_fault($dec)) return ['error' => $dec['faultString']];
    return $dec;
}

function odoo_auth($url, $db, $user, $pass) {
    $payload = xmlrpc_encode_request('authenticate', [$db, $user, $pass, []]);
    $ch = curl_init($url . '/xmlrpc/2/common');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS    => $payload,
        CURLOPT_HTTPHEADER     => ['Content-Type: text/xml'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_TIMEOUT         => 15
    ]);
    $resp = curl_exec($ch);
    curl_close($ch);
    $uid = xmlrpc_decode($resp);
    return $uid ? $uid : false;
}

function odoo_call_with($withUid, $withPass, $model, $method, $args = [], $kwargs = []) {
    global $ODOO_URL, $ODOO_DB;
    $payload = xmlrpc_encode_request('execute_kw', [
        $ODOO_DB, $withUid, $withPass, $model, $method, $args, $kwargs
    ]);
    $ch = curl_init($ODOO_URL . '/xmlrpc/2/object');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS    => $payload,
        CURLOPT_HTTPHEADER     => ['Content-Type: text/xml'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_TIMEOUT         => 30
    ]);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($code !== 200) return ['error' => "HTTP $code"];
    $dec = xmlrpc_decode($resp);
    if (xmlrpc_is_fault($dec)) return ['error' => $dec['faultString']];
    return $dec;
}

$uid = odoo_auth($ODOO_URL, $ODOO_DB, $ODOO_USER, $ODOO_APIKEY);
if (!$uid) {
    http_response_code(401);
    echo json_encode(['error' => 'Odoo authentication failed']);
    exit;
}

// ═══════════════════════════════════════════════
// OTP & SESSION HELPERS
// ═══════════════════════════════════════════════
$OTP_DIR     = sys_get_temp_dir() . '/souq_otp';
$SESSION_DIR = sys_get_temp_dir() . '/souq_sessions';
if (!is_dir($OTP_DIR))     @mkdir($OTP_DIR, 0700, true);
if (!is_dir($SESSION_DIR)) @mkdir($SESSION_DIR, 0700, true);

function otp_store($identifier, $data) {
    global $OTP_DIR;
    $key = preg_replace('/[^a-zA-Z0-9]/', '_', $identifier);
    $file = $OTP_DIR . '/' . $key . '.json';
    $data['_exp'] = time() + 300; // صالح 5 دقائق
    $data['_attempts'] = 0;
    @file_put_contents($file, json_encode($data, JSON_UNESCAPED_UNICODE));
}

function otp_retrieve($identifier) {
    global $OTP_DIR;
    $key = preg_replace('/[^a-zA-Z0-9]/', '_', $identifier);
    $file = $OTP_DIR . '/' . $key . '.json';
    if (!file_exists($file)) return null;
    $d = json_decode(@file_get_contents($file), true);
    if (!$d || time() > ($d['_exp'] ?? 0)) { @unlink($file); return null; }
    return $d;
}

function otp_increment_attempt($identifier) {
    global $OTP_DIR;
    $key = preg_replace('/[^a-zA-Z0-9]/', '_', $identifier);
    $file = $OTP_DIR . '/' . $key . '.json';
    if (!file_exists($file)) return 99;
    $d = json_decode(@file_get_contents($file), true);
    if (!$d) return 99;
    $d['_attempts'] = ($d['_attempts'] ?? 0) + 1;
    if ($d['_attempts'] > 5) { @unlink($file); return 99; }
    @file_put_contents($file, json_encode($d, JSON_UNESCAPED_UNICODE));
    return $d['_attempts'];
}

function otp_clear($identifier) {
    global $OTP_DIR;
    $key = preg_replace('/[^a-zA-Z0-9]/', '_', $identifier);
    @unlink($OTP_DIR . '/' . $key . '.json');
}

function generate_otp() {
    return strval(random_int(100000, 999999));
}

function session_store($token, $data) {
    global $SESSION_DIR;
    $data['_created'] = time();
    @file_put_contents($SESSION_DIR . '/' . $token . '.json', json_encode($data, JSON_UNESCAPED_UNICODE));
}

function session_retrieve($token) {
    global $SESSION_DIR;
    $file = $SESSION_DIR . '/' . $token . '.json';
    if (!file_exists($file)) return null;
    $d = json_decode(@file_get_contents($file), true);
    // الجلسة صالحة 30 يوم
    if (!$d || (time() - ($d['_created'] ?? 0)) > 2592000) { @unlink($file); return null; }
    return $d;
}

function session_clear($token) {
    global $SESSION_DIR;
    @unlink($SESSION_DIR . '/' . $token . '.json');
}

// ═══════════════════════════════════════════════
// PARTNER SEARCH HELPERS
// ═══════════════════════════════════════════════
function find_partner_by_phone($phone) {
    // تنظيف الرقم - نأخذ آخر 9 أرقام فقط
    $clean = preg_replace('/[^0-9]/', '', $phone);
    $last9 = substr($clean, -9);
    if (strlen($last9) < 8) return null;
    
    // بحث بنهاية الرقم لتغطية صيغ مختلفة (968XXX, +968XXX, XXX)
    $partners = odoo_call('res.partner', 'search_read',
        [['|',
          '|', ['phone', 'like', $last9],
                  ['mobile', 'like', $last9],
          ['phone', '=', $phone]
        ]],
        ['fields' => ['id', 'name', 'email', 'phone', 'mobile', 'user_id', 'parent_id'], 'limit' => 10]
    );
    if (!is_array($partners) || isset($partners['error']) || count($partners) === 0) return null;
    
    // نفضل الشريك المستقل (بدون أب) و الذي له مستخدم مرتبط
    $best = null;
    foreach ($partners as $p) {
        if (!empty($p['parent_id']) && is_array($p['parent_id'])) continue; // تجاهل جهات الاتصال الفرعية
        if ($p['user_id'] && is_array($p['user_id']) && $p['user_id'][0]) {
            return $p; // أفضل نتيجة: شريك مستقل له مستخدم
        }
        if (!$best) $best = $p;
    }
    return $best;
}

function find_partner_by_email($email) {
    $partners = odoo_call('res.partner', 'search_read',
        [['email', '=', $email]],
        ['fields' => ['id', 'name', 'email', 'phone', 'mobile', 'user_id', 'parent_id'], 'limit' => 5]
    );
    if (!is_array($partners) || isset($partners['error']) || count($partners) === 0) return null;
    
    foreach ($partners as $p) {
        if (!empty($p['parent_id']) && is_array($p['parent_id'])) continue;
        if ($p['user_id'] && is_array($p['user_id']) && $p['user_id'][0]) {
            return $p;
        }
    }
    // رجع أول شريك مستقل
    foreach ($partners as $p) {
        if (empty($p['parent_id']) || !is_array($p['parent_id'])) return $p;
    }
    return $partners[0];
}

function ensure_partner($identifier, $idType) {
    // ابحث عن شريك موجود أولاً - لا تكرر!
    $partner = ($idType === 'phone') ? find_partner_by_phone($identifier) : find_partner_by_email($identifier);
    if ($partner) return $partner;
    
    // شريك غير موجود - أنشئ واحد جديد
    $data = [];
    if ($idType === 'phone') {
        $data = ['name' => $identifier, 'phone' => $identifier];
    } else {
        $data = ['name' => explode('@', $identifier)[0], 'email' => $identifier];
    }
    $pid = odoo_call('res.partner', 'create', [$data]);
    if (!$pid || (is_array($pid) && isset($pid['error']))) return null;
    
    // جلب بيانات الشريك الجديد
    $p = odoo_call('res.partner', 'read', [[$pid]], ['fields' => ['id', 'name', 'email', 'phone', 'mobile', 'user_id']]);
    if (is_array($p) && !isset($p['error']) && count($p) > 0) return $p[0];
    return null;
}

// ═══════════════════════════════════════════════
// HELPER: Fetch extra images (product_template_image_ids ONLY)
// ═══════════════════════════════════════════════
function get_extra_images($imageIds) {
    if (empty($imageIds)) return [];
    $imgs = odoo_call('product.image', 'search_read',
        [['id', 'in', $imageIds]],
        ['fields' => ['name', 'sequence']]
    );
    if (!is_array($imgs) || isset($imgs['error'])) return [];
    usort($imgs, function($a, $b) { return ($a['sequence'] ?? 0) - ($b['sequence'] ?? 0); });
    global $ODOO_URL;
    return array_map(function($img) use ($ODOO_URL) {
        return [
            'id' => $img['id'],
            'name' => $img['name'],
            'url' => $ODOO_URL . '/web/image/product.image/' . $img['id'] . '/image_1920'
        ];
    }, $imgs);
}

// ═══════════════════════════════════════════════
// HELPER: Fetch offer prices (pricelist ID=4)
// ═══════════════════════════════════════════════
function get_offer_prices($productIds) {
    if (empty($productIds)) return [];
    $items = odoo_call('product.pricelist.item', 'search_read',
        [['pricelist_id', '=', 4], ['product_tmpl_id', 'in', $productIds]],
        ['fields' => ['product_tmpl_id', 'fixed_price', 'compute_price', 'price_discount', 'date_start', 'date_end']]
    );
    if (!is_array($items) || isset($items['error'])) return [];
    $map = [];
    $now = time();
    foreach ($items as $it) {
        $pid = is_array($it['product_tmpl_id']) ? $it['product_tmpl_id'][0] : $it['product_tmpl_id'];
        $s = !empty($it['date_start']) ? strtotime($it['date_start']) : 0;
        $e = !empty($it['date_end']) ? strtotime($it['date_end']) : 9999999999;
        if ($now < $s || $now > $e) continue;
        if ($it['compute_price'] === 'fixed' && floatval($it['fixed_price']) > 0) {
            $map[$pid] = floatval($it['fixed_price']);
        }
    }
    return $map;
}

// ═══════════════════════════════════════════════
// HELPER: Enrich single product
// ═══════════════════════════════════════════════
function enrich_product(&$p, $priceMap) {
    global $ODOO_URL;
    $p['image_url'] = $ODOO_URL . '/web/image/product.template/' . $p['id'] . '/image_1920';
    $p['extra_images'] = get_extra_images($p['product_template_image_ids'] ?? []);
    if (isset($priceMap[$p['id']])) {
        $p['offer_price'] = $priceMap[$p['id']];
        if ($priceMap[$p['id']] < $p['list_price']) {
            $p['has_discount'] = true;
            $p['discount_pct'] = round((1 - $priceMap[$p['id']] / $p['list_price']) * 100);
        }
    }
}

// ═══════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════
switch ($action) {

    // ─── إرسال كود تحقق OTP ───
    case 'send_otp':
        $identifier = trim($input['identifier'] ?? '');
        if (!$identifier) {
            echo json_encode(['success' => false, 'error' => 'يرجى إدخال البريد الإلكتروني أو رقم الهاتف']);
            break;
        }
        
        // تحديد نوع المعرّف
        $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL) !== false;
        $idType  = $isEmail ? 'email' : 'phone';
        
        // تنسيق الهاتف - إزالة المسافات والشرطات
        if (!$isEmail) {
            $identifier = preg_replace('/[^0-9+]/', '', $identifier);
        }
        
        // البحث عن شريك موجود (لمنع التكرار)
        $partner = ($idType === 'phone') ? find_partner_by_phone($identifier) : find_partner_by_email($identifier);
        
        // توليد كود OTP من 6 أرقام
        $otpCode = generate_otp();
        
        // خزّن بيانات OTP
        otp_store($identifier, [
            'code'          => $otpCode,
            'id_type'       => $idType,
            'partner_id'    => $partner ? $partner['id'] : null,
            'partner_name'  => $partner ? $partner['name'] : null,
            'partner_email' => $partner ? ($partner['email'] ?? '') : '',
            'partner_phone' => $partner ? ($partner['phone'] ?? $partner['mobile'] ?? '') : '',
            'user_id'       => ($partner && $partner['user_id'] && is_array($partner['user_id'])) ? $partner['user_id'][0] : null,
            'is_new'        => !$partner
        ]);
        
        // إرسال الكود عبر واتساب باستخدام Twilio أو WaAPI
        // في الوقت الحالي نستخدم واتساب API مباشرة
        $sent = send_otp_whatsapp($identifier, $otpCode, $idType);
        
        // سجّل في ملف اللوج للمراجعة (فقط في وضع التطوير)
        if ($DEVELOPMENT_MODE) {
            @file_put_contents($OTP_DIR . '/otp_log.txt', 
                date('Y-m-d H:i:s') . " | $idType | $identifier | OTP: $otpCode | " . ($partner ? 'existing' : 'new') . "\n", 
                FILE_APPEND);
        }
        
        echo json_encode([
            'success' => true, 
            'data' => [
                'id_type'       => $idType,
                'expires_in'    => 300,
                'is_new_user'   => !$partner,
                'found_name'    => $partner ? $partner['name'] : null,
                'hint'         => $isEmail ? substr($identifier, 0, 3) . '***@' . explode('@', $identifier)[1] : '***' . substr($identifier, -4),
                'otp_code'      => $DEVELOPMENT_MODE ? $otpCode : null  // وضع الإنتاج: لا يُعرض الكود
            ]
        ]);
        break;

    // ─── التحقق من كود OTP وتسجيل الدخول ───
    case 'verify_otp':
        $identifier = trim($input['identifier'] ?? '');
        $otpCode    = trim($input['otp_code'] ?? '');
        
        if (!$identifier || !$otpCode) {
            echo json_encode(['success' => false, 'error' => 'يرجى إدخال كود التحقق']);
            break;
        }
        
        // تنسيق المعرّف كما في send_otp
        $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL) !== false;
        if (!$isEmail) {
            $identifier = preg_replace('/[^0-9+]/', '', $identifier);
        }
        
        // استرجع بيانات OTP
        $otpData = otp_retrieve($identifier);
        if (!$otpData) {
            echo json_encode(['success' => false, 'error' => 'لم يتم إرسال كود لهذا الرقم/البريد، أو انتهت صلاحيته']);
            break;
        }
        
        // تحقق من عدد المحاولات
        $attempts = otp_increment_attempt($identifier);
        if ($attempts > 5) {
            otp_clear($identifier);
            echo json_encode(['success' => false, 'error' => 'تجاوزت الحد الأقصى للمحاولات، أرسل كود جديد']);
            break;
        }
        
        // تحقق من الكود
        if ($otpData['code'] !== $otpCode) {
            echo json_encode(['success' => false, 'error' => 'كود التحقق غير صحيح (محاولة ' . $attempts . '/5)']);
            break;
        }
        
        // الكود صحيح ✓ - احذف OTP
        otp_clear($identifier);
        
        $idType    = $otpData['id_type'] ?? 'phone';
        $partnerId = $otpData['partner_id'] ?? null;
        $isNew     = $otpData['is_new'] ?? false;
        
        // تأكد من وجود الشريك في Odoo (أنشئ إن لم يوجد)
        $partner = ensure_partner($identifier, $idType);
        if (!$partner) {
            echo json_encode(['success' => false, 'error' => 'فشل إنشاء أو العثور على حساب العميل']);
            break;
        }
        $partnerId = $partner['id'];
        
        // اقرأ بيانات الشريك النهائية
        $partnerData = null;
        $pd = odoo_call('res.partner', 'read', [[$partnerId]], [
            'fields' => ['name', 'email', 'phone', 'mobile', 'street']
        ]);
        if (is_array($pd) && !isset($pd['error']) && count($pd) > 0) {
            $partnerData = $pd[0];
        }
        
        // أنشئ رمز جلسة (session token) خاص بالتطبيق
        $sessionToken = bin2hex(random_bytes(32));
        session_store($sessionToken, [
            'partner_id'  => $partnerId,
            'identifier'  => $identifier,
            'id_type'     => $idType
        ]);
        
        echo json_encode([
            'success' => true,
            'data' => [
                'session_token' => $sessionToken,
                'partner_id'    => $partnerId,
                'name'          => $partnerData ? $partnerData['name'] : $identifier,
                'email'         => $partnerData ? ($partnerData['email'] ?? '') : ($idType === 'email' ? $identifier : ''),
                'phone'         => $partnerData ? ($partnerData['phone'] ?? $partnerData['mobile'] ?? '') : ($idType === 'phone' ? $identifier : ''),
                'street'        => $partnerData ? ($partnerData['street'] ?? '') : '',
                'is_new_user'   => $isNew
            ]
        ]);
        break;

    // ─── التحقق من جلسة المستخدم ───
    case 'validate_session':
        $token = trim($input['session_token'] ?? '');
        if (!$token) {
            echo json_encode(['success' => false, 'error' => 'رمز الجلسة مفقود']);
            break;
        }
        $sData = session_retrieve($token);
        if (!$sData) {
            echo json_encode(['success' => false, 'error' => 'جلسة غير صالحة أو منتهية']);
            break;
        }
        // اقرأ بيانات الشريك المحدثة
        $partnerId = $sData['partner_id'];
        $pd = odoo_call('res.partner', 'read', [[$partnerId]], [
            'fields' => ['name', 'email', 'phone', 'mobile', 'street']
        ]);
        $partnerData = (is_array($pd) && !isset($pd['error']) && count($pd) > 0) ? $pd[0] : null;
        echo json_encode([
            'success' => true,
            'data' => [
                'session_token' => $token,
                'partner_id'    => $partnerId,
                'name'          => $partnerData ? $partnerData['name'] : $sData['identifier'],
                'email'         => $partnerData ? ($partnerData['email'] ?? '') : '',
                'phone'         => $partnerData ? ($partnerData['phone'] ?? $partnerData['mobile'] ?? '') : '',
                'street'        => $partnerData ? ($partnerData['street'] ?? '') : ''
            ]
        ]);
        break;

    // ─── تسجيل خروج ───
    case 'logout':
        $token = trim($input['session_token'] ?? '');
        if ($token) session_clear($token);
        echo json_encode(['success' => true]);
        break;

    // ─── تحديث بيانات العميل ───
    case 'update_profile':
        $token  = trim($input['session_token'] ?? '');
        $name   = trim($input['name'] ?? '');
        $email  = trim($input['email'] ?? '');
        $phone  = trim($input['phone'] ?? '');
        $street = trim($input['street'] ?? '');
        $sData = session_retrieve($token);
        if (!$sData) {
            echo json_encode(['success' => false, 'error' => 'جلسة غير صالحة']);
            break;
        }
        $pid = $sData['partner_id'];
        if (!$pid) {
            echo json_encode(['success' => false, 'error' => 'لا يوجد حساب مرتبط']);
            break;
        }
        $updateData = [];
        if ($name)   $updateData['name']   = $name;
        if ($email)  $updateData['email']  = $email;
        if ($phone)  $updateData['phone']  = $phone;
        if ($street) $updateData['street'] = $street;
        if (!empty($updateData)) {
            $res = odoo_call('res.partner', 'write', [[$pid], $updateData]);
            if (is_array($res) && isset($res['error'])) {
                echo json_encode(['success' => false, 'error' => 'فشل التحديث']);
                break;
            }
        }
        $pd = odoo_call('res.partner', 'read', [[$pid]], ['fields' => ['name','email','phone','mobile','street']]);
        $p = (is_array($pd) && !isset($pd['error']) && count($pd) > 0) ? $pd[0] : null;
        echo json_encode(['success' => true, 'data' => [
            'partner_id' => $pid,
            'name'       => $p ? $p['name'] : $name,
            'email'      => $p ? ($p['email'] ?? '') : $email,
            'phone'      => $p ? ($p['phone'] ?? $p['mobile'] ?? '') : $phone,
            'street'     => $p ? ($p['street'] ?? '') : $street
        ]]);
        break;

    // ─── جلب المنتجات المنشورة فقط ───
    case 'get_products':
        $domain = $input['domain'] ?? [['is_published', '=', true]];
        $limit  = intval($input['limit'] ?? 20);
        $offset = intval($input['offset'] ?? 0);
        $result = odoo_call('product.template', 'search_read', $domain, [
            'fields' => ['name', 'list_price', 'default_code', 'categ_id', 'description_sale',
                         'website_description', 'is_published', 'weight', 'product_template_image_ids'],
            'limit' => $limit, 'offset' => $offset
        ]);
        if (is_array($result) && !isset($result['error'])) {
            $pmap = get_offer_prices(array_column($result, 'id'));
            foreach ($result as &$p) { enrich_product($p, $pmap); }
            unset($p);
        }
        echo json_encode(['success' => true, 'data' => $result]);
        break;

    // ─── جلب المنتجات حسب الفئة ───
    case 'get_products_by_category':
        $catId  = intval($input['category_id'] ?? 0);
        $limit  = intval($input['limit'] ?? 20);
        $offset = intval($input['offset'] ?? 0);
        $result = odoo_call('product.template', 'search_read',
            [['is_published', '=', true], ['categ_id', '=', $catId]], [
            'fields' => ['name', 'list_price', 'default_code', 'categ_id', 'description_sale',
                         'website_description', 'is_published', 'weight', 'product_template_image_ids'],
            'limit' => $limit, 'offset' => $offset
        ]);
        if (is_array($result) && !isset($result['error'])) {
            $pmap = get_offer_prices(array_column($result, 'id'));
            foreach ($result as &$p) { enrich_product($p, $pmap); }
            unset($p);
        }
        echo json_encode(['success' => true, 'data' => $result]);
        break;

    // ─── جلب الفئات ───
    case 'get_categories':
        $result = odoo_call('product.category', 'search_read', [], [
            'fields' => ['name', 'parent_id']
        ]);
        echo json_encode(['success' => true, 'data' => $result]);
        break;

    // ─── البحث في المنتجات المنشورة ───
    case 'search_products':
        $q = $input['query'] ?? '';
        $result = odoo_call('product.template', 'search_read',
            [['is_published', '=', true], ['name', 'ilike', '%' . $q . '%']], [
            'fields' => ['name', 'list_price', 'categ_id', 'description_sale', 'website_description',
                         'weight', 'product_template_image_ids'],
            'limit' => 30
        ]);
        if (isset($result['error'])) {
            echo json_encode(['success' => false, 'error' => $result['error']]);
            break;
        }
        $pmap = get_offer_prices(array_column($result, 'id'));
        foreach ($result as &$p) { enrich_product($p, $pmap); }
        unset($p);
        echo json_encode(['success' => true, 'data' => $result]);
        break;

    // ─── جلب طرق الشحن ───
    case 'get_delivery_methods':
        $carriers = odoo_call('delivery.carrier', 'search_read',
            [['website_published', '=', true]], [
            'fields' => ['name', 'fixed_price', 'free_over', 'delivery_type', 'price_rule_ids']
        ]);
        $methods = [];
        if (is_array($carriers) && !isset($carriers['error'])) {
            foreach ($carriers as $c) {
                $m = [
                    'id' => $c['id'], 'name' => $c['name'],
                    'fixed_price' => floatval($c['fixed_price']),
                    'free_over' => $c['free_over'],
                    'delivery_type' => $c['delivery_type'],
                    'rules' => []
                ];
                if ($c['delivery_type'] === 'base_on_rule' && !empty($c['price_rule_ids'])) {
                    $rules = odoo_call('delivery.price.rule', 'search_read',
                        [['id', 'in', $c['price_rule_ids']]], [
                        'fields' => ['name', 'sequence', 'variable', 'operator', 'max_value',
                                     'list_base_price', 'list_price', 'variable_factor']
                    ]);
                    if (is_array($rules) && !isset($rules['error'])) {
                        $m['rules'] = array_map(function($r) {
                            return [
                                'id' => $r['id'], 'name' => $r['name'], 'sequence' => $r['sequence'],
                                'variable' => $r['variable'], 'operator' => $r['operator'],
                                'max_value' => floatval($r['max_value']),
                                'base_price' => floatval($r['list_base_price']),
                                'price_per_unit' => floatval($r['list_price']),
                                'factor' => $r['variable_factor']
                            ];
                        }, $rules);
                    }
                }
                $methods[] = $m;
            }
        }
        echo json_encode(['success' => true, 'data' => $methods]);
        break;

    // ─── حساب تكلفة الشحن ───
    case 'calculate_shipping':
        $cid = intval($input['carrier_id'] ?? 0);
        $tw  = floatval($input['weight'] ?? 0);
        $oa  = floatval($input['order_amount'] ?? 0);
        $car = odoo_call('delivery.carrier', 'search_read',
            [['id', '=', $cid]], [
            'fields' => ['name', 'fixed_price', 'free_over', 'delivery_type', 'price_rule_ids'],
            'limit' => 1
        ]);
        if (!is_array($car) || count($car) === 0 || isset($car['error'])) {
            echo json_encode(['success' => false, 'error' => 'طريقة الشحن غير موجودة']);
            break;
        }
        $c = $car[0];
        $cost = 0; $free = false;
        if ($c['free_over'] && $oa > 0 && $oa >= floatval($c['fixed_price'])) {
            $free = true; $cost = 0;
        }
        if (!$free) {
            if ($c['delivery_type'] === 'fixed') {
                $cost = floatval($c['fixed_price']);
            } elseif ($c['delivery_type'] === 'base_on_rule' && !empty($c['price_rule_ids'])) {
                $rules = odoo_call('delivery.price.rule', 'search_read',
                    [['id', 'in', $c['price_rule_ids']]], [
                    'fields' => ['sequence', 'variable', 'operator', 'max_value',
                                 'list_base_price', 'list_price', 'variable_factor']
                ]);
                if (is_array($rules) && !isset($rules['error'])) {
                    usort($rules, function($a, $b) { return $a['sequence'] - $b['sequence']; });
                    foreach ($rules as $r) {
                        $ok = false;
                        if ($r['variable'] === 'weight') {
                            switch ($r['operator']) {
                                case '<=': $ok = ($tw <= $r['max_value']); break;
                                case '<':  $ok = ($tw <  $r['max_value']); break;
                                case '>=': $ok = ($tw >= $r['max_value']); break;
                                case '>':  $ok = ($tw >  $r['max_value']); break;
                            }
                        }
                        if ($ok) {
                            $base = floatval($r['list_base_price']);
                            $pu   = floatval($r['list_price']);
                            $cost = ($pu > 0 && $r['variable_factor'] === 'weight') ? ($base + $pu * $tw) : $base;
                            break;
                        }
                    }
                }
            }
        }
        echo json_encode(['success' => true, 'data' => [
            'carrier_id' => $cid, 'carrier_name' => $c['name'],
            'cost' => round($cost, 3), 'is_free' => $free, 'weight' => $tw
        ]]);
        break;

    // ─── جلب طرق الدفع ───
    case 'get_payment_methods':
        $providers = odoo_call('payment.provider', 'search_read',
            [['state', '=', 'enabled'], ['is_published', '=', true]], [
            'fields' => ['name', 'code', 'state', 'is_published']
        ]);
        $methods = [];
        if (is_array($providers) && !isset($providers['error'])) {
            foreach ($providers as $pv) {
                $methods[] = [
                    'id' => $pv['id'], 'name' => $pv['name'], 'code' => $pv['code'],
                    'is_online' => in_array($pv['code'], ['thawani_checkout', 'stripe', 'paypal', 'paymob_oman'])
                ];
            }
        }
        $methods[] = ['id' => 0, 'name' => 'الدفع عند الاستلام', 'code' => 'cod', 'is_online' => false];
        echo json_encode(['success' => true, 'data' => $methods]);
        break;

    // ─── إنشاء جلسة ثواني ───
    case 'create_thawani_session':
        $oid = intval($input['order_id'] ?? 0);
        $amt = floatval($input['amount'] ?? 0);
        $prov = odoo_call('payment.provider', 'search_read',
            [['code', '=', 'thawani_checkout'], ['state', '=', 'enabled']], [
            'fields' => ['thawani_api_key', 'thawani_publishable_key', 'thawani_test_mode'], 'limit' => 1
        ]);
        if (!is_array($prov) || count($prov) === 0 || isset($prov['error'])) {
            echo json_encode(['success' => false, 'error' => 'بوابة ثواني غير مفعلة']);
            break;
        }
        $pv = $prov[0];
        $ak = $pv['thawani_api_key'] ?? '';
        $pk = $pv['thawani_publishable_key'] ?? '';
        $tm = $pv['thawani_test_mode'] ?? false;
        $bu = $tm ? 'https://uatcheckout.thawani.om' : 'https://checkout.thawani.om';
        $sd = [
            'client_reference_id' => strval($oid),
            'mode' => 'payment',
            'products' => [[
                'name' => 'طلب سوق الوساط #' . $oid,
                'quantity' => 1,
                'unit_amount' => intval($amt * 1000)
            ]],
            'success_url' => $ODOO_URL . '/app/?payment=success&order=' . $oid,
            'cancel_url'  => $ODOO_URL . '/app/?payment=cancel&order=' . $oid,
            'metadata' => ['order_id' => $oid]
        ];
        $ch = curl_init($bu . '/api/v1/checkout/session');
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS    => json_encode($sd),
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json', 'thawani-api-key: ' . $ak],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_TIMEOUT         => 20
        ]);
        $resp = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        $rd = json_decode($resp, true);
        if ($code === 201 && isset($rd['data']['session_id'])) {
            $sid = $rd['data']['session_id'];
            $curl = $bu . '/pay/' . $sid . '?key=' . $pk;
            echo json_encode(['success' => true, 'data' => [
                'session_id' => $sid, 'checkout_url' => $curl, 'publishable_key' => $pk
            ]]);
        } else {
            echo json_encode(['success' => false, 'error' => 'فشل إنشاء جلسة الدفع', 'details' => $rd]);
        }
        break;

    // ─── التحقق من حالة دفع ثواني ───
    case 'verify_thawani_payment':
        $sid = trim($input['session_id'] ?? '');
        $oid = intval($input['order_id'] ?? 0);

        if (!$sid) {
            echo json_encode(['success' => false, 'error' => 'معرف الجلسة مفقود']);
            break;
        }

        // جلب مفاتيح ثواني من Odoo
        $prov = odoo_call('payment.provider', 'search_read',
            [['code', '=', 'thawani_checkout'], ['state', '=', 'enabled']], [
            'fields' => ['thawani_api_key', 'thawani_test_mode'], 'limit' => 1
        ]);
        if (!is_array($prov) || count($prov) === 0 || isset($prov['error'])) {
            echo json_encode(['success' => false, 'error' => 'بوابة ثواني غير مفعلة']);
            break;
        }
        $pv = $prov[0];
        $ak = $pv['thawani_api_key'] ?? '';
        $tm = $pv['thawani_test_mode'] ?? false;
        $bu = $tm ? 'https://uatcheckout.thawani.om' : 'https://checkout.thawani.om';

        // Retrieve Session - GET /api/v1/checkout/session/{session_id}
        $ch = curl_init($bu . '/api/v1/checkout/session/' . $sid);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json', 'thawani-api-key: ' . $ak],
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_TIMEOUT        => 15
        ]);
        $resp = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err  = curl_error($ch);
        curl_close($ch);

        if ($err) {
            echo json_encode(['success' => false, 'error' => 'فشل الاتصال بثواني: ' . $err]);
            break;
        }

        $rd = json_decode($resp, true);

        if ($code !== 200 || !isset($rd['data']) || $rd['success'] !== true) {
            echo json_encode(['success' => false, 'error' => 'فشل التحقق من حالة الدفع', 'details' => $rd]);
            break;
        }

        $pStatus = $rd['data']['payment_status'] ?? 'unpaid';

        // payment_status: unpaid | paid | successful
        $isPaid = in_array($pStatus, ['paid', 'successful']);

        // إذا الدفع ناجح، نؤكد الطلب والفاتورة في Odoo (مع حماية من التأكيد المزدوج)
        if ($isPaid && $oid > 0) {
            // فحص حالة الطلب الحالية لمنع التأكيد المزدوج
            $stR = odoo_call('sale.order', 'read', [[$oid]], ['fields' => ['state']]);
            $currentState = (is_array($stR) && !isset($stR['error']) && isset($stR[0]['state'])) ? $stR[0]['state'] : '';
            if ($currentState === 'draft') {
                // الطلب لا يزال مسودة - نؤكد
                odoo_call('sale.order', 'action_confirm', [[$oid]]);
            }
            // إنشاء فاتورة فقط إذا لم تكن موجودة مسبقاً
            $existInv = odoo_call('sale.order', 'read', [[$oid]], ['fields' => ['invoice_ids']]);
            $hasInvoice = (is_array($existInv) && !isset($existInv['error']) && isset($existInv[0]['invoice_ids']) && count($existInv[0]['invoice_ids']) > 0);
            if (!$hasInvoice) {
                $invIds = odoo_call('sale.order', '_create_invoices', [[$oid]]);
                if (is_array($invIds) && count($invIds) > 0 && !isset($invIds['error'])) {
                    odoo_call('account.move', 'action_post', [$invIds]);
                }
            } elseif ($hasInvoice) {
                // فاتورة موجودة - نتأكد أنها مرحّلة
                $invData = odoo_call('account.move', 'read', [$existInv[0]['invoice_ids']], ['fields' => ['state']]);
                if (is_array($invData) && !isset($invData['error'])) {
                    foreach ($invData as $iv) {
                        if (($iv['state'] ?? '') === 'draft') {
                            odoo_call('account.move', 'action_post', [[$iv['id']]]);
                        }
                    }
                }
            }
        }

        echo json_encode([
            'success' => true,
            'data' => [
                'session_id'      => $sid,
                'order_id'        => $oid,
                'payment_status'  => $pStatus,
                'is_paid'         => $isPaid,
                'total_amount'    => $rd['data']['total_amount'] ?? 0,
                'currency'        => $rd['data']['currency'] ?? 'OMR',
                'created_at'      => $rd['data']['created_at'] ?? '',
                'expire_at'       => $rd['data']['expire_at'] ?? ''
            ]
        ]);
        break;

    // ─── إنشاء طلب بيع ───
    case 'create_order':
        $pid     = intval($input['partner_id'] ?? 0);
        $lines   = $input['lines'] ?? [];
        $cname   = $input['customer_name'] ?? '';
        $cphone  = $input['customer_phone'] ?? '';
        $cemail  = $input['customer_email'] ?? '';
        $did     = intval($input['delivery_id'] ?? 0);
        $pcode   = $input['payment_code'] ?? 'cod';
        $daddr   = $input['delivery_address'] ?? '';
        
        // إذا عندنا session token، نستخدم الشريك المرتبط
        $stoken  = trim($input['session_token'] ?? '');
        if ($stoken && !$pid) {
            $sData = session_retrieve($stoken);
            if ($sData && $sData['partner_id']) {
                $pid = $sData['partner_id'];
            }
        }
        
        // البحث عن شريك موجود أو إنشاء جديد - بدون تكرار!
        if (!$pid) {
            $partner = null;
            if ($cphone) {
                $partner = find_partner_by_phone($cphone);
            }
            if (!$partner && $cemail) {
                $partner = find_partner_by_email($cemail);
            }
            if ($partner) {
                $pid = $partner['id'];
                // حدّث الاسم إذا مختلف
                if ($cname && $cname !== $partner['name']) {
                    odoo_call('res.partner', 'write', [[$pid], ['name' => $cname]]);
                }
            } else {
                $pid = odoo_call('res.partner', 'create', [[
                    'name' => $cname, 'phone' => $cphone,
                    'email' => $cemail, 'street' => $daddr
                ]]);
            }
        }
        if (!$pid || (is_array($pid) && isset($pid['error']))) {
            echo json_encode(['success' => false, 'error' => 'فشل إنشاء العميل']);
            break;
        }
        $od = ['partner_id' => $pid, 'state' => 'draft'];
        if ($did) $od['carrier_id'] = $did;
        $oid = odoo_call('sale.order', 'create', [$od]);
        if (!$oid || (is_array($oid) && isset($oid['error']))) {
            echo json_encode(['success' => false, 'error' => 'فشل إنشاء الطلب']);
            break;
        }
        foreach ($lines as $ln) {
            odoo_call('sale.order.line', 'create', [[
                'order_id' => $oid,
                'product_id' => intval($ln['product_id']),
                'product_uom_qty' => floatval($ln['qty']),
                'price_unit' => floatval($ln['price'])
            ]]);
        }
        // ثواني = تأكيد + فاتورة مؤكدة | COD = مسودة فقط
        // (هنا لا نحتاج فحص حالة لأن الطلب刚刚 اُنشئ وهو حتماً في حالة مسودة)
        if ($pcode === 'thawani_checkout') {
            odoo_call('sale.order', 'action_confirm', [[$oid]]);
            $invIds = odoo_call('sale.order', '_create_invoices', [[$oid]]);
            if (is_array($invIds) && count($invIds) > 0 && !isset($invIds['error'])) {
                odoo_call('account.move', 'action_post', [$invIds]);
            }
        }
        echo json_encode(['success' => true, 'data' => ['order_id' => $oid, 'partner_id' => $pid]]);
        break;

    // ─── منتجات مشابهة ───
    case 'get_similar_products':
        $cid2 = intval($input['categ_id'] ?? 0);
        $eid  = intval($input['exclude_id'] ?? 0);
        $lim2 = intval($input['limit'] ?? 8);
        if (!$cid2) {
            echo json_encode(['success' => true, 'data' => []]);
            break;
        }
        $sr = odoo_call('product.template', 'search_read',
            [['categ_id', '=', $cid2], ['is_published', '=', true], ['id', '!=', $eid]], [
            'fields' => ['name', 'list_price', 'categ_id', 'description_sale',
                         'website_description', 'product_template_image_ids'],
            'limit' => $lim2
        ]);
        if (isset($sr['error'])) {
            echo json_encode(['success' => false, 'error' => $sr['error']]);
            break;
        }
        $pm2 = get_offer_prices(array_column($sr, 'id'));
        foreach ($sr as &$sp) {
            $sp['image_url'] = $ODOO_URL . '/web/image/product.template/' . $sp['id'] . '/image_1920';
            $sp['extra_images'] = get_extra_images($sp['product_template_image_ids'] ?? []);
            if (isset($pm2[$sp['id']])) {
                $sp['offer_price'] = $pm2[$sp['id']];
                if ($pm2[$sp['id']] < $sp['list_price']) {
                    $sp['has_discount'] = true;
                    $sp['discount_pct'] = round((1 - $pm2[$sp['id']] / $sp['list_price']) * 100);
                }
            }
        }
        unset($sp);
        echo json_encode(['success' => true, 'data' => $sr]);
        break;

    // ─── تسجيل دخول تقليدي (للإدارة) ───
    case 'user_login':
        $lem = $input['login'] ?? '';
        $lpa = $input['password'] ?? '';
        $loginUid = odoo_auth($ODOO_URL, $ODOO_DB, $lem, $lpa);
        if ($loginUid) {
            $ud = odoo_call_with($loginUid, $lpa, 'res.users', 'read', [[$loginUid]], [
                'fields' => ['name', 'email', 'phone', 'partner_id']
            ]);
            $pid2 = null;
            if (is_array($ud) && !isset($ud['error']) && isset($ud[0]['partner_id'])) {
                $pid2 = $ud[0]['partner_id'][0];
            }
            // أنشئ جلسة أيضاً
            $sToken = bin2hex(random_bytes(32));
            session_store($sToken, [
                'partner_id' => $pid2,
                'identifier' => $lem,
                'id_type'    => 'email'
            ]);
            echo json_encode(['success' => true, 'data' => [
                'uid' => $loginUid, 'user' => (is_array($ud) && !isset($ud['error'])) ? $ud[0] : null,
                'partner_id' => $pid2,
                'session_token' => $sToken
            ]]);
        } else {
            echo json_encode(['success' => false, 'error' => 'بيانات الدخول غير صحيحة']);
        }
        break;

    // ─── جلب طلبات العميل ───
    case 'get_orders':
        $stoken = trim($input['session_token'] ?? '');
        $sData = session_retrieve($stoken);
        $pid_req = intval($input['partner_id'] ?? 0);
        if (!$pid_req && $sData) $pid_req = $sData['partner_id'];
        if (!$pid_req) {
            echo json_encode(['success' => false, 'error' => 'يرجى تسجيل الدخول أولاً']);
            break;
        }
        $orders = odoo_call('sale.order', 'search_read',
            [['partner_id', '=', $pid_req]], [
            'fields' => ['name', 'date_order', 'amount_total', 'state', 'carrier_id', 'payment_term_id', 'order_line'],
            'order'  => 'date_order desc',
            'limit'  => 50
        ]);
        if (isset($orders['error'])) {
            echo json_encode(['success' => false, 'error' => $orders['error']]);
        } else {
            // جلب تفاصيل سطور الطلبات
            $allLineIds = [];
            foreach ($orders as &$o) { if (!empty($o['order_line'])) $allLineIds = array_merge($allLineIds, $o['order_line']); }
            unset($o);
            $linesData = [];
            if (!empty($allLineIds)) {
                $linesData = odoo_call('sale.order.line', 'search_read',
                    [['id', 'in', array_unique($allLineIds)]],
                    ['fields' => ['name', 'product_id', 'product_uom_qty', 'price_unit', 'price_subtotal']]
                );
            }
            $linesMap = [];
            if (!isset($linesData['error']) && is_array($linesData)) {
                foreach ($linesData as $l) { $linesMap[$l['id']] = $l; }
            }
            foreach ($orders as &$ord) {
                $ordLines = [];
                if (!empty($ord['order_line'])) {
                    foreach ($ord['order_line'] as $lid) {
                        if (isset($linesMap[$lid])) {
                            $l = $linesMap[$lid];
                            $ordLines[] = ['name' => $l['name'] ?? '', 'product' => is_array($l['product_id']) ? $l['product_id'][1] : '', 'qty' => $l['product_uom_qty'] ?? 1, 'price' => $l['price_unit'] ?? 0];
                        }
                    }
                }
                $ord['order_line'] = $ordLines;
            }
            unset($ord);
            echo json_encode(['success' => true, 'data' => $orders]);
        }
        break;

    default:
        http_response_code(400);
        echo json_encode(['error' => 'Unknown action: ' . $action]);
}

// ═══════════════════════════════════════════════
// WHATSAPP OTP SENDER
// ═══════════════════════════════════════════════
function send_otp_whatsapp($identifier, $otpCode, $idType) {
    global $ODOO_URL;
    
    // للإنتاج: يمكن ربط API واتساب مثل:
    // - Twilio WhatsApp API
    // - Meta WhatsApp Business API  
    // - MessageBird
    // حالياً: إرسال عبر واتساب مباشرة (رابط wa.me)
    // 
    // في وضع التطوير: نرسل OTP عبر إشعار بسيط
    // يمكن تفعيل إرسال حقيقي عبر إضافة API واتساب
    
    $phone = $identifier;
    if ($idType === 'email') {
        // للإيميل يمكن إرسال عبر Odoo mail أو SMTP
        // حالياً لا نرسل - المستخدم يرى الكود في وضع التطوير
        return false;
    }
    
    // تنسيق الرقم
    $clean = preg_replace('/[^0-9]/', '', $phone);
    if (strlen($clean) >= 8) {
        if (substr($clean, 0, 1) !== '9' || substr($clean, 0, 3) !== '968') {
            if (substr($clean, 0, 1) === '0') {
                $clean = '968' . substr($clean, 1);
            } elseif (substr($clean, 0, 3) !== '968') {
                $clean = '968' . $clean;
            }
        }
    }
    
    $waMsg = urlencode("كود التحقق سوق الوساط: $otpCode\nصالح لمدة 5 دقائق\nلا تشارك هذا الكود مع أحد");
    
    // حاول إرسال عبر WhatsApp Business API إن وجد
    // حالياً نرجع رابط واتساب كحل بديل
    return 'https://wa.me/' . $clean . '?text=' . $waMsg;
}
