
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:ilhewl/Helpers/cache_provider.dart';
import 'package:ilhewl/Helpers/mediaitem_converter.dart';
import 'package:ilhewl/Helpers/parse_result.dart';


ParseResult parseSongs(List<dynamic> data) {
  ParseResult result = ParseResult();
  data.forEach((json) => result.add(MediaItemConverter().mapToMediaItem(json), json['id']));

  return result;
}

class SongProvider {
  CacheProvider cacheProvider;

  List<MediaItem> _songs;
  Map<String, MediaItem> _index;

  SongProvider({
    @required this.cacheProvider,
  });

  Future<void> init(List<dynamic> songData) async {
    ParseResult result = await compute(parseSongs, songData);
    _songs = result.collection.cast();
    _index = result.index.cast();

    _songs.forEach((song) async {
      if (await cacheProvider.has(song: song)) {
        print(song);
        cacheProvider.songs.add(song);
      }
    });
  }

  List<MediaItem> get songs => _songs;
}
