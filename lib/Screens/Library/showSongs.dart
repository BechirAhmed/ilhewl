import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SongsList extends StatefulWidget {
  final List data;
  Map item;
  final bool offline;
  final String title;
  SongsList({Key key, @required this.data, @required this.offline, this.title, this.item})
      : super(key: key);
  @override
  _SongsListState createState() => _SongsListState();
}

class _SongsListState extends State<SongsList> {
  List _songs = [];
  List original = [];
  bool offline;
  bool added = false;
  bool processStatus = false;
  int sortValue = Hive.box('settings').get('sortValue') ?? 2;
  String currency = Hive.box('settings').get('currency') ?? "MRU";

  void getSongs() async {
    // EasyLoading.show(status: "Loading...");
    String albumId = widget.item['id'].toString();
    final response = await Api().fetchAlbumSongs(albumId);
    if (response != null) {
      _songs = response;

      // EasyLoading.dismiss();
    } else {
      throw Exception('Failed to load Data');
    }
    added = true;
    // _songs = widget.data;
    offline = widget.offline;
    if (!offline) original = List.from(_songs);

    sortSongs();

    processStatus = true;
    setState(() {});
  }

  sortSongs() {
    if (sortValue == 0) {
      _songs.sort((a, b) =>
          a["title"].toUpperCase().compareTo(b["title"].toUpperCase()));
    }
    if (sortValue == 1) {
      _songs.sort((b, a) =>
          a["title"].toUpperCase().compareTo(b["title"].toUpperCase()));
    }
    if (sortValue == 2) {
      offline
          ? _songs
              .sort((b, a) => a["release_date"].compareTo(b["release_date"]))
          : _songs = List.from(original);
    }
    if (sortValue == 3) {
      _songs.shuffle();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!added) {
      getSongs();
    }
    return GradientContainer(
      child: Column(
        children: [
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(widget.title ?? 'Songs'),
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
              body: !processStatus
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
                  : ListView.builder(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.only(top: 10, bottom: 10),
                      shrinkWrap: true,
                      itemCount: _songs.length,
                      itemExtent: 70.0,
                      itemBuilder: (context, index) {
                        return _songs.length == 0
                            ? SizedBox()
                            : ListTile(
                                leading: Card(
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: offline
                                      ? Stack(
                                          children: [
                                            Image(
                                              image: AssetImage(
                                                  'assets/cover.jpg'),
                                            ),
                                            _songs[index]['image'] == null
                                                ? SizedBox()
                                                : SizedBox(
                                                    height: 50.0,
                                                    width: 50.0,
                                                    child: Image(
                                                      fit: BoxFit.cover,
                                                      image: MemoryImage(
                                                          _songs[index]
                                                              ['image']),
                                                    ),
                                                  ),
                                          ],
                                        )
                                      : CachedNetworkImage(
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
                                  "${_songs[index]['release_date']} - "
                                      +(_songs[index]["selling"] == 1 ? _songs[index]["price"] + " $currency" : "Free"),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      opaque: false, // set to false
                                      pageBuilder: (_, __, ___) => PlayScreen(
                                        data: {
                                          'response': _songs,
                                          'index': index,
                                          'offline': offline
                                        },
                                        fromMiniplayer: false,
                                      ),
                                    ),
                                  );
                                },
                              );
                      }),
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }
}
