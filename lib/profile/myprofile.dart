import 'package:cached_network_image/cached_network_image.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/material.dart';
import 'package:modipay/profile/editprofile.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/media.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colornotifire.dart';
import '../utils/profiletextfield.dart';
import '../utils/string.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({Key? key}) : super(key: key);

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
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

  @override
  void initState() {
    super.initState();
    getdarkmodepreviousstate();
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        title: DesktopTitleWrapper(child: Text(
          CustomStrings.myprofile,
          style: TextStyle(
              color: notifire.getdarkscolor,
              fontSize: height / 40,
              fontFamily: 'Gilroy Bold'),
        )),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfile(),
                ),
              );
            },
            child: Image.asset(
              "images/editprofile.png",
              scale: 3.5,
            ),
          ),
          const SizedBox(
            width: 8,
          )
        ],
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
                SizedBox(
                  height: height / 40,
                ),
                Container(
                  height: height / 8,
                  width: width / 4,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: auth.userAvatar != null && auth.userAvatar!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ApiService.avatarUrl(auth.userAvatar),
                            cacheKey: auth.userAvatar,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            errorWidget: (_, __, ___) => Image.asset('images/man4.png', fit: BoxFit.cover),
                          )
                        : Image.asset('images/man4.png', fit: BoxFit.cover),
                  ),
                ),
                SizedBox(
                  height: height / 30,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width / 20,
                    ),
                    Text(
                      CustomStrings.fullnamee,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: height / 50,
                          fontFamily: 'Gilroy Medium'),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Profiletextfilds.textField(
                    notifire.getdarkscolor,
                    notifire.getdarkgreycolor,
                    notifire.getbluecolor,
                    auth.userName.isEmpty ? CustomStrings.fullnames : auth.userName,
                    notifire.getdarkwhitecolor,
                    readOnly: true),
                SizedBox(
                  height: height / 50,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width / 20,
                    ),
                    Text(
                      CustomStrings.email,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: height / 50,
                          fontFamily: 'Gilroy Medium'),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Profiletextfilds.textField(
                    notifire.getdarkscolor,
                    notifire.getdarkgreycolor,
                    notifire.getbluecolor,
                    auth.userEmail.isEmpty ? CustomStrings.email : auth.userEmail,
                    notifire.getdarkwhitecolor,
                    readOnly: true),
                SizedBox(
                  height: height / 50,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width / 20,
                    ),
                    Text(
                      CustomStrings.phonenumber,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: height / 50,
                          fontFamily: 'Gilroy Medium'),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Profiletextfilds.textField(
                    notifire.getdarkscolor,
                    notifire.getdarkgreycolor,
                    notifire.getbluecolor,
                    auth.userPhone.isEmpty ? CustomStrings.phonenumbers : auth.userPhone,
                    notifire.getdarkwhitecolor,
                    readOnly: true),
                SizedBox(
                  height: height / 50,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width / 20,
                    ),
                    Text(
                      CustomStrings.address,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: height / 50,
                          fontFamily: 'Gilroy Medium'),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 18),
                  child: Container(
                    color: Colors.transparent,
                    height: height / 4,
                    child: TextField(
                      controller: TextEditingController(text: auth.userAddress),
                      readOnly: true,
                      maxLines: 3,
                      autofocus: false,
                      style: TextStyle(
                        fontSize: height / 50,
                        color: notifire.getdarkscolor,
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(height / 100),
                        filled: true,
                        fillColor: notifire.getprimerydarkcolor,
                        hintText: CustomStrings.address,
                        hintStyle: TextStyle(
                            color: notifire.getdarkgreycolor,
                            fontSize: height / 60),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: notifire.getbluecolor,
                          ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
