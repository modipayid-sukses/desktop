import 'package:flutter/material.dart';
import 'package:gobank/home/scanpay/scan.dart';
import 'package:gobank/utils/media.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colornotifire.dart';
import '../utils/string.dart';

class Seeallpayment extends StatefulWidget {
  const Seeallpayment({Key? key}) : super(key: key);

  @override
  State<Seeallpayment> createState() => _SeeallpaymentState();
}

class _SeeallpaymentState extends State<Seeallpayment> {
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

  List insuranceimg = [
    "images/health.png",
    "images/mobile.png",
    "images/water.png",
    "images/ticket.png",
  ];

  List insurancename = [
    CustomStrings.health,
    CustomStrings.mobile,
    CustomStrings.motor,
    CustomStrings.car,
  ];

  List optionimg = [
    "images/assurance.png",
    "images/shopping.png",
    "images/deals.png",
    "images/install.png",
  ];

  List optionname = [
    CustomStrings.assurance,
    CustomStrings.shopping,
    CustomStrings.deals,
    CustomStrings.install,
  ];

  List img = [
    "images/bill.png",
    "images/wifi.png",
    "images/water.png",
    "images/wallet1.png",
    "images/game.png",
    "images/television.png",
    "images/merchant.png",
    "images/install.png",
  ];

  List paymentname = [
    CustomStrings.electricity,
    CustomStrings.internet,
    CustomStrings.water,
    CustomStrings.wallet,
    CustomStrings.games,
    CustomStrings.television,
    CustomStrings.merchant,
    CustomStrings.install,
  ];

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: notifire.getprimerycolor,
        title: Text(
          CustomStrings.allservices,
          style: TextStyle(
              fontFamily: "Gilroy Bold",
              color: notifire.getdarkscolor,
              fontSize: height / 40),
        ),
        actions: [
          Icon(
            Icons.more_horiz_outlined,
            color: notifire.getdarkscolor,
            size: 35,
          ),
          const SizedBox(
            width: 10,
          )
        ],
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: height / 50,
            ),
            Row(
              children: [
                SizedBox(
                  width: width / 20,
                ),
                Text(
                  CustomStrings.bill,
                  style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontSize: height / 50,
                      fontFamily: 'Gilroy Bold'),
                ),
              ],
            ),
            SizedBox(
              height: height / 60,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Container(
                color: Colors.transparent,
                height: height / 4,
                width: width,
                child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: height / 15),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: height / 10,
                      mainAxisExtent: height / 9,
                      childAspectRatio: 3 / 2,
                      crossAxisSpacing: height / 50,
                      mainAxisSpacing: height / 50,
                    ),
                    itemCount: img.length,
                    itemBuilder: (BuildContext ctx, index) {
                      return GestureDetector(
                        onTap: () {},
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const Scan(),
                                  ),
                                );
                              },
                              child: Container(
                                height: height / 15,
                                width: width / 7,
                                decoration: BoxDecoration(
                                  color: notifire.gettabwhitecolor,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    img[index],
                                    height: height / 30,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: height / 60,
                            ),
                            Text(
                              paymentname[index],
                              style: TextStyle(
                                  fontFamily: "Gilroy Bold",
                                  color: notifire.getdarkscolor,
                                  fontSize: height / 60),
                            ),
                          ],
                        ),
                      );
                    }),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Divider(
                color: notifire.getdarkgreycolor.withOpacity(0.4),
              ),
            ),
            SizedBox(
              height: height / 100,
            ),
            Row(
              children: [
                SizedBox(
                  width: width / 20,
                ),
                Text(
                  CustomStrings.insurance,
                  style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontSize: height / 50,
                      fontFamily: 'Gilroy Bold'),
                ),
              ],
            ),
            SizedBox(
              height: height / 60,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Container(
                color: Colors.transparent,
                height: height / 8,
                width: width,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: height / 15),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: height / 10,
                    mainAxisExtent: height / 9,
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: height / 50,
                    mainAxisSpacing: height / 50,
                  ),
                  itemCount: insuranceimg.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return GestureDetector(
                      onTap: () {},
                      child: Column(
                        children: [
                          Container(
                            height: height / 15,
                            width: width / 7,
                            decoration: BoxDecoration(
                              color: notifire.gettabwhitecolor,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                insuranceimg[index],
                                height: height / 30,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: height / 60,
                          ),
                          Text(
                            insurancename[index],
                            style: TextStyle(
                                fontFamily: "Gilroy Bold",
                                color: notifire.getdarkscolor,
                                fontSize: height / 55),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Divider(
                color: notifire.getdarkgreycolor.withOpacity(0.4),
              ),
            ),
            SizedBox(
              height: height / 100,
            ),
            Row(
              children: [
                SizedBox(
                  width: width / 20,
                ),
                Text(
                  CustomStrings.option,
                  style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontSize: height / 50,
                      fontFamily: 'Gilroy Bold'),
                ),
              ],
            ),
            SizedBox(
              height: height / 60,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Container(
                color: Colors.transparent,
                height: height / 8,
                width: width,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: height / 15),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: height / 10,
                    mainAxisExtent: height / 9,
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: height / 50,
                    mainAxisSpacing: height / 50,
                  ),
                  itemCount: insuranceimg.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return GestureDetector(
                      onTap: () {},
                      child: Column(
                        children: [
                          Container(
                            height: height / 15,
                            width: width / 7,
                            decoration: BoxDecoration(
                              color: notifire.gettabwhitecolor,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                optionimg[index],
                                height: height / 30,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: height / 60,
                          ),
                          Text(
                            optionname[index],
                            style: TextStyle(
                                fontFamily: "Gilroy Bold",
                                color: notifire.getdarkscolor,
                                fontSize: height / 55),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Divider(
                color: notifire.getdarkgreycolor.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
