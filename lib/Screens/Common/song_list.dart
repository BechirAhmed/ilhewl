import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/CustomWidgets/add_queue.dart';
import 'package:ilhewl/CustomWidgets/downloadButton.dart';
import 'package:ilhewl/Screens/Player/oldaudioplayer.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:ilhewl/APIs/saavnApi.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';

class SongsListPage extends StatefulWidget {
  final Map listItem;
  final String listImage;

  SongsListPage({
    Key key,
    @required this.listItem,
    this.listImage,
  }) : super(key: key);

  @override
  _SongsListPageState createState() => _SongsListPageState();
}

class _SongsListPageState extends State<SongsListPage> {
  bool status = false;
  List songList = [];
  bool fetched = false;
  HtmlUnescape unescape = HtmlUnescape();
  double walletBalance = 0.0;
  bool walletLoading = true;
  String currency = Hive.box('settings').get('currency') ?? "MRU";


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
                      color: Colors.black54
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
    if (!status) {
      status = true;
      switch (widget.listItem['type']) {
        case 'mood':
          Api().fetchMoodSongs(widget.listItem['alt_name'])
              .then((value) {
            setState(() {
              songList = value;
              fetched = true;
            });
          });
          break;
        case 'genre':
          Api().fetchGenreSongs(widget.listItem['alt_name']).then((value) {
            setState(() {
              songList = value;
              fetched = true;
            });
          });
          break;
        case 'artist':
          Api().fetchArtistSongs("auth/artist", widget.listItem['id'].toString()).then((value) {
            setState(() {
              songList = value['songs']['data'];
              fetched = true;
            });
          });
          break;
        default:
          break;
      }
    }
    return GradientContainer(
      child: Column(
        children: [
          Expanded(
            child: Scaffold(
                backgroundColor: Colors.transparent,
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
                    : songList.isEmpty
                        ? EmptyScreen().emptyScreen(context, true, 0, ":( ", 100,
                            "SORRY", 60, "Results Not Found", 20)
                        : CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                                SliverAppBar(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  stretch: true,
                                  pinned: false,
                                  // floating: true,
                                  expandedHeight:
                                      MediaQuery.of(context).size.height * 0.4,
                                  flexibleSpace: FlexibleSpaceBar(
                                    title: Text(
                                      unescape.convert(
                                        widget.listItem['name'] ?? 'Songs',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
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
                                      child: widget.listImage == null
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
                                              imageUrl: widget.listImage
                                                  .replaceAll('http:', 'https:')
                                                  .replaceAll(
                                                      '50x50', '500x500')
                                                  .replaceAll(
                                                      '150x150', '500x500'),
                                              placeholder: (context, url) =>
                                                  Image(
                                                image: AssetImage(
                                                    'assets/album.png'),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                SliverList(
                                    delegate: SliverChildListDelegate(
                                        songList.map((entry) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 7, 7, 5),
                                    child: ListTile(
                                      contentPadding:
                                          EdgeInsets.only(left: 15.0),
                                      title: Text(
                                        '${entry["title"]}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        '${entry["artist"]}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      leading: Card(
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(7.0)),
                                        clipBehavior: Clip.antiAlias,
                                        child: CachedNetworkImage(
                                          errorWidget: (context, _, __) =>
                                              Image(
                                            image:
                                                AssetImage('assets/cover.jpg'),
                                          ),
                                          imageUrl:
                                              '${entry["artwork_url"].replaceAll('http:', 'https:')}',
                                          placeholder: (context, url) => Image(
                                            image:
                                                AssetImage('assets/cover.jpg'),
                                          ),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // DownloadButton(
                                          //   data: entry,
                                          //   icon: 'download',
                                          // ),
                                          entry['selling'] == 1 && !entry['purchased'] ?
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
                                                "${entry['price']} $currency",
                                                style: TextStyle(
                                                    color: Colors.black
                                                ),
                                              )
                                          ) : SizedBox(),
                                          AddToQueueButton(data: entry),
                                        ],
                                      ),
                                      onTap: () {
                                        entry["selling"] == 1 && !entry["purchased"]
                                            ? _handlePurchaseDialog(entry)
                                            :
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            opaque: false,
                                            pageBuilder: (_, __, ___) =>
                                              PlayScreen(
                                              data: {
                                                'response': songList,
                                                'index': songList.indexWhere(
                                                    (element) =>
                                                        element == entry),
                                                'offline': false,
                                              },
                                              fromMiniplayer: false,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // );
                                    // },
                                  );
                                }).toList()))
                              ]),
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }
}
