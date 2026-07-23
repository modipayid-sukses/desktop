Map<String, dynamic> normalizePpobMenuItem(
  Map<String, dynamic> source, {
  required String defaultCmd,
  bool flattenName = false,
}) {
  final item = <String, dynamic>{
    'name': flattenName
        ? (source['name'] ?? '').toString().replaceAll('\n', ' ')
        : (source['name'] ?? ''),
    'category': source['category'],
    'brand': source['brand'],
    'cmd': source['cmd'] ?? defaultCmd,
    'postpaid': source['is_postpaid'] == true || source['postpaid'] == true,
    'color': source['color'],
    'icon': source['icon'],
  };

  const passthroughKeys = [
    'inquiryType',
    'inquiry_type',
    'initialBrand',
    'initial_brand',
    'routeType',
    'route_type',
    'flow',
    'flow_type',
    'screen',
    'screen_type',
    'action',
    'type',
    'productType',
    'product_type',
    // ─── UI config dari admin panel ────────────────
    'input_label',
    'input_hint',
    'input_keyboard',
    'input_min_length',
    'input_max_length',
    'product_layout',
    'product_columns',
    'show_brand_tabs',
    'auto_detect_brand',
    // ─── Inquiry config (override SKU/provider untuk cek nama) ───
    'inquiry_sku',
    'inquiry_provider',
  ];

  for (final key in passthroughKeys) {
    if (source[key] != null) {
      item[key] = source[key];
    }
  }

  // Ensure PLN prepaid variants share the same inquiry-first product flow.
  final categoryLower = (item['category'] ?? '').toString().trim().toLowerCase();
  // Normalisasi nama: ganti newline/whitespace berurutan jadi satu spasi,
  // agar deteksi seperti "topup game" / "top up game" bekerja meski
  // nama dari admin panel mengandung "\n" (mis. "TopUp\nGame").
  final nameLower = (item['name'] ?? '')
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  final cmdLower = (item['cmd'] ?? defaultCmd).toString().trim().toLowerCase();
  // Deteksi item Token PLN / Token Listrik berdasarkan category ATAU name.
  // Backend admin sering pakai category generic 'ppob' dengan name='Token
  // Listrik', jadi cek nama juga supaya inquiryType='pln' tetap terset.
  final categoryIsPlnLike = categoryLower == 'pln' ||
      categoryLower == 'token pln' ||
      categoryLower == 'pln prabayar' ||
      categoryLower == 'pln prepaid';
  final nameIsTokenPlnLike = (nameLower.contains('token') &&
          (nameLower.contains('pln') || nameLower.contains('listrik'))) ||
      nameLower == 'pln prabayar' ||
      nameLower == 'pln prepaid';
  final isPlnPrepaidLike = cmdLower != 'pasca' &&
      cmdLower != 'postpaid' &&
      (categoryIsPlnLike || nameIsTokenPlnLike) &&
      // Hindari mengkapture varian Pascabayar yang masuk via name saja.
      !nameLower.contains('pasca') &&
      !nameLower.contains('postpaid') &&
      !nameLower.contains('tagihan');

  if (isPlnPrepaidLike) {
    item['name'] = 'Token Listrik';
  }

  // Canonicalize: snake_case `inquiry_type` (dari API) → camelCase `inquiryType`
  // yang dipakai konsumen di mobile (home.dart, PPOBProductScreen, dst).
  if (item['inquiryType'] == null && item['inquiry_type'] != null) {
    item['inquiryType'] = item['inquiry_type'];
  }
  if (isPlnPrepaidLike && (item['inquiryType'] == null || item['inquiryType'] == '')) {
    item['inquiryType'] = 'pln';
  }

  // Tandai shortcut "TopUp Game" pada grid pembelian (bukan item brand game
  // individual seperti "Free Fire"). Shortcut ini akan dibuka sebagai daftar
  // game (PPOBTopUpGameListScreen) — penanda dipakai di home untuk routing.
  final isGameShortcut = (nameLower.contains('topup') && nameLower.contains('game')) ||
      (nameLower.contains('top up') && nameLower.contains('game')) ||
      nameLower == 'topupgame' ||
      nameLower == 'game' ||
      categoryLower == 'games' ||
      categoryLower == 'topup game' ||
      categoryLower == 'top up game';
  if (isGameShortcut) {
    item['routeType'] = 'topup_game_list';
    // Bersihkan field misconfig yang bikin screen mengira ini e-wallet.
    item.remove('inquiryType');
    item.remove('inquiry_type');
    item.remove('initialBrand');
    item.remove('initial_brand');
  }

  return item;
}

