import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:modipay/home/scanpay/inputpin.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/string.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class Scan extends StatefulWidget {
  const Scan({Key? key}) : super(key: key);

  @override
  State<Scan> createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  // Barcode? result;
  // QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCameraPer();
  }

  getCameraPer() async {
    var camera = await Permission.camera.status;
    var micraphone = await Permission.microphone.status;

    if(camera.isGranted && micraphone.isGranted){
      getCameraCont();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      // controller!.pauseCamera();

    }

    // controller!.resumeCamera();
  }

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

  List imgs = [
    "images/pay1.png",
    "images/pay2.png",
    "images/pay3.png",
    "images/pay4.png",
    "images/pay1.png",
    "images/pay2.png",
  ];
  List names = [
    CustomStrings.rebrcca,
    CustomStrings.tiana,
    CustomStrings.susilo,
    CustomStrings.bambang,
    CustomStrings.rebrcca,
    CustomStrings.tiana,
  ];


  CameraController? cameraController;

  Future<void> getCameraCont() async {
    List<CameraDescription> _camera = await availableCameras();

    cameraController = CameraController(_camera.first, ResolutionPreset.high);
    cameraController?.initialize().then((value) {
      setState(() {});
    },);
  }
  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      // resizeToAvoidBottomInset: false,
      bottomSheet: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              height: height / 3,
              width: width,
              decoration: BoxDecoration(
                color: notifire.getprimerycolor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  topLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: height / 100,
                  ),
                  Container(
                    height: height / 120,
                    width: width / 4,
                    decoration: BoxDecoration(
                      color: notifire.getdarkgreycolor,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: height / 50,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width / 18),
                    child: Container(
                      color: Colors.transparent,
                      height: height / 15,
                      child: TextField(
                        autofocus: false,
                        style: TextStyle(
                          fontSize: height / 50,
                          color: notifire.getdarkscolor,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: notifire.getprimerydarkcolor,
                          hintText: CustomStrings.enternumberorname,
                          hintStyle: TextStyle(
                              color: notifire.getdarkgreycolor,
                              fontSize: height / 60),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: notifire.getbluecolor),
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
                  ),
                  SizedBox(
                    height: height / 60,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width / 20),
                    child: Row(
                      children: [
                        Text(
                          CustomStrings.payandsend,
                          style: TextStyle(
                              fontSize: height / 50,
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold'),
                        ),
                        const Spacer(),
                        Container(
                          height: height / 25,
                          width: width / 2.7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: notifire.getbluecolor),
                          ),
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: width / 60),
                            child: Row(
                              children: [
                                Text(
                                  CustomStrings.searchcontact,
                                  style: TextStyle(
                                      color: notifire.getbluecolor,
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: height / 60),
                                ),
                                const Spacer(),
                                Image.asset(
                                  "images/useradd.png",
                                  height: height / 50,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: height / 50,
                  ),
                  Container(
                    height: height / 10,
                    color: Colors.transparent,
                    child: ListView.builder(
                      itemCount: imgs.length,
                      padding: EdgeInsets.only(left: width / 20),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) => Row(
                        children: [
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                      ),
                                    ),
                                    backgroundColor: notifire.getprimerycolor,
                                    context: context,
                                    builder: (context) {
                                      return Column(
                                        children: [
                                          SizedBox(
                                            height: height / 80,
                                          ),
                                          Container(
                                            height: height / 80,
                                            width: width / 4,
                                            decoration: BoxDecoration(
                                              color: notifire.getdarkgreycolor,
                                              borderRadius:
                                                  const BorderRadius.all(
                                                Radius.circular(20),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: height / 50,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: width / 20),
                                            child: Row(
                                              children: [
                                                Image.asset(
                                                  "images/mcdonalds.png",
                                                  height: height / 15,
                                                ),
                                                SizedBox(
                                                  width: width / 25,
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      CustomStrings.mcdonald,
                                                      style: TextStyle(
                                                          color: notifire
                                                              .getdarkscolor,
                                                          fontFamily:
                                                              'Gilroy Bold',
                                                          fontSize:
                                                              height / 45),
                                                    ),
                                                    Text(
                                                      CustomStrings.losangel,
                                                      style: TextStyle(
                                                          color: Colors.grey,
                                                          fontFamily:
                                                              'Gilroy Medium',
                                                          fontSize:
                                                              height / 55),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: height / 40,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: width / 20),
                                            child: Container(
                                              height: height / 7,
                                              width: width,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(12),
                                                ),
                                                border: Border.all(
                                                  color: Colors.grey
                                                      .withOpacity(0.4),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    height: height / 80,
                                                  ),
                                                  Row(
                                                    children: [
                                                      SizedBox(
                                                        width: width / 20,
                                                      ),
                                                      Text(
                                                        CustomStrings
                                                            .enteramount,
                                                        style: TextStyle(
                                                            fontFamily:
                                                                'Gilroy Bold',
                                                            color: notifire
                                                                .getdarkscolor,
                                                            fontSize:
                                                                height / 50),
                                                      ),
                                                    ],
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                        left: width / 20),
                                                    child: Container(
                                                      width: width / 2,
                                                      color: Colors.transparent,
                                                      child: TextFormField(
                                                        textAlign:
                                                            TextAlign.start,
                                                        style: TextStyle(
                                                            color: notifire
                                                                .getdarkscolor,
                                                            fontSize:
                                                                height / 30,
                                                            fontFamily:
                                                                'Gilroy Bold'),
                                                        cursorColor:
                                                            Colors.black,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        decoration: InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            focusedBorder:
                                                                InputBorder
                                                                    .none,
                                                            enabledBorder:
                                                                InputBorder
                                                                    .none,
                                                            errorBorder:
                                                                InputBorder
                                                                    .none,
                                                            disabledBorder:
                                                                InputBorder
                                                                    .none,
                                                            hintText:
                                                                "Rp 36.000",
                                                            hintStyle: TextStyle(
                                                                fontSize:
                                                                    height / 30,
                                                                color: notifire
                                                                    .getdarkgreycolor
                                                                    .withOpacity(
                                                                        0.4),
                                                                fontFamily:
                                                                    'Gilroy Bold')),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: height / 5,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: width / 20),
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const InputPin(),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                height: height / 15,
                                                width: width,
                                                decoration: BoxDecoration(
                                                  color: notifire.getbluecolor,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                    Radius.circular(30),
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    CustomStrings.confirm,
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Gilroy Bold',
                                                        fontSize: height / 50),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Image.asset(
                                  imgs[index],
                                  height: height / 15,
                                ),
                              ),
                              SizedBox(
                                height: height / 100,
                              ),
                              Text(
                                names[index],
                                style: TextStyle(
                                    fontFamily: 'Gilroy Medium',
                                    color: notifire.getdarkscolor,
                                    fontSize: height / 70),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: width / 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: Column(
        children: <Widget>[
          Expanded(
              flex: 3,
              child: Stack(
                children: [
                  _buildQrView(context),
                  Column(
                    children: [
                      SizedBox(
                        height: height / 20,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: width / 20,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: height / 1.65,
                      ),
                    ],
                  )
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return Container(
      child: cameraController == null ? SizedBox() : CameraPreview(cameraController!),
    );
  }
  //
  // void _onQRViewCreated(QRViewController controller) {
  //   setState(() {
  //     this.controller = controller;
  //   });
  //   controller.scannedDataStream.listen((scanData) {
  //     setState(() {
  //       result = scanData;
  //     });
  //   });
  // }
  //
  // void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
  //   log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
  //   if (!p) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('no Permission')),
  //     );
  //   }
  // }

  @override
  void dispose() {
    // controller?.dispose();
    super.dispose();
  }
}
