import 'package:audio_service/audio_service.dart';
import 'package:audiotagger/models/audiofile.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:ilhewl/CustomWidgets/collage.dart';
import 'package:ilhewl/CustomWidgets/custom_physics.dart';
import 'package:ilhewl/Helpers/cache_provider.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/CustomWidgets/emptyScreen.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:ext_storage/ext_storage.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audiotagger/audiotagger.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'showSongs.dart';
import 'dart:io' as io;

class DownloadedSongs extends StatefulWidget {
  final String type;
  DownloadedSongs({Key key, @required this.type}) : super(key: key);
  @override
  _DownloadedSongsState createState() => _DownloadedSongsState();
}

class _DownloadedSongsState extends State<DownloadedSongs> with SingleTickerProviderStateMixin {

  List _cachedSongs = [];
  bool added = false;
  int sortValue = Hive.box('settings').get('sortValue', defaultValue: 2);
  List dirPaths = Hive.box('settings').get('cachedPaths', defaultValue: []);

  TabController _tcontroller;
  int currentIndex = 0;

  Box<String> _cached;

  @override
  void initState() {
    // getCached();

    super.initState();
  }

  void changeTitle() {
    setState(() {
      currentIndex = _tcontroller.index;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  void getCached() async {
    List _cached = Hive.box('cache').get('cachedDownloadedSongs') ?? [];

    if (_cached.isEmpty) return;
    fetchDownloaded(_cached);
    sortSongs(_cachedSongs);

    added = true;
    setState(() {});
  }

  void sortSongs(List songs) {
    if (sortValue == 0) {
      songs.sort((a, b) => a["id"]
          .split('/')
          .last
          .toString()
          .toUpperCase()
          .compareTo(b["id"].split('/').last.toString().toUpperCase()));
    }
    if (sortValue == 1) {
      songs.sort((b, a) => a["id"]
          .split('/')
          .last
          .toString()
          .toUpperCase()
          .compareTo(b["id"].split('/').last.toString().toUpperCase()));
    }
    if (sortValue == 2) {
      songs.sort((b, a) =>
          a["lastModified"].toString().compareTo(b["lastModified"].toString()));
    }
    if (sortValue == 3) {
      songs.shuffle();
    }
  }

  Future<void> fetchDownloaded(List cached) async {
    List _songs = [];

    List<FileInfo> _files = [];

    AudioPlayer _audioPlayer = AudioPlayer();

    for (String path in cached) {
      try {
        FileInfo item = await DefaultCacheManager().getFileFromCache(path);
        _files.add(item);
      } catch (e) {
        print('failed');
      }
    }


    for (FileInfo entity in _files) {
      if (entity.file.path.endsWith('.mp3') || entity.file.path.endsWith('.m4a') || entity.file.path.endsWith('.wav') || entity.file.path.endsWith('.flac')) {
        try {
          FileStat stats = await entity.file.stat();
          if (stats.size < 1048576) {
            print("Size of mediaItem found less than 1 MB");
            debugPrint("Ignoring media: ${entity.file.path}");
          } else {
            // final AudioFile audioFile = await tagger.readAudioFile(path: entity.file.path);

            final directory = await getApplicationDocumentsDirectory();
            var file = File("$directory/${entity.file.basename}");
            final audioFile = await _audioPlayer.setFilePath(file.uri.path);
            _songs.add(audioFile);
          }
        } catch (e) {
          print(e);
        }
      }
    }
    sortSongs(_songs);

    _cachedSongs = _songs;

    print("Songs: $_songs");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CacheProvider>(
        builder: (_, provider, __) {
          // print(provider.songs);
          if (provider.songs.length == 0) {
            return EmptyScreen().emptyScreen(context, false, 3, "Nothing to ", 15.0,
                "Show Here", 45, "Download Something", 23.0);
          }

          List<MediaItem> songs = provider.songs;

          return GradientContainer(
            child: Column(
              children: [
                Expanded(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                      title: Text('My Music'),
                      actions: [
                        PopupMenuButton(
                            icon: Icon(Icons.sort_rounded),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.all(Radius.circular(7.0))),
                            onSelected: (int value) {
                              sortValue = value;
                              Hive.box('settings').put('sortValue', value);
                              sortSongs(_cachedSongs);
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
                                    Text('Last Modified'),
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
                        ),
                      ],
                      centerTitle: true,
                      backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.transparent
                          : Theme.of(context).accentColor,
                      elevation: 0,
                    ),
                    body: ListView.builder(
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
                                  songs[index].artUri == null
                                      ? SizedBox()
                                      : SizedBox(
                                    height: 50.0,
                                    width: 50.0,
                                    child: CachedNetworkImage(
                                      fit: BoxFit.cover,
                                      imageUrl: songs[index].artUri.toString(),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            title: Text(songs[index].title,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              songs[index].artist ?? "",
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton(
                              icon: Icon(Icons.more_vert_rounded),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(7.0))),
                              onSelected: (value) async {
                                if (value == 0) {
                                  try {
                                    CacheProvider().remove(song: songs[index]);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        elevation: 6,
                                        backgroundColor: Colors.grey[900],
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Deleted ${songs[index].id.split('/').last}',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        action: SnackBarAction(
                                          textColor: Theme.of(context).accentColor,
                                          label: 'Ok',
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                    songs.remove(songs[index]);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        elevation: 6,
                                        backgroundColor: Colors.grey[900],
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          'Failed to delete ${songs[index].id}',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        action: SnackBarAction(
                                          textColor: Theme.of(context).accentColor,
                                          label: 'Ok',
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                  }
                                  setState(() {});
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 0,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded),
                                      Spacer(),
                                      Text('Delete'),
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
                                      'offline': true
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
        },
      ),
    );
  }

  // void getDownloaded() async {
  //   await fetchDownloaded();
  //
  //   added = true;
  //   setState(() {});
  // }

}
