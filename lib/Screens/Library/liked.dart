import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/add_playlist.dart';
import 'package:ilhewl/CustomWidgets/collage.dart';
import 'package:ilhewl/CustomWidgets/custom_physics.dart';
import 'package:ilhewl/CustomWidgets/downloadButton.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:ilhewl/CustomWidgets/song_cache_icon.dart';
import 'package:ilhewl/Helpers/cache_provider.dart';
import 'package:ilhewl/Helpers/mediaitem_converter.dart';
import 'package:ilhewl/Screens/Library/showSongs.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/Helpers/songs_count.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';

class LikedSongs extends StatefulWidget {
  final String playlistName;
  final String showName;
  LikedSongs({Key key, @required this.playlistName, this.showName})
      : super(key: key);
  @override
  _LikedSongsState createState() => _LikedSongsState();
}

class _LikedSongsState extends State<LikedSongs> with SingleTickerProviderStateMixin {
  Box likedBox;
  bool added = false;
  List _songs = [];
  Map<String, List<Map>> _albums = {};
  Map<String, List<Map>> _artists = {};
  Map<String, List<Map>> _genres = {};
  List sortedAlbumKeysList = [];
  List sortedArtistKeysList = [];
  List sortedGenreKeysList = [];
  TabController _tcontroller;
  int currentIndex = 0;
  int sortValue = Hive.box('settings').get('playlistSortValue', defaultValue: 2);
  int albumSortValue = Hive.box('settings').get('albumSortValue', defaultValue: 2);
  CacheProvider cacheProvider;

  double walletBalance = 0.0;
  bool walletLoading = true;
  String currency = Hive.box('settings').get('currency') ?? "MRU";

  Future fetchWallet() async {
    Map wallet = await Api().fetchWalletData();
    walletBalance = double.parse(wallet["balance"]);
    walletLoading = false;
    setState(() {});
  }

  void callback() {
    setState(() {});
  }

