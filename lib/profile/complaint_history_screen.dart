import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';

class ComplaintHistoryScreen extends StatefulWidget {
  const ComplaintHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ComplaintHistoryScreen> createState() => _ComplaintHistoryScreenState();
}

class _ComplaintHistoryScreenState extends State<ComplaintHistoryScreen> {
  late ColorNotifire notifire;
  List<dynamic> _complaints = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getComplaints();
      setState(() {
        _complaints = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = ApiService.userFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  String _getCategoryText(String category) {
    switch (category.toLowerCase()) {
      case 'ppob':
        return 'Transaksi PPOB';
      case 'transfer':
        return 'Transfer Saldo';
      case 'account':
        return 'Akun & Keamanan';
      case 'other':
        return 'Lainnya';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        centerTitle: true,
        title: DesktopTitleWrapper(child: Text(
          'Riwayat Pengaduan',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
          ),
        ))
      ),
      backgroundColor: notifire.getprimerycolor,
      body: Stack(
        children: [
          Container(
            height: height * 0.9,
            width: width,
            color: Colors.transparent,
            child: Image.asset(
              "images/background.png",
              fit: BoxFit.cover,
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: notifire.getdarkscolor,
                                fontFamily: 'Gilroy Medium',
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchComplaints,
                              child: const Text('Coba Lagi'),
                            )
                          ],
                        ),
                      ),
                    )
                  : _complaints.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada riwayat pengaduan.',
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Medium',
                              fontSize: 16,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchComplaints,
                          child: ListView.builder(
                            itemCount: _complaints.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            itemBuilder: (context, index) {
                              final item = _complaints[index];
                              final status = item['status']?.toString() ?? 'pending';
                              final statusColor = _getStatusColor(status);
                              final statusText = _getStatusText(status);
                              final categoryText = _getCategoryText(item['category']?.toString() ?? 'other');
                              final csReply = item['cs_reply']?.toString();

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                ),
                                color: notifire.getdarkwhitecolor,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: notifire.getbluecolor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              categoryText,
                                              style: TextStyle(
                                                color: notifire.getbluecolor,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        item['subject']?.toString() ?? '',
                                        style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['message']?.toString() ?? '',
                                        style: TextStyle(
                                          color: notifire.getdarkscolor.withOpacity(0.7),
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (item['transaction_id'] != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'ID Transaksi: #${item['transaction_id']}',
                                          style: TextStyle(
                                            color: notifire.getdarkscolor.withOpacity(0.5),
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        item['created_at'] != null 
                                            ? item['created_at'].toString().substring(0, 10) 
                                            : '',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                          fontFamily: 'Gilroy Medium',
                                        ),
                                      ),
                                      if (csReply != null && csReply.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: notifire.getprimerycolor,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.withOpacity(0.15)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.support_agent, size: 16, color: notifire.getbluecolor),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tanggapan Customer Service:',
                                                    style: TextStyle(
                                                      color: notifire.getbluecolor,
                                                      fontFamily: 'Gilroy Bold',
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                csReply,
                                                style: TextStyle(
                                                  color: notifire.getdarkscolor,
                                                  fontFamily: 'Gilroy Medium',
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ],
      ),
    );
  }
}
