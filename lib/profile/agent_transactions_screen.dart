import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AgentTransaction {
  final String id;
  final String type; // topup, transfer, ppob, qris
  final String? customerName;
  final String? customerPhone;
  final double amount;
  final double fee;
  final double commission;
  final String status; // success, failed, pending
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  AgentTransaction({
    required this.id,
    required this.type,
    this.customerName,
    this.customerPhone,
    required this.amount,
    required this.fee,
    required this.commission,
    required this.status,
    required this.timestamp,
    this.details,
  });

  String get displayName => customerName ?? customerPhone ?? 'Unknown';
  String get formattedAmount => 'Rp ${amount.toStringAsFixed(0)}';
  String get formattedFee => 'Rp ${fee.toStringAsFixed(0)}';
  String get formattedCommission => 'Rp ${commission.toStringAsFixed(0)}';
  String get formattedTotal => 'Rp ${(amount + fee).toStringAsFixed(0)}';
  String get typeLabel => type.toUpperCase();
  String get formattedDate => DateFormat('dd MMM yyyy').format(timestamp);
  String get formattedTime => DateFormat('HH:mm').format(timestamp);

  Color get statusColor {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'topup':
        return Icons.account_balance_wallet;
      case 'transfer':
        return Icons.send;
      case 'ppob':
        return Icons.receipt;
      case 'qris':
        return Icons.qr_code;
      default:
        return Icons.transaction;
    }
  }
}

class AgentTransactionsScreen extends StatefulWidget {
  @override
  State<AgentTransactionsScreen> createState() =>
      _AgentTransactionsScreenState();
}

