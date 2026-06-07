import 'package:accordion/accordion.dart';
import 'package:accordion/controllers.dart';
import 'package:flutter/material.dart';
import 'package:modipay/utils/string.dart';
import 'package:provider/provider.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';
import 'complaint_form_screen.dart';
import 'complaint_history_screen.dart';

class HelpSupport extends StatefulWidget {
  final String title;
  const HelpSupport(this.title, {Key? key}) : super(key: key);

  @override
  State<HelpSupport> createState() => _HelpSupportState();
}

class _HelpSupportState extends State<HelpSupport> {
  late ColorNotifire notifire;
  final _loremIpsum =
      "Open the modipay app to get started and follow the\nsteps. modipay doesn't charge a fee to create or\nmaintain your modipay account.";
  final _contentStyle = const TextStyle(
      color: Color(0xff999999), fontSize: 14, fontWeight: FontWeight.normal);

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        title: Text(
          widget.title,
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
          ),
        ),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        child: Stack(
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
                Container(
                  width: width,
                  height: height / 1.3,
                  color: Colors.transparent,
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: width / 20, right: width / 20, top: height / 80),
                    child: Column(
                      children: <Widget>[
                        Container(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              SizedBox(height: height / 50),
                              serarchtextField(
                                Colors.black,
                                notifire.getdarkgreycolor,
                                notifire.getbluecolor,
                                CustomStrings.search,
                              ),
                              SizedBox(height: height / 40),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ComplaintFormScreen(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: notifire.getbluecolor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: notifire.getbluecolor.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.support_agent, color: notifire.getbluecolor, size: 28),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Hubungi CS",
                                              style: TextStyle(
                                                color: notifire.getbluecolor,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Buat Laporan",
                                              style: TextStyle(
                                                color: notifire.getbluecolor.withOpacity(0.7),
                                                fontFamily: 'Gilroy Medium',
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ComplaintHistoryScreen(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: notifire.getdarkwhitecolor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.receipt_long, color: notifire.getdarkscolor, size: 28),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Riwayat Laporan",
                                              style: TextStyle(
                                                color: notifire.getdarkscolor,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Cek Status Tiket",
                                              style: TextStyle(
                                                color: notifire.getdarkscolor.withOpacity(0.6),
                                                fontFamily: 'Gilroy Medium',
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: height / 40),
                              Accordion(
                                disableScrolling: true,
                                flipRightIconIfOpen: true,
                                contentVerticalPadding: 0,
                                scrollIntoViewOfItems:
                                    ScrollIntoViewOfItems.fast,
                                contentBorderColor: Colors.transparent,
                                maxOpenSections: 1,
                                headerBackgroundColorOpened: Colors.black54,
                                headerPadding: const EdgeInsets.symmetric(
                                    vertical: 7, horizontal: 15),
                                children: [
                                  AccordionSection(
                                    sectionClosingHapticFeedback:
                                        SectionHapticFeedback.light,
                                    contentBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    headerBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    header: Text(
                                      'What is modipay?',
                                      style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content:
                                        Text(_loremIpsum, style: _contentStyle),
                                    contentHorizontalPadding: 20,
                                    contentBorderWidth: 1,
                                  ),
                                  AccordionSection(
                                    headerBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    contentBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    header: Text(
                                      'How to use modipay?',
                                      style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content:
                                        Text(_loremIpsum, style: _contentStyle),
                                    contentHorizontalPadding: 20,
                                    contentBorderWidth: 1,
                                  ),
                                  AccordionSection(
                                    headerBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    contentBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    header: Text(
                                      'Can I create my own course?',
                                      style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content:
                                        Text(_loremIpsum, style: _contentStyle),
                                    contentHorizontalPadding: 20,
                                    contentBorderWidth: 1,
                                  ),
                                  AccordionSection(
                                    headerBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    contentBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    header: Text(
                                      'Is modipay free to use?',
                                      style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content:
                                        Text(_loremIpsum, style: _contentStyle),
                                    contentHorizontalPadding: 20,
                                    contentBorderWidth: 1,
                                  ),
                                  AccordionSection(
                                    headerBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    contentBackgroundColor:
                                        notifire.gettabwhitecolor,
                                    header: Text(
                                      'How to make offer on modipay?',
                                      style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content:
                                        Text(_loremIpsum, style: _contentStyle),
                                    contentHorizontalPadding: 20,
                                    contentBorderWidth: 1,
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }

  Widget serarchtextField(
    textclr,
    hintclr,
    borderclr,
    hinttext,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 60),
      child: Container(
        color: Colors.transparent,
        height: height / 17,
        child: TextField(
          autofocus: false,
          style: TextStyle(
            fontSize: height / 50,
            color: textclr,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: notifire.getdarkwhitecolor,
            hintText: hinttext,
            prefixIcon: Icon(
              Icons.search,
              color: notifire.getdarkscolor,
            ),
            hintStyle: TextStyle(color: hintclr, fontSize: height / 60),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderclr),
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
