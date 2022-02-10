

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/snackbar.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:ilhewl/Screens/Artist/NewAlbum.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:multi_select_flutter/chip_field/multi_select_chip_field.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class EditSongModal extends StatefulWidget {
  final List albums;
  final int artistId;
  final int userId;
  final int songId;
  const EditSongModal({Key key, @required this.artistId, @required this.songId, @required this.albums, @required this.userId}) : super(key: key);

  @override
  _EditSongModalState createState() => _EditSongModalState();
}

class _EditSongModalState extends State<EditSongModal> {

  final artistId = Hive.box("settings").get("artistId");
  final userId = Hive.box("settings").get("userID");
  String token = Hive.box("settings").get("token");
  Map<String, String> headers = {};

  final _chipKey = GlobalKey<FormFieldState>();

  Map editedSong;
  bool loadCompleted = false;

  List _moodsList = [];
  List _albumsList = [];
  List _genresList = [];

  int _selectedAlbum;
  File _selectedImage;

  bool _visibility = true;
  bool _free = false;
  TextEditingController _songTitleController;
  TextEditingController _descriptionController;
  TextEditingController _lyricsController;
  TextEditingController _copyrightController;

  List _selectedGenres;
  List _initialGenres;
  List _selectedMoods;
  String _releaseDate;
  DateTime _date = DateTime.now();
  DateTime _initialDate;
  DateTime _maxDate;

  var dio = Dio();

  @override
  void initState() {
    super.initState();
    _dataLoad();

    _initialDate = DateTime(_date.year, _date.month, _date.day - 1);
    _maxDate = DateTime(_date.year, _date.month + 3, _date.day);
    _songTitleController = TextEditingController();
    _descriptionController = TextEditingController();
    _copyrightController = TextEditingController();
    _lyricsController = TextEditingController();

    _initialDate = DateTime(_date.year, _date.month, _date.day - 1);
    // _releaseDate = widget.song['release_date'];
    _maxDate = DateTime(_date.year, _date.month + 3, _date.day);

    _albumsList = widget.albums;

    dio.options.baseUrl = 'https://ilhewl.com/api';
    dio.interceptors.add(LogInterceptor());
  }


