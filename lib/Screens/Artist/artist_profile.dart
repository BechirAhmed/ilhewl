import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ArtistProfile extends StatefulWidget {
  const ArtistProfile({Key key}) : super(key: key);

  @override
  _ArtistProfileState createState() => _ArtistProfileState();
}

class _ArtistProfileState extends State<ArtistProfile> {

  TextEditingController _nameController, _phoneController, _emailController, _oldPasswordController, _newPasswordController, _bioController, _genderController, _birthdateController, _soundCloudController, _instagramController, youtubeController, _facebookController, _twitterController, _websiteController, _otpController;

  Map user;
  bool loading = true;
  bool showOtpField = false;
  bool otpChecked = false;
  String _birthText;
  String _otpCode;
  String _inputOtp;
  bool hasError = false;
  String currentText = "";
  File _selectedFile;
  String token = Hive.box("settings").get("token");
  Map<String, String> headers = {};

  final _date = DateTime.now();
  DateTime _initialBirth;

  var dio = Dio();

  final _formKey = GlobalKey<FormState>();

  StreamController<ErrorAnimationType> errorController;

  @override
  void initState() {
    _initialBirth = DateTime(_date.year - 14, _date.month, _date.day);
    main();
    errorController = StreamController<ErrorAnimationType>();
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();

    dio.options.baseUrl = 'https://ilhewl.com/api';
    dio.interceptors.add(LogInterceptor());
  }

