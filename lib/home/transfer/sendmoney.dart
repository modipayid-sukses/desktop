import 'package:flutter/material.dart';
import 'package:gobank/home/transfer/sendall.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';

class SendMoney extends StatefulWidget {
  const SendMoney({Key? key}) : super(key: key);

  @override
  State<SendMoney> createState() => _SendMoneyState();
}

class _SendMoneyState extends State<SendMoney>
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
    const SendAll(),
    const SendAll(),
    const SendAll(),
    const SendAll(),
  ];

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Kirim uang',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy Bold',
            color: notifire.getdarkscolor,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 40,
              width: 40,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withOpacity(0.4)),
              ),
              child: Icon(Icons.add, color: notifire.getdarkscolor),
            ),
          ),
        ],
        backgroundColor: notifire.getprimerycolor,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            height: 40,
            width: 40,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withOpacity(0.4)),
            ),
            child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
          ),
        ),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Stack(
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
                      height: height / 40,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        color: Colors.transparent,
                        width: width,
                        height: height / 15,
                        child: TextField(
                          autofocus: false,
                          style: TextStyle(
                            fontSize: height / 50,
                            color: notifire.getdarkscolor,
                          ),
                          decoration: InputDecoration(
                            hintText: "Cari kontak..",
                            filled: true,
                            fillColor: notifire.getprimerydarkcolor,
                            hintStyle: TextStyle(
                                color: Colors.grey, fontSize: height / 60),
                            prefixIcon: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: width / 50,
                                  vertical: height / 60),
                              child: Image.asset(
                                "images/search.png",
                                color: notifire.getdarkgreycolor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: notifire.getbluecolor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xffd3d3d3),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 1.2,
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
                                  labelStyle: const TextStyle(
                                      fontFamily: 'Gilroy Bold'),
                                  indicator: BoxDecoration(
                                      color: notifire.gettabwhitecolor,
                                      borderRadius: BorderRadius.circular(10)),
                                  indicatorColor: notifire.getbluecolor,
                                  controller: controller,
                                  labelColor: notifire.getdarkscolor,
                                  unselectedLabelColor: Colors.grey,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  tabs: const [
                                    Tab(text: CustomStrings.all),
                                    Tab(text: CustomStrings.favorite),
                                    Tab(text: CustomStrings.bank),
                                    Tab(text: CustomStrings.ewallet),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
