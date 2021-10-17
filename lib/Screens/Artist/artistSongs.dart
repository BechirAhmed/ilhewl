import 'dart:convert';

import 'package:audiotagger/models/audiofile.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/collage.dart';
import 'package:ilhewl/CustomWidgets/custom_physics.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Screens/Artist/UploadScreen.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:ext_storage/ext_storage.dart';
import 'package:hive/hive.dart';
import 'package:unicorndial/unicorndial.dart';
import 'package:audiotagger/audiotagger.dart';
import 'dart:io';
import '../Library/showSongs.dart';

class ArtistSongs extends StatefulWidget {
  final String type;
  ArtistSongs({Key key, @required this.type}) : super(key: key);
  @override
  _ArtistSongsState createState() => _ArtistSongsState();
}

class _ArtistSongsState extends State<ArtistSongs> with SingleTickerProviderStateMixin {

  List sortedCachedAlbumKeysList = [];
  List sortedCachedArtistKeysList = [];
  List sortedCachedGenreKeysList = [];

  bool added = false;
  int sortValue = Hive.box('settings').get('sortValue', defaultValue: 2);
  int albumSortValue = Hive.box('settings').get('albumSortValue', defaultValue: 2);
  List dirPaths = Hive.box('settings').get('searchPaths', defaultValue: []);
  TabController _tcontroller;
  int currentIndex = 0;
  String currency = Hive.box('settings').get('currency') ?? "MRU";


  var nextUrl;
  ScrollController _scrollController = new ScrollController();
  List loadedSongs = [];
  List loadedAlbums = [];
  List loadedGenres = [];
  bool loadCompleted = false;

  Map artist;

  Future<List> getData() async {
    // EasyLoading.show(status: "Loading...");
    final userId = Hive.box("settings").get("artistId");
    var artistData = await Api().fetchArtistData(userId.toString());
    if(artistData != null){
      artist = artistData['artist'];
    }
    final response = await Api().fetchArtistSongs("auth/artist", null);
    if (response != null) {
      var data = response;
      var songs = data['songs'];
      if (data["songs"]['next_page_url'] != null) {
        nextUrl = data["songs"]['next_page_url'];
      } else {
        loadCompleted = true;
      }
      setState(() {
        loadedSongs = songs["data"];
        loadedAlbums = data["albums"]["data"];
        loadedGenres = data["genres"];
      });
      EasyLoading.dismiss();
      return loadedSongs;
    } else {
      EasyLoading.dismiss();
      throw Exception('Failed to load Data');
    }
  }

  @override
  void initState() {
    getData();
    _tcontroller = TabController(length: 2, vsync: this);
    _tcontroller.addListener(changeTitle);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _tcontroller.dispose();
  }

  void changeTitle() {
    setState(() {
      currentIndex = _tcontroller.index;
    });
  }

  void sortSongs(List songs) {
    if (sortValue == 0) {
      songs.sort((a, b) => a["title"]
          .split('/')
          .last
          .toString()
          .toUpperCase()
          .compareTo(b["title"].split('/').last.toString().toUpperCase()));
    }
    if (sortValue == 1) {
      songs.sort((b, a) => a["title"]
          .split('/')
          .last
          .toString()
          .toUpperCase()
          .compareTo(b["title"].split('/').last.toString().toUpperCase()));
    }
    if (sortValue == 2) {
      songs.sort((b, a) =>
          a["release_date"].toString().compareTo(b["release_date"].toString()));
    }
    if (sortValue == 3) {
      songs.shuffle();
    }
  }

