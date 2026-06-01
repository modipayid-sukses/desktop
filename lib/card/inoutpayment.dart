import 'package:flutter/material.dart';
import 'package:gobank/card/inoutrequested.dart';
import 'package:gobank/utils/media.dart';
import 'package:gobank/utils/string.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colornotifire.dart';
import 'inouthistory.dart';
import 'inoutscheduled.dart';

class InOutPayment extends StatefulWidget {
  const InOutPayment({Key? key}) : super(key: key);

  @override
  State<InOutPayment> createState() => _InOutPaymentState();
}

class _InOutPaymentState extends State<InOutPayment>
    with SingleTickerProviderStateMixin {
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

  TabController? controller;
  List<Widget> tabs = [
    const InOutHistory(),
    const InOutScheduled(),
    const InOutrequested(),
  ];

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: notifire.getprimerycolor,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        title: Text(
          CustomStrings.inoutpayment,
          style: TextStyle(
              color: notifire.getdarkscolor,
              fontSize: height / 40,
              fontFamily: 'Gilroy Bold'),
        ),
        actions: [
          Image.asset(
            "images/arrowleftright.png",
            scale: 5,
            color: notifire.getdarkscolor,
          ),
          const SizedBox(
            width: 8,
          ),
          const Icon(
            Icons.more_horiz_outlined,
            size: 30,
          ),
          const SizedBox(
            width: 10,
          )
        ],
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Stack(
          children: [
            Container(
              height: height,
              width: width,
              color: Colors.transparent,
              child: Image.asset(
                "images/background.png",
                fit: BoxFit.cover,
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: height / 30,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Container(
                    height: height / 1.11,
                    color: Colors.transparent,
                    child: Column(
                      children: <Widget>[
                        Container(
                          height: 45,
                          decoration: BoxDecoration(
                              color: notifire.gettabcolor,
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: EdgeInsets.all(height / 200),
                            child: TabBar(
                              labelStyle:
                                  const TextStyle(fontFamily: 'Gilroy Bold'),
                              indicator: BoxDecoration(
                                  color: notifire.gettabwhitecolor,
                                  borderRadius: BorderRadius.circular(10)),
                              indicatorColor: notifire.gettabcolor,
                              controller: controller,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: notifire.getdarkscolor,
                              unselectedLabelColor: Colors.grey,
                              tabs: const [
                                Tab(
                                  text: CustomStrings.history,
                                ),
                                Tab(text: CustomStrings.scheduled),
                                Tab(text: CustomStrings.requested),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: controller,
                            children: tabs.map((tab) => tab).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
