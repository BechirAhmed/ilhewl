import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';

class SongCached {
  final MediaItem song;
  final FileInfo info;

  SongCached({@required this.song, @required this.info});
}

class CacheProvider with ChangeNotifier {
  List<MediaItem> songs = [];

  List _cachedSongs = Hive.box("cache").get('cachedDownloadedSongs', defaultValue: []);

  final BehaviorSubject<bool> _cacheCleared = BehaviorSubject();
  ValueStream<bool> get cacheClearedStream => _cacheCleared.stream;

  final BehaviorSubject<MediaItem> _singleCacheRemoved = BehaviorSubject();
  ValueStream<MediaItem> get singleCacheRemovedStream => _singleCacheRemoved.stream;

  final BehaviorSubject<SongCached> _songCached = BehaviorSubject();
  ValueStream<SongCached> get songCachedStream => _songCached.stream;

  static CacheManager _cache = DefaultCacheManager();

  Future<void> cache({@required MediaItem song}) async {
    FileInfo fileInfo = await _cache.downloadFile(
      song.extras["url"],
      key: song.extras["cacheKey"],
      force: true,
    );

    _songCached.add(SongCached(song: song, info: fileInfo));
    songs.add(song);
    _cachedSongs.add(song.extras['cacheKey']);
    Hive.box('cache').put('cachedDownloadedSongs', _cachedSongs);
    notifyListeners();
  }

  Future<FileInfo> get({@required MediaItem song}) async {
    return await _cache.getFileFromCache(song.extras['cacheKey']);
  }

  Future<bool> has({@required MediaItem song}) async {
    return await this.get(song: song) != null;
  }

  Future<void> remove({@required MediaItem song}) async {
    await _cache.removeFile(song.extras['cacheKey']);
    _singleCacheRemoved.add(song);
    this.songs.remove(song);
    notifyListeners();
  }

  Future<void> clear() async {
    await _cache.emptyCache();
    _cacheCleared.add(true);
    this.songs.clear();
    notifyListeners();
  }
}
