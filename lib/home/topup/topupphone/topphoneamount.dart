import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/colornotifire.dart';
import '../../../utils/media.dart';
import '../../../utils/string.dart';
import '../topup_channel_screen.dart';

class TopPhoneAmount extends StatefulWidget {
  final String contactName;
  final String contactPhone;

  const TopPhoneAmount({
    Key? key,
    required this.contactName,
    required this.contactPhone,
  }) : super(key: key);

  @override
  State<TopPhoneAmount> createState() => _TopPhoneAmountState();
}

class _TopPhoneAmountState extends State<TopPhoneAmount> {
  late ColorNotifire notifire;
  bool _isLoading = false;

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  final List<Map> _myjson = [
    {
      'id': '1',
      'image': 'images/visa1.png',
      'Text': "258 250 4649",
    },
    {
      'id': '2',
      'image': 'images/visa2.png',
      'Text': "258 250 4649",
    },
    {
      'id': '3',
      'image': 'images/visa3.png',
      'Text': "258 250 4649",
    },
  ];
  String? _selectedindex;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getdarkmodepreviousstate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
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
                      height: height / 20,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Icon(
                              Icons.arrow_back,
                              color: notifire.getdarkscolor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CustomStrings.topphone,
                            style: TextStyle(
                                color: notifire.getdarkscolor,
                                fontSize: height / 40,
                                fontFamily: 'Gilroy Bold'),
                          ),
                          const Spacer(),
                          Image.asset(
                            "images/info.png",
                            height: height / 25,
                            color: notifire.getdarkscolor,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: width / 20,
                        ),
                        Text(
                          CustomStrings.from,
                          style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 45),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: width / 20,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: notifire.gettabwhitecolor,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                          height: height / 8,
                          width: width / 1.12,
                          child: DropdownButtonHideUnderline(
                            child: ButtonTheme(
                              buttonColor: notifire.getdarkscolor,
                              child: DropdownButton<String>(
                                dropdownColor: notifire.getprimerydarkcolor,
                                icon: Padding(
                                  padding: EdgeInsets.only(right: width / 30),
                                  child: Image.asset(
                                    "images/arrow-down.png",
                                    scale: 4,
                                    color: notifire.getdarkgreycolor
                                        .withOpacity(0.4),
                                  ),
                                ),
                                hint: Container(
                                  height: height / 7,
                                  width: width / 1.3,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    color: notifire.gettabwhitecolor,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: width / 50,
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: height / 300),
                                        child: Image.asset("images/visa1.png"),
                                      ),
                                      SizedBox(
                                        width: width / 40,
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: height / 400,
                                          ),
                                          Text(
                                            CustomStrings.citibankvisacard,
                                            style: TextStyle(
                                                color: notifire.getdarkscolor,
                                                fontSize: height / 50,
                                                fontFamily: 'Gilroy Bold'),
                                          ),
                                          SizedBox(
                                            height: height / 1000,
                                          ),
                                          Text(
                                            "258 250 4649",
                                            style: TextStyle(
                                                color:
                                                    notifire.getdarkgreycolor,
                                                fontSize: height / 60,
                                                fontFamily: 'Gilroy Medium'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                value: _selectedindex,
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedindex = newValue;
                                  });
                                },
                                items: _myjson.map(
                                  (Map map) {
                                    return DropdownMenuItem<String>(
                                      value: map["id"].toString(),
                                      child: Row(
                                        children: <Widget>[
                                          SizedBox(
                                            width: width / 40,
                                          ),
                                          Image.asset(
                                            map["image"].toString(),
                                            height: 40,
                                          ),
                                          SizedBox(
                                            width: width / 40,
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                height: height / 400,
                                              ),
                                              Text(
                                                CustomStrings.citibankvisacard,
                                                style: TextStyle(
                                                    color:
                                                        notifire.getdarkscolor,
                                                    fontSize: height / 50,
                                                    fontFamily: 'Gilroy Bold'),
                                              ),
                                              SizedBox(
                                                height: height / 800,
                                              ),
                                              Text(
                                                map["Text"].toString(),
                                                style: TextStyle(
                                                    color: notifire
                                                        .getdarkgreycolor,
                                                    fontSize: height / 60,
                                                    fontFamily:
                                                        'Gilroy Medium'),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            width: width / 50,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                            ),
                          ),
                        ),

                        // Container(
                        //   width: Get.width,
                        //   height: Get.height * 0.11,
                        //   decoration: BoxDecoration(
                        //       color: Colors.red,
                        //       borderRadius:
                        //           BorderRadius.all(Radius.circular(8))),
                        //   child: DropdownButton<String>(
                        //     focusColor: Colors.white,
                        //     //elevation: 5,
                        //     style: TextStyle(color: Colors.white),
                        //     iconEnabledColor: Colors.black,
                        //     items: <String>[
                        //       'Android',
                        //       'IOS',
                        //       'Flutter',
                        //       'Node',
                        //       'Java',
                        //       'Python',
                        //       'PHP',
                        //     ].map<DropdownMenuItem<String>>((String value) {
                        //       return DropdownMenuItem<String>(
                        //         value: value,
                        //         child: Text(
                        //           value,
                        //           style: TextStyle(color: Colors.black),
                        //         ),
                        //       );
                        //     }).toList(),
                        //     hint: Text(
                        //       "Please choose a langauage",
                        //       style: TextStyle(
                        //           color: Colors.black,
                        //           fontSize: 14,
                        //           fontWeight: FontWeight.w500),
                        //     ),
                        //   ),
                        // ),
                        SizedBox(
                          width: width / 20,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: width / 20,
                        ),
                        Text(
                          CustomStrings.to,
                          style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 45),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 12,
                        width: width,
                        decoration: BoxDecoration(
                          color: notifire.gettabwhitecolor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: width / 60,
                            ),
                            Container(
                              height: height / 16,
                              width: width / 7,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                "images/contact3.png",
                              ),
                            ),
                            SizedBox(
                              width: width / 60,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: height / 60,
                                ),
                                Text(
                                  widget.contactName,
                                  style: TextStyle(
                                      color: notifire.getdarkscolor,
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: height / 50),
                                ),
                                SizedBox(
                                  height: height / 200,
                                ),
                                Text(
                                  widget.contactPhone,
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: height / 60),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Image.asset(
                              "images/delete.png",
                              height: height / 20,
                            ),
                            SizedBox(
                              width: width / 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: width / 20,
                        ),
                        Text(
                          CustomStrings.amount,
                          style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 45),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: TextFormField(
                        controller: _amountController,
                        style: TextStyle(
                            color: notifire.getdarkscolor,
                            fontSize: height / 45),
                        cursorColor: Colors.black,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          hintText: "Amount",
                          hintStyle: TextStyle(
                              fontSize: height / 50,
                              color: notifire.getdarkgreycolor.withOpacity(0.4),
                              fontFamily: 'Gilroy Bold'),
                        ),
                      ),
                    ),
                    // Divider(thickness: 1,color: notifire.getdarkgreycolor.withOpacity(0.4),),
                    SizedBox(
                      height: height / 2.7,
                    ),
                    Container(
                      width: width / 1.6,
                      alignment: Alignment.center,
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
                              ),
                      ),

                      // child: SlideAction(
                      //   borderRadius: 24,
                      //   onSubmit: () async {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //         builder: (context) => const ConfirmPayment(),
                      //       ),
                      //     );
                      //   },
                      //   height: height / 15,
                      //   sliderButtonIconPadding: 8,
                      //   sliderButtonIcon: Image.asset(
                      //     "images/arrow.png",
                      //     height: height / 30,
                      //     color: notifire.getbluecolor,
                      //   ),
                      //   text: "Swipe for Top Up",
                      //   textStyle: TextStyle(
                      //       color: notifire.getprimerycolor,
                      //       fontFamily: 'Gilroy Bold',
                      //       fontSize: height / 45),
                      //   alignment: Alignment.center,
                      //   outerColor: notifire.getbluecolor,
                      // ),
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
