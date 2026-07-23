import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../profile/agent_transactions_screen.dart';

class ExportService {
  /// Export transactions to CSV
  Future<File> exportTransactionsToCSV(
    List<AgentTransaction> transactions, {
    String? filename,
  }) async {
    try {
      // Prepare CSV data
      final List<List<dynamic>> csvData = [
        [
          'Transaction ID',
          'Type',
          'Customer',
          'Phone',
          'Amount',
          'Fee',
          'Commission',
          'Status',
          'Date',
          'Time',
        ],
      ];

      for (final tx in transactions) {
        csvData.add([
          tx.id,
          tx.type,
          tx.customerName ?? '',
          tx.customerPhone ?? '',
          tx.amount,
          tx.fee,
          tx.commission,
          tx.status,
          tx.formattedDate,
          tx.formattedTime,
        ]);
      }

      // Add summary at the end
      final totalAmount = transactions.fold<double>(
        0,
        (sum, tx) => sum + tx.amount,
      );
      final totalFee =
          transactions.fold<double>(0, (sum, tx) => sum + tx.fee);
      final totalCommission = transactions.fold<double>(
        0,
        (sum, tx) => sum + tx.commission,
      );

      csvData.add([]);
      csvData.add(['SUMMARY']);
      csvData.add(['Total Transactions', transactions.length]);
      csvData.add(['Total Amount', totalAmount]);
      csvData.add(['Total Fees', totalFee]);
      csvData.add(['Total Commission', totalCommission]);

      // Convert to CSV string
      final csv = const ListToCsvConverter().convert(csvData);

      // Save to file
      final dir = await getTemporaryDirectory();
      final fileName = filename ??
          'transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(csv, encoding: utf8);

      return file;
    } catch (e) {
      throw Exception('Failed to export to CSV: $e');
    }
  }

  /// Export transactions to PDF
  Future<File> exportTransactionsToPDF(
    List<AgentTransaction> transactions, {
    String? filename,
    String? agentName,
  }) async {
    try {
      final pdf = pw.Document();

      // Calculate summary
      final totalAmount = transactions.fold<double>(
        0,
        (sum, tx) => sum + tx.amount,
      );
      final totalFee =
          transactions.fold<double>(0, (sum, tx) => sum + tx.fee);
      final totalCommission = transactions.fold<double>(
        0,
        (sum, tx) => sum + tx.commission,
      );

      // Page 1: Summary
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'TRANSACTION REPORT',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Agent: ${agentName ?? 'N/A'}'),
                        pw.Text('Report Date: ${DateTime.now()}'),
                        pw.Text(
                          'Total Transactions: ${transactions.length}',
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        _buildPdfCell('Metric'),
                        _buildPdfCell('Amount', align: pw.TextAlign.right),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell('Total Amount'),
                        _buildPdfCell(
                          'Rp ${totalAmount.toStringAsFixed(0)}',
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell('Total Fees'),
                        _buildPdfCell(
                          'Rp ${totalFee.toStringAsFixed(0)}',
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell('Total Commission'),
                        _buildPdfCell(
                          'Rp ${totalCommission.toStringAsFixed(0)}',
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell(
                          'Net Settlement',
                          bold: true,
                        ),
                        _buildPdfCell(
                          'Rp ${(totalAmount - totalFee).toStringAsFixed(0)}',
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'TRANSACTIONS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Page 2+: Transaction details (paginated)
      final itemsPerPage = 20;
      for (int i = 0; i < transactions.length; i += itemsPerPage) {
        final end = (i + itemsPerPage) < transactions.length
            ? i + itemsPerPage
            : transactions.length;
        final pageTransactions = transactions.sublist(i, end);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Text(
                    'TRANSACTION DETAILS (${i + 1}-$end of ${transactions.length})',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      pw.TableRow(
                        children: [
                          _buildPdfCell('ID', bold: true),
                          _buildPdfCell('Type', bold: true),
                          _buildPdfCell('Customer', bold: true),
                          _buildPdfCell('Amount', bold: true),
                          _buildPdfCell('Status', bold: true),
                        ],
                      ),
                      ...pageTransactions.map(
                        (tx) => pw.TableRow(
                          children: [
                            _buildPdfCell(tx.id, fontSize: 9),
                            _buildPdfCell(tx.typeLabel, fontSize: 9),
                            _buildPdfCell(tx.displayName, fontSize: 9),
                            _buildPdfCell(
                              tx.formattedAmount,
                              fontSize: 9,
                              align: pw.TextAlign.right,
                            ),
                            _buildPdfCell(tx.status, fontSize: 9),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save to file
      final dir = await getTemporaryDirectory();
      final fileName = filename ??
          'transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      throw Exception('Failed to export to PDF: $e');
    }
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    double fontSize = 10,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
