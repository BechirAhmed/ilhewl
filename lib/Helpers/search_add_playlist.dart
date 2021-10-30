
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ilhewl/APIs/saavnApi.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Helpers/playlist.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SearchAddPlaylist {
  Future<Map> addYtPlaylist(String inLink) async {
    final String link = '$inLink&';
    try {
      final RegExpMatch id = RegExp(r'.*list\=(.*?)&').firstMatch(link);
      return {};
    } catch (e) {
      return {};
    }
  }

  Stream<Map> songsAdder(String playName, List tracks) async* {
    int _done = 0;
    for (final track in tracks) {
      String trackName;
      try {
        trackName = (track as Video).title;
        yield {'done': ++_done, 'name': trackName};
      } catch (e) {
        yield {'done': ++_done, 'name': ''};
      }
      try {
        final List result =
        await SaavnAPI().fetchTopSearchResult(trackName.split('|')[0]);
        addMapToPlaylist(playName, result[0] as Map);
      } catch (e) {
        // print('Error in $_done: $e');
      }
    }
  }

  Future<void> showProgress(
      int _total, BuildContext cxt, Stream songAdd) async {
    await showModalBottomSheet(
      isDismissible: false,
      backgroundColor: Colors.transparent,
      context: cxt,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStt) {
              return BottomGradientContainer(
                child: SizedBox(
                  height: 300,
                  width: 300,
                  child: StreamBuilder<Object>(
                      stream: songAdd as Stream<Object>,
                      builder: (ctxt, AsyncSnapshot snapshot) {
                        final Map data = snapshot.data as Map;
                        final int _done = (data ?? const {})['done'] as int ?? 0;
                        final String name =
                            (data ?? const {})['name'] as String ?? '';
                        if (_done == _total) Navigator.pop(ctxt);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Center(
                                child: Text(
                                  AppLocalizations.of(context).convertingSongs,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                )),
                            SizedBox(
                              height: 80,
                              width: 80,
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text('$_done / $_total'),
                                  ),
                                  Center(
                                    child: SizedBox(
                                      height: 77,
                                      width: 77,
                                      child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(ctxt).colorScheme.secondary),
                                          value: _done / _total),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Center(
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                )),
                          ],
                        );
                      }),
                ),
              );
            });
      },
    );
  }
}
