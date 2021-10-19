

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:multi_select_flutter/chip_field/multi_select_chip_field.dart';

class ModalWithScroll extends StatefulWidget {
  final List genres;
  final List moods;
  final int artistId;
  final int userId;
  const ModalWithScroll({Key key, @required this.artistId, @required this.userId, @required this.genres, @required this.moods}) : super(key: key);

  @override
  _ModalWithScrollState createState() => _ModalWithScrollState();
}

class _ModalWithScrollState extends State<ModalWithScroll> {

  TextEditingController _nameController;
  TextEditingController _descriptionController;
  TextEditingController _copyrightController;

  List _selectedGenres;
  List _selectedMoods;
  String _releaseDate;
  DateTime _date = DateTime.now();
  DateTime _initialDate;
  DateTime _maxDate;

  File _selectedFile;
  String _fileSize = "0 KB";
  double _progressValue = 0;
  int _progressPercentValue = 0;
  bool _fileUploaded = false;

  var dio = Dio();

  @override
  void initState() {
    super.initState();
    _initialDate = DateTime(_date.year, _date.month, _date.day - 1);
    _maxDate = DateTime(_date.year, _date.month + 3, _date.day);
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _copyrightController = TextEditingController();


    dio.options.baseUrl = 'https://ilhewl.com/api';
    dio.interceptors.add(LogInterceptor());
    // dio.interceptors.add(
    //   InterceptorsWrapper(
    //     onError: (error, handler) {
    //       log(jsonEncode(error));
    //       handler.reject(error); // Added this line to let error propagate outside the interceptor
    //     },
    //   ),
    // );

  }


  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _copyrightController.dispose();
    super.dispose();
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
                    initialDateTime: _initialDate,
                    maximumDate: _maxDate,
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (val) {
                      setState(() {
                        _releaseDate = DateFormat("yyyy-MM-dd").format(val).toString();
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

  Future<FormData> FormData1(String name, String description, String _release, String _copy) async {
    return FormData.fromMap({
      'title': name,
      'description': description,
      'genre': _selectedGenres.join(","),
      'mood': _selectedMoods.join(","),
      'released_at': _release,
      'copyright': _copy,
      'artistIds': widget.artistId,
      'user_id': widget.userId,
      'artwork': await MultipartFile.fromFile(_selectedFile.path, filename: 'artwork.png'),
    });
  }

  Future _saveAlbumData(String name, String description, String _release, String _copy) async {
    if (widget.artistId == null || name == null || _selectedFile == null) {
      EasyLoading.showError("Fields Required!");
      return;
    }

    Response response;

    EasyLoading.show(status: "Sending...");

    response = await dio.post(
      '/album',
      data: await FormData1(name, description, _release, _copy),
      onSendProgress: (received, total) {
        if (total != -1) {
          print((received / total * 100).toStringAsFixed(0) + '%');
        }
      },
    );

    EasyLoading.dismiss();
    if(response.statusCode == 200){
      EasyLoading.showSuccess("Success!");
      EasyLoading.dismiss();
      Navigator.of(context).pop();
    }else{
      EasyLoading.showError("Failed! Try again");
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppConfig().init(context);

    return Material(
      color: Colors.white70,
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          leading: TextButton(
            child: Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          middle: Text('New Album'),
          trailing: TextButton(
            child: Text("Save"),
            onPressed: () {
              _saveAlbumData(_nameController.text, _descriptionController.text, _releaseDate, _copyrightController.text);
            },
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.all(10.0),
            child: ListView(
                shrinkWrap: true,
                controller: ModalScrollController.of(context),
                children: [
                  _customLabel("Image", true),
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
                                            : AssetImage("assets/album.png"),
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(10),
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
                  _customLabel("Title", true),
                  SizedBox(height: 5,),
                  Container(
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
                      controller: _nameController,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              width: 1.5, color: Colors.transparent),
                        ),
                        border: InputBorder.none,
                        hintText: "Album Title",
                        // hintStyle: TextStyle(
                        //   color: Colors.white60,
                        // ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Description", false),
                  SizedBox(height: 5,),
                  Container(
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
                      controller: _descriptionController,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              width: 1.5, color: Colors.transparent),
                        ),
                        border: InputBorder.none,
                        hintText: "Album Description..",
                        // hintStyle: TextStyle(
                        //   color: Colors.white60,
                        // ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Release Date", true),
                  SizedBox(height: 5,),
                  Container(
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
                        // leading: Icon(
                        //   Icons.date_range,
                        //   color: Theme.of(context).accentColor,
                        // ),
                        title: Text(_releaseDate == null ? "Release Date" : _releaseDate, style: TextStyle(color: MyTheme().isDark ? Colors.white70 : Colors.black87),),
                        onTap: () {
                          _showIOS_DatePicker(context);
                        },
                      )
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Genres", true),
                  SizedBox(height: 5,),
                  widget.genres != null && widget.genres.isNotEmpty ? MultiSelectChipField(
                    items: widget.genres,
                    title: Text("Genres"),
                    icon: Icon(Icons.check, color: Theme.of(context).accentColor, size: 5.0,),
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10)
                    ),
                    textStyle: TextStyle(
                        color: MyTheme().isDark ? Colors.white : Colors.black87
                    ),
                    chipColor: Colors.white38,
                    showHeader: false,
                    onTap: (values) {
                      setState(() {
                        _selectedGenres = values;
                      });
                    },
                  ) : SizedBox(),
                  SizedBox(height: 20.0,),
                  _customLabel("Moods", true),
                  SizedBox(height: 5,),
                  widget.moods != null && widget.moods.isNotEmpty ? MultiSelectChipField(
                    items: widget.moods,
                    title: Text("Moods"),
                    icon: Icon(Icons.check, color: Theme.of(context).accentColor, size: 5.0,),
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10)
                    ),
                    textStyle: TextStyle(
                        color: MyTheme().isDark ? Colors.white : Colors.black87
                    ),
                    chipColor: Colors.white38,
                    showHeader: false,
                    onTap: (values) {
                      setState(() {
                        _selectedMoods = values;
                      });
                    },
                  ) : SizedBox(),
                  SizedBox(height: 20.0,),
                  _customLabel("Copyright", false),
                  SizedBox(height: 5,),
                  Container(
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
                      controller: _copyrightController,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              width: 1.5, color: Colors.transparent),
                        ),
                        border: InputBorder.none,
                        hintText: "Album Copyright, default is ILHEWL",
                        // hintStyle: TextStyle(
                        //   color: Colors.white60,
                        // ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0,),
                ]
            ),
          ),
        ),
      ),
    );
  }

  Widget _customLabel(String labelText, bool isRequired) {
    return RichText(
      text: TextSpan(
          text: '$labelText',
          style: TextStyle(
            fontSize: AppConfig.screenWidth * .035,
            color: MyTheme().isDark ? Colors.white : Colors.black87
          ),
          children: [
            isRequired ?
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
                fontSize: AppConfig.screenWidth * .04,
              ),

            ) : TextSpan()
          ]),
    );
  }
}