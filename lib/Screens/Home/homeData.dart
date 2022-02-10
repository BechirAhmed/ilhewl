import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/format.dart';
import 'package:ilhewl/Screens/Common/song_list.dart';
import 'package:ilhewl/Screens/Home/allSongs.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/saavnApi.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

bool fetched = false;
List preferredLanguage = Hive.box('settings').get('preferredLanguage') ?? ['English'];
String currency = Hive.box('settings').get('currency') ?? "MRU";
Map data = Hive.box('cache').get('homepage', defaultValue: {});
List lists = [...?data["collections"]];

class HomeData extends StatefulWidget {
  @override
  _HomeDataState createState() => _HomeDataState();
}

class _HomeDataState extends State<HomeData> with AutomaticKeepAliveClientMixin<HomeData> {
  double walletBalance = 0.0;
  bool walletLoading = true;
  bool isFirstLoad = true;

  void callback() {
    setState(() {});
  }

  @override
  void initState() {
    requestPermission();
    super.initState();
  }

  void requestPermission() async {
    var status = await Permission.notification.request();
    if(status.isGranted){
      print("Granted");
    }
    if(status.isDenied){
      if(await Permission.notification.request().isPermanentlyDenied){
        status = await Permission.notification.request();
        if(status.isGranted){
          print("Granted");
        }else{
          openAppSettings();
        }
      }
    }
  }

  void getHomePageData() async {

    // Hive.box('cache').delete('cachedDownloadedSongs');

    EasyLoading.show(status: "Loading...");
    Map recievedData = await Api().fetchHomePageData();

    if (recievedData != null && recievedData.isNotEmpty) {
      Hive.box('cache').put('homepage', recievedData);
      data = recievedData;
      lists = [...?data["collections"]];
      // lists = ["recent", ...?data["collections"]];
    }
    setState(() {});
    EasyLoading.dismiss();
  }

  void fetchWallet() async {
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
                  _handlePurchaseSong(album);
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
    if(result != null && result['success']){
      Navigator.popUntil(context, (route) => route.settings.name == '/');
      getHomePageData();
    }
    EasyLoading.showError("Something went wrong!");
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
    } else if (type == "album") {
      return formatString('${item["song_count"]} Song(s)');
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

  Future<void> _pullRefresh() async {
    getHomePageData();
  }

  getPlayableSongs(_songs) {
    List _playableSongs = [];
    _songs.forEach((item) {
      if((item['selling'] == 1 && item['purchased']) || item['selling'] == 0){
        if((_playableSongs.firstWhere((el) => el['id'] == item['id'], orElse: () => null)) != null){

        }else{
          _playableSongs.add(item);
        }
      }
    });

    return _playableSongs;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!fetched) {
      getHomePageData();
      fetched = true;
    }
    return RefreshIndicator(
      child: ListView.builder(
        physics: BouncingScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
        scrollDirection: Axis.vertical,
        itemCount: data.isEmpty ? 0 : lists.length,
        itemBuilder: (context, idx) {
          return Column(
            children: [
              data[lists[idx]].length < 1
                ? SizedBox()
                : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 0, 5),
                    child: Text(
                      '${formatString(data['modules'][lists[idx]]["title"])}',
                      style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if(data['modules'][lists[idx]]["see_all"])
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 10, 5, 5),
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (_, __, ___) => AllSongs(
                                title: "All Songs",
                                api: data['modules'][lists[idx]]["see_all_api"],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: Theme.of(context).accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              data[lists[idx]].length < 1
                  ? SizedBox()
                  : SizedBox(
                      height: MediaQuery.of(context).size.height / 4 + 5,
                      child: ListView.builder(
                        physics: BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                        itemCount: data[lists[idx]].length,
                        itemBuilder: (context, index) {
                          final item = data[lists[idx]][index];
                          final currentSongList = data[lists[idx]].where((e) => (e["type"] == 'song')).toList();
                          final _playableSongs = getPlayableSongs(data[lists[idx]].where((e) => (e["type"] == 'song')).toList());
                          final subTitle = getSubTitle(item);
                          if (item.isEmpty) return const SizedBox();
                          return GestureDetector(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.height / 4 - 60,
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Card(
                                        elevation: 5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: item['type'] == 'artist' ? BorderRadius.circular(100.0) : BorderRadius.circular(10.0),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: CachedNetworkImage(
                                          errorWidget: (context, _, __) => Image(
                                            image: AssetImage('assets/cover.jpg'),
                                          ),
                                          imageUrl: item["artwork_url"] != null ? item["artwork_url"].replaceAll('http:', 'https:') : "",
                                          placeholder: (context, url) => Image(
                                            image: (item["type"] == 'playlist' || item["type"] == 'album')
                                                ? AssetImage('assets/album.png')
                                                : item["type"] == 'artist'
                                                    ? AssetImage('assets/artist.png')
                                                    : AssetImage('assets/song.png'),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      item['selling'] == 1 && !item['purchased'] ?
                                      Positioned(
                                        right: 10,
                                        top: 10,
                                        child: Container(
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
                                      ) : SizedBox()
                                    ],
                                  ),
                                  Text(
                                    '${formatString(item["title"] ?? item['name'])}',
                                    textAlign: TextAlign.center,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13
                                    ),
                                  ),
                                  subTitle != '' && item['type'] == 'song'
                                      ? Text(
                                          subTitle,
                                          textAlign: TextAlign.center,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .caption
                                                  .color),
                                        )
                                      : SizedBox(),
                                ],
                              ),
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
                                        imageUrl: item['artwork_url']
                                            .toString()
                                            .replaceAll('http:', 'https:')
                                            .replaceAll('50x50', '500x500')
                                            .replaceAll('150x150', '500x500'),
                                        placeholder: (context, url) => Image(
                                          image: (item['type'] == 'playlist' ||
                                              item['type'] == 'album')
                                              ? const AssetImage('assets/album.png')
                                              : item['type'] == 'artist'
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
                              item["selling"] == 1 && !item["purchased"]
                                ? _handlePurchaseDialog(item)
                                :
                                  // DefaultCacheManager().removeFile(item['cacheKey']);
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      pageBuilder: (_, __, ___) => item["type"] ==
                                              "song"
                                          ? PlayScreen(
                                              data: {
                                                'response': _playableSongs,
                                                'index': _playableSongs.indexWhere(
                                                        (e) => (e["id"] == item['id'])),
                                                'offline': false,
                                              },
                                              fromMiniplayer: false,
                                            )
                                          : SongsListPage(
                                              listImage: item["artwork_url"],
                                              listItem: item,
                                            ),
                                    ),
                                  );
                            },
                          );
                        },
                      ),
                    ),
            ],
          );
          }),
      onRefresh: _pullRefresh,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
