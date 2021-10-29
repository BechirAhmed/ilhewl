import 'dart:developer';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/format.dart';
import 'package:ilhewl/Screens/Common/song_list.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/saavnApi.dart';
import 'package:ilhewl/Services/song_provider.dart';
import 'package:provider/provider.dart';

bool fetched = false;
List preferredLanguage = Hive.box('settings').get('preferredLanguage') ?? ['English'];
String currency = Hive.box('settings').get('currency') ?? "MRU";
Map data = Hive.box('cache').get('homepage', defaultValue: {});
List lists = [...?data["collections"]];

class HomeData extends StatefulWidget {
  @override
  _HomeDataState createState() => _HomeDataState();
}

class _HomeDataState extends State<HomeData> {
  List recentList = Hive.box('recentlyPlayed').get('recentSongs', defaultValue: []);

  double walletBalance = 0.0;
  bool walletLoading = true;

  void callback() {
    setState(() {});
  }

  void getHomePageData() async {

    SongProvider songProvider = context.watch();
    // Hive.box('cache').delete('cachedDownloadedSongs');

    EasyLoading.show(status: "Loading...");
    Map recievedData = await Api().fetchHomePageData();

    if (recievedData != null && recievedData.isNotEmpty) {
      Hive.box('cache').put('homepage', recievedData);
      data = recievedData;
      lists = [...?data["collections"]];
      songProvider.init(data['latests']);
      // lists = ["recent", ...?data["collections"]];
    }
    setState(() {});
    EasyLoading.dismiss();
  }

  void fetchWallet() async {
    Map wallet = await Api().fetchWalletData();
    walletBalance = double.parse(wallet["balance"]);
    walletLoading = false;
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
              ),
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
                trailing: walletBalance < double.parse(item['price']) ? TextButton(
                  child: Text("Wallet", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                WalletPage(callback: callback)));
                  },
                ) : TextButton(
                  child: Text("Buy", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),),
                  onPressed: () {
                    _handlePurchaseSong(item);
                  },
                ),
                onTap: () {
                  _handlePurchaseSong(item);
                },
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
      Navigator.popUntil(context, (route) => route.settings.name == '/');
      getHomePageData();
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

  Future<void> _pullRefresh() async {
    Provider.of<SongProvider>(context, listen: false);
    getHomePageData();
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
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
                ],
              ),
              data[lists[idx]] == null
                  ? SizedBox(
                      height: MediaQuery.of(context).size.height / 4 + 5,
                      child: ListView.builder(
                        physics: BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                        itemCount: 10,
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: MediaQuery.of(context).size.height / 4 - 30,
                            child: Column(
                              children: [
                                Card(
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image(
                                    image: AssetImage('assets/cover.jpg'),
                                  ),
                                ),
                                Text(
                                  'Loading ...',
                                  textAlign: TextAlign.center,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Please Wait',
                                  textAlign: TextAlign.center,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .textTheme
                                          .caption
                                          .color),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
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
                          final subTitle = getSubTitle(item);
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
                                                'response': currentSongList,
                                                'index': currentSongList.indexWhere(
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
}
