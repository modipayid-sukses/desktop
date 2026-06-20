import 'package:accordion/accordion.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';
import '../utils/responsive.dart';

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
      appBar: isDesktopPopup(context) ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: DesktopLeadingWrapper(
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1D1D1D)),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1D1D1D)),
        title: DesktopTitleWrapper(child: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontFamily: 'Gilroy Bold',
            fontSize: 17,
          ),
        ))
      ),
      backgroundColor: const Color(0xFFF3F6FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            serarchtextField(
              Colors.black,
              notifire.getdarkgreycolor,
              notifire.getbluecolor,
              CustomStrings.search,
            ),
            const SizedBox(height: 16),
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
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Accordion(
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
    return SizedBox(
      height: 48,
      child: TextField(
        autofocus: false,
        style: TextStyle(
          fontSize: height / 50,
          color: textclr,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hinttext,
          prefixIcon: Icon(
            Icons.search,
            color: notifire.getdarkscolor,
          ),
          hintStyle: TextStyle(color: hintclr, fontSize: height / 60),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(20),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(20),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
