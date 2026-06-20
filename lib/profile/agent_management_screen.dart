import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import 'add_agent_screen.dart';

class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({Key? key}) : super(key: key);

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  bool _isLoading = false;
  List<dynamic> _agents = [];
  List<dynamic> _filteredAgents = [];
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchAgents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getAgens();
      if (response.containsKey('data')) {
        setState(() {
          _agents = response['data'] is List ? response['data'] : [];
          _filteredAgents = _agents;
        });
      } else {
        Fluttertoast.showToast(msg: response['message'] ?? 'Gagal memuat daftar agen');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAgents = _agents.where((agent) {
        final name = agent['name']?.toString().toLowerCase() ?? '';
        final phone = agent['phone']?.toString().toLowerCase() ?? '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _updateMarginDialog(double currentMargin) async {
    final marginController = TextEditingController(text: currentMargin.toStringAsFixed(0));
    final notifire = Provider.of<ColorNotifire>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Ubah Markup Margin',
            style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Margin markup ini akan ditambahkan ke harga pokok produk untuk semua Agen Anda.',
                style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: marginController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Markup Margin (Rupiah)',
                  labelStyle: const TextStyle(fontFamily: 'Gilroy Medium'),
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Gilroy Bold')),
            ),
            ElevatedButton(
              onPressed: () async {
                final marginVal = double.tryParse(marginController.text) ?? 0.0;
                if (marginVal < 0) {
                  Fluttertoast.showToast(msg: 'Margin tidak boleh negatif');
                  return;
                }
                Navigator.pop(ctx);
                
                setState(() => _isLoading = true);
                try {
                  final res = await ApiService.updateMargin(marginVal);
                  Fluttertoast.showToast(msg: res['message'] ?? 'Margin berhasil diperbarui');
                  if (mounted) {
                    await Provider.of<AuthProvider>(context, listen: false).fetchProfile();
                  }
                } catch (e) {
                  Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: notifire.getbluecolor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Simpan', style: TextStyle(fontFamily: 'Gilroy Bold', color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAgentDialog(Map<String, dynamic> agent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Hapus Agen',
            style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus "${agent['name'] ?? 'agen ini'}" dari daftar agen Anda? Tindakan ini tidak dapat dibatalkan.',
            style: const TextStyle(fontFamily: 'Gilroy Medium', fontSize: 13, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Gilroy Bold')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Hapus', style: TextStyle(fontFamily: 'Gilroy Bold', color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.deleteAgen(agent['id']);
      Fluttertoast.showToast(msg: res['message'] ?? 'Agen berhasil dihapus');
      await _fetchAgents();
    } catch (e) {
      Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    final bgColor = notifire.getprimerycolor;
    final cardColor = notifire.getdarkwhitecolor;
    final textColor = notifire.getdarkscolor;
    final subtitleColor = notifire.getdarkgreycolor;
    final accent = notifire.getbluecolor;

    final double markupMargin = double.tryParse(auth.user?['markup_margin']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: true,
        title: DesktopTitleWrapper(child: Text(
          'Kelola Agen',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontFamily: 'Gilroy Bold',
          ),
        ))
      ),
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAgentScreen()),
          );
          if (added == true) {
            _fetchAgents();
          }
        },
        backgroundColor: accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Header Info Margin
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Markup Margin Saat Ini',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Gilroy Medium',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(markupMargin),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontFamily: 'Gilroy Bold',
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _updateMarginDialog(markupMargin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Ubah',
                    style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari agen berdasarkan nama/nomor...',
                hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontFamily: 'Gilroy Medium'),
                prefixIcon: Icon(Icons.search, color: subtitleColor, size: 20),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD3DBE8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD3DBE8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // List of Agents
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAgents,
              child: _isLoading && _agents.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAgents.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 64, color: subtitleColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tidak ada agen yang terdaftar',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Klik tombol + di kanan bawah untuk menambah',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 12,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _filteredAgents.length,
                          itemBuilder: (context, index) {
                            final agent = _filteredAgents[index];
                            final balance = double.tryParse(agent['balance']?.toString() ?? '0') ?? 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE9E9EE)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person, color: accent, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          agent['name'] ?? 'Nama Agen',
                                          style: TextStyle(
                                            color: textColor,
                                            fontFamily: 'Gilroy Bold',
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          agent['phone'] ?? '-',
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Saldo: ${_currencyFormat.format(balance)}',
                                          style: TextStyle(
                                            color: accent,
                                            fontFamily: 'Gilroy Bold',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: subtitleColor, size: 20),
                                    padding: EdgeInsets.zero,
                                    splashRadius: 20,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    onSelected: (value) {
                                      if (value == 'delete') _deleteAgentDialog(agent);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Hapus Agen',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