  _handlePurchaseDialog(item) async {
    EasyLoading.show(status: "loading...");
    await fetchWallet();
    EasyLoading.dismiss();
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CachedNetworkImage(
                fit: BoxFit.cover,
                width: MediaQuery.of(context).size.width,
                errorWidget: (BuildContext context, _, __) => Image(
                  image: AssetImage('assets/cover.jpg'),
                ),
                placeholder: (BuildContext context, _) => Image(
                  image: AssetImage('assets/cover.jpg'),
                ),
                imageUrl: item.artUri != null ? item.artUri.toString() : "",
              ),
              ListTile(
                leading: new Icon(Icons.music_note),
                title: new Text(item.title),
                subtitle: Text(item.artist),
                trailing: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).accentColor,
                        ),
                        color: Theme.of(context).accentColor,
                        borderRadius: BorderRadius.all(Radius.circular(7))),
                    padding: EdgeInsets.only(left: 3.0, right: 3.0),
                    child: Text(
                      "${item.extras['price']} $currency",
                      style: TextStyle(color: Colors.black),
                    )),
              ),
              ListTile(
                tileColor: Theme.of(context).accentColor,
                leading: walletLoading
                    ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                    ))
                    : new Icon(Icons.account_balance_wallet_outlined),
                title: new Text(
                  '$walletBalance $currency',
                  style: TextStyle(
                      color: walletBalance < double.parse(item.extras['price'])
                          ? Colors.red
                          : Colors.black54),
                ),
                subtitle: Text(
                  walletBalance < double.parse(item.extras['price'])
                      ? "Recharge your wallet"
                      : "Your Wallet Balance",
                  style: TextStyle(color: Colors.black54),
                ),
                trailing: walletBalance < double.parse(item.extras['price'])
                    ? TextButton(
                  child: Text(
                    "Wallet",
                    style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                WalletPage(callback: callback)));
                  },
                )
                    : TextButton(
                  child: Text(
                    "Buy",
                    style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _handlePurchaseSong(item);
                  },
                ),
                onTap: () {
                  _handlePurchaseSong(item);
                },
              ),
              SizedBox(
                height: 50,
              )
            ],
          );
        });
  }

  Future<dynamic> _handlePurchaseSong(item) {
    return showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text("Are you sure?"),
          content: Text("You Want to buy " +
              item.title +
              " for " +
              item.extras['price'] +
              " " +
              currency +
              " ?"),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("CANCEL")),
            TextButton(
                onPressed: () {
                  _purchase(item);
                  Navigator.pop(context);
                },
                child: Text("YES")),
          ],
        ));
  }

  void _purchase(item) async {
    EasyLoading.show(status: "Wait...");
    Map result = await Api().purchaseSong(item);
    if (result['success']) {
      AudioService.skipToQueueItem(item.id);
      // Navigator.popUntil(context, (route) => route.settings.name == '/');
    }
    EasyLoading.dismiss();
  }


  @override
  void initState() {
    _tcontroller = TabController(length: 4, vsync: this);
    _tcontroller.addListener(changeTitle);
    getLiked();
    super.initState();
  }

  void changeTitle() {
    setState(() {
      currentIndex = _tcontroller.index;
    });
  }

  void getLiked() {
    likedBox = Hive.box(widget.playlistName);
    _songs = likedBox?.values?.toList() ?? [];

    AddSongsCount().addSong(
      widget.playlistName,
      _songs.length,
      _songs.length >= 4
          ? _songs.sublist(0, 4)
          : _songs.sublist(0, _songs.length),
    );
    setArtistAlbum();
  }

  void setArtistAlbum() {
    for (Map element in _songs) {
      if (_albums.containsKey(element['album'])) {
        List tempAlbum = _albums[element['album']];
        tempAlbum.add(element);
        _albums.addEntries([MapEntry(element['album'], tempAlbum)]);
      } else {
        _albums.addEntries([
          MapEntry(element['album'], [element])
        ]);
      }

      if (_artists.containsKey(element['artist'])) {
        List tempArtist = _artists[element['artist']];
        tempArtist.add(element);
        _artists.addEntries([MapEntry(element['artist'], tempArtist)]);
      } else {
        _artists.addEntries([
          MapEntry(element['artist'], [element])
        ]);
      }

      if (_genres.containsKey(element['genre'])) {
        List tempGenre = _genres[element['genre']];
        tempGenre.add(element);
        _genres.addEntries([MapEntry(element['genre'], tempGenre)]);
      } else {
        _genres.addEntries([
          MapEntry(element['genre'], [element])
        ]);
      }
    }

    sortSongs();

    sortedAlbumKeysList = _albums.keys.toList();
    sortedArtistKeysList = _artists.keys.toList();
    sortedGenreKeysList = _genres.keys.toList();

    sortAlbums();

    added = true;
    setState(() {});
  }

  sortSongs() {
    if (sortValue == 0) {
      _songs.sort((a, b) => a["title"]
          .toString()
          .toUpperCase()
          .compareTo(b["title"].toString().toUpperCase()));
    }
    if (sortValue == 1) {
      _songs.sort((b, a) => a["title"]
          .toString()
          .toUpperCase()
          .compareTo(b["title"].toString().toUpperCase()));
    }
    if (sortValue == 2) {
      _songs = likedBox.values.toList();
    }
    if (sortValue == 3) {
      _songs.shuffle();
    }
  }

  sortAlbums() {
    if (albumSortValue == 0) {
      sortedAlbumKeysList.sort((a, b) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      sortedArtistKeysList.sort((a, b) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      sortedGenreKeysList.sort((a, b) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
    }
    if (albumSortValue == 1) {
      sortedAlbumKeysList.sort((b, a) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      sortedArtistKeysList.sort((b, a) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
      sortedGenreKeysList.sort((b, a) =>
          a.toString().toUpperCase().compareTo(b.toString().toUpperCase()));
    }
    if (albumSortValue == 2) {
      sortedAlbumKeysList
          .sort((b, a) => _albums[a].length.compareTo(_albums[b].length));
      sortedArtistKeysList
          .sort((b, a) => _artists[a].length.compareTo(_artists[b].length));
      sortedGenreKeysList
          .sort((b, a) => _genres[a].length.compareTo(_genres[b].length));
    }
    if (albumSortValue == 3) {
      sortedAlbumKeysList
          .sort((a, b) => _albums[a].length.compareTo(_albums[b].length));
      sortedArtistKeysList
          .sort((a, b) => _artists[a].length.compareTo(_artists[b].length));
      sortedGenreKeysList
          .sort((a, b) => _genres[a].length.compareTo(_genres[b].length));
    }
    if (albumSortValue == 4) {
      sortedAlbumKeysList.shuffle();
      sortedArtistKeysList.shuffle();
      sortedGenreKeysList.shuffle();
    }
  }

  void deleteLiked(index) {
    likedBox.deleteAt(index);
    if (_albums[_songs[index]['album']].length == 1)
      sortedAlbumKeysList.remove(_songs[index]['album']);
    _albums[_songs[index]['album']].remove(_songs[index]);

    if (_artists[_songs[index]['artist']].length == 1)
      sortedArtistKeysList.remove(_songs[index]['artist']);
    _artists[_songs[index]['artist']].remove(_songs[index]);

    if (_genres[_songs[index]['genre']].length == 1)
      sortedGenreKeysList.remove(_songs[index]['genre']);
    _genres[_songs[index]['genre']].remove(_songs[index]);

    _songs.remove(_songs[index]);
    AddSongsCount().addSong(
      widget.playlistName,
      _songs.length,
      _songs.length >= 4
          ? _songs.sublist(0, 4)
          : _songs.sublist(0, _songs.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 4,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  title: Text(widget.showName == null
                      ? widget.playlistName[0].toUpperCase() +
                          widget.playlistName.substring(1)
                      : widget.showName[0].toUpperCase() +
                          widget.showName.substring(1)),
                  centerTitle: true,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.transparent
                          : Theme.of(context).accentColor,
                  elevation: 0,
                  bottom: TabBar(controller: _tcontroller, tabs: [
                    Tab(
                      text: 'Songs',
                    ),
                    Tab(
                      text: 'Albums',
                    ),
                    Tab(
                      text: 'Artists',
                    ),
                    Tab(
                      text: 'Genres',
                    ),
                  ]),
                  actions: [
                    if (_songs.isNotEmpty)
                      MultiDownloadButton(
                        data: _songs,
                      ),
                    PopupMenuButton(
                        icon: Icon(Icons.sort_rounded),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(7.0))),
                        onSelected: (currentIndex == 0)
                            ? (value) {
                                sortValue = value;
                                Hive.box('settings').put('sortValue', value);
                                sortSongs();
                                setState(() {});
                              }
                            : (value) {
                                albumSortValue = value;
                                Hive.box('settings')
                                    .put('albumSortValue', value);
                                sortAlbums();
                                setState(() {});
                              },
                        itemBuilder: (currentIndex == 0)
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
                                        Text('Last Added'),
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
                ),
                body: !added
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
                    : TabBarView(
                        physics: CustomPhysics(),
                        controller: _tcontroller,
                        children: [
                          _songs.length == 0
                              ? EmptyScreen().emptyScreen(
                                  context, false,
                                  3,
                                  "Nothing to ",
                                  15.0,
                                  "Show Here",
                                  50,
                                  "Go and Add Something",
                                  23.0)
                              : ListView.builder(
                                  physics: BouncingScrollPhysics(),
                                  padding: EdgeInsets.only(top: 10, bottom: 10),
                                  shrinkWrap: true,
                                  itemCount: _songs.length,
                                  itemExtent: 70.0,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                        leading: Card(
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(7.0),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: CachedNetworkImage(
                                            errorWidget: (context, _, __) =>
                                                Image(
                                              image: AssetImage(
                                                  'assets/cover.jpg'),
                                            ),
                                            imageUrl: _songs[index]['image']
                                                .replaceAll('http:', 'https:'),
                                            placeholder: (context, url) =>
                                                Image(
                                              image: AssetImage(
                                                  'assets/cover.jpg'),
                                            ),
                                          ),
                                        ),
                                        onTap: () {
                                          _songs[index]["selling"] == 1 && !_songs[index]["purchased"]
                                              ? _handlePurchaseDialog(_songs[index])
                                              :
                                          Navigator.of(context).push(
                                            PageRouteBuilder(
                                              opaque: false, // set to false
                                              pageBuilder: (_, __, ___) =>
                                                  PlayScreen(
                                                data: {
                                                  'index': index,
                                                  'response': _songs,
                                                  'offline': false,
                                                },
                                                fromMiniplayer: false,
                                              ),
                                            ),
                                          );
                                        },
                                        title: Text(
                                          '${_songs[index]['title']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${_songs[index]['artist'] ?? 'Artist name'}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _songs[index]['selling'] == 1 && !_songs[index]['purchased'] ?
                                            Container(
                                                decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Theme.of(context).accentColor,
                                                    ),
                                                    color: Theme.of(context).accentColor,
                                                    borderRadius: BorderRadius.all(Radius.circular(7))
                                                ),
                                                padding: EdgeInsets.only(left: 3.0, right: 3.0),
                                                child: Text(
                                                  "${_songs[index]['price']} $currency",
                                                  style: TextStyle(
                                                      color: Colors.black
                                                  ),
                                                )
                                            ) : SizedBox(),
                                            // DownloadButton(
                                            //     data: _songs[index],
                                            //     icon: 'download'),

                                            SongCacheIcon(song: _songs[index]),
                                            PopupMenuButton(
                                                icon: Icon(
                                                    Icons.more_vert_rounded),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                7.0))),
                                                itemBuilder: (context) => [
                                                      PopupMenuItem(
                                                        value: 0,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons
                                                                .delete_rounded),
                                                            Spacer(),
                                                            Text('Remove'),
                                                            Spacer(),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 1,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons
                                                                .playlist_add_rounded),
                                                            Spacer(),
                                                            Text(
                                                                'Add to Playlist'),
                                                            Spacer(),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                onSelected: (value) async {
                                                  if (value == 1) {
                                                    AddToPlaylist()
                                                        .addToPlaylist(
                                                            context,
                                                            MediaItemConverter()
                                                                .mapToMediaItem(
                                                                    _songs[
                                                                        index]));
                                                  }
                                                  if (value == 0) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        elevation: 6,
                                                        backgroundColor:
                                                            Colors.grey[900],
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        content: Text(
                                                          'Removed ${_songs[index]["title"]} from ${widget.playlistName}',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                        action: SnackBarAction(
                                                          textColor:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          label: 'Ok',
                                                          onPressed: () {},
                                                        ),
                                                      ),
                                                    );
                                                    setState(() {
                                                      deleteLiked(index);
                                                    });
                                                  }
                                                }),
                                          ],
                                        ));
                                  }),
                          albumsTab(),
                          artistsTab(),
                          genresTab()
                        ],
                      ),
              ),
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }

  albumsTab() {
    return sortedAlbumKeysList.length == 0
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0,
            "Show Here", 50, "Go and Add Something", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemCount: sortedAlbumKeysList.length,
            itemExtent: 70.0,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Collage(
                  imageList: _albums[sortedAlbumKeysList[index]].length >= 4
                      ? _albums[sortedAlbumKeysList[index]].sublist(0, 4)
                      : _albums[sortedAlbumKeysList[index]].sublist(
                          0, _albums[sortedAlbumKeysList[index]].length),
                  placeholderImage: 'assets/album.png',
                ),
                title: Text(
                  '${sortedAlbumKeysList[index]}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _albums[sortedAlbumKeysList[index]].length == 1
                      ? '${_albums[sortedAlbumKeysList[index]].length} Song'
                      : '${_albums[sortedAlbumKeysList[index]].length} Songs',
                ),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => SongsList(
                        data: _albums[sortedAlbumKeysList[index]],
                        offline: false,
                      ),
                    ),
                  );
                },
              );
            });
  }

  artistsTab() {
    return (sortedArtistKeysList.isEmpty)
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0,
            "Show Here", 50, "Go and Add Something", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemCount: sortedArtistKeysList.length,
            itemExtent: 70.0,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Collage(
                  imageList: _artists[sortedArtistKeysList[index]].length >= 4
                      ? _artists[sortedArtistKeysList[index]].sublist(0, 4)
                      : _artists[sortedArtistKeysList[index]].sublist(
                          0, _artists[sortedArtistKeysList[index]].length),
                  placeholderImage: 'assets/artist.png',
                ),
                title: Text('${sortedArtistKeysList[index]}',
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  _artists[sortedArtistKeysList[index]].length == 1
                      ? '${_artists[sortedArtistKeysList[index]].length} Song'
                      : '${_artists[sortedArtistKeysList[index]].length} Songs',
                ),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => SongsList(
                        data: _artists[sortedArtistKeysList[index]],
                        offline: false,
                      ),
                    ),
                  );
                },
              );
            });
  }

  genresTab() {
    return (sortedGenreKeysList.isEmpty)
        ? EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0,
            "Show Here", 50, "Go and Add Something", 23.0)
        : ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 20, bottom: 10),
            shrinkWrap: true,
            itemCount: sortedGenreKeysList.length,
            itemExtent: 70.0,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Collage(
                  imageList: _genres[sortedGenreKeysList[index]].length >= 4
                      ? _genres[sortedGenreKeysList[index]].sublist(0, 4)
                      : _genres[sortedGenreKeysList[index]].sublist(
                          0, _genres[sortedGenreKeysList[index]].length),
                  placeholderImage: 'assets/album.png',
                ),
                title: Text(
                  '${sortedGenreKeysList[index]}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _genres[sortedGenreKeysList[index]].length == 1
                      ? '${_genres[sortedGenreKeysList[index]].length} Song'
                      : '${_genres[sortedGenreKeysList[index]].length} Songs',
                ),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false, // set to false
                      pageBuilder: (_, __, ___) => SongsList(
                        data: _genres[sortedGenreKeysList[index]],
                        offline: false,
                      ),
                    ),
                  );
                },
              );
            });
  }
}
