import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/platform_tags/iso_dep.dart';
import 'package:nfc_manager/src/platform_tags/mifare.dart';
import 'package:nfc_manager/src/platform_tags/mifare_classic.dart';
import 'package:nfc_manager/src/platform_tags/mifare_ultralight.dart';
import 'package:nfc_manager/src/platform_tags/nfc_a.dart';
import 'package:nfc_manager/src/platform_tags/nfc_b.dart';
import 'package:nfc_manager/src/platform_tags/nfc_f.dart';
import 'package:nfc_manager/src/platform_tags/nfc_v.dart';
import 'package:provider/provider.dart';

import '../../utils/colornotifire.dart';
import '../../utils/media.dart';

class _InfoSection {
  final String title;
  final List<MapEntry<String, String>> rows;
  final String? note;

  const _InfoSection({
    required this.title,
    required this.rows,
    this.note,
  });
}

class _ApduAidProbe {
  final String label;
  final String aidHex;

  const _ApduAidProbe({
    required this.label,
    required this.aidHex,
  });
}

class _TlvNode {
  final String tagHex;
  final Uint8List value;
  final bool constructed;
  final List<_TlvNode> children;

  const _TlvNode({
    required this.tagHex,
    required this.value,
    required this.constructed,
    this.children = const [],
  });
}

class _EmvPdolItem {
  final String tagHex;
  final int length;

  const _EmvPdolItem({
    required this.tagHex,
    required this.length,
  });
}

class _AflEntry {
  final int sfi;
  final int firstRecord;
  final int lastRecord;

  const _AflEntry({
    required this.sfi,
    required this.firstRecord,
    required this.lastRecord,
  });
}

class _ScanBuildResult {
  final List<_InfoSection> sections;
  final Map<int, Uint8List> readableBlocks;

  const _ScanBuildResult({
    required this.sections,
    required this.readableBlocks,
  });
}

class NfcTollScanScreen extends StatefulWidget {
  const NfcTollScanScreen({Key? key}) : super(key: key);

  @override
  State<NfcTollScanScreen> createState() => _NfcTollScanScreenState();
}

