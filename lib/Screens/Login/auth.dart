import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Screens/Login/register.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String appVersion;
  Map deviceInfo = {};
  // final dbRef = FirebaseDatabase.instance.reference().child("Users");
  TextEditingController phoneController, passwordController;
  String _phone;
  final _formKey = GlobalKey<FormState>();

  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  Map<String, dynamic> _deviceData = <String, dynamic>{};

  @override
  void initState() {
    // main();
    super.initState();
    initPlatformState();
    phoneController = TextEditingController();
    passwordController = TextEditingController();
  }

  Future<void> initPlatformState() async {
    var deviceData = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        deviceData = _readAndroidBuildData(await deviceInfoPlugin.androidInfo);
      } else if (Platform.isIOS) {
        deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
      }
    } on PlatformException {
      deviceData = <String, dynamic>{
        'Error:': 'Failed to get platform version.'
      };
    }

    if (!mounted) return;

    setState(() {
      _deviceData = deviceData;
    });
  }

  Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'version.securityPatch': build.version.securityPatch,
      'version.sdkInt': build.version.sdkInt,
      'version.release': build.version.release,
      'version.previewSdkInt': build.version.previewSdkInt,
      'version.incremental': build.version.incremental,
      'version.codename': build.version.codename,
      'version.baseOS': build.version.baseOS,
      'board': build.board,
      'bootloader': build.bootloader,
      'brand': build.brand,
      'device': build.device,
      'display': build.display,
      'fingerprint': build.fingerprint,
      'hardware': build.hardware,
      'host': build.host,
      'id': build.id,
      'manufacturer': build.manufacturer,
      'model': build.model,
      'product': build.product,
      'supported32BitAbis': build.supported32BitAbis,
      'supported64BitAbis': build.supported64BitAbis,
      'supportedAbis': build.supportedAbis,
      'tags': build.tags,
      'type': build.type,
      'isPhysicalDevice': build.isPhysicalDevice,
      'androidId': build.androidId,
      'systemFeatures': build.systemFeatures,
    };
  }

  Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'systemName': data.systemName,
      'systemVersion': data.systemVersion,
      'model': data.model,
      'localizedModel': data.localizedModel,
      'identifierForVendor': data.identifierForVendor,
      'isPhysicalDevice': data.isPhysicalDevice,
      'utsname.sysname:': data.utsname.sysname,
      'utsname.nodename:': data.utsname.nodename,
      'utsname.release:': data.utsname.release,
      'utsname.version:': data.utsname.version,
      'utsname.machine:': data.utsname.machine,
    };
  }

    @override
    void dispose() {
      phoneController.dispose();
      passwordController.dispose();
      super.dispose();
    }
  //
  // void main() async {
  //   PackageInfo packageInfo = await PackageInfo.fromPlatform();
  //   DeviceInfoPlugin info = DeviceInfoPlugin();
  //   AndroidDeviceInfo androidInfo = await info.androidInfo;
  //   appVersion = packageInfo.version;
  //   deviceInfo.addAll({
  //     'Brand': androidInfo.brand,
  //     'Manufacturer': androidInfo.manufacturer,
  //     'Device': androidInfo.device,
  //     'isPhysicalDevice': androidInfo.isPhysicalDevice,
  //     'Fingerprint': androidInfo.fingerprint,
  //     'Model': androidInfo.model,
  //     'Build': androidInfo.display,
  //     'Product': androidInfo.product,
  //     'androidVersion': androidInfo.version.release,
  //     'supportedAbis': androidInfo.supportedAbis,
  //   });
  //   setState(() {});
  // }

  Future _addUserData(String phone, String password) async {
    // print(_deviceData);
    // return;
    if(password == null || password == ''){
      EasyLoading.showError("Password is Required!");
      return;
    }
    EasyLoading.show(status: "Loading...");

    Map user = await Api().registerOrLogin(
        'phone='+phone
        +'&password='+password
        +'&device_id='+_deviceData['identifierForVendor']
        +'&device_name='+_deviceData['name']
    );
    // print(user);
    if(user != null && user["success"]){
      Hive.box('settings').put('userID', user["user"]["id"]);
      Hive.box('settings').put('name', user["user"]["name"]);
      Hive.box('settings').put('phone', user["user"]["phone"]);
      Hive.box('settings').put('token', user['access_token']);
      Hive.box('settings').put('artistId', user["user"]['artist_id']);
      Hive.box('settings').put('artwork_url', user["user"]['artwork_url']);
      Hive.box('settings').put('currency', user['currency']);

      EasyLoading.dismiss();
      Navigator.popAndPushNamed(context, '/');
      EasyLoading.showSuccess("Success!");
      final savedDeviceToken = Hive.box('cache').get('deviceToken');
      if (user['user']["device_id"] != savedDeviceToken) {
        Api().updateDevice(
            data: {
              "device_id": savedDeviceToken,
              "device_type": Platform.isIOS ? "1" : "2"
            }
        );
      }
    }else{
      EasyLoading.showError(user['message'], duration: Duration(seconds: 30), dismissOnTap: true);
    }

    EasyLoading.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    AppConfig().init(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus.unfocus(),
        child: GradientContainer(
          child: Stack(
            children: [
              Positioned(
                left: MediaQuery.of(context).size.width / 2,
                top: MediaQuery.of(context).size.width / 5,
                child: Image(
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: Image(
                          image: AssetImage('assets/logo.png'),
                          width: AppConfig.screenWidth / 2,
                          height: AppConfig.screenWidth / 2,
                        ),
                      ),
                      SizedBox(height: AppConfig.screenHeight * .1,),
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
                                    counterText: "",
                                    border: InputBorder.none,
                                    hintText: "Phone Number",
                                    // hintStyle: TextStyle(
                                    //   color: Colors.white60,
                                    // ),
                                  ),
                                  initialCountryCode: 'MR',
                                  onChanged: (value){
                                    setState(() {
                                      _phone = value.completeNumber;
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 20,),
                            Padding(
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
                                child: TextFormField(
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
                                      // hintStyle: TextStyle(
                                      //   color: Colors.white60,
                                      // ),
                                    ),
                                  ),
                              ),
                            ),
                            SizedBox(height: 20,),
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
                                  child: Text("Login", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),),
                                  onPressed: () {
                                    if(_formKey.currentState.validate()){
                                      _addUserData(_phone, passwordController.text);
                                    }
                                  },
                                )
                              ),
                            ),
                            SizedBox(height: 20,),
                            Padding(
                              padding: const EdgeInsets.only(left: 10, right: 10),
                              child: TextButton(
                                child: Text("Or Register", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => RegisterScreen()));
                                },
                              )
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
      ),
    );
  }
}
