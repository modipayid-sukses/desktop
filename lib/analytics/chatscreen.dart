import 'package:flutter/material.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/string.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colornotifire.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> analyticsData;
  const ChatScreen({Key? key, required this.analyticsData}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ColorNotifire notifire;

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  String _formatAmount(dynamic amount) {
    final value = (amount is int) ? amount.toDouble() : (amount as double?) ?? 0.0;
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(value.toInt())}';
  }

  List<Map<String, dynamic>> get _transactions {
    final txns = widget.analyticsData['transactions'];
    if (txns == null) return [];
    return List<Map<String, dynamic>>.from(txns);
  }

  double get _totalIncome => (widget.analyticsData['total_income'] ?? 0).toDouble();
  double get _totalExpense => (widget.analyticsData['total_expense'] ?? 0).toDouble();

  List<Map<String, dynamic>> get _incomeTransactions =>
      _transactions.where((t) => t['type'] == 'income').toList();

  List<Map<String, dynamic>> get _expenseTransactions =>
      _transactions.where((t) => t['type'] == 'expense').toList();

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: height / 40,
            ),
            Row(
              children: [
                Container(
                  height: height / 12,
                  width: width / 2.5,
                  decoration: BoxDecoration(
                    color: notifire.getpurplcolor,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(10),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: width / 40),
                    child: Row(
                      children: [
                        Image.asset(
                          "images/income.png",
                          height: height / 20,
                        ),
                        SizedBox(
                          width: width / 80,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: height / 80,
                            ),
                            Text(
                              CustomStrings.income,
                              style: TextStyle(
                                  color: notifire.getdarkgreycolor,
                                  fontSize: height / 60,
                                  fontFamily: 'Gilroy Medium'),
                            ),
                            SizedBox(
                              height: height / 100,
                            ),
                            Text(
                              _formatAmount(_totalIncome),
                              style: TextStyle(
                                  color: notifire.getdarkscolor,
                                  fontSize: height / 60,
                                  fontFamily: 'Gilroy Bold'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  height: height / 12,
                  width: width / 2.5,
                  decoration: BoxDecoration(
                    color: notifire.getpurplcolor,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(10),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: width / 40),
                    child: Row(
                      children: [
                        Image.asset(
                          "images/outcome.png",
                          height: height / 20,
                        ),
                        SizedBox(
                          width: width / 80,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: height / 80,
                            ),
                            Text(
                              CustomStrings.outcome,
                              style: TextStyle(
                                  color: notifire.getdarkgreycolor,
                                  fontSize: height / 60,
                                  fontFamily: 'Gilroy Medium'),
                            ),
                            SizedBox(
                              height: height / 100,
                            ),
                            Text(
                              _formatAmount(_totalExpense),
                              style: TextStyle(
                                  color: notifire.getdarkscolor,
                                  fontSize: height / 60,
                                  fontFamily: 'Gilroy Bold'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: height / 80,
            ),
            // columnchart(),
            SizedBox(
              height: height / 60,
            ),
            Row(
              children: [
                Text(
                  CustomStrings.recent,
                  style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 50),
                ),
              ],
            ),
            SizedBox(
              height: height / 60,
            ),
            Container(
              height: height / 3.6,
              color: Colors.transparent,
              child: _incomeTransactions.isEmpty
                  ? Center(
                      child: Text('Belum ada pemasukan',
                          style: TextStyle(
                              color: notifire.getdarkgreycolor,
                              fontFamily: 'Gilroy Medium')))
                  : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _incomeTransactions.length > 3 ? 3 : _incomeTransactions.length,
                      itemBuilder: (context, index) {
                        final t = _incomeTransactions[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: height / 80),
                          child: Container(
                            height: height / 12,
                            width: width,
                            decoration: BoxDecoration(
                              color: notifire.getdarkwhitecolor,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: width / 30),
                              child: Row(
                                children: [
                                  Container(
                                    color: Colors.transparent,
                                    width: 50,
                                    height: 40,
                                    child: Image.asset("images/chart3.png"),
                                  ),
                                  SizedBox(width: width / 30),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: height / 60),
                                        Text(
                                          t['date'] ?? '',
                                          style: TextStyle(
                                              color: notifire.getdarkscolor,
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: height / 50),
                                        ),
                                        SizedBox(height: height / 300),
                                        Text(
                                          '${t['count']} transaksi',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: height / 60),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '+${_formatAmount(t['total'])}',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: height / 50),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              height: height / 60,
            ),
            Row(
              children: [
                Text(
                  CustomStrings.historytransactions,
                  style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 50),
                ),
              ],
            ),
            SizedBox(
              height: height / 60,
            ),
            Container(
              height: height / 3.6,
              color: Colors.transparent,
              child: _expenseTransactions.isEmpty
                  ? Center(
                      child: Text('Belum ada pengeluaran',
                          style: TextStyle(
                              color: notifire.getdarkgreycolor,
                              fontFamily: 'Gilroy Medium')))
                  : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _expenseTransactions.length > 3 ? 3 : _expenseTransactions.length,
                      itemBuilder: (context, index) {
                        final t = _expenseTransactions[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: height / 80),
                          child: Container(
                            height: height / 12,
                            width: width,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                              color: notifire.getdarkwhitecolor,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: width / 30),
                              child: Row(
                                children: [
                                  Image.asset(
                                    "images/chart5.png",
                                    height: height / 25,
                                  ),
                                  SizedBox(width: width / 30),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: height / 60),
                                        Text(
                                          t['date'] ?? '',
                                          style: TextStyle(
                                              color: notifire.getdarkscolor,
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: height / 50),
                                        ),
                                        SizedBox(height: height / 300),
                                        Text(
                                          '${t['count']} transaksi',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: height / 60),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '-${_formatAmount(t['total'])}',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: height / 50),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              height: height / 10,
            ),
          ],
        ),
      ),
    );
  }

  // Widget columnchart() {
  //   return SfCartesianChart(
  //     primaryXAxis: CategoryAxis(interval: 10),
  //     annotations: const <CartesianChartAnnotation>[
  //       CartesianChartAnnotation(
  //           coordinateUnit: CoordinateUnit.percentage,
  //           region: AnnotationRegion.plotArea,
  //           widget: Text(
  //             '',
  //             style: TextStyle(
  //               fontSize: 14,
  //             ),
  //           ),
  //           x: '50%',
  //           y: '50%')
  //     ],
  //     series: <ChartSeries<ChartData, String>>[
  //       ColumnSeries<ChartData, String>(
  //           color: notifire.getbluecolor,
  //           borderRadius: const BorderRadius.all(Radius.circular(10)),
  //           dataSource: chartData,
  //           xValueMapper: (ChartData data, _) => data.x,
  //           yValueMapper: (ChartData data, _) => data.y)
  //     ],
  //   );
  // }
}

class ChartData {
  const ChartData(this.x, this.y);

  final String x;
  final int y;
}
