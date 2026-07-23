import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';

class SettlementSummary {
  final DateTime settlementDate;
  final int totalTransactions;
  final double totalAmount;
  final double totalFees;
  final double totalCommission;
  final Map<String, int> breakdownByType;
  final List<String> agentIds;

  SettlementSummary({
    required this.settlementDate,
    required this.totalTransactions,
    required this.totalAmount,
    required this.totalFees,
    required this.totalCommission,
    required this.breakdownByType,
    required this.agentIds,
  });

  double get netSettlement => totalAmount - totalFees;
  String get formattedDate => DateFormat('dd MMM yyyy').format(settlementDate);
  String get formattedTotalAmount => 'Rp ${totalAmount.toStringAsFixed(0)}';
  String get formattedTotalFees => 'Rp ${totalFees.toStringAsFixed(0)}';
  String get formattedTotalCommission => 'Rp ${totalCommission.toStringAsFixed(0)}';
  String get formattedNetSettlement => 'Rp ${netSettlement.toStringAsFixed(0)}';
}

class SettlementSummaryScreen extends StatefulWidget {
  final SettlementSummary? initialData;

  const SettlementSummaryScreen({this.initialData});

  @override
  State<SettlementSummaryScreen> createState() =>
      _SettlementSummaryScreenState();
}

class _SettlementSummaryScreenState extends State<SettlementSummaryScreen> {
  late SettlementSummary _settlementData;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 30)),
    end: DateTime.now(),
  );
  String _selectedPeriod = 'daily';
  bool _isLoading = true;
  final ExportService _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    _initializeSettlementData();
  }

  Future<void> _initializeSettlementData() async {
    try {
      setState(() => _isLoading = true);

      await Future.delayed(Duration(milliseconds: 500));

      _settlementData = widget.initialData ??
          SettlementSummary(
            settlementDate: DateTime.now(),
            totalTransactions: 156,
            totalAmount: 45600000,
            totalFees: 228000,
            totalCommission: 456000,
            breakdownByType: {
              'topup': 45,
              'transfer': 67,
              'ppob': 32,
              'qris': 12,
            },
            agentIds: ['AGT001', 'AGT002', 'AGT003'],
          );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settlement data: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _initializeSettlementData();
      });
    }
  }

  Future<void> _exportSettlementReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generating settlement report...')),
      );

      final reportData = {
        'agentName': 'All Agents',
        'startDate': DateFormat('dd MMM yyyy').format(_dateRange.start),
        'endDate': DateFormat('dd MMM yyyy').format(_dateRange.end),
        'totalTransactions': _settlementData.totalTransactions,
        'totalAmount': _settlementData.totalAmount,
        'totalFees': _settlementData.totalFees,
        'totalCommission': _settlementData.totalCommission,
        'breakdown': _settlementData.breakdownByType,
      };

      final file = await _exportService.exportSettlementReportToPDF(reportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement report saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settlement Summary'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initializeSettlementData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    SizedBox(height: 16),
                    _buildDateRangeSelector(),
                    SizedBox(height: 24),
                    _buildSummaryCards(),
                    SizedBox(height: 24),
                    _buildTransactionBreakdown(),
                    SizedBox(height: 24),
                    _buildDetailedSummary(),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _initializeSettlementData,
                            icon: Icon(Icons.refresh),
                            label: Text('Refresh'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportSettlementReport,
                            icon: Icon(Icons.download),
                            label: Text('Export'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Daily')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedPeriod = newSelection.first;
                _initializeSettlementData();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return GestureDetector(
      onTap: _selectDateRange,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settlement Period',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Transactions',
                _settlementData.totalTransactions.toString(),
                Icons.receipt,
                Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Amount',
                'Rp ${(_settlementData.totalAmount / 1000000).toStringAsFixed(1)}M',
                Icons.attach_money,
                Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Commission',
                'Rp ${(_settlementData.totalCommission / 1000).toStringAsFixed(0)}K',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Net Settlement',
                'Rp ${(_settlementData.netSettlement / 1000000).toStringAsFixed(1)}M',
                Icons.account_balance_wallet,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Breakdown',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: 12),
        Card(
          child: Column(
            children: _settlementData.breakdownByType.entries.map((entry) {
              final percentage =
                  (_settlementData.totalTransactions > 0)
                      ? (entry.value / _settlementData.totalTransactions * 100)
                      : 0.0;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getColorForType(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settlement Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _summaryRow('Settlement Date', _settlementData.formattedDate),
              Divider(),
              _summaryRow(
                'Total Transactions',
                _settlementData.totalTransactions.toString(),
              ),
              Divider(),
              _summaryRow('Total Amount', _settlementData.formattedTotalAmount),
              Divider(),
              _summaryRow('Total Fees', _settlementData.formattedTotalFees),
              Divider(),
              _summaryRow(
                'Total Commission',
                _settlementData.formattedTotalCommission,
              ),
              Divider(thickness: 2),
              _summaryRow(
                'NET SETTLEMENT',
                _settlementData.formattedNetSettlement,
                isHighlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.blue : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'topup':
        return Colors.blue;
      case 'transfer':
        return Colors.green;
      case 'ppob':
        return Colors.orange;
      case 'qris':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