  @override
  void dispose() {
    errorController.close();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void main() async {
    EasyLoading.show(status: "Loading...");
    final userId = await Hive.box('settings').get('userID');
    if(userId != null){
      user = await Api().fetchUserData(userId);
      _nameController = TextEditingController(text: user["name"]);
      _phoneController = TextEditingController(text: user["phone"]);
      _emailController = TextEditingController(text: user["email"]);
      _bioController = TextEditingController(text: user["bio"]);
      _birthdateController = TextEditingController(text: user["birth"]);
      _birthText = user["birth"];
      _initialBirth = user["birth"] != null ? DateTime.parse(user["birth"]) : _initialBirth;
      setState(() {

      });
    }

    loading = false;
    EasyLoading.dismiss();
    setState(() {});
  }

  Future<FormData> FormData1() async {
    return FormData.fromMap({
      'name': _nameController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'bio': _bioController.text,
      'birth': _birthText,
      'password': _oldPasswordController.text,
      'new_password': _newPasswordController.text,
      'artwork': _selectedFile != null ? await MultipartFile.fromFile(_selectedFile.path, filename: 'artwork.jpg') : null,
    });
  }

  Future _updateUserData(String name, String phone, String email, String bio, String _birth, String _pass, String _newPass) async {
    if(phone == null || name == null){
      EasyLoading.showError("Fields Required!");
      return;
    }

    headers = {"Accept": "application/json", 'Authorization': 'Bearer $token'};

    EasyLoading.show(status: "Sending...");
    Response response;

    try{
      response = await dio.post(
        '/auth/user/profile',
        data: await FormData1(),
        options: Options(headers: headers),
        onSendProgress: (received, total) {
          if (total != -1) {
            // EasyLoading.showProgress(received / total * 100);
            // print((received / total * 100).toStringAsFixed(0) + '%');
          }
        },
      );

    }catch(e){
      print(e);
    }

    EasyLoading.dismiss();

    if(response.statusCode == 200 && response.data['success']){
      Hive.box('settings').delete('name');
      Hive.box('settings').delete('phone');

      Hive.box('settings').put('name', response.data["user"]["name"]);
      Hive.box('settings').put('phone', response.data["user"]["phone"]);

      EasyLoading.dismiss();
      Navigator.of(context).pop();
      EasyLoading.showSuccess("Success!");
    }else{
      EasyLoading.showError(response.data['message']);
    }

    EasyLoading.dismiss();
  }

  Future _checkOtp(String phone) async {
    EasyLoading.show(status: "Loading...");

    var res = await Api().authData('check-phone?phone=$phone');

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

  Future _verifyOtp(String otp, String phone) async {
    EasyLoading.show(status: "Loading...");

    if(otp == _otpCode){

      var res = await Api().authData('check-phone?phone=$phone');

      EasyLoading.dismiss();
      EasyLoading.showSuccess("OTP Verified! Complete your registration.");
      setState(() {
        otpChecked = true;
      });
    }else{
      setState(() {
        otpChecked = true;
      });
      EasyLoading.showError("OTP is not correct!");
    }

    EasyLoading.dismiss();
  }

  Widget _buildField(String text, TextEditingController controller, TextInputType type, icon, maxLine, bool _obscure, bool _textInputNext){
    return Padding(
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
          controller: controller,
          textAlignVertical: TextAlignVertical.center,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: type,
          maxLines: maxLine,
          obscureText: _obscure,
          textInputAction: _textInputNext ? TextInputAction.next : TextInputAction.done,
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  width: 1.5, color: Colors.transparent),
            ),
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).accentColor,
            ),
            border: InputBorder.none,
            hintText: "$text",
            hintStyle: TextStyle(
              color: MyTheme().isDark ? Colors.white60 : Colors.black38,
            ),
          ),
        ),
      ),
    );
  }

  void _showIOS_DatePicker(ctx) {
    showCupertinoModalPopup(
        context: ctx,
        builder: (_) => Container(
          height: AppConfig.screenHeight / 3,
          color: Color.fromARGB(255, 255, 255, 255),
          child: Column(
            children: [
              Container(
                height: AppConfig.screenHeight / 3,
                child: CupertinoDatePicker(
                    initialDateTime: _initialBirth,
                    maximumYear: DateTime.now().year - 13,
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (val) {
                      setState(() {
                        _birthText = DateFormat("yyyy-MM-dd").format(val).toString();
                        _birthdateController = TextEditingController(text: val.toString());
                      });
                    }),
              ),
            ],
          ),
        ));
  }


  pickImageModal(BuildContext context) async {
    var image = await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      _selectedFile = File(image.path);
    });
  }


  @override
  Widget build(BuildContext context) {
    AppConfig().init(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(color: MyTheme().isDark ? Colors.white60 : Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: MyTheme().isDark ? Colors.white60 : Colors.black87, //change your color here
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              pickImageModal(context);
                            },
                            child: Container(
                              width: AppConfig.screenWidth * .4,
                              height: AppConfig.screenWidth * .4,
                              decoration: BoxDecoration(
                                color: const Color(0xff7c94b6),
                                image: DecorationImage(
                                  image: _selectedFile != null
                                      ? FileImage(File(_selectedFile.path))
                                      : user != null && user['artwork_url'] != null
                                      ? NetworkImage(user['artwork_url'])
                                      : AssetImage("assets/artist.png"),
                                  fit: BoxFit.cover,
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppConfig.screenWidth * .2),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () async {
                                pickImageModal(context);
                              },
                              child: Container(
                                height: 25,
                                width: 25,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  heightFactor: 25,
                                  widthFactor: 25,
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.0),
                    ],
                  ),
                ),
              ],
            ),
            _buildField("Your Name", _nameController, TextInputType.name, Icons.person, 1, false, true),
            SizedBox(height: 20,),
            _buildField("Phone Number", _phoneController, TextInputType.phone, Icons.phone_iphone, 1, false, true),
            SizedBox(height: 20,),
            _buildField("Your Email", _emailController, TextInputType.emailAddress, Icons.email_outlined, 1, false, true),
            SizedBox(height: 20,),
            _buildField("Your Bio", _bioController, TextInputType.multiline, Icons.text_fields, 4, false, true),
            SizedBox(height: 20,),
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10),
              child: Container(
                  padding: EdgeInsets.only(top: 3, bottom: 3, left: 10, right: 10),
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
                  child: ListTile(
                    leading: Icon(
                      Icons.date_range,
                      color: Theme.of(context).accentColor,
                    ),
                    title: Text(_birthText == null ? "Birthdate" : _birthText, style: TextStyle(color: MyTheme().isDark ? Colors.white : Colors.black),),
                    onTap: () {
                      _showIOS_DatePicker(context);
                    },
                  )
              ),
            ),
            SizedBox(height: 20,),
            _buildField("Password", _oldPasswordController, TextInputType.visiblePassword, Icons.vpn_key, 1, true, false),
            SizedBox(height: 20,),
            Center(
              child: Text(
                  "Enter new password only if you want to change the old one!"
              ),
            ),
            SizedBox(height: 20,),
            _buildField("New Password", _newPasswordController, TextInputType.visiblePassword, Icons.vpn_key_outlined, 1, true, false),
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
                    child: Text("Update", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),),
                    onPressed: () {
                      if(_formKey.currentState.validate()){
                        _updateUserData(_nameController.text, _phoneController.text, _emailController.text, _bioController.text, _birthText, _oldPasswordController.text, _newPasswordController.text);
                      }
                    },
                  )
              ),
            ),
          ],
        ),
      ),
    );
  }

  // snackBar Widget
  snackBar(String message) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