  void sortAlbums(List _sortedAlbumKeysList, List _sortedArtistKeysList,
      List _sortedGenreKeysList, List albums, List artists, List genres) {
    if (albumSortValue == 0) {
      _sortedAlbumKeysList.sort((a, b) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      _sortedArtistKeysList.sort((a, b) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      _sortedGenreKeysList.sort((a, b) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
    }
    if (albumSortValue == 1) {
      _sortedAlbumKeysList.sort((b, a) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      _sortedArtistKeysList.sort((b, a) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      _sortedGenreKeysList.sort((b, a) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
    }
    if (albumSortValue == 2) {
      _sortedAlbumKeysList
          .sort((b, a) => albums[a].length.compareTo(albums[b].length));
      _sortedArtistKeysList
          .sort((b, a) => artists[a].length.compareTo(artists[b].length));
      _sortedGenreKeysList
          .sort((b, a) => genres[a].length.compareTo(genres[b].length));
    }
    if (albumSortValue == 3) {
      _sortedAlbumKeysList
          .sort((a, b) => albums[a].length.compareTo(albums[b].length));
      _sortedArtistKeysList
          .sort((a, b) => artists[a].length.compareTo(artists[b].length));
      _sortedGenreKeysList
          .sort((a, b) => genres[a].length.compareTo(genres[b].length));
    }
    if (albumSortValue == 4) {
      _sortedAlbumKeysList.shuffle();
      _sortedArtistKeysList.shuffle();
      _sortedGenreKeysList.shuffle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Column(
        children: [
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: !loadCompleted
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
                    )
                : NestedScrollView(
                    physics: BouncingScrollPhysics(),
                    headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                      return <Widget>[
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          stretch: true,
                          pinned: true,
                          // floating: true,
                          expandedHeight:
                          MediaQuery.of(context).size.height * 0.4,
                          actions: [
                            PopupMenuButton(
                                icon: Icon(Icons.sort_rounded),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.all(Radius.circular(7.0))),
                                onSelected: (currentIndex == 0 || currentIndex == 4)
                                    ? (int value) {
                                  sortValue = value;
                                  Hive.box('settings').put('sortValue', value);
                                  sortSongs(loadedSongs);
                                  setState(() {});
                                }
                                    : (int value) {
                                  albumSortValue = value;
                                  Hive.box('settings')
                                      .put('albumSortValue', value);
                                  sortAlbums(
                                      sortedCachedAlbumKeysList,
                                      sortedCachedArtistKeysList,
                                      sortedCachedGenreKeysList,
                                      loadedAlbums,
                                      loadedSongs,
                                      loadedGenres);
                                  setState(() {});
                                },
                                itemBuilder: (currentIndex == 0 || currentIndex == 4)
                                    ? (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: Row(
                                      children: [
                                        sortValue == 0
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          'A-Z',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 1,
                                    child: Row(
                                      children: [
                                        sortValue == 1
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          'Z-A',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 2,
                                    child: Row(
                                      children: [
                                        sortValue == 2
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text('Release Date'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 3,
                                    child: Row(
                                      children: [
                                        sortValue == 3
                                            ? Icon(
                                          Icons.shuffle_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          'Shuffle',
                                        ),
                                      ],
                                    ),
                                  ),
                                ]
                                    : (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: Row(
                                      children: [
                                        albumSortValue == 0
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          'A-Z',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 1,
                                    child: Row(
                                      children: [
                                        albumSortValue == 1
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          'Z-A',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 2,
                                    child: Row(
                                      children: [
                                        albumSortValue == 2
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          '10-1',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 3,
                                    child: Row(
                                      children: [
                                        albumSortValue == 3
                                            ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          '1-10',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 4,
                                    child: Row(
                                      children: [
                                        albumSortValue == 4
                                            ? Icon(
                                          Icons.shuffle_rounded,
                                          color: Theme.of(context)
                                              .brightness ==
                                              Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                            : SizedBox(),
                                        SizedBox(width: 10),
                                        Text(
                                          'Shuffle',
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            // title: Text(
                            //   "${artist['name']}",
                            //   textAlign: TextAlign.center,
                            // ),
                            centerTitle: true,
                            stretchModes: [StretchMode.zoomBackground],
                            background: ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black,
                                    Colors.transparent
                                  ],
                                ).createShader(Rect.fromLTRB(
                                    0, 0, rect.width, rect.height));
                              },
                              blendMode: BlendMode.dstIn,
                              child: artist['artwork_url'] == null
                                ? Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage(
                                      'assets/cover.jpg'))
                                  : CachedNetworkImage(
                                fit: BoxFit.cover,
                                errorWidget: (context, _, __) =>
                                    Image(
                                      image: AssetImage(
                                          'assets/album.png'),
                                    ),
                                imageUrl: artist['artwork_url'].replaceAll('http:', 'https:').replaceAll('50x50', '500x500').replaceAll('150x150', '500x500'),
                                placeholder: (context, url) =>
                                    Image(
                                      image: AssetImage(
                                          'assets/album.png'),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ];
                    },
                    body: DefaultTabController(
                      length: 2,
                      child: Scaffold(
                        backgroundColor: Colors.transparent,
                        appBar: AppBar(
                          title: Text("${artist['name']}"),
                          automaticallyImplyLeading: false,
                          bottom: TabBar(
                              controller: _tcontroller,
                              tabs: [
                                Tab(
                                  text: 'Songs',
                                ),
                                Tab(
                                  text: 'Albums',
                                ),
                                // Tab(
                                //   text: 'Genres',
                                // ),
                              ]
                          ),
                          centerTitle: true,
                          backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.transparent
                              : Theme.of(context).accentColor,
                          elevation: 0,
                        ),
                        body: TabBarView(
                            physics: CustomPhysics(),
                            controller: _tcontroller,
                            children: [
                              songsTab(),
                              albumsTab(),
                              // genresTab(),
                            ]
                        ),
                      ),
                    ),
                  ),

              floatingActionButton: UnicornDialer(
                  backgroundColor: Colors.transparent,
                  parentButtonBackground: Theme.of(context).accentColor,
                  orientation: UnicornOrientation.VERTICAL,
                  parentButton: Icon(Icons.add),
                childButtons: [
                  UnicornButton(
                      hasLabel: true,
                      labelText: "Upload New Song",
                      currentButton: FloatingActionButton(
                        heroTag: "upload",
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        mini: true,
                        child: Icon(Icons.upload),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UploadScreen()));
                        },
                      ))
                ],
              ),
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }

  songsTab() {
    return loadedSongs.length == 0
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0, "Show Here", 45, "Upload something", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemExtent: 70.0,
            itemCount: loadedSongs.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Image(
                        image: AssetImage('assets/cover.jpg'),
                      ),
                      loadedSongs[index]['artwork_url'] == null
                          ? SizedBox()
                          : SizedBox(
                              height: 50.0,
                              width: 50.0,
                              child: CachedNetworkImage(
                                errorWidget: (context, _, __) =>
                                    Image(
                                      image: AssetImage(
                                          'assets/cover.jpg'),
                                    ),
                                imageUrl: loadedSongs[index]['artwork_url']
                                    .replaceAll('http:', 'https:'),
                                placeholder: (context, url) =>
                                    Image(
                                      image: AssetImage(
                                          'assets/cover.jpg'),
                                    ),
                              ),
                            )
                    ],
                  ),
                ),
                title: Text(
                  loadedSongs[index]['title'] != null &&
                      loadedSongs[index]['title'].trim() != ""
                      ? loadedSongs[index]['title']
                      : '${loadedSongs[index]['id'].split('/').last}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  loadedSongs[index]['release_date']
                      +" - "
                      +(loadedSongs[index]["selling"] == 1 ? loadedSongs[index]["price"] + " $currency" : "Free"),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton(
                  icon: Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(7.0))),
                  onSelected: (value) async {
                    if (value == 0) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          String fileName = loadedSongs[index]['title']
                              .split('/')
                              .last
                              .toString();
                          List temp = fileName.split('.');
                          temp.removeLast();
                          String songName = temp.join('.');
                          final controller =
                              TextEditingController(text: songName);
                          return AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Title',
                                      style: TextStyle(
                                          color: Theme.of(context).accentColor),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                TextField(
                                    autofocus: true,
                                    controller: controller,
                                    onSubmitted: (value) async {
                                      try {
                                        Navigator.pop(context);
                                        String newName = loadedSongs[index]
                                                ['title']
                                            .toString()
                                            .replaceFirst(songName, value);

                                        while (await File(newName).exists()) {
                                          newName = newName.replaceFirst(
                                              value, value + ' (1)');
                                        }

                                        File(loadedSongs[index]['title'])
                                            .rename(newName);
                                        loadedSongs[index]['title'] = newName;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            elevation: 6,
                                            backgroundColor: Colors.grey[900],
                                            behavior: SnackBarBehavior.floating,
                                            content: Text(
                                              'Renamed to ${loadedSongs[index]['title'].split('/').last}',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            action: SnackBarAction(
                                              textColor:
                                                  Theme.of(context).accentColor,
                                              label: 'Ok',
                                              onPressed: () {},
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            elevation: 6,
                                            backgroundColor: Colors.grey[900],
                                            behavior: SnackBarBehavior.floating,
                                            content: Text(
                                              'Failed to Rename ${loadedSongs[index]['id'].split('/').last}',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            action: SnackBarAction(
                                              textColor:
                                                  Theme.of(context).accentColor,
                                              label: 'Ok',
                                              onPressed: () {},
                                            ),
                                          ),
                                        );
                                      }
                                      setState(() {});
                                    }),
                              ],
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  primary: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.grey[700],
                                  //       backgroundColor: Theme.of(context).accentColor,
                                ),
                                child: Text(
                                  "Cancel",
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  primary: Colors.white,
                                  backgroundColor:
                                      Theme.of(context).accentColor,
                                ),
                                child: Text(
                                  "Ok",
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () async {
                                  try {
                                    Navigator.pop(context);
                                    String newName = loadedSongs[index]['title']
                                        .toString()
                                        .replaceFirst(
                                            songName, controller.text);

                                    while (await File(newName).exists()) {
                                      newName = newName.replaceFirst(
                                          controller.text,
                                          controller.text + ' (1)');
                                    }

                                    File(loadedSongs[index]['title'])
                                        .rename(newName);
                                    loadedSongs[index]['title'] = newName;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        elevation: 6,
                                        backgroundColor: Colors.grey[900],
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Renamed to ${loadedSongs[index]['title'].split('/').last}',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        action: SnackBarAction(
                                          textColor:
                                              Theme.of(context).accentColor,
                                          label: 'Ok',
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        elevation: 6,
                                        backgroundColor: Colors.grey[900],
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Failed to Rename ${loadedSongs[index]['title'].split('/').last}',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        action: SnackBarAction(
                                          textColor:
                                              Theme.of(context).accentColor,
                                          label: 'Ok',
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                  }
                                  setState(() {});
                                },
                              ),
                              SizedBox(
                                width: 5,
                              ),
                            ],
                          );
                        },
                      );
                    }
                    if (value == 1) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          final _titlecontroller = TextEditingController(
                              text: loadedSongs[index]['title']);
                          final _albumcontroller = TextEditingController(
                              text: loadedSongs[index]['album']);
                          final _artistcontroller = TextEditingController(
                              text: loadedSongs[index]['artist']);
                          final _albumArtistController = TextEditingController(
                              text: loadedSongs[index]['albumArtist']);
                          final _genrecontroller = TextEditingController(
                              text: loadedSongs[index]['genre']);
                          final _yearcontroller = TextEditingController(
                              text: loadedSongs[index]['release_date']);
                          return AlertDialog(
                            content: Container(
                              height: 400,
                              width: 300,
                              child: SingleChildScrollView(
                                physics: BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Title',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                        autofocus: true,
                                        controller: _titlecontroller,
                                        onSubmitted: (value) {}),
                                    SizedBox(
                                      height: 30,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Artist',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                        autofocus: true,
                                        controller: _artistcontroller,
                                        onSubmitted: (value) {}),
                                    SizedBox(
                                      height: 30,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Album Artist',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                        autofocus: true,
                                        controller: _albumArtistController,
                                        onSubmitted: (value) {}),
                                    SizedBox(
                                      height: 30,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Album',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                        autofocus: true,
                                        controller: _albumcontroller,
                                        onSubmitted: (value) {}),
                                    SizedBox(
                                      height: 30,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Genre',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                        autofocus: true,
                                        controller: _genrecontroller,
                                        onSubmitted: (value) {}),
                                    SizedBox(
                                      height: 30,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Year',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                        autofocus: true,
                                        controller: _yearcontroller,
                                        onSubmitted: (value) {}),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  primary: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                child: Text("Cancel"),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  primary: Colors.white,
                                  backgroundColor:
                                      Theme.of(context).accentColor,
                                ),
                                child: Text(
                                  "Ok",
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () async {
                                  try {
                                    Navigator.pop(context);
                                    loadedSongs[index]['title'] =
                                        _titlecontroller.text;
                                    loadedSongs[index]['album'] =
                                        _albumcontroller.text;
                                    loadedSongs[index]['artist'] =
                                        _artistcontroller.text;
                                    loadedSongs[index]['albumArtist'] =
                                        _albumArtistController.text;
                                    loadedSongs[index]['genre'] =
                                        _genrecontroller.text;
                                    loadedSongs[index]['year'] =
                                        _yearcontroller.text;
                                    final tag = Tag(
                                      title: _titlecontroller.text,
                                      artist: _artistcontroller.text,
                                      album: _albumcontroller.text,
                                      genre: _genrecontroller.text,
                                      year: _yearcontroller.text,
                                      albumArtist: _albumArtistController.text,
                                    );

                                    final tagger = Audiotagger();
                                    await tagger.writeTags(
                                      path: loadedSongs[index]['id'],
                                      tag: tag,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        elevation: 6,
                                        backgroundColor: Colors.grey[900],
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Successfully edited tags',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        action: SnackBarAction(
                                          textColor:
                                              Theme.of(context).accentColor,
                                          label: 'Ok',
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        elevation: 6,
                                        backgroundColor: Colors.grey[900],
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Failed to edit tags',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        action: SnackBarAction(
                                          textColor:
                                              Theme.of(context).accentColor,
                                          label: 'Ok',
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              SizedBox(
                                width: 5,
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded),
                          Spacer(),
                          Text('Rename'),
                          Spacer(),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(
                              // CupertinoIcons.tag
                              Icons.local_offer_rounded),
                          Spacer(),
                          Text('Edit Tags'),
                          Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => PlayScreen(
                        data: {
                          'response': loadedSongs,
                          'index': index,
                          'offline': false
                        },
                        fromMiniplayer: false,
                      ),
                    ),
                  );
                },
              );
            });
  }

  albumsTab() {
    return loadedAlbums.isEmpty
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0,
            "Show Here", 45, "Create new Albums", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemExtent: 70.0,
            itemCount: loadedAlbums.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Image(
                        image: AssetImage('assets/cover.jpg'),
                      ),
                      loadedAlbums[index]['artwork_url'] == null
                          ? SizedBox()
                          : SizedBox(
                        height: 50.0,
                        width: 50.0,
                        child: CachedNetworkImage(
                          errorWidget: (context, _, __) =>
                              Image(
                                image: AssetImage(
                                    'assets/cover.jpg'),
                              ),
                          imageUrl: loadedAlbums[index]['artwork_url']
                              .replaceAll('http:', 'https:'),
                          placeholder: (context, url) =>
                              Image(
                                image: AssetImage(
                                    'assets/cover.jpg'),
                              ),
                        ),
                      )
                    ],
                  ),
                ),
                title: Text(
                  '${loadedAlbums[index]["title"]}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  loadedAlbums[index]["song_count"] < 2
                      ? '${loadedAlbums[index]['song_count']} Song'
                      : '${loadedAlbums[index]["song_count"]} Songs',
                ),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => SongsList(
                        data: loadedAlbums,
                        item: loadedAlbums[index],
                        offline: false,
                      ),
                    ),
                  );
                },
              );
            });
  }

  genresTab() {
    return loadedGenres.isEmpty
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0,
            "Show Here", 45, "Upload Songs", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemExtent: 70.0,
            itemCount: loadedGenres.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Image(
                        image: AssetImage('assets/cover.jpg'),
                      ),
                      loadedGenres[index]['artwork_url'] == null
                          ? SizedBox()
                          : SizedBox(
                        height: 50.0,
                        width: 50.0,
                        child: CachedNetworkImage(
                          errorWidget: (context, _, __) =>
                              Image(
                                image: AssetImage(
                                    'assets/cover.jpg'),
                              ),
                          imageUrl: loadedGenres[index]['artwork_url']
                              .replaceAll('http:', 'https:'),
                          placeholder: (context, url) =>
                              Image(
                                image: AssetImage(
                                    'assets/cover.jpg'),
                              ),
                        ),
                      )
                    ],
                  ),
                ),
                title: Text(
                  '${loadedGenres[index]['name']}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  loadedGenres[index]['song_count'] == 1
                      ? '${loadedGenres[index]['song_count']} Song'
                      : '${loadedGenres[index]['song_count']} Songs',
                ),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => SongsList(
                        data: loadedGenres[index],
                        offline: true,
                      ),
                    ),
                  );
                },
              );
            });
  }

}