class _NfcTollScanScreenState extends State<NfcTollScanScreen> {
  static final List<MapEntry<String, Uint8List>> _commonMifareKeys = [
    MapEntry('FF FF FF FF FF FF', Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])),
    MapEntry('A0 A1 A2 A3 A4 A5', Uint8List.fromList([0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5])),
    MapEntry('D3 F7 D3 F7 D3 F7', Uint8List.fromList([0xD3, 0xF7, 0xD3, 0xF7, 0xD3, 0xF7])),
    MapEntry('4D 3A 99 C3 51 DD', Uint8List.fromList([0x4D, 0x3A, 0x99, 0xC3, 0x51, 0xDD])),
    MapEntry('1A 98 2C 7E 45 9A', Uint8List.fromList([0x1A, 0x98, 0x2C, 0x7E, 0x45, 0x9A])),
  ];

  static const List<_ApduAidProbe> _isoDepAidProbes = [
    _ApduAidProbe(label: 'PPSE', aidHex: '325041592E5359532E4444463031'),
    _ApduAidProbe(label: 'PSE', aidHex: '315041592E5359532E4444463031'),
    _ApduAidProbe(label: 'Visa AID', aidHex: 'A0000000031010'),
    _ApduAidProbe(label: 'Mastercard AID', aidHex: 'A0000000041010'),
    _ApduAidProbe(label: 'EMV AID', aidHex: 'A000000003000000'),
  ];

  bool _isAvailable = false;
  bool _isScanning = false;
  Map<String, dynamic>? _tagData;
  String? _sessionMessage;
  String? _sessionError;
  List<_InfoSection> _sections = [];
  Map<int, Uint8List>? _previousReadableBlocks;
  DateTime? _previousSnapshotAt;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await NfcManager.instance.isAvailable();
    if (!mounted) return;
    setState(() => _isAvailable = available);
  }

  String _toHex(dynamic bytesLike) {
    if (bytesLike == null) return '-';
    final List<int> ints;
    if (bytesLike is Uint8List) {
      ints = bytesLike.toList();
    } else if (bytesLike is List) {
      ints = bytesLike.whereType<int>().toList();
    } else {
      return '-';
    }
    if (ints.isEmpty) return '-';
    return ints.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
  }

  String _techList(Map<String, dynamic> data) {
    final keys = data.keys.where((k) => k != 'ndef').toList()..sort();
    return keys.isEmpty ? '-' : keys.join(', ');
  }

  String _safeString(dynamic value) {
    if (value == null) return '-';
    if (value is String && value.trim().isEmpty) return '-';
    return value.toString();
  }

  String _asciiFromBytes(Uint8List bytes) {
    final chars = bytes
        .map((byte) => byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : ' ')
        .join();
    return chars.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _extractCandidateNumbers(Uint8List bytes) {
    final ascii = _asciiFromBytes(bytes);
    if (ascii.isEmpty) return const [];

    final matches = RegExp(r'\b\d{8,20}\b').allMatches(ascii);
    final values = matches.map((match) => match.group(0)!).toList();
    return values.toSet().toList();
  }

  int _sectorFirstBlockIndex(int sectorIndex) {
    if (sectorIndex < 32) {
      return sectorIndex * 4;
    }
    return 128 + (sectorIndex - 32) * 16;
  }

  int _sectorBlockCount(int sectorIndex) {
    return sectorIndex < 32 ? 4 : 16;
  }

  Uint8List _hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final values = <int>[];
    for (var index = 0; index < cleaned.length; index += 2) {
      values.add(int.parse(cleaned.substring(index, index + 2), radix: 16));
    }
    return Uint8List.fromList(values);
  }

  Uint8List _buildSelectAidApdu(String aidHex) {
    final aidBytes = _hexToBytes(aidHex);
    return Uint8List.fromList([
      0x00,
      0xA4,
      0x04,
      0x00,
      aidBytes.length,
      ...aidBytes,
      0x00,
    ]);
  }

  String _apduStatus(Uint8List response) {
    if (response.length < 2) return '?? ??';
    final sw1 = response[response.length - 2];
    final sw2 = response[response.length - 1];
    return '${sw1.toRadixString(16).padLeft(2, '0')} ${sw2.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  String _apduPayload(Uint8List response) {
    if (response.length <= 2) return '-';
    return _toHex(response.sublist(0, response.length - 2));
  }

  bool _isConstructedTag(Uint8List tagBytes) {
    return tagBytes.isNotEmpty && (tagBytes[0] & 0x20) != 0;
  }

  _TlvNode? _parseOneTlv(Uint8List data, int start) {
    if (start >= data.length) return null;

    var index = start;
    final tagBytes = <int>[data[index++]];
    if ((tagBytes[0] & 0x1F) == 0x1F) {
      while (index < data.length) {
        final byte = data[index++];
        tagBytes.add(byte);
        if ((byte & 0x80) == 0) break;
      }
    }

    if (index >= data.length) return null;

    final firstLengthByte = data[index++];
    int length;
    if (firstLengthByte < 0x80) {
      length = firstLengthByte;
    } else {
      final lengthByteCount = firstLengthByte & 0x7F;
      if (lengthByteCount == 0 || index + lengthByteCount > data.length) return null;
      length = 0;
      for (var i = 0; i < lengthByteCount; i++) {
        length = (length << 8) | data[index++];
      }
    }

    if (index + length > data.length) return null;

    final value = Uint8List.fromList(data.sublist(index, index + length));
    final tag = Uint8List.fromList(tagBytes);
    final constructed = _isConstructedTag(tag);
    final children = constructed ? _parseTlv(value) : <_TlvNode>[];
    return _TlvNode(
      tagHex: _toHex(tag),
      value: value,
      constructed: constructed,
      children: children,
    );
  }

  List<_TlvNode> _parseTlv(Uint8List data) {
    final nodes = <_TlvNode>[];
    var index = 0;
    while (index < data.length) {
      final node = _parseOneTlv(data, index);
      if (node == null) break;
      nodes.add(node);

      var advanced = 0;
      var cursor = index;
      cursor++;
      if ((data[index] & 0x1F) == 0x1F) {
        while (cursor < data.length) {
          advanced++;
          if ((data[cursor] & 0x80) == 0) {
            cursor++;
            break;
          }
          cursor++;
        }
      }
      if (cursor >= data.length) break;

      final firstLengthByte = data[cursor++];
      if (firstLengthByte < 0x80) {
        index = cursor + firstLengthByte;
        continue;
      }

      final lengthByteCount = firstLengthByte & 0x7F;
      if (cursor + lengthByteCount > data.length) break;
      var length = 0;
      for (var i = 0; i < lengthByteCount; i++) {
        length = (length << 8) | data[cursor++];
      }
      index = cursor + length;
    }
    return nodes;
  }

  String _tagName(String tagHex) {
    switch (tagHex.toUpperCase()) {
      case '6F':
        return 'FCI Template';
      case '84':
        return 'DF Name';
      case 'A5':
        return 'FCI Proprietary Template';
      case '50':
        return 'Application Label';
      case '5F2D':
        return 'Language Preference';
      case '5F24':
        return 'Application Expiration';
      case '87':
        return 'Application Priority';
      case '9F10':
        return 'Issuer Application Data';
      case '9F11':
        return 'Issuer Code Table Index';
      case '9F12':
        return 'Application Preferred Name';
      case '9F38':
        return 'PDOL';
      case '82':
        return 'AIP';
      case '94':
        return 'AFL';
      case '9F36':
        return 'ATC';
      case '9F6E':
        return 'Form Factor Indicator';
      case '5A':
        return 'PAN';
      default:
        return 'Tag $tagHex';
    }
  }

  String _decodeEmvValue(String tagHex, Uint8List value) {
    final upperTag = tagHex.toUpperCase();
    if (upperTag == '50' || upperTag == '9F12' || upperTag == '5F2D') {
      return utf8.decode(value, allowMalformed: true).trim();
    }
    if (upperTag == '5A') {
      final digits = value
          .expand((byte) => [byte >> 4, byte & 0x0F])
          .takeWhile((nibble) => nibble != 0x0F)
          .map((nibble) => nibble.toString())
          .join();
      return digits.isEmpty ? _toHex(value) : digits;
    }
    if (upperTag == '5F24' && value.length == 3) {
      return '${value[0].toRadixString(16).padLeft(2, '0')}/${value[1].toRadixString(16).padLeft(2, '0')}/${value[2].toRadixString(16).padLeft(2, '0')}';
    }
    if (upperTag == '87' && value.isNotEmpty) {
      return 'Priority ${value[0]}';
    }
    if (upperTag == '82' || upperTag == '94' || upperTag == '9F38' || upperTag == '9F10' || upperTag == '9F11' || upperTag == '9F36' || upperTag == '9F6E') {
      return _toHex(value);
    }
    final text = utf8.decode(value, allowMalformed: true).trim();
    if (text.isNotEmpty && RegExp(r'^[\x20-\x7E]+$').hasMatch(text)) {
      return text;
    }
    return _toHex(value);
  }

  List<MapEntry<String, String>> _flattenTlvRows(List<_TlvNode> nodes, {String prefix = ''}) {
    final rows = <MapEntry<String, String>>[];
    for (final node in nodes) {
      final label = prefix.isEmpty ? '${node.tagHex} (${_tagName(node.tagHex)})' : '$prefix / ${node.tagHex} (${_tagName(node.tagHex)})';
      rows.add(MapEntry(label, _decodeEmvValue(node.tagHex, node.value)));
      if (node.children.isNotEmpty) {
        rows.addAll(_flattenTlvRows(node.children, prefix: label));
      }
    }
    return rows;
  }

  Uint8List? _findTlvValue(List<_TlvNode> nodes, String targetTagHex) {
    for (final node in nodes) {
      if (node.tagHex.toUpperCase() == targetTagHex.toUpperCase()) return node.value;
      if (node.children.isNotEmpty) {
        final found = _findTlvValue(node.children, targetTagHex);
        if (found != null) return found;
      }
    }
    return null;
  }

  List<_EmvPdolItem> _parsePdol(Uint8List pdol) {
    final items = <_EmvPdolItem>[];
    var index = 0;
    while (index < pdol.length) {
      final tagBytes = <int>[pdol[index++]];
      if ((tagBytes[0] & 0x1F) == 0x1F) {
        while (index < pdol.length) {
          final next = pdol[index++];
          tagBytes.add(next);
          if ((next & 0x80) == 0) break;
        }
      }
      if (index >= pdol.length) break;
      final length = pdol[index++];
      items.add(_EmvPdolItem(tagHex: _toHex(Uint8List.fromList(tagBytes)), length: length));
    }
    return items;
  }

  Uint8List _buildGpoCommandFromPdol(Uint8List pdol) {
    final items = _parsePdol(pdol);
    final dataField = <int>[0x83];
    final pdolData = <int>[];
    for (final item in items) {
      pdolData.addAll(List<int>.filled(item.length, 0x00));
    }
    dataField.add(pdolData.length);
    dataField.addAll(pdolData);
    return Uint8List.fromList([
      0x80,
      0xA8,
      0x00,
      0x00,
      dataField.length,
      ...dataField,
      0x00,
    ]);
  }

  Uint8List _buildReadRecordApdu(int recordNumber, int sfi) {
    return Uint8List.fromList([
      0x00,
      0xB2,
      recordNumber,
      ((sfi << 3) | 0x04) & 0xFF,
      0x00,
    ]);
  }

  List<_AflEntry> _parseAfl(Uint8List afl) {
    final entries = <_AflEntry>[];
    for (var index = 0; index + 3 < afl.length; index += 4) {
      final sfi = afl[index] >> 3;
      final firstRecord = afl[index + 1];
      final lastRecord = afl[index + 2];
      entries.add(_AflEntry(sfi: sfi, firstRecord: firstRecord, lastRecord: lastRecord));
    }
    return entries;
  }

  String _shortTimestamp(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
  }

  _InfoSection _buildReadableBlockComparisonSection(
    Map<int, Uint8List> previous,
    Map<int, Uint8List> current,
  ) {
    final rows = <MapEntry<String, String>>[];
    final changedRows = <MapEntry<String, String>>[];

    final allBlocks = <int>{...previous.keys, ...current.keys}.toList()..sort();
    for (final blockIndex in allBlocks) {
      final prev = previous[blockIndex];
      final curr = current[blockIndex];
      if (prev == null && curr != null) {
        rows.add(MapEntry('B$blockIndex', 'BARU: ${_toHex(curr)}'));
        continue;
      }
      if (prev != null && curr == null) {
        rows.add(MapEntry('B$blockIndex', 'HILANG (sebelumnya: ${_toHex(prev)})'));
        continue;
      }
      if (prev == null || curr == null) continue;

      final len = prev.length < curr.length ? prev.length : curr.length;
      final changedOffsets = <int>[];
      for (var index = 0; index < len; index++) {
        if (prev[index] != curr[index]) changedOffsets.add(index);
      }

      if (changedOffsets.isNotEmpty || prev.length != curr.length) {
        final offsetText = changedOffsets.isEmpty ? '-' : changedOffsets.join(',');
        changedRows.add(
          MapEntry(
            'B$blockIndex',
            'offset[$offsetText] | BEFORE=${_toHex(prev)} | AFTER=${_toHex(curr)}',
          ),
        );
      }
    }

    rows.addAll(changedRows.take(12));

    return _InfoSection(
      title: 'Perbandingan Scan Sebelumnya',
      rows: rows.isEmpty ? const [MapEntry('Status', 'Tidak ada perubahan pada blok yang terbaca')] : rows,
      note: rows.isEmpty
          ? 'Tidak ada byte yang berubah pada blok yang terbuka. Coba scan sebelum dan sesudah transaksi kartu untuk memunculkan kandidat field saldo.'
          : 'Menampilkan perubahan blok terbaca (maksimal 12 baris). Perubahan setelah transaksi adalah kandidat kuat lokasi saldo/riwayat.',
    );
  }

  String _decodeTrack2Equivalent(Uint8List value) {
    final nibbles = value
        .expand((byte) => [byte >> 4, byte & 0x0F])
        .takeWhile((nibble) => nibble != 0x0F)
        .toList();
    if (nibbles.isEmpty) return _toHex(value);

    final chars = nibbles.map((nibble) => nibble.toRadixString(16).toUpperCase()).join();
    final separatorIndex = chars.indexOf('D');
    if (separatorIndex > 0) {
      final pan = chars.substring(0, separatorIndex);
      final remainder = chars.substring(separatorIndex + 1);
      if (remainder.length >= 4) {
        final expiry = remainder.substring(0, 4);
        return 'PAN=$pan | EXP=$expiry';
      }
      return 'PAN=$pan | RAW=$chars';
    }

    return chars;
  }

  List<MapEntry<String, String>> _buildEmvSummaryRows(List<_TlvNode> nodes) {
    final rows = <MapEntry<String, String>>[];

    final dfName = _findTlvValue(nodes, '84');
    if (dfName != null && dfName.isNotEmpty) {
      rows.add(MapEntry('DF Name', _decodeEmvValue('84', dfName)));
    }

    final appLabel = _findTlvValue(nodes, '50');
    if (appLabel != null && appLabel.isNotEmpty) {
      rows.add(MapEntry('Application Label', _decodeEmvValue('50', appLabel)));
    }

    final pdol = _findTlvValue(nodes, '9F38');
    if (pdol != null && pdol.isNotEmpty) {
      final items = _parsePdol(pdol);
      final pdolSummary = items.map((item) => '${item.tagHex}:${item.length}').join(', ');
      rows.add(MapEntry('PDOL', pdolSummary.isEmpty ? _toHex(pdol) : pdolSummary));
    }

    final afl = _findTlvValue(nodes, '94');
    if (afl != null && afl.isNotEmpty) {
      final entries = _parseAfl(afl);
      final aflSummary = entries.map((entry) => 'SFI ${entry.sfi} R${entry.firstRecord}-${entry.lastRecord}').join(', ');
      rows.add(MapEntry('AFL', aflSummary.isEmpty ? _toHex(afl) : aflSummary));
    }

    final pan = _findTlvValue(nodes, '5A');
    if (pan != null && pan.isNotEmpty) {
      rows.add(MapEntry('PAN', _decodeEmvValue('5A', pan)));
    }

    final track2 = _findTlvValue(nodes, '57');
    if (track2 != null && track2.isNotEmpty) {
      rows.add(MapEntry('Track 2', _decodeTrack2Equivalent(track2)));
    }

    final atc = _findTlvValue(nodes, '9F36');
    if (atc != null && atc.isNotEmpty) {
      rows.add(MapEntry('ATC', _decodeEmvValue('9F36', atc)));
    }

    final iad = _findTlvValue(nodes, '9F10');
    if (iad != null && iad.isNotEmpty) {
      rows.add(MapEntry('Issuer Application Data', _decodeEmvValue('9F10', iad)));
    }

    final fii = _findTlvValue(nodes, '9F6E');
    if (fii != null && fii.isNotEmpty) {
      rows.add(MapEntry('Form Factor Indicator', _decodeEmvValue('9F6E', fii)));
    }

    return rows;
  }

  Future<_InfoSection> _probeIsoDepApdu(IsoDep isoDep) async {
    final rows = <MapEntry<String, String>>[];
    final matchedLabels = <String>[];
    Uint8List? emvSelectPayload;

    for (final probe in _isoDepAidProbes) {
      try {
        final command = _buildSelectAidApdu(probe.aidHex);
        final response = await isoDep.transceive(data: command);
        final status = _apduStatus(response);
        final payload = _apduPayload(response);
        rows.add(MapEntry(probe.label, 'AID=${probe.aidHex} | SW=$status | DATA=$payload'));
        if (status == '90 00') {
          matchedLabels.add(probe.label);
          if (probe.label == 'EMV AID') {
            emvSelectPayload = response.length > 2 ? response.sublist(0, response.length - 2) : null;
          }
        }
      } catch (error) {
        rows.add(MapEntry(probe.label, 'AID=${probe.aidHex} | ERR=$error'));
      }
    }

    try {
      final getAtc = Uint8List.fromList([0x80, 0xCA, 0x9F, 0x36, 0x00]);
      final response = await isoDep.transceive(data: getAtc);
      rows.add(MapEntry('GET ATC', 'SW=${_apduStatus(response)} | DATA=${_apduPayload(response)}'));
    } catch (error) {
      rows.add(MapEntry('GET ATC', 'ERR=$error'));
    }

    try {
      final getBalance = Uint8List.fromList([0x80, 0x5C, 0x00, 0x02, 0x04]);
      final response = await isoDep.transceive(data: getBalance);
      rows.add(MapEntry('GET BALANCE', 'SW=${_apduStatus(response)} | DATA=${_apduPayload(response)}'));
    } catch (error) {
      rows.add(MapEntry('GET BALANCE', 'ERR=$error'));
    }

    if (emvSelectPayload != null && emvSelectPayload!.isNotEmpty) {
      final tlvNodes = _parseTlv(emvSelectPayload!);
      rows.addAll(_buildEmvSummaryRows(tlvNodes));
      rows.addAll(_flattenTlvRows(tlvNodes));

      final pdol = _findTlvValue(tlvNodes, '9F38');
      if (pdol != null && pdol.isNotEmpty) {
        try {
          final gpoCommand = _buildGpoCommandFromPdol(pdol);
          final gpoResponse = await isoDep.transceive(data: gpoCommand);
          final gpoStatus = _apduStatus(gpoResponse);
          final gpoPayload = gpoResponse.length > 2 ? gpoResponse.sublist(0, gpoResponse.length - 2) : Uint8List(0);
          rows.add(MapEntry('GET PROCESSING OPTIONS', 'SW=$gpoStatus | DATA=${_toHex(gpoPayload)}'));

          if (gpoStatus == '90 00' && gpoPayload.isNotEmpty) {
            final gpoNodes = _parseTlv(gpoPayload);
            rows.addAll(_buildEmvSummaryRows(gpoNodes));
            rows.addAll(_flattenTlvRows(gpoNodes, prefix: 'GPO'));

            final afl = _findTlvValue(gpoNodes, '94');
            if (afl != null && afl.isNotEmpty) {
              final aflEntries = _parseAfl(afl);
              for (final entry in aflEntries) {
                for (var recordNumber = entry.firstRecord; recordNumber <= entry.lastRecord; recordNumber++) {
                  try {
                    final readRecordResponse = await isoDep.transceive(data: _buildReadRecordApdu(recordNumber, entry.sfi));
                    final readStatus = _apduStatus(readRecordResponse);
                    final readPayload = _apduPayload(readRecordResponse);
                    rows.add(MapEntry('READ RECORD SFI ${entry.sfi} R$recordNumber', 'SW=$readStatus | DATA=$readPayload'));
                  } catch (error) {
                    rows.add(MapEntry('READ RECORD SFI ${entry.sfi} R$recordNumber', 'ERR=$error'));
                  }
                }
              }
            }
          }
        } catch (error) {
          rows.add(MapEntry('GET PROCESSING OPTIONS', 'ERR=$error'));
        }
      }
    }

    return _InfoSection(
      title: 'IsoDep APDU Probe',
      rows: rows,
      note: matchedLabels.isEmpty
          ? 'Tidak ada AID umum yang cocok. Jika ini Mandiri E-Money, kemungkinan AID atau perintahnya proprietary sehingga perlu probe lebih spesifik.'
          : 'AID yang merespons 9000: ${matchedLabels.join(', ')}',
    );
  }

  String _decodeNdefRecord(NdefRecord record) {
    final typeHex = _toHex(record.type);
    final payload = record.payload;

    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        record.type.length == 1 &&
        record.type[0] == 0x54 &&
        payload.isNotEmpty) {
      final languageLength = payload[0];
      if (payload.length > languageLength + 1) {
        final textBytes = payload.sublist(languageLength + 1);
        return 'Text (${_safeString(String.fromCharCodes(payload.sublist(1, languageLength + 1)))}): ${utf8.decode(textBytes, allowMalformed: true)}';
      }
    }

    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        record.type.length == 1 &&
        record.type[0] == 0x55 &&
        payload.isNotEmpty) {
      final prefixIndex = payload[0];
      final prefix = prefixIndex < NdefRecord.URI_PREFIX_LIST.length
          ? NdefRecord.URI_PREFIX_LIST[prefixIndex]
          : '';
      final suffix = utf8.decode(payload.sublist(1), allowMalformed: true);
      return 'URI: $prefix$suffix';
    }

    if (record.typeNameFormat == NdefTypeNameFormat.media ||
        record.typeNameFormat == NdefTypeNameFormat.absoluteUri ||
        record.typeNameFormat == NdefTypeNameFormat.nfcExternal) {
      final payloadText = utf8.decode(payload, allowMalformed: true).trim();
      if (payloadText.isNotEmpty) {
        return 'Payload: $payloadText';
      }
    }

    return 'TNF=${record.typeNameFormat.name}, Type=$typeHex, Payload=${_toHex(payload)}';
  }

  Future<_ScanBuildResult> _buildSectionsFromTag(NfcTag tag) async {
    final data = Map<String, dynamic>.from(tag.data);
    final sections = <_InfoSection>[];
    final availableTechs = data.keys.toList()..sort();
    final uid = _toHex(data['nfca']?['identifier'] ?? data['nfcb']?['identifier'] ?? data['nfcf']?['identifier'] ?? data['iso7816']?['identifier']);

    final nfcA = NfcA.from(tag);
    final nfcB = NfcB.from(tag);
    final nfcF = NfcF.from(tag);
    final nfcV = NfcV.from(tag);
    final isoDep = IsoDep.from(tag);
    final miFare = MiFare.from(tag);
    final mifareClassic = MifareClassic.from(tag);
    final mifareUltralight = MifareUltralight.from(tag);
    final ndef = Ndef.from(tag);

    sections.add(
      _InfoSection(
        title: 'Ringkasan Tag',
        rows: [
          MapEntry('UID', uid),
          MapEntry('Teknologi aktif', availableTechs.join(', ')),
          MapEntry('NDEF', ndef == null ? 'Tidak tersedia' : 'Tersedia'),
          MapEntry('MiFare family', miFare == null ? '-' : miFare.mifareFamily.name),
        ],
        note: 'Ini membaca identitas dan teknologi yang terbuka dari kartu. Jika kartu terlindungi, isi saldo/akun biasanya tidak bisa dibaca tanpa protokol resmi.',
      ),
    );

    if (nfcA != null) {
      sections.add(
        _InfoSection(
          title: 'NfcA',
          rows: [
            MapEntry('ATQA', _toHex(nfcA.atqa)),
            MapEntry('SAK', nfcA.sak.toString()),
            MapEntry('Max transceive', nfcA.maxTransceiveLength.toString()),
            MapEntry('Timeout', '${nfcA.timeout} ms'),
          ],
        ),
      );
    }

    if (nfcB != null) {
      sections.add(
        _InfoSection(
          title: 'NfcB',
          rows: [
            MapEntry('Application data', _toHex(nfcB.applicationData)),
            MapEntry('Protocol info', _toHex(nfcB.protocolInfo)),
            MapEntry('Max transceive', nfcB.maxTransceiveLength.toString()),
          ],
        ),
      );
    }

    if (nfcF != null) {
      sections.add(
        _InfoSection(
          title: 'NfcF',
          rows: [
            MapEntry('Identifier', _toHex(nfcF.identifier)),
            MapEntry('System code', _toHex(nfcF.systemCode)),
            MapEntry('Manufacturer', _toHex(nfcF.manufacturer)),
            MapEntry('Max transceive', nfcF.maxTransceiveLength.toString()),
            MapEntry('Timeout', '${nfcF.timeout} ms'),
          ],
        ),
      );
    }

    if (nfcV != null) {
      sections.add(
        _InfoSection(
          title: 'NfcV',
          rows: [
            MapEntry('Identifier', _toHex(nfcV.identifier)),
            MapEntry('DSF ID', nfcV.dsfId.toString()),
            MapEntry('Response flags', nfcV.responseFlags.toString()),
            MapEntry('Max transceive', nfcV.maxTransceiveLength.toString()),
          ],
        ),
      );
    }

    if (isoDep != null) {
      sections.add(
        _InfoSection(
          title: 'IsoDep',
          rows: [
            MapEntry('Identifier', _toHex(isoDep.identifier)),
            MapEntry('Hi layer response', _toHex(isoDep.hiLayerResponse)),
            MapEntry('Historical bytes', _toHex(isoDep.historicalBytes)),
            MapEntry('Extended APDU', isoDep.isExtendedLengthApduSupported ? 'Ya' : 'Tidak'),
            MapEntry('Max transceive', isoDep.maxTransceiveLength.toString()),
            MapEntry('Timeout', '${isoDep.timeout} ms'),
          ],
        ),
      );

      sections.add(await _probeIsoDepApdu(isoDep));
    }

    if (miFare != null) {
      sections.add(
        _InfoSection(
          title: 'MiFare',
          rows: [
            MapEntry('Family', miFare.mifareFamily.name),
            MapEntry('Identifier', _toHex(miFare.identifier)),
            MapEntry('Historical bytes', _toHex(miFare.historicalBytes)),
          ],
        ),
      );
    }

    if (mifareClassic != null) {
      sections.add(
        _InfoSection(
          title: 'MifareClassic',
          rows: [
            MapEntry('Identifier', _toHex(mifareClassic.identifier)),
            MapEntry('Type', mifareClassic.type.toString()),
            MapEntry('Block count', mifareClassic.blockCount.toString()),
            MapEntry('Sector count', mifareClassic.sectorCount.toString()),
            MapEntry('Size', mifareClassic.size.toString()),
          ],
          note: 'Kartu jenis ini biasanya perlu autentikasi kunci sektor untuk membaca isi blok. Di mode debug ini saya hanya menampilkan metadata yang aman.',
        ),
      );
    }

    if (mifareUltralight != null) {
      sections.add(
        _InfoSection(
          title: 'MifareUltralight',
          rows: [
            MapEntry('Identifier', _toHex(mifareUltralight.identifier)),
            MapEntry('Type', mifareUltralight.type.toString()),
            MapEntry('Max transceive', mifareUltralight.maxTransceiveLength.toString()),
            MapEntry('Timeout', '${mifareUltralight.timeout} ms'),
          ],
        ),
      );
    }

    final readableBlocks = <int, Uint8List>{};

    if (mifareClassic != null) {
      final readRows = <MapEntry<String, String>>[];
      final candidateNumbers = <String>{};
      final readableSectors = <int>[];
      final highlightedBlocks = <String>[];
      var readableBlockCount = 0;
      final maxSectorsToTry = mifareClassic.sectorCount < 24 ? mifareClassic.sectorCount : 24;

      for (var sectorIndex = 0; sectorIndex < maxSectorsToTry; sectorIndex++) {
        final firstBlock = _sectorFirstBlockIndex(sectorIndex);
        final blockCount = _sectorBlockCount(sectorIndex);
        final sectorParts = <String>[];

        try {
          var authenticated = false;
          String? authKeyLabel;

          for (final keyEntry in _commonMifareKeys) {
            try {
              authenticated = await mifareClassic.authenticateSectorWithKeyA(
                sectorIndex: sectorIndex,
                key: keyEntry.value,
              );
              if (authenticated) {
                authKeyLabel = '${keyEntry.key} / Key A';
                break;
              }
            } catch (_) {}

            try {
              authenticated = await mifareClassic.authenticateSectorWithKeyB(
                sectorIndex: sectorIndex,
                key: keyEntry.value,
              );
              if (authenticated) {
                authKeyLabel = '${keyEntry.key} / Key B';
                break;
              }
            } catch (_) {}
          }

          if (!authenticated) {
            sectorParts.add('auth gagal');
          } else {
            readableSectors.add(sectorIndex);
            if (authKeyLabel != null) {
              sectorParts.add('auth=$authKeyLabel');
            }
            for (var offset = 0; offset < blockCount; offset++) {
              final blockIndex = firstBlock + offset;
              if (blockIndex >= mifareClassic.blockCount) break;
              try {
                final blockData = await mifareClassic.readBlock(blockIndex: blockIndex);
                readableBlocks[blockIndex] = Uint8List.fromList(blockData);
                readableBlockCount++;
                final ascii = _asciiFromBytes(blockData);
                final numbers = _extractCandidateNumbers(blockData);
                if (numbers.isNotEmpty) candidateNumbers.addAll(numbers);
                if (blockData.any((byte) => byte != 0x00)) {
                  highlightedBlocks.add('B$blockIndex=${_toHex(blockData)}');
                }
                sectorParts.add('B$blockIndex=${_toHex(blockData)}${ascii.isNotEmpty ? ' | $ascii' : ''}');
              } catch (error) {
                sectorParts.add('B$blockIndex=err');
              }
            }
          }
        } catch (error) {
          sectorParts.add('err: $error');
        }

        readRows.add(MapEntry('Sector $sectorIndex', sectorParts.join(' ; ')));
      }

      sections.add(
        _InfoSection(
          title: 'Mandiri E-Money Best Effort',
          rows: readRows,
          note: [
            'Sektor kebuka: ${readableSectors.isEmpty ? '-' : readableSectors.join(', ')}',
            'Blok terbaca: $readableBlockCount',
            if (highlightedBlocks.isNotEmpty) 'Blok non-zero: ${highlightedBlocks.take(8).join(' | ')}',
            if (candidateNumbers.isNotEmpty) 'Nomor kandidat: ${candidateNumbers.join(', ')}',
            if (candidateNumbers.isEmpty) 'Tidak ada nomor kandidat yang berhasil diekstrak dari blok yang terbuka atau dari key umum MifareClassic. Untuk banyak kartu Mandiri E-Money, saldo dan nomor kartu memang disimpan di sektor yang dilindungi.',
          ].join('\n'),
        ),
      );
    }

    if (_previousReadableBlocks != null && readableBlocks.isNotEmpty) {
      sections.add(_buildReadableBlockComparisonSection(_previousReadableBlocks!, readableBlocks));
    }

    if (ndef != null) {
      final rows = <MapEntry<String, String>>[
        MapEntry('Writable', ndef.isWritable ? 'Ya' : 'Tidak'),
        MapEntry('Max size', ndef.maxSize.toString()),
        MapEntry('Cached records', ndef.cachedMessage?.records.length.toString() ?? '0'),
      ];

      final lines = <String>[];
      var message = ndef.cachedMessage;
      if (message == null) {
        try {
          message = await ndef.read();
        } catch (error) {
          lines.add('Gagal membaca NDEF langsung: $error');
        }
      }
      if (message != null) {
        for (var index = 0; index < message.records.length; index++) {
          final record = message.records[index];
          lines.add('Record ${index + 1}: ${_decodeNdefRecord(record)}');
        }
      }

      sections.add(
        _InfoSection(
          title: 'NDEF',
          rows: rows,
          note: lines.isEmpty ? 'Tag ini tidak punya isi NDEF yang tersimpan.' : lines.join('\n'),
        ),
      );
    }

    if (mifareUltralight != null) {
      try {
        final pageData = await mifareUltralight.readPages(pageOffset: 0);
        sections.add(
          _InfoSection(
            title: 'MifareUltralight Read',
            rows: [
              MapEntry('Pages 0-3', _toHex(pageData)),
            ],
            note: 'Ini hanya membaca halaman awal yang biasanya terbuka. Jika kartu tidak mengizinkan, hasil akan kosong atau error.',
          ),
        );
      } catch (error) {
        sections.add(
          _InfoSection(
            title: 'MifareUltralight Read',
            rows: const [
              MapEntry('Pages 0-3', 'Gagal dibaca'),
            ],
            note: 'Error baca halaman awal: $error',
          ),
        );
      }
    }

    return _ScanBuildResult(
      sections: sections,
      readableBlocks: readableBlocks,
    );
  }

  Future<void> _startScan() async {
    if (!_isAvailable) {
      Fluttertoast.showToast(msg: 'NFC tidak tersedia di perangkat ini');
      return;
    }

    setState(() {
      _isScanning = true;
      _tagData = null;
      _sections = [];
      _sessionMessage = 'Tempelkan kartu ke belakang HP';
      _sessionError = null;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          final data = Map<String, dynamic>.from(tag.data);
          final scanResult = await _buildSectionsFromTag(tag);
          if (!mounted) return;

          setState(() {
            _tagData = data;
            _sections = scanResult.sections;
            if (_previousReadableBlocks == null) {
              _sessionMessage = 'Tag terbaca. Baseline blok terbaca disimpan. Lakukan transaksi lalu scan ulang untuk melihat perubahan otomatis.';
            } else if (scanResult.readableBlocks.isNotEmpty) {
              final previousTime = _previousSnapshotAt == null ? '-' : _shortTimestamp(_previousSnapshotAt!);
              _sessionMessage = 'Tag terbaca. Perbandingan dengan scan sebelumnya ($previousTime) sudah ditampilkan.';
            } else {
              _sessionMessage = 'Tag terbaca, tetapi tidak ada blok MifareClassic yang terbaca untuk dibandingkan.';
            }
            if (scanResult.readableBlocks.isNotEmpty) {
              _previousReadableBlocks = Map<int, Uint8List>.from(scanResult.readableBlocks);
              _previousSnapshotAt = DateTime.now();
            }
            _isScanning = false;
          });

          await NfcManager.instance.stopSession();
        },
        onError: (error) async {
          if (!mounted) return;
          setState(() {
            _isScanning = false;
            _sessionError = 'Gagal scan NFC: ${error.message}';
            _sessionMessage = null;
          });
          Fluttertoast.showToast(msg: 'Gagal scan NFC: ${error.message}');
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _sessionError = 'Gagal memulai sesi NFC: $error';
        _sessionMessage = null;
      });
      Fluttertoast.showToast(msg: 'Gagal memulai sesi NFC');
    }
  }

  Widget _row(String label, String value) {
    final notifire = Provider.of<ColorNotifire>(context, listen: false);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 180),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width / 3.2,
            child: Text(
              label,
              style: TextStyle(
                color: notifire.getdarkgreycolor,
                fontFamily: 'Gilroy Medium',
                fontSize: height / 62,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontFamily: 'Gilroy Bold',
                fontSize: height / 62,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(_InfoSection section) {
    final notifire = Provider.of<ColorNotifire>(context, listen: false);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 20, vertical: height / 110),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(width / 22),
        decoration: BoxDecoration(
          color: notifire.gettabwhitecolor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: notifire.getdarkgreycolor.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontFamily: 'Gilroy Bold',
                fontSize: height / 54,
              ),
            ),
            Divider(color: notifire.getdarkgreycolor.withOpacity(0.2)),
            ...section.rows.map((row) => _row(row.key, row.value)),
            if (section.note != null && section.note!.trim().isNotEmpty) ...[
              SizedBox(height: height / 180),
              SelectableText(
                section.note!,
                style: TextStyle(
                  color: notifire.getdarkgreycolor,
                  fontFamily: 'Gilroy Medium',
                  fontSize: height / 70,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);

    final rawJson = _tagData == null ? '{}' : const JsonEncoder.withIndent('  ').convert(_tagData);

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: height / 45),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
                    ),
                    const Spacer(),
                    Text(
                      'Scan Kartu Toll (Uji Coba)',
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 42,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(width: height / 24),
                  ],
                ),
              ),
              SizedBox(height: height / 45),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(width / 22),
                  decoration: BoxDecoration(
                    color: notifire.gettabwhitecolor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: notifire.getdarkgreycolor.withOpacity(0.16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yang dicoba terbaca dari kartu:',
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontFamily: 'Gilroy Bold',
                          fontSize: height / 58,
                        ),
                      ),
                      SizedBox(height: height / 220),
                      Text(
                        'UID, teknologi aktif, isi NDEF jika ada, serta metadata Android lain yang terbaca.',
                        style: TextStyle(
                          color: notifire.getdarkgreycolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 68,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: height / 45),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: SizedBox(
                  width: double.infinity,
                  height: height / 15,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.nfc, color: Colors.white),
                    label: Text(
                      _isScanning ? 'Tempelkan kartu ke belakang HP...' : 'Mulai Scan NFC',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 55,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notifire.getbluecolor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              if (_sessionMessage != null)
                Padding(
                  padding: EdgeInsets.only(top: height / 55, left: width / 20, right: width / 20),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(width / 25),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withOpacity(0.12)),
                    ),
                    child: Text(
                      _sessionMessage!,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 65,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),

              if (_sessionError != null)
                Padding(
                  padding: EdgeInsets.only(top: height / 55, left: width / 20, right: width / 20),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(width / 25),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.12)),
                    ),
                    child: Text(
                      _sessionError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 65,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),

              if (!_isAvailable)
                Padding(
                  padding: EdgeInsets.only(top: height / 55),
                  child: Text(
                    'NFC tidak aktif / tidak didukung di perangkat ini.',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Gilroy Medium',
                      fontSize: height / 60,
                    ),
                  ),
                ),

              if (_sections.isNotEmpty) ...[
                SizedBox(height: height / 40),
                ..._sections.map(_buildSectionCard),
              ],

              if (_tagData != null) ...[
                SizedBox(height: height / 55),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(width / 25),
                    decoration: BoxDecoration(
                      color: notifire.gettabwhitecolor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: notifire.getdarkgreycolor.withOpacity(0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Raw Data (Debug)',
                          style: TextStyle(
                            color: notifire.getdarkscolor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 58,
                          ),
                        ),
                        SizedBox(height: height / 220),
                        SelectableText(
                          rawJson,
                          style: TextStyle(
                            color: notifire.getdarkgreycolor,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 74,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: height / 20),
            ],
          ),
        ),
      ),
    );
  }
}
