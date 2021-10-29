import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/FabMiniMenu.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/CustomWidgets/snackbar.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/util.dart';
import 'package:ilhewl/Screens/Artist/NewAlbum.dart';
import 'package:ilhewl/Screens/Artist/artistSongs.dart';
import 'package:ilhewl/Services/FileService.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as fileUtil;
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:dio/dio.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class UploadScreen extends StatefulWidget {
  final List albums;
  const UploadScreen({Key key, @required this.albums}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with TickerProviderStateMixin {

  AnimationController _controller;
  final _scaffoldKey = GlobalKey<ScaffoldState>(); // new line
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = new GlobalKey<RefreshIndicatorState>();
  final artistId = Hive.box("settings").get("artistId");
  final userId = Hive.box("settings").get("userID");
  String token = Hive.box("settings").get("token");
  Map<String, String> headers = {};

  List _tagsList = [];
  List _moodsList = [];
  List _albumsList = [];
  List _genresList = [];
  List<FabMiniMenu> fabItems;
  int _selectedAlbum;
  File _selectedFile;
  File _selectedImage;
  String _fileSize = "0 KB";
  double _progressValue = 0;
  int _progressPercentValue = 0;
  bool _fileUploaded = false;
  bool _showControlBtn = false;
  Map _uploadedSong;
  String _releaseDate;
  List _selectedGenres;
  List _selectedMoods;

  DateTime _date = DateTime.now();
  DateTime _initialDate;
  DateTime _maxDate;

  bool _visibility = true;
  bool _free = false;
  TextEditingController _songTitleController;
  TextEditingController _descriptionController;
  TextEditingController _lyricsController;
  TextEditingController _copyrightController;

  var dio = Dio();

  @override
  void initState() {
    super.initState();
    dio.options.baseUrl = 'https://ilhewl.com/api';

    _initialDate = DateTime(_date.year, _date.month, _date.day - 1);
    _maxDate = DateTime(_date.year, _date.month + 3, _date.day);
    _songTitleController = TextEditingController();
    _descriptionController = TextEditingController();
    _lyricsController = TextEditingController();
    _copyrightController = TextEditingController();

    _controller = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _albumsList = widget.albums;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      //_refreshIndicatorKey.currentState.show();
      _dataLoad();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _songTitleController.dispose();
    _descriptionController.dispose();
    _lyricsController.dispose();
    _copyrightController.dispose();
    super.dispose();
  }

  Future<String> getFileSize(String filepath, int decimals) async {
    var file = File(filepath);
    int bytes = await file.length();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1000)).floor();
    var size = ((bytes / pow(1000, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
    return size;
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

  void _buildFabMenus() {
    fabItems = [
      FabMiniMenu(icon: Icons.cloud_upload, action: () => _uploadFile(_selectedFile)),
      FabMiniMenu(
        //icon: Icons.image, action: () => _pickImage(ImageSource.gallery)),
          icon: Icons.image,
          action: () => _chooseFile()),
    ];
  }

  void _uploadFile(File file) async {
    if (file == null) {
      _showSnackBar("Select file first");
      return;
    }

    _setUploadProgress(0, 0);

    try {
      // var httpResponse = await FileService.fileUpload(
      //     file: file, onUploadProgress: _setUploadProgress);

      var song = await FileService().fileUploadMultipart(file: file, onUploadProgress: _setUploadProgress);

      if(song.contains("id")){
        _showSnackBar("File uploaded - ${fileUtil.basename(file.path)}");
        EasyLoading.showToast("Song Uploaded Success! Now please fill all song information to complete the upload.", duration: Duration(seconds: 3), toastPosition: EasyLoadingToastPosition.center, dismissOnTap: true);
        setState(() {
          _showControlBtn = false;
          _fileUploaded = true;
          _uploadedSong = jsonDecode(song);
          _songTitleController = TextEditingController(text: _uploadedSong["title"]);
        });

      }
    } catch (e) {
      print(e.toString());
      _showSnackBar(e.toString());
    }
  }

  void _setUploadProgress(int sentBytes, int totalBytes) {
    double __progressValue = Util.remap(sentBytes.toDouble(), 0, totalBytes.toDouble(), 0, 1);

    __progressValue = double.parse(__progressValue.toStringAsFixed(2));

    if (__progressValue != _progressValue)
      setState(() {
        _progressValue = __progressValue;
        _progressPercentValue = (_progressValue * 100.0).toInt();
      });
  }

  Future<Null> _dataLoad() async {
    try {
      _refreshIndicatorKey?.currentState?.show();

      var data = await Api().fetchHomePageData();

      List _lists = data["genres"];
      List _items = data["moods"];

      _genresList = _lists.map((e) => MultiSelectItem(e['id'], e["name"])).toList();
      _moodsList = _items.map((e) => MultiSelectItem(e['id'], e["name"])).toList();

      setState(() {});
    } catch (err) {
      _showSnackBar("Error loading data");
    } finally {
      //_refreshIndicatorKey.currentState.hide();
    }
  }

  Future _reloadAlbums() async {
    EasyLoading.show(status: "loading...");
    final response = await Api().fetchArtistSongs("auth/artist", null);
    if (response != null) {
      List data = response["albums"]["data"];
      if(data != null && data.isNotEmpty) {
        EasyLoading.dismiss();
        setState(() {
          _albumsList = data;
        });
      }else{
        EasyLoading.dismiss();
        EasyLoading.showError("You don't have any albums, try create new one!");
      }
      EasyLoading.dismiss();
    } else {
      EasyLoading.dismiss();
      throw Exception('Failed to load Data');
    }
    EasyLoading.dismiss();
  }

  Future<FormData> FormData1() async {
    return FormData.fromMap({
      'id': _uploadedSong["id"],
      'title': _songTitleController.text,
      'description': _descriptionController.text,
      'album_id': _selectedAlbum,
      'genre': _selectedGenres.join(","),
      'mood': _selectedMoods.join(","),
      'released_at': _releaseDate,
      'copyright': _copyrightController.text,
      'user_id': userId,
      'visibility': _visibility,
      'selling': _free ? 1 : 0,
      'artwork': await MultipartFile.fromFile(_selectedImage.path, filename: 'artwork.jpg'),
    });
  }

  Future _updateSongData() async {
    if (_songTitleController.text == null || _uploadedSong == null || _selectedImage == null) {
      EasyLoading.showError("You missed something, check all required infos!");
      return;
    }
    headers = {"Accept": "application/json", 'Authorization': 'Bearer $token'};

    // EasyLoading.show(status: "Loading...");
    Response response;

    try{
      response = await dio.post(
        '/song/update/${_uploadedSong["id"]}',
        data: await FormData1(),
        options: Options(headers: headers),
        onSendProgress: (received, total) {
          if (total != -1) {
            EasyLoading.showProgress(received / total * 100);
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

  _showSnackBar(String text) {
    ShowSnackBar().showSnackBar(context, text);
  }

  void _chooseFile() async {
    var result = await FilePicker.platform.pickFiles(type: FileType.any);

    setState(() {
      _selectedFile = File(result.files.single.path);
      _showControlBtn = true;
      getFileSize(_selectedFile.path, 1).then((value) => {
        setState(() {
          _fileSize = value;
        })
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    AppConfig().init(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus.unfocus(),
      child: GradientContainer(
        child: Scaffold(
          appBar: AppBar( 
            title: Text(
              'Upload Song',
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SizedBox(
            height: AppConfig.screenHeight,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppConfig.blockSizeVertical),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      _fileUploaded ? null : _chooseFile();
                    },
                    child: Container(
                    height: 80,
                      child: Card(
                        color: Colors.white38,
                        elevation: 10.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              alignment: AlignmentDirectional.center,
                              children: [
                                Image(
                                  image: AssetImage("assets/song.png"),
                                  width: 72,
                                  height: 72,
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("$_progressPercentValue %"),
                                    Text(_selectedFile != null ? "$_fileSize" : "0 KB"),
                                  ],
                                )
                              ],
                            ),
                            Container(
                              width: AppConfig.screenWidth - 80,
                              padding: EdgeInsets.only(top: 10.0),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        _selectedFile == null ? "Choose file" : "File: ${fileUtil.basename(_selectedFile.path)}",
                                        style: TextStyle(fontSize: AppConfig.screenWidth * .04),
                                      ),
                                    ),
                                    Container(
                                        width: AppConfig.screenWidth - 80,
                                        child: LinearProgressIndicator(
                                          value: _selectedFile == null ? 0.0 : _progressValue,
                                          color: _fileUploaded ? Colors.green : Theme.of(context).accentColor,
                                          minHeight: 6.0,
                                        )
                                    ),
                                    // new Expanded(flex: 1, child: _buildPreviewImage()),
                                  ]),
                            ),
                          ],
                        ),
                      )  ,
                    ),
                  ),
                  SizedBox(height: 10,),
                  _showControlBtn ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        child: Container(
                            padding: EdgeInsets.only(left: 10, right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              color: Theme.of(context).colorScheme.secondary,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5.0,
                                  spreadRadius: 0.0,
                                  offset: Offset(0.0, 3.0),
                                )
                              ],
                            ),
                            child: TextButton.icon(
                              icon: Icon(Icons.delete, color: Colors.white,),
                              label: Text(
                                "Clear",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedFile = null;
                                });
                              },
                            )
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        child: Container(
                            padding: EdgeInsets.only(left: 10, right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              color: Theme.of(context).colorScheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5.0,
                                  spreadRadius: 0.0,
                                  offset: Offset(0.0, 3.0),
                                )
                              ],
                            ),
                            child: TextButton.icon(
                              icon: Icon(Icons.upload, color: Colors.white,),
                              label: Text(
                                "Upload",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                _uploadFile(_selectedFile);
                              },
                            )
                        ),
                      ),
                    ],
                  ) : SizedBox(),
                  SizedBox(height: 10,),
                  _fileUploaded ? _buildDetailsView() : SizedBox(),
                ],
              ),
            ),
          ),
          // floatingActionButton: AnimatedOpacity(
          //   opacity: _fabOpacity,
          //   duration: Duration(milliseconds: 250),
          //   curve: Curves.easeOut,
          //   child: _buildFabMenu(context),
          // ),
        ),
      ),
    );
  }

  double _fabOpacity = 1;

  Widget _buildFabMenu(BuildContext context) {
    Color backgroundColor = Theme.of(context).cardColor;
    Color foregroundColor = Theme.of(context).accentColor;

    return new Column(
      mainAxisSize: MainAxisSize.min,
      children: new List.generate(fabItems.length, (int index) {
        Widget child = new Container(
          padding: EdgeInsets.only(bottom: 10),
          // height: 70.0,
          // width: 56.0,
          //alignment: FractionalOffset.bottomRight,
          child: new ScaleTransition(
            scale: new CurvedAnimation(
              parent: _controller,
              //   curve: new Interval(
              //       1.0 * index / 10.0, 1.0 - index / fabItems.length / 2.0,
              //       curve: Curves.fastOutSlowIn),
              curve: Curves.fastOutSlowIn,
            ),
            child: new FloatingActionButton(
              heroTag: null,
              backgroundColor: backgroundColor,
              mini: false,
              child: new Icon(fabItems[index].icon, color: foregroundColor),
              onPressed: () {
                fabItems[index].action();
                _controller.reverse();
              },
            ),
          ),
        );
        return child;
      }).toList()
        ..add(
          new FloatingActionButton(
            heroTag: null,
            child: new AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget child) {
                return new Transform(
                  transform: new Matrix4.rotationZ(_controller.value * 0.5 * math.pi),
                  alignment: FractionalOffset.center,
                  child: new Icon(_controller.isDismissed ? Icons.menu : Icons.close),
                );
              },
            ),
            onPressed: () {
              if (_controller.isDismissed) {
                _controller.forward();
              } else {
                _controller.reverse();
              }
            },
          ),
        ),
    );
  }

  Widget _customLabel(String labelText, bool isRequired) {
    return RichText(
      text: TextSpan(
          text: '$labelText',
          style: TextStyle(
              fontSize: AppConfig.screenWidth * .035
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

  Widget _buildDetailsView() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                  text: 'Please note that fields marked with',
                  style: TextStyle(
                    fontSize: AppConfig.screenWidth * .03,
                    color: Colors.white,
                    fontWeight: FontWeight.w100
                  ),
                  children: [
                    TextSpan(
                      text: ' * ',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: AppConfig.screenWidth * .03,
                        fontWeight: FontWeight.bold
                      ),

                    ),
                    TextSpan(
                      text: 'are required in order to publish the song.  All songs will be verified before they are approved.',
                      style: TextStyle(
                          fontSize: AppConfig.screenWidth * .03,
                          color: Colors.white
                      ),
                    )
                  ]),
            )
          ),
          SizedBox(height: 20,),
          _customLabel("Image", true),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Stack(
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
                              margin: const EdgeInsets.only(top: 69.5, left: 69.5),
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
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20,),
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
            child: _albumsList != null && _albumsList.isNotEmpty ? DropdownButtonHideUnderline(
              child: DropdownButton(
                value: _selectedAlbum,
                isExpanded: true,
                items: _albumsList.map((value) {
                  return DropdownMenuItem(
                    value: value['id'],
                    child: Text(value['title'], style: TextStyle(color: Colors.white),),
                  );
                }).toList(),
                hint:Text(
                  "Please choose an album",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedAlbum = val;
                  });
                },
              ),
            ) : ListTile(
              title: Text("Create new album +"),
              trailing: PopupMenuButton(
                onSelected: (value) {
                  if(value == 1){
                    showCupertinoModalBottomSheet(
                      backgroundColor: Colors.white70,
                      expand: true,
                      context: context,
                      builder: (context) => ModalWithScroll(artistId: artistId, userId: userId, genres: _genresList, moods: _moodsList,),
                    );
                  }else if(value == 2){
                    _reloadAlbums();
                  }
                },
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: Theme.of(context).iconTheme.color,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(7.0))),
                itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                  const PopupMenuItem(
                    value: 1,
                    child: Text('New Album'),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Text('Refresh Albums list'),
                  ),
                ],
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
                title: Text(_releaseDate == null ? "Release Date" : _releaseDate, style: TextStyle(color: Colors.white70),),
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
            title: Text("Genres"),
            icon: Icon(Icons.check, color: Theme.of(context).accentColor, size: 5.0,),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10)
            ),
            textStyle: TextStyle(
              color: Colors.white
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
                color: Colors.white
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
          SizedBox(height: 20,),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10),
              child: Container(
                  padding: EdgeInsets.only(left: 10, right: 10),
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
                  child: TextButton.icon(
                    icon: Icon(Icons.save, color: Colors.white,),
                    label: Text(
                      "Save",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _updateSongData();
                    },
                  )
              ),
            ),
          ),
          SizedBox(height: 100,)
        ],
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (_selectedFile == null) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          "Choose file",
          style: TextStyle(fontSize: 26),
        ),
      );
    } else if (_selectedFile != null &&
        ['.jpg', 'jpeg', '.bmp', '.png'].contains(
            fileUtil.extension(_selectedFile.path))) // .contains(fileUtil.extension(_imageFile.path))
        {
      return Image.file(_selectedFile);
    } else {
      return Container(
        alignment: Alignment.center,
        child: Text(
          "File: ${fileUtil.basename(_selectedFile.path)}",
          style: TextStyle(fontSize: 26),
        ),
      );
    }
  }
}

class FilePreview extends StatefulWidget {
  _FilePreviewState createState() => _FilePreviewState();

  FilePreview({@required this.file});

  final File file;
}

class _FilePreviewState extends State<FilePreview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Image"),
      ),
      body: Container(
        alignment: Alignment.center,
        child: Image.file(
          widget.file,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }
}