  @override
  void dispose() {
    _songTitleController.dispose();
    _descriptionController.dispose();
    _copyrightController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<Null> _dataLoad() async {
    try {
      // EasyLoading.show(status: "Loading...");
      var data = await Api().fetchHomePageData();
      var res = await Api().getResponse('song/${widget.songId}');

      List _lists = data["genres"];
      List _items = data["moods"];

      _genresList = _lists.map((e) => MultiSelectItem(e['id'], e["name"])).toList();
      _moodsList = _items.map((e) => MultiSelectItem(e['id'], e["name"])).toList();

      editedSong = json.decode(res.body);

      if(editedSong != null){
        _songTitleController = TextEditingController(text: editedSong['title']);
        _descriptionController = TextEditingController(text: editedSong['description']);
        _copyrightController = TextEditingController(text: editedSong['copyright']);
        _lyricsController = TextEditingController(text: editedSong['lyrics']);

        _visibility = editedSong['visibility'] == 0 ? false : true;
        _free = editedSong['selling'] == 0 ? true : false;
        _selectedAlbum = editedSong['album'] != null ? editedSong['album']['id'] : null;
        _releaseDate = editedSong['released_at'];
        _initialDate = DateTime.parse(editedSong['released_at']);

        // _selectedGenres = editedSong['genres'];
        // _selectedMoods = editedSong['moods'];

        _initialGenres = editedSong['genres'];

        loadCompleted = true;
      }else{
        loadCompleted = false;
        Navigator.of(context).pop();
        EasyLoading.showError("Error Loading data!");
      }
        // print(editedSong);


      setState(() {});

      // EasyLoading.dismiss();
    } catch (err) {
      ShowSnackBar().showSnackBar(context, "Error loading data");
    } finally {
      //_refreshIndicatorKey.currentState.hide();
    }
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

  Future<FormData> FormData1() async {
    return FormData.fromMap({
      'id': widget.songId,
      'title': _songTitleController.text,
      'description': _descriptionController.text,
      'album_id': _selectedAlbum,
      'genre': _selectedGenres != null ? _selectedGenres.join(",") : null,
      'mood': _selectedMoods != null ? _selectedMoods.join(",") : null,
      'released_at': _releaseDate,
      'copyright': _copyrightController.text,
      'user_id': userId,
      'visibility': _visibility,
      'free': _free,
      'artwork': _selectedImage != null ? await MultipartFile.fromFile(_selectedImage.path, filename: 'artwork.jpg') : null,
    });
  }

  Future _updateSongData() async {
    if (_songTitleController.text == null || widget.songId == null || _releaseDate == null) {
      EasyLoading.showError("You missed something, check all required infos!");
      return;
    }
    headers = {"Accept": "application/json", 'Authorization': 'Bearer $token'};

    EasyLoading.show(status: "Loading...");
    Response response;

    try{
      response = await dio.post(
        '/song/update/${widget.songId}',
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
    if(response.statusCode == 200){
      EasyLoading.showSuccess("Success!");
      EasyLoading.dismiss();
      Navigator.of(context).pop();
      // Navigator.push(
      //     context,
      //     MaterialPageRoute(builder: (context) => ArtistSongs()));
    }else{
      EasyLoading.showError("Failed! Try again");
      EasyLoading.dismiss();
    }

  }

  pickImageModal(BuildContext context) async {
    var image = await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      _selectedImage = File(image.path);
    });
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
          middle: Text('Edit Song'),
          trailing: TextButton(
            child: Text("Save"),
            onPressed: () {
              _updateSongData();
            },
          ),
        ),
        child:
        !loadCompleted
            ? Container(
          child: Center(
            child: Container(
                height: MediaQuery.of(context).size.width / 7,
                width: MediaQuery.of(context).size.width / 7,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).accentColor),
                  strokeWidth: 5,
                )),
          ),
        ) :
        SafeArea(
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
                                        image: _selectedImage != null
                                            ? FileImage(File(_selectedImage.path))
                                            : editedSong != null && editedSong['artwork_url'] != null
                                            ? NetworkImage(editedSong['artwork_url'])
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
                                        heightFactor: 24,
                                        widthFactor: 24,
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
                      controller: _songTitleController,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              width: 1.5, color: Colors.transparent),
                        ),
                        border: InputBorder.none,
                        hintText: "Title",
                        // hintStyle: TextStyle(
                        //   color: Colors.white60,
                        // ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Album", false),
                  SizedBox(height: 5,),
                  Container(
                      width: AppConfig.screenWidth,
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton(
                          value: _selectedAlbum,
                          isExpanded: true,
                          items: _albumsList.map((value) {
                            return DropdownMenuItem(
                              value: value['id'],
                              child: Text(value['title'], style: TextStyle(color: MyTheme().isDark ? Colors.white : Colors.black),),
                            );
                          }).toList(),
                          hint:Text(
                            "Please choose an album",
                            style: TextStyle(
                                color: MyTheme().isDark ? Colors.white : Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedAlbum = val;
                            });
                          },
                        ),
                      )
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Description", true),
                  SizedBox(height: 5,),
                  Container(
                    width: AppConfig.screenWidth,
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
                      maxLines: 6,
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              width: 1.5, color: Colors.transparent),
                        ),
                        border: InputBorder.none,
                        hintText: "Description",
                        // hintStyle: TextStyle(
                        //   color: Colors.white60,
                        // ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Lyrics", false),
                  SizedBox(height: 5,),
                  Container(
                    width: AppConfig.screenWidth,
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
                      controller: _lyricsController,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: 10,
                      decoration: InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              width: 1.5, color: Colors.transparent),
                        ),
                        border: InputBorder.none,
                        hintText: "Lyrics Snippets",
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
                        title: Text(_releaseDate == null ? "Release Date" : _releaseDate, style: TextStyle(color: MyTheme().isDark ? Colors.white : Colors.black),),
                        onTap: () {
                          _showIOS_DatePicker(context);
                        },
                      )
                  ),
                  SizedBox(height: 20.0,),
                  _customLabel("Genres", true),
                  SizedBox(height: 5,),
                  _genresList != null && _genresList.isNotEmpty ? MultiSelectChipField(
                    items: _genresList,
                    key: _chipKey,
                    title: Text("Genres"),
                    icon: Icon(Icons.check, color: Theme.of(context).accentColor, size: 5.0,),
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10)
                    ),
                    textStyle: TextStyle(
                        color: MyTheme().isDark ? Colors.white : Colors.black
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
                  _moodsList != null && _moodsList.isNotEmpty ? MultiSelectChipField(
                    items: _moodsList,
                    title: Text("Moods"),
                    icon: Icon(Icons.check, color: Theme.of(context).accentColor, size: 5.0,),
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10)
                    ),
                    textStyle: TextStyle(
                        color: MyTheme().isDark ? Colors.white : Colors.black
                    ),
                    chipColor: Colors.white38,
                    showHeader: false,
                    onTap: (values) {
                      setState(() {
                        _selectedMoods = values;
                      });
                    },
                  ) : SizedBox(),
                  SizedBox(height: 20,),
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
                        hintText: "Copyright",
                        // hintStyle: TextStyle(
                        //   color: Colors.white60,
                        // ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20,),
                  _customLabel("Ready to be Published", false),
                  SizedBox(height: 5,),
                  Checkbox(
                    value: _visibility,
                    onChanged: (value) {
                      setState(() {
                        _visibility = value;
                      });
                    },
                  ),
                  SizedBox(height: 20,),
                  _customLabel("Free", false),
                  SizedBox(height: 5,),
                  Checkbox(
                    value: _free,
                    onChanged: (value) {
                      setState(() {
                        _free = value;
                      });
                    },
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
            color: MyTheme().isDark ? Colors.white : Colors.black
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