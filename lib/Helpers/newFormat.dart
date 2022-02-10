import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:dart_des/dart_des.dart';
import 'package:ilhewl/APIs/saavnApi.dart';

class NewFormatResponse {
  String decode(String input) {
    String key = "38346591";
    DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB);

    Uint8List encrypted = base64.decode(input);
    List<int> decrypted = desECB.decrypt(encrypted);
    String decoded =
        utf8.decode(decrypted).replaceAll(RegExp(r'.mp4.*'), '.mp4');
    return decoded;
  }

  String capitalize(String msg) {
    return "${msg[0].toUpperCase()}${msg.substring(1)}";
  }

  String formatString(String text) {
    return text
        .toString()
        .replaceAll("&amp;", "&")
        .replaceAll("&#039;", "'")
        .replaceAll("&quot;", "\"")
        .trim();
  }

  Future<List> formatSongsResponse(List responseList, String type) async {
    List searchedList = [];
    for (int i = 0; i < responseList.length; i++) {
      Map response;
      switch (type) {
        case 'song':
        case 'album':
        case 'genre':
          response = await formatSingleSongResponse(responseList[i]);
          break;
        case 'mood':
          response = await formatSingleSongResponse(responseList[i]);
          break;
        case 'playlist':
          response = await formatSingleSongResponse(responseList[i]);
          break;
        case 'artist':
          response = await formatSingleSongResponse(responseList[i]);
          break;
        default:
          break;
      }

      if (response.containsKey('Error')) {
        print("Error at index $i inside FormatResponse: ${response['Error']}");
      } else {
        searchedList.add(response);
      }
    }
    return searchedList;
  }


  Future<Map> formatSingleSongResponse(Map response) async {
    // Map cachedSong = Hive.box('songDetails').get(response['id']);
    // if (cachedSong != null) {
    //   return cachedSong;
    // }
    try {
      List artistNames = [];
      List genresNames = [];
      if (response['artists'] == null || response['artists'].length == 0) {
        artistNames.add("Unknown");
      } else {
        response['artists'].forEach((element) {
          artistNames.add(element["name"]);
        });
      }
      
      if(response['genres'] == null || response['genres'].length == 0){
        genresNames.add("Unknown");
      }else{
        response['genres'].forEach((element) {
          genresNames.add(element['name']);
        });
      }


      Map info = {
        "id": response["id"],
        "type": response["type"],
        "album_model": response["album"] == null || response["album"] == "null" ? {} : response["album"],
        "album": response["album"] == null || response["album"] == "null" ? formatString("ilhewl") : formatString(response["album"]["title"]),
        // .split('(')
        // .first
        "price": response["price"],
        "duration": response["duration"],
        "selling": response["selling"],
        "purchased": response["purchased"],
        // "genre": capitalize(response["genre"].toString()),
        "genre": formatString(genresNames.join(", ")),
        "allow_download": response["allow_download"],
        "has_lyrics": response['has_lyrics'],
        "favorite": response["favorite"],
        "lyrics_snippet": response['has_lyrics'] ? formatString(response["lyric"]["lyrics"]) : "",
        "release_date": response["released_at"],
        "title": formatString(response['title']),
        "approved": response['approved'],
        "visibility": response['visibility'],
        // .split('(')
        // .first
        "artist": formatString(artistNames.join(", ")),
        "artwork_url": response["artwork_url"]
            .toString()
            .replaceAll('http:', 'https:'),
        "url": response["stream_url"]
      };
      info["url"] = info["url"].replaceAll("http:", "https:");
      // Hive.box('songDetails').put(response['id'], info);
      return info;
    } catch (e) {
      return {"Error": e};
    }
  }

  Future<Map> formatSingleAlbumSongResponse(Map response) async {
    try {
      List artistNames = [];
      if (response['primary_artists'] == null ||
          response['primary_artists'].toString().trim() == '') {
        if (response['featured_artists'] == null ||
            response['featured_artists'].toString().trim() == '') {
          if (response['singers'] == null ||
              response['singer'].toString().trim() == '') {
            response['singers'].toString().split(', ').forEach((element) {
              artistNames.add(element);
            });
          } else {
            artistNames.add("Unknown");
          }
        } else {
          response['featured_artists']
              .toString()
              .split(', ')
              .forEach((element) {
            artistNames.add(element);
          });
        }
      } else {
        response['primary_artists'].toString().split(', ').forEach((element) {
          artistNames.add(element);
        });
      }

      Map info = {
        "id": response["id"],
        "type": response["type"],
        "album": formatString(response["album"]),
        // .split('(')
        // .first
        "year": response["year"],
        "duration": response["duration"],
        "language": capitalize(response["language"].toString()),
        "genre": capitalize(response["language"].toString()),
        "320kbps": response["320kbps"],
        "has_lyrics": response["has_lyrics"],
        "lyrics_snippet": formatString(response["lyrics_snippet"]),
        "release_date": response["release_date"],
        "album_id": response["album_id"],
        "subtitle": formatString(
            "${response['primary_artists'].toString().trim()} - ${response['album'].toString().trim()}"),
        "title": formatString(response['song']),
        // .split('(')
        // .first
        "artist": formatString(artistNames.join(", ")),
        "album_artist": response["more_info"] == null
            ? response["music"]
            : response["more_info"]["music"],
        "artUri": response["artwork_url"]
            .toString()
            .replaceAll("150x150", "500x500")
            .replaceAll('50x50', "500x500")
            .replaceAll('http:', 'https:'),
        "url": decode(response["encrypted_media_url"])
      };
      return info;
    } catch (e) {
      return {"Error": e};
    }
  }

  Future<List> formatAlbumResponse(List responseList, String type) async {
    List searchedAlbumList = [];
    for (int i = 0; i < responseList.length; i++) {
      Map response;
      switch (type) {
        case 'album':
          response = await formatSingleAlbumResponse(responseList[i]);
          break;
        case 'artist':
          response = await formatSingleArtistResponse(responseList[i]);
          break;
        case 'playlist':
          response = await formatSinglePlaylistResponse(responseList[i]);
          break;
      }
      if (response.containsKey('Error')) {
        print(
            "Error at index $i inside FormatAlbumResponse: ${response['Error']}");
      } else {
        searchedAlbumList.add(response);
      }
    }
    return searchedAlbumList;
  }

  Future<Map> formatSingleAlbumResponse(Map response) async {
    try {
      Map info = {
        "id": response["id"],
        "type": response["type"],
        "album": formatString(response["title"]),
        // .split('(')
        // .first
        "year": response["more_info"]["year"] ?? response["year"],
        "language": capitalize(response["more_info"]["language"] == null
            ? response["language"].toString()
            : response["more_info"]["language"].toString()),
        "genre": capitalize(response["more_info"]["language"] == null
            ? response["language"].toString()
            : response["more_info"]["language"].toString()),
        "album_id": response["id"],
        "subtitle": response["description"] == null
            ? formatString(response["subtitle"])
            : formatString(response["description"]),
        "title": formatString(response['title']),
        // .split('(')
        // .first
        "artist": response["music"] == null
            ? response["more_info"]["music"] == null
                ? response["more_info"]["artistMap"]["primary_artists"] == null
                    ? ''
                    : formatString(response["more_info"]["artistMap"]
                        ["primary_artists"][0]["name"])
                : formatString(response["more_info"]["music"])
            : formatString(response["music"]),
        "album_artist": response["more_info"] == null
            ? response["music"]
            : response["more_info"]["music"],
        "artUri": response["artwork_url"]
            .toString()
            .replaceAll("150x150", "500x500")
            .replaceAll('50x50', "500x500")
            .replaceAll('http:', 'https:'),
        "count": response["more_info"]["song_pids"] == null
            ? 0
            : response["more_info"]["song_pids"].toString().split(", ").length,
        "songs_pids": response["more_info"]["song_pids"].toString().split(", "),
      };
      return info;
    } catch (e) {
      return {"Error": e};
    }
  }

  Future<Map> formatSinglePlaylistResponse(Map response) async {
    try {
      Map info = {
        "id": response["id"],
        "type": response["type"],
        "album": formatString(response["title"]),
        "language": capitalize(response["language"] == null
            ? response["more_info"]["language"].toString()
            : response["language"].toString()),
        "genre": capitalize(response["language"] == null
            ? response["more_info"]["language"].toString()
            : response["language"].toString()),
        "playlistId": response["id"],
        "subtitle": response["description"] == null
            ? formatString(response["subtitle"])
            : formatString(response["description"]),
        "title": formatString(response['title']),
        // .split('(')
        // .first
        "artist": formatString(response["extra"]),
        "album_artist": response["more_info"] == null
            ? response["music"]
            : response["more_info"]["music"],
        "artUri": response["artwork_url"]
            .toString()
            .replaceAll("150x150", "500x500")
            .replaceAll('50x50', "500x500")
            .replaceAll('http:', 'https:'),
      };
      return info;
    } catch (e) {
      return {"Error": e};
    }
  }

  Future<Map> formatSingleArtistResponse(Map response) async {
    try {
      Map info = {
        "id": response["id"],
        "type": response["type"],
        "album": response['title'] == null
            ? formatString(response['name'])
            : formatString(response['title']),
        "language": capitalize(response["language"].toString()),
        "genre": capitalize(response["language"].toString()),
        "artistId": response["id"],
        "artistToken": response["url"] == null
            ? response["perma_url"].toString().split('/').last
            : response["url"].toString().split('/').last,
        "subtitle": response["description"] == null
            ? capitalize(response["role"])
            : formatString(response["description"]),
        "title": response['title'] == null
            ? formatString(response['name'])
            : formatString(response['title']),
        // .split('(')
        // .first

        "artist": formatString(response["title"]),
        "album_artist": response["more_info"] == null
            ? response["music"]
            : response["more_info"]["music"],
        "artUri": response["artwork_url"]
            .toString()
            .replaceAll("150x150", "500x500")
            .replaceAll('50x50', "500x500")
            .replaceAll('http:', 'https:'),
      };
      return info;
    } catch (e) {
      return {"Error": e};
    }
  }

  Future<List> formatArtistTopAlbumsResponse(List responseList) async {
    List result = [];
    for (int i = 0; i < responseList.length; i++) {
      Map response =
          await formatSingleArtistTopAlbumSongResponse(responseList[i]);
      if (response.containsKey('Error')) {
        print("Error at index $i inside FormatResponse: ${response['Error']}");
      } else {
        result.add(response);
      }
    }
    return result;
  }

  Future<Map> formatSingleArtistTopAlbumSongResponse(Map response) async {
    try {
      List artistNames = [];
      if (response['more_info']["artistMap"]['primary_artists'] == null ||
          response['more_info']["artistMap"]['primary_artists'].length == 0) {
        if (response['more_info']["artistMap"]['featured_artists'] == null ||
            response['more_info']["artistMap"]['featured_artists'].length ==
                0) {
          if (response['more_info']["artistMap"]['artists'] == null ||
              response['more_info']["artistMap"]['artists'].length == 0) {
            artistNames.add("Unknown");
          } else {
            response['more_info']["artistMap"]['artists'].forEach((element) {
              artistNames.add(element["name"]);
            });
          }
        } else {
          response['more_info']["artistMap"]['featured_artists']
              .forEach((element) {
            artistNames.add(element["name"]);
          });
        }
      } else {
        response['more_info']["artistMap"]['primary_artists']
            .forEach((element) {
          artistNames.add(element["name"]);
        });
      }

      Map info = {
        "id": response["id"],
        "type": response["type"],
        "album": formatString(response["title"]),
        // .split('(')
        // .first
        "year": response["year"],
        "language": capitalize(response["language"].toString()),
        "genre": capitalize(response["language"].toString()),
        "album_id": response["id"],
        "subtitle": formatString(response["subtitle"]),
        "title": formatString(response['title']),
        // .split('(')
        // .first
        "artist": formatString(artistNames.join(", ")),
        "album_artist": response["more_info"] == null
            ? response["music"]
            : response["more_info"]["music"],
        "artUri": response["artwork_url"]
            .toString()
            .replaceAll("150x150", "500x500")
            .replaceAll('50x50', "500x500")
            .replaceAll('http:', 'https:'),
      };
      return info;
    } catch (e) {
      return {"Error": e};
    }
  }

  // Future<List> formatArtistSinglesResponse(List response) async {
  // List result = [];
  // return result;
  // }

  // Future<List> formatArtistLatestReleaseResponse(List response) async {
  //   List result = [];
  //   return result;
  // }

  // Future<List> formatArtistDedicatedArtistPlaylistResponse(
  //     List response) async {
  //   List result = [];
  //   return result;
  // }

  // Future<List> formatArtistFeaturedArtistPlaylistResponse(List response) async {
  //   List result = [];
  //   return result;
  // }

  Future<Map> formatHomePageData(Map data) async {
    try {
      data["new_trending"] = await formatSongsInList(data["new_trending"], false);
      data["latests"] = await formatSongsInList(data["latests"], false);

      data["collections"] = [
        "new_trending",
        "latests",
        "popular_artists",
        "albums",
        "genres",
        "moods",
        // "artist_recos",
      ];
    } catch (err) {
      print(err);
    }
    return data;
  }
  Future<Map> formatSearchData(Map data) async {
    try {
      data["songs"] = await formatSongsInList(data["songs"], false);

      data["collections"] = [
        "songs",
        "artists",
        "genres",
        "moods",
      ];
    } catch (err) {
      print(err);
    }
    return data;
  }

  Future<Map> formatSearchData(Map data) async {
    try {
      data["songs"] = await formatSongsInList(data["songs"], false);

      data["collections"] = [
        "songs",
        "artists",
        "genres",
        "moods",
      ];
    } catch (err) {
      print(err);
    }
    return data;
  }

  Future<Map> formatArtistPageData(Map data) async {
    try {
      data["songs"] = await formatSongsInList(data["songs"], false);
      data["latests"] = await formatSongsInList(data["latests"], false);

      data["collections"] = [
        "new_trending",
        "latests",
        "popular_artists",
        "genres",
        "moods",
        // "artist_recos",
      ];
    } catch (err) {
      print(err);
    }
    return data;
  }

  Future<Map> formatCollectionPageData(Map data) async {
    try {
      // data["new_trending"] = await formatSongsInList(data["new_trending"], false);
      // data["latests"] = await formatSongsInList(data["latests"], false);

      data["collections"] = [
        // "slides",
        "genres",
        "moods",
        // "channels",
      ];
    } catch (err) {
      print(err);
    }
    return data;
  }


  Future<Map> formatPromoLists(Map data) async {
    try {
      List promoList = data['collections_temp'];
      for (int i = 0; i < promoList.length; i++) {
        data[promoList[i]] = await formatSongsInList(data[promoList[i]], true);
      }
      data['collections'].addAll(promoList);
      data['collections_temp'] = [];
    } catch (err) {
      print(err);
    }
    return data;
  }

  Future<List> formatSongsInList(List list, bool fetchDetails) async {

    if (list.isNotEmpty) {
      for (int i = 0; i < list.length; i++) {
        Map item = list[i];
        list[i] = await formatSingleSongResponse(item);
      }
    }
    list.removeWhere((value) => value == null);
    return list;
  }
}
