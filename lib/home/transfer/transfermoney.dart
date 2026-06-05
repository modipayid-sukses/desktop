import 'package:flutter/material.dart';
import 'package:modipay/home/transfer/transferconfirm.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';

class TransferMoney extends StatefulWidget {
  final int contactId;
  final String contactName;
  final String contactPhone;
  final String contactCategory;

  const TransferMoney({
    Key? key,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactCategory,
  }) : super(key: key);

  @override
  State<TransferMoney> createState() => _TransferMoneyState();
}

class _TransferMoneyState extends State<TransferMoney> {
  late ColorNotifire notifire;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
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

  final List<Map> _myjson = [
    {
      'id': '1',
      'image': 'images/dollar.png',
      'Text': "USD",
    },
    {
      'id': '2',
      'image': 'images/dollar.png',
      'Text': "USD",
    },
    {
      'id': '3',
      'image': 'images/dollar.png',
      'Text': "USD",
    },
    {
      'id': '4',
      'image': 'images/dollar.png',
      'Text': "USD",
    },
    {
      'id': '5',
      'image': 'images/dollar.png',
      'Text': "USD",
    }
  ];
  var items = [
    CustomStrings.salary,
  ];

  String dropdownvalue = CustomStrings.salary;
  String? _selectedindex;

  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedTime;

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        title: Text(
          'Transfer Money',
          style: TextStyle(
            fontFamily: 'Gilroy Bold',
            color: notifire.getdarkscolor,
          ),
        ),
        actions: [
          Image.asset(
            "images/fillstar.png",
            scale: 4,
          ),
          const SizedBox(
            width: 10,
          )
        ],
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
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
                      height: height / 80,
                    ),
                    Container(
                      height: height / 10,
                      width: width / 5,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset("images/man4.png"),
                    ),
                    SizedBox(
                      height: height / 60,
                    ),
                    Text(
                      widget.contactName,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 40,
                      ),
                    ),
                    SizedBox(
                      height: height / 200,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.contactCategory.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 50,
                          ),
                        ),
                        SizedBox(
                          width: width / 100,
                        ),
                        Text(
                          "|",
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 50,
                          ),
                        ),
                        SizedBox(
                          width: width / 100,
                        ),
                        Text(
                          widget.contactPhone,
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 50,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    const Divider(
                      thickness: 0.6,
                      color: Colors.grey,
                    ),
                    SizedBox(
                      height: height / 60,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 10,
                        width: width,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: notifire.getbluecolor),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: width / 20,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color:
                                        notifire.getbluecolor.withOpacity(0.4),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(30),
                                    ),
                                  ),
                                  height: height / 20,
                                  child: DropdownButtonHideUnderline(
                                    child: ButtonTheme(
                                      buttonColor: notifire.getdarkscolor,
                                      child: DropdownButton<String>(
                                        dropdownColor: notifire.getprimerycolor,
                                        icon: Padding(
                                          padding: EdgeInsets.only(
                                              right: width / 50),
                                          child: Image.asset(
                                            "images/arrow-down.png",
                                            scale: 4,
                                            color: notifire.getdarkscolor,
                                          ),
                                        ),
                                        hint: Row(
                                          children: [
                                            SizedBox(
                                              width: width / 40,
                                            ),
                                            Image.asset(
                                              "images/dollar.png",
                                              height: height / 28,
                                              color: notifire.getbluecolor,
                                            ),
                                            SizedBox(
                                              width: width / 80,
                                            ),
                                            Text(
                                              "USD",
                                              style: TextStyle(
                                                  color: notifire.getdarkscolor,
                                                  fontFamily: 'Gilroy Bold'),
                                            ),
                                          ],
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
                                                    width: width / 15,
                                                    color:
                                                        notifire.getbluecolor,
                                                  ),
                                                  SizedBox(
                                                    width: width / 80,
                                                  ),
                                                  Text(
                                                    map["Text"].toString(),
                                                    style: TextStyle(
                                                        color: notifire
                                                            .getdarkscolor,
                                                        fontFamily:
                                                            'Gilroy Bold'),
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
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: width / 20),
                              child: Container(
                                width: width / 2.1,
                                color: Colors.transparent,
                                child: TextFormField(
                                  controller: _amountController,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      color: notifire.getdarkscolor,
                                      fontSize: height / 30,
                                      fontFamily: 'Gilroy Bold'),
                                  cursorColor: Colors.black,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      hintText: "Rp 129.500",
                                      hintStyle: TextStyle(
                                          fontSize: height / 30,
                                          color: notifire.getdarkgreycolor
                                              .withOpacity(0.4),
                                          fontFamily: 'Gilroy Bold')),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 60,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    CustomStrings.schedule,
                                    style: TextStyle(
                                        color: notifire.getdarkscolor,
                                        fontSize: height / 50,
                                        fontFamily: 'Gilroy Bold'),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: height / 50,
                              ),
                              Container(
                                height: height / 17,
                                width: width / 2.3,
                                decoration: BoxDecoration(
                                  color: notifire.getprimerydarkcolor,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: width / 40,
                                    ),
                                    Text(
                                      CustomStrings.news,
                                      style: TextStyle(
                                          color: notifire.getdarkgreycolor),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () async {
                                        final DateTime? dateTime =
                                            await showDatePicker(
                                          context: context,
                                          initialDate: selectedDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(3000),
                                        );
                                        if (dateTime != null) {
                                          setState(() {
                                            selectedDate
                                                .toString()
                                                .split(" ")
                                                .first;
                                          });
                                        }
                                      },
                                      child: Icon(Icons.date_range,
                                          color: notifire.getdarkgreycolor,
                                          size: height / 40),
                                    ),
                                    SizedBox(
                                      width: width / 40,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    CustomStrings.schedule,
                                    style: TextStyle(
                                        color: notifire.getdarkscolor,
                                        fontSize: height / 50,
                                        fontFamily: 'Gilroy Bold'),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: height / 50,
                              ),
                              Container(
                                height: height / 17,
                                width: width / 2.3,
                                decoration: BoxDecoration(
                                  color: notifire.getprimerydarkcolor,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: width / 40,
                                    ),
                                    Text(
                                      CustomStrings.news,
                                      style: TextStyle(
                                          color: notifire.getdarkgreycolor),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () async {
                                        final TimeOfDay? time =
                                            await showTimePicker(
                                          context: context,
                                          initialTime:
                                              selectedTime ?? TimeOfDay.now(),
                                          initialEntryMode:
                                              TimePickerEntryMode.dial,
                                        );
                                        setState(() {
                                          selectedTime = time;
                                        });
                                      },
                                      child: Icon(
                                        Icons.alarm,
                                        color: notifire.getdarkgreycolor,
                                        size: height / 40,
                                      ),
                                    ),
                                    SizedBox(
                                      width: width / 40,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Row(
                        children: [
                          Text(
                            CustomStrings.selectcategory,
                            style: TextStyle(
                                color: notifire.getdarkscolor,
                                fontSize: height / 50,
                                fontFamily: 'Gilroy Bold'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 16,
                        width: width,
                        decoration: BoxDecoration(
                          color: notifire.getprimerydarkcolor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.4),
                          ),
                        ),
                        child: DropdownButton(
                          dropdownColor: notifire.getprimerycolor,
                          underline: const SizedBox(),
                          style: TextStyle(color: notifire.getdarkscolor),
                          value: dropdownvalue,
                          icon: Row(
                            children: [
                              SizedBox(
                                width: width / 1.5,
                              ),
                              Image.asset(
                                "images/arrow-down.png",
                                scale: 4,
                                color: notifire.getdarkscolor,
                              ),
                            ],
                          ),
                          items: items.map((String items) {
                            return DropdownMenuItem(
                              value: items,
                              child: Row(
                                children: [
                                  SizedBox(width: width / 50),
                                  Text(
                                    items,
                                    style: TextStyle(fontSize: height / 60),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              dropdownvalue = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Row(
                        children: [
                          Text(
                            CustomStrings.notes,
                            style: TextStyle(
                                color: notifire.getdarkscolor,
                                fontSize: height / 50,
                                fontFamily: 'Gilroy Bold'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        color: Colors.transparent,
                        width: width,
                        height: height / 17,
                        child: TextField(
                          controller: _notesController,
                          autofocus: false,
                          style: TextStyle(
                            fontSize: height / 50,
                            color: notifire.getdarkscolor,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: notifire.getprimerydarkcolor,
                            hintText: "Notes",
                            hintStyle: TextStyle(
                                color: Colors.grey, fontSize: height / 60),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey.withOpacity(0.4),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey.withOpacity(0.4),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 20,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: GestureDetector(
                        onTap: () {
                          _showMyDialog();
                        },
                        child: Container(
                          height: height / 17,
                          width: width,
                          decoration: BoxDecoration(
                            color: notifire.getbluecolor,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(30),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              CustomStrings.continues,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: height / 50),
                            ),
                          ),
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

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(32.0),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: notifire.gettabwhitecolor,
              borderRadius: const BorderRadius.all(
                Radius.circular(20),
              ),
            ),
            height: height / 1.7,
            child: Column(
              children: [
                SizedBox(
                  height: height / 40,
                ),
                Image.asset(
                  "images/totaltransfer.png",
                  height: height / 10,
                ),
                SizedBox(
                  height: height / 40,
                ),
                Text(
                  CustomStrings.totaltransfer,
                  style: TextStyle(
                    color: notifire.getdarkgreycolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 50,
                  ),
                ),
                SizedBox(
                  height: height / 100,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Rp 154.000,",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 35,
                      ),
                    ),
                    Text(
                      "42",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 60,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width / 20,
                    ),
                    Text(
                      CustomStrings.transferdetails,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 60,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Text(
                        CustomStrings.from,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "e-Wallet 3446 4655 5445",
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: height / 80,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Text(
                        CustomStrings.to,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "BCA 2468 3545 4534",
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: height / 80,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Text(
                        CustomStrings.transfer,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Rp 154.420",
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: height / 80,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Text(
                        CustomStrings.adminfee,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: height / 40,
                        width: width / 10,
                        decoration: BoxDecoration(
                          color: notifire.getbluecolor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            CustomStrings.free,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: height / 60,
                                fontFamily: 'Gilroy Medium'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: const Divider(
                    thickness: 0.6,
                    color: Colors.grey,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Text(
                        CustomStrings.totaltransfer,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Rp 154.420",
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: height / 30,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: buttons(notifire.gettabwhitecolor,
                            CustomStrings.cancel, notifire.getdarkscolor),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransferConfirm(
                                receiverId: widget.contactId,
                                amount: double.tryParse(_amountController.text) ?? 0,
                                notes: _notesController.text,
                                receiverName: widget.contactName,
                              ),
                            ),
                          );
                        },
                        child: buttons(notifire.getbluecolor,
                            CustomStrings.confirm, Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buttons(clr, txt, clr2) {
    return Container(
      height: height / 20,
      width: width / 3.5,
      decoration: BoxDecoration(
        color: clr,
        borderRadius: const BorderRadius.all(
          Radius.circular(30),
        ),
      ),
      child: Center(
        child: Text(
          txt,
          style: TextStyle(
              color: clr2, fontSize: height / 60, fontFamily: 'Gilroy Bold'),
        ),
      ),
    );
  }
}
