import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/string.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colornotifire.dart';
import '../utils/itextfield.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({Key? key}) : super(key: key);

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  late ColorNotifire notifire;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureText = true;
  bool _obscureText2 = true;
  bool _obscureText3 = true;
  bool _isSaving = false;

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  void _toggle2() {
    setState(() {
      _obscureText2 = !_obscureText2;
    });
  }

  void _toggle3() {
    setState(() {
      _obscureText3 = !_obscureText3;
    });
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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(msg: 'Passwords do not match');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      Fluttertoast.showToast(msg: 'Password must be at least 6 characters');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
        _confirmPasswordController.text,
      );
      if (result['message']?.toString().contains('successfully') == true) {
        Fluttertoast.showToast(msg: 'Kata sandi berhasil diubah');
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Gagal mengubah kata sandi');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Kesalahan jaringan');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        centerTitle: true,
        title: DesktopTitleWrapper(child: Text(
          CustomStrings.createnewpassword,
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
          ),
        ))
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
                  height: height / 50,
                ),
                Text(
                  CustomStrings.accessaccount,
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 60,
                  ),
                ),
                SizedBox(
                  height: height / 40,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width / 20,
                    ),
                    Text(
                      "Current Password",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Customtextfild2.textField(
                      _obscureText3,
                      "Current Password",
                      Colors.grey,
                      notifire.getdarkscolor,
                      "images/password.png",
                      GestureDetector(
                          onTap: () {
                            _toggle3();
                          },
                          child: _obscureText3
                              ? Image.asset(
                                  "images/eye.png",
                                  height: height / 60,
                                )
                              : const Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.grey,
                                )),
                      notifire.getbluecolor,
                      notifire.getdarkwhitecolor,
                      controller: _currentPasswordController),
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
                      CustomStrings.newpassword,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Customtextfild2.textField(
                      _obscureText,
                      "New Password",
                      Colors.grey,
                      notifire.getdarkscolor,
                      "images/password.png",
                      GestureDetector(
                          onTap: () {
                            _toggle();
                          },
                          child: _obscureText
                              ? Image.asset(
                                  "images/eye.png",
                                  height: height / 60,
                                )
                              : const Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.grey,
                                )),
                      notifire.getbluecolor,
                      notifire.getdarkwhitecolor,
                      controller: _newPasswordController),
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
                      CustomStrings.confirmnewpassword,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: height / 50,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Customtextfild2.textField(
                      _obscureText2,
                      "Confirm Password",
                      Colors.grey,
                      notifire.getdarkscolor,
                      "images/password.png",
                      GestureDetector(
                        onTap: () {
                          _toggle2();
                        },
                        child: _obscureText2
                            ? Image.asset(
                                "images/eye.png",
                                height: height / 60,
                              )
                            : const Icon(
                                Icons.remove_red_eye,
                                color: Colors.grey,
                              ),
                      ),
                      notifire.getbluecolor,
                      notifire.getdarkwhitecolor,
                      controller: _confirmPasswordController),
                ),
                SizedBox(
                  height: height / 4,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: GestureDetector(
                    onTap: _isSaving ? null : _changePassword,
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
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                CustomStrings.createpasswords,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy Medium',
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
      ),
    );
  }
}
