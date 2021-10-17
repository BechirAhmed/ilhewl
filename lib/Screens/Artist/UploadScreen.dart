import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/FabMiniMenu.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/CustomWidgets/snackbar.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/util.dart';
import 'package:ilhewl/Services/FileService.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as fileUtil;
import 'package:multi_select_flutter/multi_select_flutter.dart';

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
  // List _genresList = [];
  List _moodsList = [];
  List _tagsList = [];
  List _albumsList = [];
  List _genresList = [];
  List<FabMiniMenu> fabItems;
  File _selectedFile;
  String _fileSize = "0 KB";
  double _progressValue = 0;
  int _progressPercentValue = 0;
  bool _fileUploaded = false;
  bool _showControlBtn = false;
  Map _uploadedSong;
  String _releaseDate;
  String _selectedGenres;
  String _selectedMoods;

  DateTime _date = DateTime.now();
  DateTime _initialDate;
  DateTime _maxDate;

  TextEditingController _songTitleController;
  TextEditingController _descriptionController;
  TextEditingController _lyricsController;
  TextEditingController _copyrightController;

  @override
  void initState() {
    super.initState();
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
    print(_albumsList);

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

      _showSnackBar("File uploaded - ${fileUtil.basename(file.path)}");
      if(song.contains("id")){
        //TODO: Notify Artist to fill up song informations
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

  _showSnackBar(String text) {
    // final snackBar = SnackBar(content: Text(text));
    ShowSnackBar().showSnackBar(context, text);
    // _scaffoldKey.currentState.showSnackBar(snackBar);
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
          // Container(
          //   height: 80,
          //   child: Card(
          //     color: Colors.white38,
          //     elevation: 10.0,
          //     child: Row(
          //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Stack(
          //           alignment: AlignmentDirectional.center,
          //           children: [
          //             Image(
          //               image: AssetImage("assets/song.png"),
          //               width: 72,
          //               height: 72,
          //             ),
          //             Column(
          //               mainAxisAlignment: MainAxisAlignment.center,
          //               children: [
          //                 Text("$_progressPercentValue %"),
          //                 Text(_selectedFile != null ? "$size" : "0 KB"),
          //               ],
          //             )
          //           ],
          //         ),
          //         Container(
          //           width: AppConfig.screenWidth - 80,
          //           padding: EdgeInsets.only(top: 10.0),
          //           child: Column(
          //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //               crossAxisAlignment: CrossAxisAlignment.start,
          //               children: [
          //                 Container(
          //                   padding: const EdgeInsets.only(left: 8.0),
          //                   child: Text(
          //                       _selectedFile == null ? "Choose file" : "File: ${fileUtil.basename(_selectedFile.path)}",
          //                     style: TextStyle(fontSize: AppConfig.screenWidth * .04),
          //                   ),
          //                 ),
          //                 // new Container(
          //                 //     padding: EdgeInsets.only(top: 10),
          //                 //     child: new Column(children: <Widget>[
          //                 //       Text(
          //                 //         '$_progressPercentValue %',
          //                 //         style: Theme.of(context).textTheme.display1,
          //                 //       ),
          //                 //     ])
          //                 // ),
          //                 Container(
          //                     width: AppConfig.screenWidth - 80,
          //                     child: LinearProgressIndicator(value: _selectedFile == null ? 0 : _progressValue)
          //                 ),
          //                 // new Expanded(flex: 1, child: _buildPreviewImage()),
          //               ]),
          //         ),
          //       ],
          //     ),
          //   )  ,
          // ),
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
            child: _albumsList != null ? DropdownButton(
              items: _albumsList.map((value) {
                return DropdownMenuItem<String>(
                  value: value['id'],
                  child: Text(value['title']),
                );
              }).toList(),
              onChanged: (val) {
                print(val);
              },
            ) : TextButton(
                onPressed: () {

                },
                child: Text(
                  "Create new album +",
                  style: TextStyle(
                    color: Colors.white38
                  ),
                )
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
                _selectedGenres = values.toString();
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
                _selectedMoods = values.toString();
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