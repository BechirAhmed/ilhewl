import 'package:audio_service/audio_service.dart';

class MediaItemConverter {
  Map mediaItemtoMap(MediaItem mediaItem) {
    return {
      'id': mediaItem.id.toString(),
      'album': mediaItem.album.toString(),
      'artist': mediaItem.artist.toString(),
      'duration': mediaItem.duration.inSeconds.toString(),
      "genre": mediaItem.genre.toString(),
      "has_lyrics": mediaItem.extras["has_lyrics"],
      "lyrics_snippet": mediaItem.extras["lyrics_snippet"],
      'image': mediaItem.artUri.toString(),
      "release_date": mediaItem.extras["release_date"],
      "allow_download": mediaItem.extras["allow_download"],
      "price": mediaItem.extras["price"],
      "selling": mediaItem.extras["selling"],
      "purchased": mediaItem.extras["purchased"],
      'title': mediaItem.title.toString(),
      'url': mediaItem.extras['url'].toString(),
      'artwork_url': mediaItem.artUri.toString(),
    };
  }

  MediaItem mapToMediaItem(Map song) {
    return MediaItem(
        id: song['id'].toString(),
        album: song['album'],
        artist: song["artist"],
        duration: Duration(
            seconds: int.parse(
                (song['duration'] == null || song['duration'] == 'null')
                    ? 180
                    : song['duration'].toString())),
        title: song['title'],
        artUri: Uri.parse(song['artwork_url']),
        genre: song["genre"],
        extras: {
          "url": song["url"],
          "has_lyrics": song['has_lyrics'],
          "lyrics_snippet": song['lyrics_snippet'],
          "release_date": song["release_date"],
          "album_id": song["album_id"],
          "price": song["price"],
          "selling": song["selling"],
          "purchased": song["purchased"],
          "allow_download": song["allow_download"],
        });
  }
}
