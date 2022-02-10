import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/downloadButton.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/CustomWidgets/like_button.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/Helpers/mediaitem_converter.dart';
import 'package:ilhewl/Helpers/newFormat.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:ilhewl/Services/download.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:ilhewl/Helpers/app_config.dart';

List dataSongs =  Hive.box('cache').get("allSongs", defaultValue: []);
int _pageKey = Hive.box("cache").get("_pageKey", defaultValue: 1);

class AllSongs extends StatefulWidget {
  String api;
  final String title;
  AllSongs({Key key, @required this.api, this.title})
      : super(key: key);
  @override
  _AllSongsState createState() => _AllSongsState();
}

class _AllSongsState extends State<AllSongs> {
  List _songs = [];
  List _playableSongs = [];
  bool loading = false;
  bool allLoaded = false;
  List original = [];
  bool offline = false;
  bool added = false;
  bool processStatus = false;
  int sortValue = Hive.box('settings').get('sortValue') ?? 2;
  String currency = Hive.box('settings').get('currency') ?? "MRU";
  String token = Hive.box("settings").get("token");
  Box downloadsBox = Hive.box('downloads');
  Map<String, String> headers = {};

  bool isFirstLoad = true;

  final ScrollController _scrollController = ScrollController();

  final PagingController _pagingController = PagingController(firstPageKey: 0);

  @override
  void initState() {
    // Hive.box("cache").delete("_pageKey");
    super.initState();
    _scrollController.addListener(() {
      if(_scrollController.position.pixels >= _scrollController.position.maxScrollExtent && !loading){
        _fetchPage(_pageKey);
      }
    });

    _songs = dataSongs;
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    if(allLoaded){
      return;
    }
    setState(() {
      loading = true;
    });
    print(pageKey);

    final _url = widget.api+'?page='+pageKey.toString();
    headers = {"Accept": "application/json", 'Authorization': 'Bearer $token'};
    final str = "${Api().apiStr}/${widget.api}";
    final _fullUrl = Uri.https(Api().baseUrl, str, {'page': pageKey.toString()});
    try {
      final res = await get(_fullUrl, headers: headers);
      final data = json.decode(res.body);

      final songs = await NewFormatResponse().formatSongsInList(data['data'], false);

      if(songs.isNotEmpty){
        if(_pageKey <= data['last_page']) {
          setState(() {
            _pageKey = _pageKey + 1;
          });
        }

        songs.forEach((element) {
          if((dataSongs.firstWhere((item) => item['id'] == element['id'], orElse: () => null)) != null){

          }else{
            _songs.add(element);

            Hive.box("cache").put("allSongs", _songs);
            Hive.box("cache").put("_pageKey", _pageKey);
          }
        });

        _songs.forEach((item) {
          if((item['selling'] == 1 && item['purchased']) || item['selling'] == 0){
            if((_playableSongs.firstWhere((el) => el['id'] == item['id'], orElse: () => null)) != null){

            }else{
              _playableSongs.add(item);
            }
          }
        });
      }

      setState(() {
        loading = false;
        allLoaded = songs.isEmpty;
      });

    } catch (error) {
      print("T: ${error}");
      _pagingController.error = error;
    }

    added = true;
    sortSongs();

    processStatus = true;

    setState(() {});
  }

  void getSongs() async {
    EasyLoading.show(status: "Loading...");
    final response = await Api().getResponse(widget.api);

    if (response != null) {
      var body = json.decode(response.body);

      _songs = await NewFormatResponse().formatSongsInList(body['data'], false);

      EasyLoading.dismiss();
    } else {
      EasyLoading.dismiss();
      throw Exception('Failed to load Data');
    }
    added = true;
    sortSongs();

    processStatus = true;

    setState(() {});
  }

  sortSongs() {
    if (sortValue == 0) {
      _songs.sort((a, b) => a["title"].toUpperCase().compareTo(b["title"].toUpperCase()));
    }
    if (sortValue == 1) {
      _songs.sort((b, a) => a["title"].toUpperCase().compareTo(b["title"].toUpperCase()));
    }
    if (sortValue == 2) {
      _songs.sort((b, a) => a["release_date"].compareTo(b["release_date"]));
    }
    if (sortValue == 3) {
      _songs.shuffle();
    }
  }
  void callback() {
    setState(() {});
  }

  double walletBalance = 0.0;
  bool walletLoading = true;

