import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/snackbar.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:image_picker/image_picker.dart';

class ClaimArtistProfile extends StatefulWidget {
  const ClaimArtistProfile({Key key}) : super(key: key);

  @override
  _ClaimArtistProfileState createState() => _ClaimArtistProfileState();
}

class _ClaimArtistProfileState extends State<ClaimArtistProfile> {

  int artistId = Hive.box("settings").get('artistId', defaultValue: 0);
  int userId = Hive.box("settings").get('userID', defaultValue: 0);

  String token = Hive.box("settings").get("token");
  Map<String, String> headers = {};
  Map artist;
  bool loading = true;
  String _selectedAffiliation;
  List _affiliationsList = [
    'Artist/Band Member',
    'Manager',
    'Label',
    'Other'
  ];
  File _selectedFile;
  TextEditingController _nameController, _phoneController, _emailController, _messageController, _youtubeController, _facebookController;
  var dio = Dio();

  pickImageModal(BuildContext context) async {
    var image = await ImagePicker().pickImage(source: ImageSource.gallery);
    setState(() {
      _selectedFile = File(image.path);
    });
  }

  @override
  void initState() {
    super.initState();
    main();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _messageController = TextEditingController();
    _youtubeController = TextEditingController();
    _facebookController = TextEditingController();

    dio.options.baseUrl = 'https://ilhewl.com/api';
    dio.interceptors.add(LogInterceptor());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    super.dispose();
  }

  void main() async {
    EasyLoading.show(status: "Loading...");
    if(userId != null){
      Map user = await Api().fetchUserData(userId);
      if(user['artist_id'] != 0){
        if(artistId == 0){
          Hive.box('settings').put('artistId', user['artist_id']);
        }
        ShowSnackBar().showSnackBar(context, 'Your Request already accepted!');
      }
      _nameController = TextEditingController(text: user["name"]);
      _phoneController = TextEditingController(text: user["phone"]);
      _emailController = TextEditingController(text: user["email"]);
      setState(() {});
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
      'message': _messageController.text,
      'youtube': _youtubeController.text,
      'facebook': _facebookController.text,
      'affiliation': _selectedAffiliation,
      'artwork': _selectedFile != null ? await MultipartFile.fromFile(_selectedFile.path, filename: 'artwork.jpg') : null,
    });
  }

  Future _requestProfile() async {

    headers = {"Accept": "application/json", 'Authorization': 'Bearer $token'};

    EasyLoading.show(status: "Sending...");
    Response response;

    try{
      response = await dio.post(
        '/artist/claim_profile',
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
    print(response.data);
    if(response.statusCode == 200 && response.data['success']){

      Hive.box('cache').put('requestId', response.data["requestId"]);

      EasyLoading.dismiss();
      EasyLoading.showSuccess("Success!");
    }else{
      EasyLoading.showError(response.data['message']);
    }

    EasyLoading.dismiss();
  }

  Widget _buildField(String text, TextEditingController controller, TextInputType type, icon, maxLine, bool _obscure, bool _textInputNext){
    return Padding(
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

  @override
  Widget build(BuildContext context) {
    AppConfig().init(context);
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: CustomScrollView(physics: BouncingScrollPhysics(), slivers: [
        SliverAppBar(
          elevation: 0,
          stretch: true,
          pinned: true,
          backgroundColor: Theme.of(context).accentColor,
          expandedHeight: MediaQuery.of(context).size.height / 3.5,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            stretchModes: [StretchMode.zoomBackground],
            background: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: Center(
                child: Text(
                  "Connect with your fans on ilhewl",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppConfig.screenWidth * .09,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate(
            [
              _buildField("Your Full Name", _nameController, TextInputType.name, Icons.person, 1, false, true),
              SizedBox(height: 20,),
              _buildField("Phone Number", _phoneController, TextInputType.phone, Icons.phone, 1, false, true),
              SizedBox(height: 20,),
              _buildField("Your Email", _emailController, TextInputType.emailAddress, Icons.email, 1, false, true),
              SizedBox(height: 20,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Stack(
                    children: [
                      Container(
                          padding: EdgeInsets.only(top: 5, bottom: 5, left: 60, right: 10),
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
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              value: _selectedAffiliation,
                              isExpanded: true,
                              items: _affiliationsList.map((value) {
                                return DropdownMenuItem(
                                  value: value,
                                  child: Text(value, style: TextStyle(color: MyTheme().isDark ? Colors.white : Colors.black),),
                                );
                              }).toList(),
                              hint:Text(
                                "Affiliation to Artist",
                                style: TextStyle(
                                    color: MyTheme().isDark ? Colors.white : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _selectedAffiliation = val;
                                });
                              },
                            ),
                          )
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 15.0, left: 20.0),
                        child: Icon(
                          Icons.music_note_outlined,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                    ]),
              ),
              SizedBox(height: 20,),
              _buildField("Explain your relationship to the artist and provide a band link", _messageController, TextInputType.multiline, Icons.text_fields, 4, false, true),
              SizedBox(height: 10,),
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("SpeedUp the verification by uploading your Passport/NNI"),
              ),
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
                                width: AppConfig.screenWidth - 20,
                                height: AppConfig.screenWidth * .4,
                                decoration: BoxDecoration(
                                  color: const Color(0xff7c94b6),
                                  image: DecorationImage(
                                    image: _selectedFile != null
                                        ? FileImage(File(_selectedFile.path))
                                        : artist != null && artist['artwork_url'] != null
                                        ? NetworkImage(artist['artwork_url'])
                                        : AssetImage("assets/artist.png"),
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                              ),
                            ),

                            _selectedFile != null ? Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    _selectedFile = null;
                                  });
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
                                      Icons.delete_forever,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ) : Align(
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
              SizedBox(height: 20,),
              _buildField("Facebook Profile", _facebookController, TextInputType.text, Icons.facebook, 1, false, true),
              SizedBox(height: 20,),
              _buildField("Youtube Channel", _youtubeController, TextInputType.text, Icons.youtube_searched_for, 1, false, false),
              SizedBox(height: 20,),
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
                    child: TextButton(
                      child: Text("Send Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
                      onPressed: () {
                        _requestProfile();
                      },
                    )
                ),
              ),
              SizedBox(height: 50,)
            ],
          ),
        ),
      ]),
    );
  }
}