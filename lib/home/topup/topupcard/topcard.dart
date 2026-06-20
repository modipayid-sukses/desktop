import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/utils/string.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/colornotifire.dart';
import '../../../utils/media.dart';
import '../topup_channel_screen.dart';

class TopCard extends StatefulWidget {
  const TopCard({Key? key}) : super(key: key);

  @override
  State<TopCard> createState() => _TopCardState();
}

class _TopCardState extends State<TopCard> {
  late ColorNotifire notifire;
  int _selectedIndex = 0;
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  List img = [
    "images/citi.png",
    "images/boa.png",
    "images/usbank.png",
    "images/barclays.png",
    "images/hsbc.png",
    "images/deutsche.jpg",
    "images/dbs.png"
  ];
  List bankname = [
    "Citibank",
    "Bank of America",
    "usbank",
    "Barclays Bank",
    "HSBC India",
    "Deutsche Bank",
    "DBS Bank"
  ];
  List amount = [
    "Rp 10.000",
    "Rp 50.000",
    "Rp 100.000",
  ];
  final int _numPages = 4;
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  List<Widget> _buildPageIndicator() {
    List<Widget> list = [];
    for (int i = 0; i < _numPages; i++) {
      list.add(i == _currentPage ? _indicator(true) : _indicator(false));
    }
    return list;
  }

  Widget _indicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(microseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 3.0),
      height: 7.0,
      width: isActive ? 30.0 : 7.0,
      decoration: BoxDecoration(
        color: isActive
            ? notifire.getbluecolor
            : notifire.getbluecolor.withOpacity(0.4),
        borderRadius: const BorderRadius.all(
          Radius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            height: 40,
            width: 40,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.4)),
            ),
            child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
          ),
        ),
        title: DesktopTitleWrapper(child: Text(
          CustomStrings.topupcard,
          style: TextStyle(color: notifire.getdarkscolor),
        )),
        centerTitle: true,
        actions: [
          Container(
              height: 40,
              width: 40,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.4)),
              ),
              child: Image.asset(
                'images/info.png',
                color: notifire.getdarkscolor,
                scale: 4.5,
              )),
        ],
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
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
                Column(
                  children: [
                    SizedBox(
                      height: height / 50,
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: width / 20),
                          child: Text(
                            CustomStrings.selectbank,
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 43,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Container(
                      color: Colors.transparent,
                      height: height / 8,
                      child: ListView.builder(
                        padding: EdgeInsets.only(left: width / 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: img.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  height: height / 9,
                                  width: width / 3,
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: notifire.getbluecolor
                                            .withOpacity(0.4),
                                        blurRadius:
                                            _selectedIndex == index ? 5.0 : 0.0,
                                      ),
                                    ],
                                    color: notifire.gettabwhitecolor,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    border: Border.all(
                                      color: _selectedIndex == index
                                          ? Colors.transparent
                                          : notifire.getbluecolor
                                              .withOpacity(0.1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: height / 50,
                                      ),
                                      Image.asset(
                                        img[index].toString(),
                                        height: height / 25,
                                      ),
                                      SizedBox(
                                        height: height / 100,
                                      ),
                                      Text(
                                        bankname[index],
                                        style: TextStyle(
                                            color: notifire.getdarkscolor,
                                            fontSize: height / 60,
                                            fontFamily: 'Gilroy Bold'),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width / 40,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: height / 40,
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: width / 20),
                          child: Text(
                            CustomStrings.choosenominal,
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 43,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 7,
                        width: width,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          border: Border.all(
                            color: notifire.getbluecolor.withOpacity(0.1),
                          ),
                        ),
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
                                  CustomStrings.enteramount,
                                  style: TextStyle(
                                    color: notifire.getdarkscolor,
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: height / 50,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: width / 20),
                              child: TextFormField(
                                controller: _amountController,
                                style: TextStyle(
                                    color: notifire.getdarkscolor,
                                    fontSize: height / 40),
                                cursorColor: Colors.black,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    hintText: "Rp 1.000",
                                    hintStyle: TextStyle(
                                        fontSize: height / 30,
                                        color: notifire.getdarkgreycolor
                                            .withOpacity(0.4),
                                        fontFamily: 'Gilroy Bold')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 30,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 20,
                        color: Colors.transparent,
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemCount: amount.length,
                          itemBuilder: (context, index) => Padding(
                            padding: EdgeInsets.only(right: width / 30),
                            child: Container(
                              height: height / 20,
                              width: width / 5,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(10),
                                ),
                                color: notifire.getbluecolor.withOpacity(0.3),
                              ),
                              child: Center(
                                child: Text(
                                  amount[index],
                                  style: TextStyle(
                                      color: notifire.getbluecolor,
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: height / 50),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 30,
                    ),
                    Container(
                      color: Colors.transparent,
                      height: height / 5,
                      width: width,
                      child: PageView(
                        physics: const ClampingScrollPhysics(),
                        controller: _pageController,
                        onPageChanged: (int page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Container(
                              height: height / 10,
                              width: width,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                child: Image.asset(
                                  "images/visa1.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Container(
                              height: height / 10,
                              width: width,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                child: Image.asset(
                                  "images/visa2.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Container(
                              height: height / 10,
                              width: width,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                child: Image.asset(
                                  "images/visa3.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Container(
                              height: height / 10,
                              width: width,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                child: Image.asset(
                                  "images/visa1.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height / 40,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildPageIndicator(),
                    ),
                    SizedBox(
                      height: height / 30,
                    ),
                    Container(
                      width: width / 1.6,
                      //alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.circular(20),
                        ),
                      ),

                      child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TopupChannelScreen(),
                              ),
                            );
                          },
                          child: _isLoading
                              ? SizedBox(
                                  height: height / 18,
                                  child: Center(child: CircularProgressIndicator(color: notifire.getbluecolor)),
                                )
                              : scannerbutton(
                                  notifire.getbluecolor,
                                  CustomStrings.topcredit,
                                  Colors.white,
                                )),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget scannerbutton(clr, txt, clr2) {
    return Container(
      height: height / 18,
      width: width / 2,
      decoration: BoxDecoration(
          color: clr,
          borderRadius: const BorderRadius.all(
            Radius.circular(30),
          ),
          border: Border.all(color: notifire.getbluecolor)),
      child: Center(
        child: Text(
          txt,
          style: TextStyle(
              color: clr2, fontSize: height / 55, fontFamily: 'Gilroy Bold'),
        ),
      ),
    );
  }
}
