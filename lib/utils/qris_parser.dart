/// QRIS TLV (Tag-Length-Value) Parser
/// Parses raw QRIS string based on EMV QR Code standard.
///
/// Key tags:
/// - 00: Payload Format Indicator
/// - 01: Point of Initiation Method (11=static, 12=dynamic)
/// - 26-45: Merchant Account Information (contains acquirer info)
/// - 51: QRIS Merchant Account Info
/// - 52: Merchant Category Code (MCC)
/// - 53: Transaction Currency (360 = IDR)
/// - 54: Transaction Amount
/// - 58: Country Code
/// - 59: Merchant Name
/// - 60: Merchant City
/// - 61: Postal Code
/// - 62: Additional Data Field
/// - 63: CRC

class QrisData {
  final String? payloadFormat;
  final String? initiationMethod;
  final String? acquirer;
  final String? acquirerRaw;
  final String? merchantName;
  final String? merchantCity;
  final String? postalCode;
  final String? countryCode;
  final String? mcc;
  final String? currency;
  final String? amount;
  final String? merchantId;
  final String? nmid;
  final Map<String, String> allTags;

  QrisData({
    this.payloadFormat,
    this.initiationMethod,
    this.acquirer,
    this.acquirerRaw,
    this.merchantName,
    this.merchantCity,
    this.postalCode,
    this.countryCode,
    this.mcc,
    this.currency,
    this.amount,
    this.merchantId,
    this.nmid,
    this.allTags = const {},
  });

  /// Build formatted location string like "ACEH UTARA, 24352, ID"
  String get locationString {
    final parts = <String>[];
    if (merchantCity != null && merchantCity!.isNotEmpty) parts.add(merchantCity!);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    if (countryCode != null && countryCode!.isNotEmpty) parts.add(countryCode!);
    return parts.join(', ');
  }

  /// Get friendly acquirer name from raw identifier
  String get acquirerName {
    if (acquirerRaw == null || acquirerRaw!.isEmpty) return '';
    final raw = acquirerRaw!.toUpperCase();

    if (raw.contains('XENDIT')) return 'Xendit';
    if (raw.contains('DANA')) return 'DANA';
    if (raw.contains('OVO')) return 'OVO';
    if (raw.contains('GOPAY')) return 'GoPay';
    if (raw.contains('SHOPEEPAY')) return 'ShopeePay';
    if (raw.contains('LINKAJA')) return 'LinkAja';
    if (raw.contains('BCA')) return 'BCA';
    if (raw.contains('BRI')) return 'BRI';
    if (raw.contains('BNI')) return 'BNI';
    if (raw.contains('MANDIRI')) return 'Mandiri';
    if (raw.contains('CIMB')) return 'CIMB Niaga';
    if (raw.contains('NOBU')) return 'Nobu';
    if (raw.contains('PERMATA')) return 'Permata';
    if (raw.contains('MAYBANK')) return 'Maybank';

    // Fallback: extract name from domain format like "CO.XENDIT.WWW"
    final parts = acquirerRaw!.split('.');
    if (parts.length >= 2) {
      // Try to find the meaningful part (not CO, COM, WWW, ID, etc.)
      final filtered = parts.where((p) =>
          !['CO', 'COM', 'WWW', 'ID', 'OR', 'ORG', 'NET'].contains(p.toUpperCase()));
      if (filtered.isNotEmpty) return filtered.first;
    }

    return acquirerRaw!;
  }

  bool get isStaticQris => initiationMethod == '11';
  bool get isDynamicQris => initiationMethod == '12';

  @override
  String toString() {
    return 'QrisData(merchant: $merchantName, city: $merchantCity, '
        'postal: $postalCode, country: $countryCode, '
        'acquirer: $acquirerName ($acquirerRaw), mcc: $mcc, '
        'amount: $amount, nmid: $nmid)';
  }
}

class QrisParser {
  /// Parse raw QRIS string into structured QrisData
  static QrisData? parse(String qrisString) {
    if (qrisString.isEmpty || qrisString.length < 40) return null;

    try {
      final tags = _parseTlv(qrisString);

      // Extract acquirer from merchant account info (tags 26-45)
      String? acquirerRaw;
      for (int i = 26; i <= 45; i++) {
        final tagKey = i.toString().padLeft(2, '0');
        if (tags.containsKey(tagKey)) {
          final subTags = _parseTlv(tags[tagKey]!);
          if (subTags.containsKey('00')) {
            acquirerRaw = subTags['00'];
            break;
          }
        }
      }

      // Extract NMID from tag 51
      String? nmid;
      if (tags.containsKey('51')) {
        final subTags = _parseTlv(tags['51']!);
        nmid = subTags['02'] ?? subTags['01'];
      }

      return QrisData(
        payloadFormat: tags['00'],
        initiationMethod: tags['01'],
        acquirerRaw: acquirerRaw,
        merchantName: tags['59'],
        merchantCity: tags['60'],
        postalCode: tags['61'],
        countryCode: tags['58'],
        mcc: tags['52'],
        currency: tags['53'],
        amount: tags['54'],
        nmid: nmid,
        allTags: tags,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse TLV encoded string into a map of tag -> value
  static Map<String, String> _parseTlv(String data) {
    final result = <String, String>{};
    int pos = 0;

    while (pos + 4 <= data.length) {
      // Tag is 2 chars
      final tag = data.substring(pos, pos + 2);
      pos += 2;

      // Length is 2 chars
      if (pos + 2 > data.length) break;
      final lengthStr = data.substring(pos, pos + 2);
      final length = int.tryParse(lengthStr);
      if (length == null) break;
      pos += 2;

      // Value is [length] chars
      if (pos + length > data.length) break;
      final value = data.substring(pos, pos + length);
      pos += length;

      result[tag] = value;
    }

    return result;
  }
}
