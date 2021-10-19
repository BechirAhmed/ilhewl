import 'dart:async';
import 'dart:ui';
import 'package:ilhewl/APIs/api.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:otp_text_field/style.dart';
import 'package:package_info/package_info.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String appVersion;
  Map deviceInfo = {};
  bool phoneCheck = true;
  bool showOtpField = false;
  bool otpChecked = false;
  bool otpStatus = false;
  bool _otpFocus = false;
  final _formKey = GlobalKey<FormState>();

  // final dbRef = FirebaseDatabase.instance.reference().child("Users");
  TextEditingController nameController, emailController, phoneController, passwordController, otpController;

  String _completePhone;
  String _otpCode;
  String _inputOtp;

  double imgSize = AppConfig.screenWidth / 2;

  // ignore: close_sinks
  StreamController<ErrorAnimationType> errorController;

  bool hasError = false;
  String currentText = "";

  @override
  void initState() {
    main();
    errorController = StreamController<ErrorAnimationType>();
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    errorController.close();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }



  void main() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    DeviceInfoPlugin info = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await info.androidInfo;
    appVersion = packageInfo.version;
    deviceInfo.addAll({
      'Brand': androidInfo.brand,
      'Manufacturer': androidInfo.manufacturer,
      'Device': androidInfo.device,
      'isPhysicalDevice': androidInfo.isPhysicalDevice,
      'Fingerprint': androidInfo.fingerprint,
      'Model': androidInfo.model,
      'Build': androidInfo.display,
      'Product': androidInfo.product,
      'androidVersion': androidInfo.version.release,
      'supportedAbis': androidInfo.supportedAbis,
    });
    setState(() {});
  }

  Future _checkPhone(String phone) async {
    EasyLoading.show(status: "Loading...");

    var res = await Api().authData('check-phone?phone=$phone');
    print(res);
    if(!res['success'] && res['status'] == "phone_exist"){
      EasyLoading.dismiss();
      EasyLoading.showError("Phone Number Exist! Please login instead.");
    }else if(res['success'] && res['status'] == "continue"){
      EasyLoading.showToast("Please insert the otp code sent to you!", toastPosition: EasyLoadingToastPosition.top);
      EasyLoading.dismiss();
      setState(() {
        _otpCode = res["otp_code"].toString();
        showOtpField = true;
        _otpFocus = true;
      });
    }

    EasyLoading.dismiss();
  }

  Future _resendOtp(String phone) async {
    EasyLoading.show(status: "Loading...");

    var res = await Api().authData('check-phone?phone=$phone');
    print(res);
    if(!res['success'] && res['status'] == "phone_exist"){
      EasyLoading.dismiss();
      EasyLoading.showError("Phone Number Exist! Please login instead.");
    }else if(res['success'] && res['status'] == "continue"){
      EasyLoading.showToast("Please insert the otp code sent to you!", toastPosition: EasyLoadingToastPosition.top);
      EasyLoading.dismiss();
      setState(() {
        _otpCode = res["otp_code"].toString();
        showOtpField = true;
      });
    }

    EasyLoading.dismiss();
  }

  Future _verifyOtp(String otp) async {
    EasyLoading.show(status: "Loading...");

    if(otp == _otpCode){
      EasyLoading.dismiss();
      EasyLoading.showSuccess("OTP Verified! Complete your registration.");
      setState(() {
        phoneCheck = false;
        otpChecked = true;
        otpStatus = true;
        imgSize = AppConfig.screenWidth / 4;
      });
    }else{
      setState(() {
        otpStatus = false;
        otpChecked = true;
      });
      EasyLoading.showError("OTP is not correct!");
    }

    EasyLoading.dismiss();
  }

  Future _addUserData(String name, String phone, String email, String password) async {
    EasyLoading.show(status: "Loading...");

    if(_inputOtp == null || _inputOtp == '' || _inputOtp != _otpCode){
      EasyLoading.showError("OTP is not correct, check if you have changed it.");
      return;
    }


    Map user = await Api().authData('signup?'
        'name='+name
        +'&phone='+phone
        +'&email='+email
        +'&password='+password
    );
    // print(user);
    if(user != null){
      Hive.box('settings').put('userID', user["user"]["id"]);
      Hive.box('settings').put('name', user["user"]["name"]);
      Hive.box('settings').put('phone', user["user"]["phone"]);
      Hive.box('settings').put('token', user['access_token']);
      Hive.box('settings').put('artistId', user['artist_id']);
      Hive.box('settings').put('artwork_url', user["user"]['artwork_url']);
      Hive.box('settings').put('currency', user['currency']);
      EasyLoading.dismiss();
      Navigator.popAndPushNamed(context, '/');
      EasyLoading.showSuccess("Success!");
    }else{
      EasyLoading.showError("Error!");
    }

    EasyLoading.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    AppConfig().init(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus.unfocus(),
      child: GradientContainer(
        child: Stack(
          children: [
            Positioned(
              left: MediaQuery.of(context).size.width / 2,
              top: MediaQuery.of(context).size.width / 2,
              child: Image(
                width: AppConfig.screenWidth,
                image: AssetImage(
                  'assets/icon.png',
                ),
              ),
            ),
            GradientContainer(
              child: null,
              opacity: true,
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SingleChildScrollView(
                padding: EdgeInsets.only(left: 15.0, right: 15.0, top: AppConfig.safeAreaVertical),
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        "Register",
                        style: TextStyle(
                          fontSize: AppConfig.screenWidth * .08
                        ),
                      ),
                    ),
                    SizedBox(height: 40,),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: Image(
                        image: AssetImage('assets/logo.png'),
                        width: imgSize,
                        height: imgSize,
                      ),
                    ),
                    SizedBox(height: 40,),
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                              padding: EdgeInsets.only(top: 5, bottom: 5, left: 10, right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Theme.of(context).cardColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5.0,
                                    spreadRadius: 0.0,
                                    offset: Offset(0.0, 3.0),
                                  )
                                ],
                              ),
                              child: IntlPhoneField(
                                showCountryFlag: false,
                                showDropdownIcon: false,
                                autofocus: true,
                                controller: phoneController,
                                textAlignVertical: TextAlignVertical.top,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        width: 1.5, color: Colors.transparent),
                                  ),
                                  border: InputBorder.none,
                                  hintText: "Phone Number",
                                  hintStyle: TextStyle(
                                    color: Colors.white60,
                                  ),
                                  counterText: "",
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.refresh),
                                    onPressed: () {
                                      _resendOtp(_completePhone);
                                    },
                                  )
                                ),
                                initialCountryCode: 'MR',
                                onChanged: (phone) {
                                  setState(() {
                                    _completePhone = phone.completeNumber;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 20,),
                          showOtpField ? Column(
                            children: [
                              Text(
                                "Enter the code sent to $_completePhone",
                                style: TextStyle(
                                  color: Colors.white
                                ),
                              ),
                              SizedBox(height: 10,),
                              Padding(
                                padding: const EdgeInsets.only(left: 10, right: 10),
                                child: Container(
                                  padding: EdgeInsets.only(top: 5, bottom: 0, left: 10, right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    color: Theme.of(context).cardColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 5.0,
                                        spreadRadius: 0.0,
                                        offset: Offset(0.0, 3.0),
                                      )
                                    ],
                                  ),
                                  child: PinCodeTextField(
                                    appContext: context,
                                    autoFocus: _otpFocus,
                                    enablePinAutofill: true,
                                    pastedTextStyle: TextStyle(
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    length: 4,
                                    obscureText: false,
                                    obscuringCharacter: '*',
                                    blinkWhenObscuring: true,
                                    // obscuringWidget: Image.asset("assets/logo.png", width: 24, height: 24,),
                                    animationType: AnimationType.fade,
                                    pinTheme: PinTheme(
                                      shape: PinCodeFieldShape.underline,
                                      fieldHeight: 40,
                                      fieldWidth: 40,
                                      activeFillColor: Colors.white,
                                    ),
                                    cursorColor: Colors.black,
                                    animationDuration: Duration(milliseconds: 300),
                                    enableActiveFill: false,
                                    errorAnimationController: errorController,
                                    controller: otpController,
                                    keyboardType: TextInputType.number,
                                    boxShadows: [
                                      BoxShadow(
                                        offset: Offset(0, 1),
                                        color: Colors.white60,
                                        blurRadius: 10,
                                      )
                                    ],
                                    onCompleted: (pin) {
                                      _verifyOtp(pin);
                                      setState(() {
                                        _inputOtp = pin;
                                      });
                                    },
                                    // onTap: () {
                                    //   print("Pressed");
                                    // },
                                    onChanged: (value) {
                                      print(value);
                                      setState(() {
                                        currentText = value;
                                      });
                                    },
                                    beforeTextPaste: (text) {
                                      print("Allowing to paste $text");
                                      //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
                                      //but you can show anything you want here, like your pop up saying wrong paste format or etc
                                      return true;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ) : SizedBox(),
                          SizedBox(height: 20,),
                          phoneCheck ? SizedBox() : Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                              padding: EdgeInsets.only(
                                  top: 5, bottom: 5, left: 10, right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Theme.of(context).cardColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5.0,
                                    spreadRadius: 0.0,
                                    offset: Offset(0.0, 3.0),
                                  )
                                ],
                              ),
                              child: TextField(
                                  controller: nameController,
                                  textAlignVertical: TextAlignVertical.center,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.name,
                                  decoration: InputDecoration(
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          width: 1.5, color: Colors.transparent),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person,
                                      color: Theme.of(context).accentColor,
                                    ),
                                    border: InputBorder.none,
                                    hintText: "Your Name",
                                    hintStyle: TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  // onSubmitted: (String value) {
                                  //   if (value == '') {
                                  //     Hive.box('settings').put('name', 'Guest');
                                  //     _addUserData('Guest', gender);
                                  //   } else {
                                  //     Hive.box('settings').put('name', value.trim());
                                  //     _addUserData(value, gender);
                                  //   }
                                  //   Navigator.popAndPushNamed(context, '/');
                                  // }
                                  ),
                            ),
                          ),
                          phoneCheck ? SizedBox() : SizedBox(height: 20,),
                          phoneCheck ? SizedBox() : Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                              padding: EdgeInsets.only(
                                  top: 5, bottom: 5, left: 10, right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Theme.of(context).cardColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5.0,
                                    spreadRadius: 0.0,
                                    offset: Offset(0.0, 3.0),
                                  )
                                ],
                              ),
                              child: TextField(
                                  controller: emailController,
                                  textAlignVertical: TextAlignVertical.center,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          width: 1.5, color: Colors.transparent),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.phone_iphone,
                                      color: Theme.of(context).accentColor,
                                    ),
                                    border: InputBorder.none,
                                    hintText: "Email Address",
                                    hintStyle: TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  // onSubmitted: (String value) {
                                  //   if (value == '') {
                                  //     Hive.box('settings').put('phone', 'Guest');
                                  //     _addUserData('Guest', gender);
                                  //   } else {
                                  //     Hive.box('settings').put('phone', value.trim());
                                  //     _addUserData(value, gender);
                                  //   }
                                  //   Navigator.popAndPushNamed(context, '/');
                                  // }
                                ),
                            ),
                          ),
                          phoneCheck ? SizedBox() : SizedBox(height: 20,),
                          phoneCheck ? SizedBox() : Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                              padding: EdgeInsets.only(
                                  top: 5, bottom: 5, left: 10, right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Theme.of(context).cardColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5.0,
                                    spreadRadius: 0.0,
                                    offset: Offset(0.0, 3.0),
                                  )
                                ],
                              ),
                              child: TextField(
                                  controller: passwordController,
                                  textAlignVertical: TextAlignVertical.center,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.name,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          width: 1.5, color: Colors.transparent),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.vpn_key,
                                      color: Theme.of(context).accentColor,
                                    ),
                                    border: InputBorder.none,
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  // onSubmitted: (String value) {
                                  //   if (value == '') {
                                  //     Hive.box('settings').put('phone', 'Guest');
                                  //     _addUserData('Guest', gender);
                                  //   } else {
                                  //     Hive.box('settings').put('phone', value.trim());
                                  //     _addUserData(value, gender);
                                  //   }
                                  //   Navigator.popAndPushNamed(context, '/');
                                  // }
                                ),
                            ),
                          ),
                          phoneCheck ? SizedBox() : SizedBox(height: 20,),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                              padding: EdgeInsets.only(top: 5, bottom: 5, left: 10, right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Theme.of(context).accentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5.0,
                                    spreadRadius: 0.0,
                                    offset: Offset(0.0, 3.0),
                                  )
                                ],
                              ),
                              child: TextButton(
                                child: Text(
                                  !phoneCheck ? "Register" : "Get OTP",
                                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),),
                                onPressed: () {
                                  if(showOtpField) {
                                    if (otpChecked && !phoneCheck && otpStatus) {
                                      _addUserData(
                                          nameController.text,
                                          _completePhone,
                                          emailController.text,
                                          passwordController.text);
                                    }
                                  }else {
                                    _checkPhone(_completePhone);
                                  }
                                },
                              )
                            ),
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
      ),
    );
  }
}
