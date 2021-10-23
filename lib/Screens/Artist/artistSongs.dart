import 'dart:convert';

import 'package:audiotagger/models/audiofile.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/collage.dart';
import 'package:ilhewl/CustomWidgets/custom_physics.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:ilhewl/Screens/Artist/EditSong.dart';
import 'package:ilhewl/Screens/Artist/NewAlbum.dart';
import 'package:ilhewl/Screens/Artist/UploadScreen.dart';
import 'package:ilhewl/Screens/Artist/artist_profile.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:ext_storage/ext_storage.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/Screens/Settings/profile.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:unicorndial/unicorndial.dart';
import 'package:audiotagger/audiotagger.dart';
import 'dart:io';
import '../Library/showSongs.dart';


int userId = Hive.box("settings").get("userID", defaultValue: 0);
int artistId = Hive.box("settings").get("artistId", defaultValue: 0);
Map homeData = Hive.box('cache').get('homepage', defaultValue: {});
Map data = Hive.box('cache').get('artistPage', defaultValue: {});


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
  double offset = 0.0;

  List loadedSongs = [];
  List loadedAlbums = [];
  List loadedGenres = [];
  List _moodsList = [];
  List _genresList = [];
  bool loadCompleted = false;

  Map artist;

  bool get isShrink {
    return _scrollController.hasClients && offset > (MediaQuery.of(context).size.height * 0.2 - kToolbarHeight);
  }

  bool barStatus = true;

  _scrollListener() {
    if (isShrink != barStatus) {
      setState(() {
        barStatus = isShrink;
      });
    }
  }

  Future<List> getData() async {
    var receivedData = await Api().fetchArtistData(artistId.toString());

    if(receivedData != null && receivedData.isNotEmpty){
      Hive.box('cache').put('artistPage', receivedData);
      data = receivedData;
      loadCompleted = true;
    }

    List _lists = homeData["genres"];
    List _items = homeData["moods"];

    if(_lists.isNotEmpty && _lists != null){
      _genresList = _lists.map((e) => MultiSelectItem(e['id'], e["name"])).toList();
    }
    if(_items.isNotEmpty && _items != null){
      _moodsList = _items.map((e) => MultiSelectItem(e['id'], e["name"])).toList();
    }

    setState(() {});
    // EasyLoading.dismiss();
    // final response = await Api().fetchArtistSongs("auth/artist", null);
    // if (response != null) {
    //   var data = response;
    //   var songs = data['songs'];
    //   if (data["songs"]['next_page_url'] != null) {
    //     nextUrl = data["songs"]['next_page_url'];
    //   } else {
    //     loadCompleted = true;
    //   }
    //   setState(() {
    //     loadedSongs = songs["data"];
    //     loadedAlbums = data["albums"]["data"];
    //     loadedGenres = data["genres"];
    //   });
    //   EasyLoading.dismiss();
    //   return loadedSongs;
    // } else {
    //   EasyLoading.dismiss();
    //   throw Exception('Failed to load Data');
    // }
  }

  _updateSongStatus(songId, status) async {
    try {
      Navigator.pop(context);
      EasyLoading.show(status: "Loading...");
      // loadedSongs[index]['visibility'] = !loadedSongs[index]['visibility'];
      Map res = await Api().authData('song/update_data/$songId?id=$songId&user_id=$userId&visibility=publish');
      if(res.containsKey('id')){
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
        }
      }
      EasyLoading.dismiss();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 6,
          backgroundColor: Colors.grey[900],
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Song has been updated!',
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
      EasyLoading.dismiss();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 6,
          backgroundColor: Colors.grey[900],
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Something went wrong, Try again!',
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
    EasyLoading.dismiss();
    setState(() {});
  }

  @override
  void initState() {
    getData();
    _tcontroller = TabController(length: 2, vsync: this);
    _tcontroller.addListener(changeTitle);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        offset = _scrollController.offset;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _tcontroller.dispose();
    _scrollController.removeListener(_scrollListener);
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent
    ));
    return GradientContainer(
      child: Column(
        children: [
          !loadCompleted ? LinearProgressIndicator(
            backgroundColor: Colors.grey,
            color: Theme.of(context).accentColor,
            minHeight: 1,
          ) : SizedBox(),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              extendBodyBehindAppBar: true,
              body: data.isEmpty
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
                    floatHeaderSlivers: true,
                    controller: _scrollController,
                    headerSliverBuilder: (BuildContext scontext, bool innerBoxIsScrolled) {
                      return <Widget>[
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          stretch: true,
                          pinned: true,
                          floating: true,
                          snap: true,
                          expandedHeight: MediaQuery.of(context).size.height * 0.2,
                          systemOverlayStyle: SystemUiOverlayStyle(
                              statusBarColor: Colors.transparent
                          ),
                          automaticallyImplyLeading: false,
                          // leading: Builder(
                          //   builder: (BuildContext context) {
                          //     return Transform.rotate(
                          //       angle: 22 / 7 * 2,
                          //       child: IconButton(
                          //         color: Theme.of(context).brightness == Brightness.dark
                          //             ? null
                          //             : Colors.grey[700],
                          //         icon: const Icon(
                          //             Icons.horizontal_split_rounded), // line_weight_rounded),
                          //         onPressed: () {
                          //           Scaffold.of(context).openDrawer();
                          //         },
                          //         tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                          //       ),
                          //     );
                          //   },
                          // ),
                          actions: [
                            PopupMenuButton(
                                icon: Icon(Icons.more_vert_rounded, color: isShrink ? Colors.black87 : Colors.white,),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.all(Radius.circular(7.0))),
                                onSelected: (int value) {

                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    ArtistProfile()));
                                      },
                                      label: Text("Edit Profile", style: TextStyle(color: MyTheme().isDark ? Colors.white : Colors.black),),
                                      icon: Icon(
                                        Icons.edit,
                                        color: MyTheme().isDark ? Colors.white60 : Colors.grey[700],
                                      ),
                                    )
                                  ),
                                ]),
                            // PopupMenuButton(
                            //     icon: Icon(Icons.sort_rounded),
                            //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(7.0))),
                            //     onSelected: (currentIndex == 0 || currentIndex == 4)
                            //         ? (int value) {
                            //       sortValue = value;
                            //       Hive.box('settings').put('sortValue', value);
                            //       sortSongs(loadedSongs);
                            //       setState(() {});
                            //     }
                            //         : (int value) {
                            //       albumSortValue = value;
                            //       Hive.box('settings')
                            //           .put('albumSortValue', value);
                            //       sortAlbums(
                            //           sortedCachedAlbumKeysList,
                            //           sortedCachedArtistKeysList,
                            //           sortedCachedGenreKeysList,
                            //           loadedAlbums,
                            //           loadedSongs,
                            //           loadedGenres);
                            //       setState(() {});
                            //     },
                            //     itemBuilder: (currentIndex == 0 || currentIndex == 4)
                            //         ? (context) => [
                            //       PopupMenuItem(
                            //         value: 0,
                            //         child: Row(
                            //           children: [
                            //             sortValue == 0
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               'A-Z',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 1,
                            //         child: Row(
                            //           children: [
                            //             sortValue == 1
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               'Z-A',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 2,
                            //         child: Row(
                            //           children: [
                            //             sortValue == 2
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text('Release Date'),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 3,
                            //         child: Row(
                            //           children: [
                            //             sortValue == 3
                            //                 ? Icon(
                            //               Icons.shuffle_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               'Shuffle',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //     ]
                            //         : (context) => [
                            //       PopupMenuItem(
                            //         value: 0,
                            //         child: Row(
                            //           children: [
                            //             albumSortValue == 0
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               'A-Z',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 1,
                            //         child: Row(
                            //           children: [
                            //             albumSortValue == 1
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               'Z-A',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 2,
                            //         child: Row(
                            //           children: [
                            //             albumSortValue == 2
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               '10-1',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 3,
                            //         child: Row(
                            //           children: [
                            //             albumSortValue == 3
                            //                 ? Icon(
                            //               Icons.check_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               '1-10',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       PopupMenuItem(
                            //         value: 4,
                            //         child: Row(
                            //           children: [
                            //             albumSortValue == 4
                            //                 ? Icon(
                            //               Icons.shuffle_rounded,
                            //               color: Theme.of(context)
                            //                   .brightness ==
                            //                   Brightness.dark
                            //                   ? Colors.white
                            //                   : Colors.grey[700],
                            //             )
                            //                 : SizedBox(),
                            //             SizedBox(width: 10),
                            //             Text(
                            //               'Shuffle',
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //     ]),
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
                                    Theme.of(context).accentColor,
                                    Colors.transparent
                                  ],
                                ).createShader(Rect.fromLTRB(
                                    0, 0, rect.width, rect.height));
                              },
                              blendMode: BlendMode.dstIn,
                              child: data['artist']['artwork_url'] == null
                                ? Image(
                                    fit: BoxFit.cover,
                                    image: AssetImage('assets/cover.jpg'),
                                  )
                                  : CachedNetworkImage(
                                      fit: BoxFit.cover,
                                      errorWidget: (context, _, __) =>
                                          Image(
                                            image: AssetImage('assets/artist.png'),
                                            fit: BoxFit.cover,
                                          ),
                                      imageUrl: data['artist']['artwork_url'].replaceAll('http:', 'https:').replaceAll('50x50', '500x500').replaceAll('150x150', '500x500'),
                                      placeholder: (context, url) =>
                                          Image(
                                            image: AssetImage('assets/artist.png'),
                                            fit: BoxFit.cover,
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
                          title: Text("${data['artist']['name']}", style: TextStyle(color: MyTheme().isDark ? Colors.white : Colors.black54,),),
                          automaticallyImplyLeading: false,
                          bottom: TabBar(
                              controller: _tcontroller,
                              labelColor: MyTheme().isDark ? Colors.white : Colors.black54,
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
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                        body: TabBarView(
                            physics: CustomPhysics(),
                            controller: _tcontroller,
                            children: [
                              songsTab(data['artist']['songs']),
                              albumsTab(data['artist']['albums']),
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
                              MaterialPageRoute(builder: (context) => UploadScreen(albums: loadedAlbums,)));
                        },
                      )),
                  UnicornButton(
                      hasLabel: true,
                      labelText: "New Album",
                      currentButton: FloatingActionButton(
                        heroTag: "add",
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        mini: true,
                        child: Icon(Icons.add),
                        onPressed: () {
                          showCupertinoModalBottomSheet(
                            backgroundColor: Colors.white70,
                            expand: true,
                            context: context,
                            builder: (context) => ModalWithScroll(artistId: artistId, userId: userId, genres: _genresList, moods: _moodsList,),
                          );
                        },
                      ))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  songsTab(songs) {
    return songs.length == 0
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0, "Show Here", 45, "Upload something", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemExtent: 70.0,
            itemCount: songs.length,
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
                      songs[index]['artwork_url'] == null
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
                                imageUrl: songs[index]['artwork_url']
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
                  songs[index]['title'] != null &&
                      songs[index]['title'].trim() != ""
                      ? songs[index]['title']
                      : '${songs[index]['id'].split('/').last}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  songs[index]['released_at']
                      +" - "
                      +(songs[index]["selling"] == 1 ? songs[index]["price"] + " $currency" : "Free"),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton(
                  icon: Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(7.0))),
                  onSelected: (value) async {
                    if (value == 0) {
                      showDialog(context: context, builder: (BuildContext context) {
                          int songId = songs[index]['id'];
                          int status = songs[index]['visibility'];
                          return CupertinoAlertDialog(
                            title: Text(songs[index]['visibility'] == 0 ? 'Publish' : 'UnPublish'),
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
                                  _updateSongStatus(songId, status);
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
                      showCupertinoModalBottomSheet(
                        backgroundColor: Colors.white70,
                        expand: true,
                        context: context,
                        builder: (context) => EditSongModal(artistId: artistId, userId: userId, songId: songs[index]['id'], albums: loadedAlbums,),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(songs[index]['visibility'] == 0 ? Icons.publish : Icons.unpublished),
                          Spacer(),
                          Text(songs[index]['visibility'] == 0 ? 'Publish' : 'UnPublish'),
                          Spacer(),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          Spacer(),
                          Text('Edit Song'),
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
                          'response': songs,
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

  albumsTab(albums) {
    loadedAlbums = albums;
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
