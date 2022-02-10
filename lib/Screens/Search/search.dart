import 'dart:ui';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/add_queue.dart';
import 'package:ilhewl/CustomWidgets/downloadButton.dart';
import 'package:ilhewl/Screens/Common/song_list.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Screens/Search/albums.dart';
import 'package:ilhewl/Screens/Search/artists.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:ilhewl/APIs/saavnApi.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

Map data = Hive.box('cache').get('homepage', defaultValue: {});
List lists = [...?data["collections"]];
String currency = Hive.box('settings').get('currency') ?? "MRU";

class SearchPage extends StatefulWidget {
  final String query;
  SearchPage({Key key, @required this.query}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  bool status = false;
  Map<String, List> searchedData = {};
  Map<int, String> position = {};
  List<int> sortedKeys = [];
  List topSearch = [];
  bool fetched = false;
  bool albumFetched = false;
  List search = Hive.box('settings').get('search', defaultValue: []);
  bool showHistory = Hive.box('settings').get('showHistory', defaultValue: true);
  FloatingSearchBarController _controller = FloatingSearchBarController();
  List _playableSongs = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double walletBalance = 0.0;
  bool walletLoading = true;

  void fetchWallet() async {
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
      getResultsData();
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

  void getResultsData() async {
    EasyLoading.show(status: "Loading...");
    Map receivedData = await Api().fetchSongSearchResults(query == '' ? widget.query : query);
    if (receivedData != null && receivedData.isNotEmpty) {
      data = receivedData;
      lists = [...?data["collections"]];
    }
    data['songs'].forEach((item) {
      if((item['selling'] == 1 && item['purchased']) || item['selling'] == 0){
        if((_playableSongs.firstWhere((el) => el['id'] == item['id'], orElse: () => null)) != null){

        }else{
          _playableSongs.add(item);
        }
      }
    });
    setState(() {});
    EasyLoading.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (!fetched) {
      getResultsData();
      fetched = true;
    }

    return GradientContainer(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  backgroundColor: Colors.transparent,
                  body: FloatingSearchBar(
                    borderRadius: BorderRadius.circular(10.0),
                    controller: _controller,
                    automaticallyImplyBackButton: false,
                    automaticallyImplyDrawerHamburger: false,
                    elevation: 8.0,
                    insets: EdgeInsets.zero,
                    leadingActions: [
                      FloatingSearchBarAction.icon(
                        showIfClosed: true,
                        showIfOpened: true,
                        size: 20.0,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? null
                              : Colors.grey[700],
                        ),
                        onTap: () {
                          _controller.isOpen
                              ? _controller.close()
                              : Navigator.of(context).pop();
                        },
                      ),
                    ],
                    hint: 'Songs, albums or artists',
                    height: 52.0,
                    margins: EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 15.0),
                    scrollPadding: EdgeInsets.only(bottom: 50),
                    backdropColor: Colors.black12,
                    transitionCurve: Curves.easeInOut,
                    physics: BouncingScrollPhysics(),
                    axisAlignment: 0.0,
                    openAxisAlignment: 0.0,
                    clearQueryOnClose: false,
                    debounceDelay: Duration(milliseconds: 500),
                    // onQueryChanged: (_query) {
                    // print(_query);
                    // },
                    onFocusChanged: (isFocused) async {
                      topSearch = await Api().getTopSearches();
                      setState(() {});
                    },
                    onSubmitted: (_query) {
                      _controller.close();

                      setState(() {
                        fetched = false;
                        query = _query;
                        status = false;
                        data = {};
                        if (search.contains(_query)) search.remove(_query);
                        search.insert(0, _query);
                        if (search.length > 5) search = search.sublist(0, 5);
                        Hive.box('settings').put('search', search);
                      });
                    },
                    transition:
                    // CircularFloatingSearchBarTransition(),
                    SlideFadeFloatingSearchBarTransition(),
                    actions: [
                      FloatingSearchBarAction(
                        showIfOpened: false,
                        child: CircularButton(
                          icon: Icon(CupertinoIcons.search),
                          onPressed: () {},
                        ),
                      ),
                      FloatingSearchBarAction(
                        showIfOpened: true,
                        showIfClosed: false,
                        child: CircularButton(
                          icon: Icon(
                            CupertinoIcons.clear,
                            size: 20.0,
                          ),
                          onPressed: () {
                            _controller.clear();
                          },
                        ),
                      ),
                    ],
                    builder: (context, transition) {
                      return Column(
                        children: [
                          if (showHistory)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: GradientCard(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: search
                                        .map((e) => ListTile(
                                      // dense: true,
                                        horizontalTitleGap: 0.0,
                                        title: Text(e),
                                        leading: Icon(CupertinoIcons.search),
                                        trailing: IconButton(
                                            icon: Icon(
                                              CupertinoIcons.clear,
                                              size: 15.0,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                search.remove(e);
                                                Hive.box('settings')
                                                    .put('search', search);
                                              });
                                            }),
                                        onTap: () {
                                          _controller.close();

                                          setState(() {
                                            fetched = false;
                                            query = e;
                                            status = false;
                                            data = {};

                                            search.remove(e);
                                            search.insert(0, e);
                                            Hive.box('settings')
                                                .put('search', search);
                                          });
                                        }))
                                        .toList()),
                              ),
                            ),
                          if (topSearch.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: GradientCard(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: topSearch
                                        .map((e) => ListTile(
                                        horizontalTitleGap: 0.0,
                                        title: Text(e),
                                        leading:
                                        Icon(Icons.trending_up_rounded),
                                        onTap: () {
                                          _controller.close();
                                          setState(() {
                                            fetched = false;
                                            query = e;
                                            status = false;
                                            data = {};
                                            search.insert(0, e);
                                            Hive.box('settings').put('search', search);
                                          });
                                        }))
                                        .toList()),
                              ),
                            ),
                        ],
                      );
                    },
                    body: !fetched
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
                        : (data.isEmpty)
                        ? EmptyScreen().emptyScreen(context, false, 0, ":( ", 100,
                        "SORRY", 60, "Results Not Found", 20)
                        : SingleChildScrollView(
                        padding: EdgeInsets.only(top: 80),
                        physics: BouncingScrollPhysics(),
                        child: ListView.builder(
                            physics: BouncingScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
                            scrollDirection: Axis.vertical,
                            itemCount: data.isEmpty ? 0 : lists.length,
                            itemBuilder: (context, idx) {
                              return Column(
                                children: [
                                  data[lists[idx]].length <= 0
                                    ? SizedBox()
                                    : Row(
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
                    ),
                  ),
                ),
              ),
              MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}
