import 'dart:convert';
import 'dart:math';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/CustomWidgets/custom_physics.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/Helpers/newFormat.dart';
import 'package:ilhewl/Screens/Common/song_list.dart';
import 'package:ilhewl/Screens/Player/oldaudioplayer.dart';
import 'package:ilhewl/Screens/Search/search.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:ilhewl/APIs/api.dart';

List items = [];
List globalItems = [];
List cachedItems = [];
List cachedGlobalItems = [];
bool fetched = false;
bool emptyRegional, emptyGlobal = false;

// List data;
List data = Hive.box('cache').get('collections', defaultValue: []);

class Collections extends StatefulWidget {
  const Collections({Key key}) : super(key: key);

  @override
  _CollectionsState createState() => _CollectionsState();
}

class _CollectionsState extends State<Collections> {

  Future<List> scrapData() async {
    EasyLoading.show(status: "Loading...");
    String unencodedPath = 'discover/collections';
    List result;

    try {
      Response res = await Api().getResponse(unencodedPath);
      if (res.statusCode == 200) {
        result = json.decode(res.body);
        // result = await NewFormatResponse().formatCollectionPageData(data);
      }
    } catch (e) {
      print(e);
    }
    EasyLoading.dismiss();
    return result;
  }

  void getData() async {
    List receivedData = await scrapData();

    if (receivedData != null && receivedData.isNotEmpty) {
      Hive.box('cache').put('collections', receivedData);
      data = receivedData;
    }
    setState(() {});
  }

  bool loading = true;
  final _random = Random();


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
    getData();
  }

  @override
  Widget build(BuildContext cntxt) {
    if (!fetched) {
      getData();
      fetched = true;
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: 10.0,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Browse all',
                style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            SizedBox(
              height: 20.0,
            ),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: MediaQuery.of(context).size.width / (MediaQuery.of(context).size.height) / .27,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 0
              ),
              physics: BouncingScrollPhysics(),
              scrollDirection: Axis.vertical,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              itemCount: data == null ? 0 : data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final color = Colors.primaries[_random.nextInt(Colors.primaries.length)];
                final color1 = color[300];
                final color2 = color[700];
                return GestureDetector(
                  child: SizedBox(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          clipBehavior: Clip.hardEdge,
                          height: 90.0,
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment(0.8, 0.0),
                                colors: [
                                  color1,
                                  color2,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(5)),
                          child: Stack(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Flexible(
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 15, left: 10),
                                      child: Text(
                                        '${formatString(item["name"] ?? item["title"])}',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(top: 10, left: 10),
                                    child: RotationTransition(
                                      turns: new AlwaysStoppedAnimation(15 / 360),
                                      child: CachedNetworkImage(
                                        errorWidget: (context, _, __) => Image(
                                          image: AssetImage('assets/cover.jpg'),
                                          height: 70,
                                          width: 70,
                                          fit: BoxFit.cover,
                                        ),
                                        imageUrl: item["artwork_url"] != null ? item["artwork_url"].replaceAll('http:', 'https:') : "",
                                        placeholder: (context, url) => Image(
                                          image: (item["type"] == 'playlist' || item["type"] == 'album')
                                              ? AssetImage('assets/album.png')
                                              : item["type"] == 'artist' ? AssetImage('assets/artist.png') : AssetImage('assets/cover.jpg'),
                                          height: 70,
                                          width: 70,
                                          fit: BoxFit.cover,
                                        ),
                                        imageBuilder: (context, imageProvider) => Container(
                                          width: 70.0,
                                          height: 70.0,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.rectangle,
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(5),
                                            ),
                                            image: DecorationImage(
                                                image: imageProvider, fit: BoxFit.cover),
                                          ),
                                        ),
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (_, __, ___) => SongsListPage(
                          listImage: item["artwork_url"],
                          listItem: item,
                        ),
                      ),
                    );
                  },
                );
              },
            )
          ],
        ),
      )
    );
  }
}