class _AgentTransactionsScreenState extends State<AgentTransactionsScreen> {
  late List<AgentTransaction> _allTransactions;
  late List<AgentTransaction> _filteredTransactions;

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 30)),
    end: DateTime.now(),
  );

  Set<String> _selectedStatuses = {'success', 'failed', 'pending'};
  Set<String> _selectedTypes = {'topup', 'transfer', 'ppob', 'qris'};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() => _isLoading = true);

      // Simulate loading from API
      await Future.delayed(Duration(milliseconds: 500));

      // Generate sample transactions
      _allTransactions = _generateSampleTransactions();
      _applyFilters();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredTransactions = _allTransactions.where((tx) {
      // Date filter
      if (tx.timestamp.isBefore(_dateRange.start) ||
          tx.timestamp.isAfter(_dateRange.end)) {
        return false;
      }

      // Status filter
      if (!_selectedStatuses.contains(tx.status)) {
        return false;
      }

      // Type filter
      if (!_selectedTypes.contains(tx.type)) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return tx.id.toLowerCase().contains(query) ||
            tx.displayName.toLowerCase().contains(query) ||
            tx.customerPhone?.contains(query) ?? false;
      }

      return true;
    }).toList();

    // Sort by date (newest first)
    _filteredTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<AgentTransaction> _generateSampleTransactions() {
    final now = DateTime.now();
    return [
      AgentTransaction(
        id: 'TRX001',
        type: 'topup',
        customerName: 'John Doe',
        customerPhone: '081234567890',
        amount: 100000,
        fee: 1500,
        commission: 1000,
        status: 'success',
        timestamp: now.subtract(Duration(hours: 2)),
      ),
      AgentTransaction(
        id: 'TRX002',
        type: 'transfer',
        customerName: 'Jane Smith',
        customerPhone: '081234567891',
        amount: 500000,
        fee: 2500,
        commission: 5000,
        status: 'success',
        timestamp: now.subtract(Duration(hours: 4)),
      ),
      AgentTransaction(
        id: 'TRX003',
        type: 'ppob',
        customerName: 'PT Maju Jaya',
        customerPhone: '081234567892',
        amount: 250000,
        fee: 1000,
        commission: 2500,
        status: 'failed',
        timestamp: now.subtract(Duration(hours: 6)),
      ),
    ];
  }

  TransactionSummary _calculateSummary() {
    double totalAmount = 0;
    double totalFees = 0;
    double totalCommission = 0;
    int successCount = 0;
    int failedCount = 0;

    for (final tx in _filteredTransactions) {
      totalAmount += tx.amount;
      totalFees += tx.fee;
      totalCommission += tx.commission;

      if (tx.status == 'success') {
        successCount++;
      } else if (tx.status == 'failed') {
        failedCount++;
      }
    }

    return TransactionSummary(
      totalTransactions: _filteredTransactions.length,
      totalAmount: totalAmount,
      totalFees: totalFees,
      totalCommission: totalCommission,
      successCount: successCount,
      failedCount: failedCount,
    );
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
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _calculateSummary();

    return Scaffold(
      appBar: AppBar(
        title: Text('Agent Transactions'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    _buildSummaryCards(summary),
                    SizedBox(height: 24),

                    // Filter section
                    _buildFilterSection(),
                    SizedBox(height: 16),

                    // Search bar
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by ID, name, or phone',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Transactions list
                    _buildTransactionsList(summary),

                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _exportTransactions(summary),
                        icon: Icon(Icons.download),
                        label: Text('Export Results'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards(TransactionSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Transactions',
                summary.totalTransactions.toString(),
                Icons.receipt,
                Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Success',
                summary.successCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Failed',
                summary.failedCount.toString(),
                Icons.error,
                Colors.red,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                'Total Amount',
                'Rp ${summary.totalAmount.toStringAsFixed(0)}',
              ),
              SizedBox(height: 8),
              _buildSummaryRow(
                'Commission',
                'Rp ${summary.totalCommission.toStringAsFixed(0)}',
              ),
              SizedBox(height: 8),
              Divider(),
              SizedBox(height: 8),
              _buildSummaryRow(
                'Net Settlement',
                'Rp ${(summary.totalAmount - summary.totalFees).toStringAsFixed(0)}',
                isHighlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
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
            Icon(icon, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 13,
            color: Colors.grey[700],
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date range
        Row(
          children: [
            Icon(Icons.calendar_today, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _selectDateRange,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${DateFormat('dd MMM').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),

        // Status filter
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip(
              'Success',
              _selectedStatuses.contains('success'),
              () {
                setState(() {
                  _selectedStatuses.contains('success')
                      ? _selectedStatuses.remove('success')
                      : _selectedStatuses.add('success');
                  _applyFilters();
                });
              },
            ),
            _buildFilterChip(
              'Failed',
              _selectedStatuses.contains('failed'),
              () {
                setState(() {
                  _selectedStatuses.contains('failed')
                      ? _selectedStatuses.remove('failed')
                      : _selectedStatuses.add('failed');
                  _applyFilters();
                });
              },
            ),
            _buildFilterChip(
              'Pending',
              _selectedStatuses.contains('pending'),
              () {
                setState(() {
                  _selectedStatuses.contains('pending')
                      ? _selectedStatuses.remove('pending')
                      : _selectedStatuses.add('pending');
                  _applyFilters();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildTransactionsList(TransactionSummary summary) {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.receipt, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No transactions found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Group transactions by date
    Map<String, List<AgentTransaction>> groupedTx = {};
    for (final tx in _filteredTransactions) {
      final dateKey = DateFormat('dd MMM yyyy').format(tx.timestamp);
      groupedTx.putIfAbsent(dateKey, () => []).add(tx);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: groupedTx.keys.length,
      itemBuilder: (context, index) {
        final dateKey = groupedTx.keys.elementAt(index);
        final txList = groupedTx[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: txList.length,
              separatorBuilder: (_, __) => SizedBox(height: 8),
              itemBuilder: (context, txIndex) {
                final tx = txList[txIndex];
                return _buildTransactionCard(tx);
              },
            ),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(AgentTransaction tx) {
    return Card(
      child: ListTile(
        leading: Icon(tx.typeIcon, color: Colors.blue),
        title: Text(tx.displayName),
        subtitle: Row(
          children: [
            Text(tx.typeLabel, style: TextStyle(fontSize: 11)),
            SizedBox(width: 8),
            Text(tx.formattedTime, style: TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tx.formattedAmount,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tx.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tx.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: tx.statusColor,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showTransactionDetail(tx),
      ),
    );
  }

  void _showTransactionDetail(AgentTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Transaction ID', tx.id),
              _detailRow('Type', tx.typeLabel),
              _detailRow('Customer', tx.displayName),
              _detailRow('Date', tx.formattedDate),
              _detailRow('Time', tx.formattedTime),
              Divider(),
              _detailRow('Amount', tx.formattedAmount),
              _detailRow('Fee', tx.formattedFee),
              _detailRow('Commission', tx.formattedCommission),
              Divider(),
              _detailRow('Status', tx.status.toUpperCase(),
                  color: tx.statusColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Share receipt
              Navigator.pop(context);
              _shareReceipt(tx);
            },
            icon: Icon(Icons.share),
            label: Text('Share'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _shareReceipt(AgentTransaction tx) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt sharing coming soon')),
    );
  }

  void _exportTransactions(TransactionSummary summary) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting ${_filteredTransactions.length} transactions...')),
    );
  }
}

class TransactionSummary {
  final int totalTransactions;
  final double totalAmount;
  final double totalFees;
  final double totalCommission;
  final int successCount;
  final int failedCount;

  TransactionSummary({
    required this.totalTransactions,
    required this.totalAmount,
    required this.totalFees,
    required this.totalCommission,
    required this.successCount,
    required this.failedCount,
  });
}