  Future fetchWallet() async {
    Map wallet = await Api().fetchWalletData();
    walletBalance = double.parse(wallet["balance"]);
    walletLoading = false;
    isFirstLoad = false;
    setState(() {});
  }

  _handlePurchaseDialog(item) async {
    if(isFirstLoad){
      EasyLoading.show(status: "loading...");
      await fetchWallet();
      EasyLoading.dismiss();
    }

    bool isAlbumForSell = false;

    Map album = item["album_model"];
    if(album != null){
      if(album["selling"] == 1){
        isAlbumForSell = true;
      }
      setState(() {});
    }

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
                errorWidget:
                    (BuildContext context,
                    _,
                    __) =>
                    Image(
                      image: AssetImage(
                          'assets/cover.jpg'),
                    ),
                placeholder:
                    (BuildContext context,
                    _) =>
                    Image(
                      image: AssetImage(
                          'assets/cover.jpg'),
                    ),
                imageUrl: item["artwork_url"] != null ? item["artwork_url"]
                    .replaceAll('http:', 'https:') : "",
              ),
              ListTile(
                leading: new Icon(Icons.music_note),
                title: new Text(item['title']),
                subtitle: Text(getSubTitle(item)),
                trailing: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).accentColor,
                        ),
                        color: Theme.of(context).accentColor,
                        borderRadius: BorderRadius.all(Radius.circular(7))
                    ),
                    padding: EdgeInsets.only(left: 3.0, right: 3.0),
                    child: Text(
                      "${item['price']} $currency",
                      style: TextStyle(
                          color: Colors.black
                      ),
                    )
                ),
                onTap: () {
                  _handlePurchaseSong(item);
                },
              ),
              isAlbumForSell ?
              ListTile(
                leading: new Icon(Icons.album),
                title: new Text("Or Buy the whole album"),
                subtitle: Text("${album['title']} (${album["song_count"]})"),
                trailing: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).accentColor,
                        ),
                        color: Theme.of(context).accentColor,
                        borderRadius: BorderRadius.all(Radius.circular(7))
                    ),
                    padding: EdgeInsets.only(left: 3.0, right: 3.0),
                    child: Text(
                      "${album['price']} $currency",
                      style: TextStyle(
                          color: Colors.black
                      ),
                    )
                ),
                onTap: () {
                  _handlePurchaseSong(item);
                },
              ) : SizedBox(),
              ListTile(
                tileColor: Theme.of(context).accentColor,
                leading: walletLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black,)) : new Icon(Icons.account_balance_wallet_outlined),
                title: new Text(
                  '$walletBalance $currency',
                  style: TextStyle(
                      color: walletBalance < double.parse(item['price']) ? Colors.white : Colors.black54
                  ),
                ),
                subtitle: Text(
                  walletBalance < double.parse(item['price']) ? "Recharge your wallet" : "Your Wallet Balance",
                  style: TextStyle(
                      color: Colors.black54
                  ),
                ),
                trailing: TextButton(
                  child: Text("Wallet", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                WalletPage(callback: callback)));
                  },
                ),
                // onTap: () {
                //   _handlePurchaseSong(item);
                // },
              ),
              SizedBox(height: 50,)
            ],
          );
        });
  }

  Future<dynamic> _handlePurchaseSong(item){
    return showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text("Are you sure?"),
          content: Text("You Want to buy "+ item['title']+" for "+ item['price']+" "+ currency+" ?"),
          actions: [
            TextButton(
                onPressed: (){
                  Navigator.pop(context);
                },
                child: Text("CANCEL")
            ),
            TextButton(
                onPressed: (){
                  _purchase(item);
                  Navigator.pop(context);
                },
                child: Text("YES")
            ),
          ],
        )
    );
  }

  void _purchase(item) async {
    EasyLoading.show(status: "Wait...");
    Map result = await Api().purchaseSong(item);
    if(result['success']){
      Navigator.of(context).pop();
      // getSongs();
      _songs.map((el) => {
        if(el['id'] == item['id']){
          el['purchased'] = true,
          setState(() {})
        }
      });
    }
    EasyLoading.dismiss();
  }


  String getSubTitle(Map item) {
    final type = item['type'];
    if (type == 'genres') {
      return formatString(item['name']);
    } else if (type == 'moods') {
      return formatString(item['name']);
    } else if (type == 'radio_station') {
      return "Artist Radio";
    } else if (type == "song") {
      return formatString(item["artist"]);
    } else {
      return formatString(item['name']);
      // final artists = item['artists']
      //     .map((artist) => artist['name'])
      //     .toList();
      // return formatString(artists.join(', '));
    }
  }

  String formatString(String text) {
    return text == null
        ? ''
        : text
        .toString()
        .replaceAll("&amp;", "&")
        .replaceAll("&#039;", "'")
        .replaceAll("&quot;", "\"")
        .trim();
  }


  @override
  Widget build(BuildContext context) {
    if (!added) {
      _fetchPage(1);
      // _pagingController.addPageRequestListener((pageKey) {
      //   _fetchPage(pageKey);
      // });
    }
    AppConfig().init(context);
    return GradientContainer(
      child: Column(
        children: [
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(widget.title ?? 'All Songs'),
                actions: [
                  PopupMenuButton(
                      icon: Icon(Icons.sort_rounded),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(7.0))),
                      onSelected: (value) {
                        sortValue = value;
                        Hive.box('settings').put('sortValue', value);
                        sortSongs();
                        setState(() {});
                      },
                      itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 0,
                              child: Row(
                                children: [
                                  sortValue == 0
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(context).brightness ==
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
                                          color: Theme.of(context).brightness ==
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
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.grey[700],
                                        )
                                      : SizedBox(),
                                  SizedBox(width: 10),
                                  Text(
                                      offline ? 'Last Modified' : 'Release Date'),
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
                                          color: Theme.of(context).brightness ==
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
                          ])
                ],
                centerTitle: true,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.transparent
                    : Theme.of(context).accentColor,
                elevation: 0,
              ),
              body: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                                padding: EdgeInsets.only(top: 0, bottom: 0, left: 10, right: 10),
                                // decoration: BoxDecoration(
                                //   borderRadius: BorderRadius.circular(50.0),
                                //   color: Theme.of(context).accentColor,
                                //   boxShadow: [
                                //     BoxShadow(
                                //       color: Colors.black26,
                                //       blurRadius: 5.0,
                                //       spreadRadius: 0.0,
                                //       offset: Offset(0.0, 3.0),
                                //     )
                                //   ],
                                // ),
                                child: TextButton.icon(
                                  icon: Icon(Icons.play_arrow, color: Theme.of(context).accentColor),
                                  label: Text("Play", style: TextStyle(color: Theme.of(context).accentColor, fontWeight: FontWeight.bold),),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        opaque: false, // set to false
                                        pageBuilder: (_, __, ___) => PlayScreen(
                                          data: {
                                            'response': _playableSongs,
                                            'index': 0,
                                            'offline': offline
                                          },
                                          fromMiniplayer: false,
                                        ),
                                      ),
                                    );
                                  },
                                )
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Container(
                                padding: EdgeInsets.only(top: 0, bottom: 0, left: 10, right: 10),
                                // decoration: BoxDecoration(
                                //   borderRadius: BorderRadius.circular(50.0),
                                //   color: Theme.of(context).accentColor,
                                //   boxShadow: [
                                //     BoxShadow(
                                //       color: Colors.black26,
                                //       blurRadius: 5.0,
                                //       spreadRadius: 0.0,
                                //       offset: Offset(0.0, 3.0),
                                //     )
                                //   ],
                                // ),
                                child: TextButton.icon(
                                  icon: Icon(Icons.shuffle_rounded, color: Theme.of(context).accentColor),
                                  label: Text("Shuffle", style: TextStyle(color: Theme.of(context).accentColor, fontWeight: FontWeight.bold),),
                                  onPressed: () {
                                    _playableSongs.shuffle();
                                    setState(() {});
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        opaque: false, // set to false
                                        pageBuilder: (_, __, ___) => PlayScreen(
                                          data: {
                                            'response': _playableSongs,
                                            'index': 0,
                                            'offline': offline
                                          },
                                          fromMiniplayer: false,
                                        ),
                                      ),
                                    );
                                  },
                                )
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            ListView.builder(
                                controller: _scrollController,
                                physics: BouncingScrollPhysics(),
                                padding: EdgeInsets.only(top: 10, bottom: 10),
                                shrinkWrap: true,
                                itemCount: _songs.length + (allLoaded?1:0),
                                itemExtent: 70.0,
                                itemBuilder: (context, index) {
                                  if(index < _songs.length) {
                                    return _songs.length == 0
                                        ? SizedBox()
                                        : ListTile(
                                            leading: Card(
                                              elevation: 5,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(7.0),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: CachedNetworkImage(
                                                      errorWidget: (context, _, __) =>
                                                          Image(
                                                        image:
                                                            AssetImage('assets/cover.jpg'),
                                                      ),
                                                      imageUrl: _songs[index]['artwork_url']
                                                          .replaceAll('http:', 'https:'),
                                                      placeholder: (context, url) => Image(
                                                        image:
                                                            AssetImage('assets/cover.jpg'),
                                                      ),
                                                    ),
                                            ),
                                            title: Text(
                                              '${_songs[index]['title']}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              "${_songs[index]['artist']} - ${_songs[index]['album']}",
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: _songs[index]['selling'] == 1 && !_songs[index]['purchased'] ?
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
                                            ) : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                LikeButton(
                                                  mediaItem: MediaItemConverter().mapToMediaItem(_songs[index]),
                                                ),
                                                if(downloadsBox.containsKey(_songs[index]['id'].toString()))
                                                  SizedBox()
                                                else
                                                  DownloadButton(
                                                    icon: 'download',
                                                    data: {
                                                      'id': MediaItemConverter().mapToMediaItem(_songs[index]).id.toString(),
                                                      'artist': MediaItemConverter().mapToMediaItem(_songs[index]).artist.toString(),
                                                      'album': MediaItemConverter().mapToMediaItem(_songs[index]).album.toString(),
                                                      'image': MediaItemConverter().mapToMediaItem(_songs[index]).artUri.toString(),
                                                      'duration': MediaItemConverter().mapToMediaItem(_songs[index]).duration.inSeconds.toString(),
                                                      'title': MediaItemConverter().mapToMediaItem(_songs[index]).title.toString(),
                                                      'url': MediaItemConverter().mapToMediaItem(_songs[index]).extras['url'].toString(),
                                                      'genre': MediaItemConverter().mapToMediaItem(_songs[index]).genre.toString(),
                                                      'has_lyrics': MediaItemConverter().mapToMediaItem(_songs[index]).extras['has_lyrics'],
                                                      'release_date': MediaItemConverter().mapToMediaItem(_songs[index]).extras['release_date'],
                                                      'album_id': MediaItemConverter().mapToMediaItem(_songs[index]).extras['album_id'],
                                                    }
                                                  )
                                              ],
                                            ),
                                            onLongPress: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    backgroundColor: Colors.transparent,
                                                    contentPadding: EdgeInsets.zero,
                                                    content: Card(
                                                      elevation: 5,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(15.0),
                                                      ),
                                                      clipBehavior: Clip.antiAlias,
                                                      child: CachedNetworkImage(
                                                        fit: BoxFit.cover,
                                                        errorWidget: (context, _, __) =>
                                                        const Image(
                                                          image: AssetImage('assets/cover.jpg'),
                                                        ),
                                                        imageUrl: _songs[index]['artwork_url']
                                                            .toString()
                                                            .replaceAll('http:', 'https:'),
                                                        placeholder: (context, url) => Image(
                                                          image: (_songs[index]['type'] == 'playlist' ||
                                                              _songs[index]['type'] == 'album')
                                                              ? const AssetImage('assets/album.png')
                                                              : _songs[index]['type'] == 'artist'
                                                              ? const AssetImage(
                                                              'assets/artist.png')
                                                              : const AssetImage(
                                                              'assets/cover.jpg'),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            onTap: () {
                                              _songs[index]["selling"] == 1 && !_songs[index]["purchased"]
                                                  ? _handlePurchaseDialog(_songs[index])
                                                  :
                                              Navigator.of(context).push(
                                                PageRouteBuilder(
                                                  opaque: false, // set to false
                                                  pageBuilder: (_, __, ___) => PlayScreen(
                                                    data: {
                                                      'response': _playableSongs,
                                                      'index': _playableSongs.indexOf(_songs[index]),
                                                      'offline': offline
                                                    },
                                                    fromMiniplayer: false,
                                                  ),
                                                ),
                                              );
                                            },
                                          );

                                  } else {
                                    return Container(
                                      width: AppConfig.screenWidth,
                                      height: 50,
                                      child: Center(
                                        child: Text("Nothing more to load!", style: TextStyle(color: Colors.white60),),
                                      ),
                                    );
                                  }
                            }),
                            if(loading)...[
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: Container(
                                  height: 60,
                                  width: AppConfig.screenWidth,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).accentColor),
                                      strokeWidth: 5,
                                    ),
                                  ),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }
}
