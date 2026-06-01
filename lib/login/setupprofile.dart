import 'package:flutter/material.dart';
import 'package:gobank/verification/indetyfiyverifiy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/button.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';
import '../utils/normaltextfild.dart';
import '../utils/string.dart';

class SetupProfile extends StatefulWidget {
  const SetupProfile({Key? key}) : super(key: key);

  @override
  State<SetupProfile> createState() => _SetupProfileState();
}

class _SetupProfileState extends State<SetupProfile> {
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

  String dropdownvalue = '01';
  String monthvalue = 'Jan';
  String yearvalue = '2018';
  String gendervalue = CustomStrings.male;

  var items = [
    '01',
    '02',
    '03',
    '04',
    '05',
  ];
  var monthitems = [
    'Jan',
    'feb',
    'mar',
    'ape',
    'may',
  ];
  var yearitems = [
    '2018',
    '2019',
    '2020',
    '2021',
    '2022',
  ];
  var genderitems = [
    CustomStrings.male,
    CustomStrings.female,
  ];

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          CustomStrings.setupprofile,
          style: TextStyle(
              color: notifire.getdarkscolor,
              fontSize: height / 40,
              fontFamily: 'Gilroy Bold'),
        ),
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        actions: [
          Center(
            child: Text(
              CustomStrings.skip,
              style: TextStyle(
                  color: notifire.getdarkscolor, fontFamily: 'Gilroy Bold'),
            ),
          ),
          const SizedBox(
            width: 10,
          )
        ],
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
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
                      height: height / 12,
                    ),
                    Stack(
                      children: [
                        Center(
                          child: Container(
                            height: height / 1.25,
                            width: width / 1.1,
                            decoration: BoxDecoration(
                              color: notifire.gettabwhitecolor,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(40),
                                topLeft: Radius.circular(40),
                              ),
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: height / 8.5),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: width / 18,
                                    ),
                                    Text(
                                      CustomStrings.personalinformations,
                                      style: TextStyle(
                                          color: notifire.getdarkscolor,
                                          fontSize: height / 45,
                                          fontFamily: 'Gilroy Bold'),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height / 40),
                                Container(
                                  height: height / 2,
                                  width: width / 1.25,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(height: height / 70),
                                      Row(
                                        children: [
                                          SizedBox(width: width / 20),
                                          Text(
                                            CustomStrings.fullnamee,
                                            style: TextStyle(
                                                color: notifire.getdarkscolor,
                                                fontSize: height / 50,
                                                fontFamily: 'Gilroy Bold'),
                                          )
                                        ],
                                      ),
                                      SizedBox(height: height / 80),
                                      NormalCustomtextfilds.textField(
                                          notifire.getdarkscolor,
                                          notifire.getdarkgreycolor,
                                          notifire.getbluecolor,
                                          CustomStrings.antorpaul,
                                          width / 20,
                                          notifire.gettabwhitecolor,
                                          context),
                                      SizedBox(height: height / 60),
                                      Row(
                                        children: [
                                          SizedBox(width: width / 20),
                                          Text(
                                            CustomStrings.contactnumber,
                                            style: TextStyle(
                                                color: notifire.getdarkscolor,
                                                fontSize: height / 50,
                                                fontFamily: 'Gilroy Bold'),
                                          )
                                        ],
                                      ),
                                      SizedBox(height: height / 80),
                                      NormalCustomtextfilds.textField(
                                          notifire.getdarkscolor,
                                          notifire.getdarkgreycolor,
                                          notifire.getbluecolor,
                                          "+1 59405 5946",
                                          width / 20,
                                          notifire.gettabwhitecolor,
                                          context),
                                      SizedBox(height: height / 50),
                                      Row(
                                        children: [
                                          SizedBox(width: width / 20),
                                          Text(
                                            CustomStrings.dateofbirth,
                                            style: TextStyle(
                                                color: notifire.getdarkscolor,
                                                fontSize: height / 50,
                                                fontFamily: 'Gilroy Bold'),
                                          )
                                        ],
                                      ),
                                      SizedBox(height: height / 80),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Container(
                                            height: height / 17,
                                            width: width / 4.5,
                                            decoration: BoxDecoration(
                                              color: notifire.getwhite,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.grey
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: DropdownButton(
                                              dropdownColor:
                                                  notifire.getprimerydarkcolor,
                                              underline: const SizedBox(),
                                              // Initial Value
                                              value: dropdownvalue,

                                              // Down Arrow Icon

                                              icon: Row(
                                                children: [
                                                  SizedBox(width: width / 15),
                                                  Image.asset(
                                                    'images/arrow-down.png',
                                                    color:
                                                        notifire.getdarkscolor,
                                                    scale: 5,
                                                  )
                                                ],
                                              ),

                                              // Array list of items
                                              items: items.map((String items) {
                                                return DropdownMenuItem(
                                                  value: items,
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                          width: width / 50),
                                                      Text(
                                                        items,
                                                        style: TextStyle(
                                                            color: notifire
                                                                .getdarkscolor,
                                                            fontSize:
                                                                height / 60),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              // After selecting the desired option,it will
                                              // change button value to selected value
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  dropdownvalue = newValue!;
                                                });
                                              },
                                            ),
                                          ),
                                          Container(
                                            height: height / 17,
                                            width: width / 4.5,
                                            decoration: BoxDecoration(
                                              color: notifire.getwhite,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.grey
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: DropdownButton(
                                              borderRadius:
                                                  const BorderRadius.all(
                                                      Radius.circular(5)),
                                              dropdownColor:
                                                  notifire.getprimerycolor,
                                              underline: const SizedBox(),
                                              // Initial Value
                                              value: monthvalue,

                                              // Down Arrow Icon
                                              icon: Row(
                                                children: [
                                                  SizedBox(width: width / 15),
                                                  Image.asset(
                                                    'images/arrow-down.png',
                                                    color:
                                                        notifire.getdarkscolor,
                                                    scale: 5,
                                                  )
                                                ],
                                              ),

                                              // Array list of items
                                              items: monthitems
                                                  .map((String monthitems) {
                                                return DropdownMenuItem(
                                                  value: monthitems,
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                          width: width / 50),
                                                      Text(
                                                        monthitems,
                                                        style: TextStyle(
                                                            color: notifire
                                                                .getdarkscolor,
                                                            fontSize:
                                                                height / 60),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              // After selecting the desired option,it will
                                              // change button value to selected value
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  monthvalue = newValue!;
                                                });
                                              },
                                            ),
                                          ),
                                          Container(
                                            height: height / 17,
                                            width: width / 4.5,
                                            decoration: BoxDecoration(
                                              color: notifire.getwhite,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.grey
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: DropdownButton(
                                              dropdownColor:
                                                  notifire.getprimerydarkcolor,
                                              underline: const SizedBox(),
                                              // Initial Value
                                              value: yearvalue,

                                              // Down Arrow Icon
                                              icon: Row(
                                                children: [
                                                  SizedBox(width: width / 20),
                                                  Image.asset(
                                                    'images/arrow-down.png',
                                                    color:
                                                        notifire.getdarkscolor,
                                                    scale: 5,
                                                  )
                                                ],
                                              ),

                                              // Array list of items
                                              items: yearitems
                                                  .map((String yearitems) {
                                                return DropdownMenuItem(
                                                  value: yearitems,
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                          width: width / 50),
                                                      Text(
                                                        yearitems,
                                                        style: TextStyle(
                                                            color: notifire
                                                                .getdarkscolor,
                                                            fontSize:
                                                                height / 60),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  yearvalue = newValue!;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: height / 50),
                                      Row(
                                        children: [
                                          SizedBox(width: width / 20),
                                          Text(
                                            CustomStrings.gender,
                                            style: TextStyle(
                                                color: notifire.getdarkscolor,
                                                fontSize: height / 50,
                                                fontFamily: 'Gilroy Bold'),
                                          )
                                        ],
                                      ),
                                      SizedBox(height: height / 80),
                                      Container(
                                        height: height / 17,
                                        width: width / 1.39,
                                        decoration: BoxDecoration(
                                          color: notifire.getwhite,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.grey.withOpacity(0.3),
                                          ),
                                        ),
                                        child: DropdownButton(
                                          dropdownColor:
                                              notifire.getprimerydarkcolor,
                                          style: TextStyle(
                                              color: notifire.getdarkscolor),
                                          underline: const SizedBox(),
                                          // Initial Value
                                          value: gendervalue,

                                          // Down Arrow Icon
                                          icon: Row(
                                            children: [
                                              SizedBox(width: width / 2),
                                              Image.asset(
                                                'images/arrow-down.png',
                                                scale: 5,
                                                color: notifire.getdarkscolor,
                                              )
                                            ],
                                          ),

                                          // Array list of items
                                          items: genderitems
                                              .map((String genderitems) {
                                            return DropdownMenuItem(
                                              value: genderitems,
                                              child: Row(
                                                children: [
                                                  SizedBox(width: width / 50),
                                                  Text(
                                                    genderitems,
                                                    style: TextStyle(
                                                        fontSize: height / 60),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),

                                          onChanged: (String? newValue) {
                                            setState(() {
                                              gendervalue = newValue!;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: height / 32),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const VerifiyIdenty(),
                                      ),
                                    );
                                  },
                                  child: Custombutton.button(
                                      notifire.getbluecolor,
                                      CustomStrings.continues,
                                      width / 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
                    SizedBox(
                      height: height / 50,
                    ),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            height: height / 6,
                            width: width / 2.5,
                            decoration: BoxDecoration(
                              color: notifire.getbluecolor.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.person,
                                size: height / 9,
                                color: notifire.getbluecolor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: width / 3.5, top: height / 10),
                            child: Image.asset("images/adprofile.png",
                                height: height / 22),
                          )
                        ],
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