String resolvePpobRouteType(Map<String, dynamic> item) {
  final explicitCandidates = [
    item['routeType'],
    item['route_type'],
    item['flow'],
    item['flow_type'],
    item['screen'],
    item['screen_type'],
    item['action'],
    item['type'],
    item['productType'],
    item['product_type'],
  ];

  for (final candidate in explicitCandidates) {
    final normalized = _normalizeRouteValue(candidate);
    if (normalized != null) return normalized;
  }

  final category = (item['category'] ?? '').toString().trim().toLowerCase();
  final brand = (item['brand'] ?? '').toString().trim().toLowerCase();
  final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
  final initialBrand = (item['initialBrand'] ?? item['initial_brand'] ?? '')
      .toString()
      .trim()
      .toLowerCase();

  if (category == 'all') return 'all_services';
  if (category == 'transfer_bank' || item['cmd'] == 'transfer') return 'bank_transfer';

  if (_containsTollKeyword(category) ||
      _containsTollKeyword(brand) ||
      _containsTollKeyword(itemName) ||
      _containsTollKeyword(initialBrand)) {
    return 'product';
  }

  // E-Money / E-Wallet tanpa brand spesifik → tampilkan halaman pilih brand.
  // Anggap brand 'tidak spesifik' jika kosong, sama dengan nama kategori,
  // atau hanya berisi label generik kategorinya.
  final isEmoneyCategory = category == 'e-money' || category == 'e-wallet';
  final hasSpecificBrand = initialBrand.isNotEmpty && initialBrand != category;
  final brandIsGeneric = brand.isEmpty || brand == category;
  if (isEmoneyCategory && !hasSpecificBrand && brandIsGeneric) {
    return 'emoney_brand';
  }

  if (item['postpaid'] == true || (brand.isNotEmpty && category.isEmpty)) {
    return 'postpaid';
  }

  return 'product';
}

String? _normalizeRouteValue(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;

  switch (normalized) {
    case 'all':
    case 'all_services':
    case 'all-services':
    case 'services':
      return 'all_services';
    case 'bank_transfer':
    case 'bank-transfer':
    case 'transfer_bank':
    case 'transfer-bank':
    case 'transfer':
      return 'bank_transfer';
    case 'qris_payment':
    case 'qris-payment':
    case 'qris':
      return 'qris_payment';
    case 'postpaid':
    case 'pascabayar':
    case 'pasca':
    case 'bill':
    case 'billing':
      return 'postpaid';
    case 'nfc_toll':
    case 'nfc-toll':
    case 'toll_nfc':
    case 'toll-nfc':
    case 'e_toll':
    case 'e-toll':
    case 'toll':
      return 'product';
    case 'product':
    case 'prepaid':
    case 'produk':
    case 'ppob_product':
    case 'ppob-product':
      return 'product';
    case 'emoney_brand':
    case 'emoney-brand':
    case 'e_money_brand':
    case 'e-money-brand':
      return 'emoney_brand';
    case 'topup_game_list':
    case 'topup-game-list':
    case 'topup_game':
    case 'topup-game':
    case 'top_up_game':
    case 'top-up-game':
      return 'topup_game_list';
  }

  return null;
}

bool _containsTollKeyword(String value) {
  return value.contains('e-toll') ||
      value.contains('etoll') ||
      value.contains('toll') ||
      value.contains('tol');
}

// Kategori yang seharusnya selalu masuk grup Postpaid (pembayaran) meski
// admin panel/backend menaruhnya di grup pembelian (prepaid) secara keliru.
const List<String> _knownPostpaidKeywords = [
  'indihome',
  'gas negara',
  'pgn',
  'tv pasca',
  'tv berbayar',
  'tv kabel',
];

bool isKnownPostpaidItem(Map<String, dynamic> item) {
  final name = (item['name'] ?? '').toString().toLowerCase();
  final category = (item['category'] ?? '').toString().toLowerCase();
  final hay = '$name $category';
  return _knownPostpaidKeywords.any((k) => hay.contains(k));
}

/// Pindahkan item yang seharusnya Postpaid dari [pembelian] ke [pembayaran]
/// berdasarkan nama/kategori yang dikenal (lihat [isKnownPostpaidItem]).
/// Dipanggil setelah `parseGroup` di setiap layar yang menampilkan
/// submenu Prepaid/Postpaid (home, promo, riwayat transaksi, semua layanan).
void reclassifyPostpaidItems(
  List<Map<String, dynamic>> pembelian,
  List<Map<String, dynamic>> pembayaran,
) {
  pembelian.removeWhere((item) {
    if (!isKnownPostpaidItem(item)) return false;
    item['cmd'] = 'pasca';
    pembayaran.add(item);
    return true;
  });
}