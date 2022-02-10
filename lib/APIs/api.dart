import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:ilhewl/Helpers/newFormat.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:ilhewl/Helpers/format.dart';
import 'package:http/io_client.dart';

class Api {
  List preferredLanguages = Hive.box('settings').get('preferredLanguage', defaultValue: ['English'])?.toList();
  Map<String, String> headers = {};
  String baseUrl = "www.ilhewl.com";
  String apiStr = "/api";
  Box settingsBox = Hive.box('settings');
  String token = Hive.box("settings").get("token");

  Future<Response> getResponse(String params, {bool usev4 = true, bool useProxy = false}) async {
    Uri url;
    if (!usev4)
      url = Uri.https( baseUrl, "$apiStr/$params".replaceAll("&api_version=4", ""));
    else
      url = Uri.https(baseUrl, "$apiStr/$params");
    preferredLanguages = preferredLanguages.map((lang) => lang.toLowerCase()).toList();
    String languageHeader = 'L=' + preferredLanguages.join('%2C');
    headers = {"cookie": languageHeader, "Accept": "application/json", 'Authorization': 'Bearer $token'};

    // useProxy = useProxy && settingsBox.get('useProxy', defaultValue: false);
    // if (useProxy) {
    //   final proxyIP = settingsBox.get("proxyIp");
    //   final proxyPort = settingsBox.get("proxyPort");
    //   HttpClient httpClient = new HttpClient();
    //   httpClient.findProxy = (uri) {
    //     return "PROXY $proxyIP:$proxyPort;";
    //   };
    //   httpClient.badCertificateCallback = ((X509Certificate cert, String host, int port) => Platform.isAndroid);
    //   IOClient myClient = IOClient(httpClient);
    //   return await myClient.get(url, headers: headers);
    // }

    // print(url);

    return await get(url, headers: headers);
  }

  _setHeaders() => {
    'Content-type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token'
  };


  Future<Map> fetchHomePageData() async {
    String params = "discover";
    Map result;
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        result = await NewFormatResponse().formatHomePageData(data);
      }
    } catch (e) {
      print(e);
    }
    return result;
  }

  Future<Map> fetchAllSongs(page, limit) async {
    String params = "all_songs";
    Map result;
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        result = await NewFormatResponse().formatHomePageData(data);
      }
    } catch (e) {
      print(e);
    }
    return result;
  }


  Future<Map> fetchWalletData() async {
    String params = "settings/wallet";
    Map result;
    try {
      final res = await getResponse(params);
      if(res.statusCode == 200){
        var body = json.decode(res.body);
        result = body["wallet"];
      }
    } catch (e) {
      print(e);
    }

    return result;
  }

  Future<Map> fetchUserData(userId) async {
    String params = "auth/user/profile";
    Map result;
    try {
      final res = await getResponse(params);
      if(res.statusCode == 200){
        var body = json.decode(res.body);
        result = body;
      }
    } catch (e) {
      print(e);
    }

    return result;
  }
  Future<Map> checkArtistRequest(userId) async {
    String params = "auth/user/check-artist-request";
    Map result;
    try {
      final res = await getResponse(params);
        var body = json.decode(res.body);
        result = body;
    } catch (e) {
      print(e);
    }

    return result;
  }

  Future<Map> updateDevice({data}) async {
    String url = '/auth/user/update-device';
    String fullUrl = 'https://'+baseUrl+apiStr+url;
    Map result;
    try {
      final res = await post(
        Uri.parse(fullUrl),
        body: data,
        headers: {
          "Accept": "application/json",
          'Authorization': 'Bearer $token'
        }
      );
      if(res.statusCode == 200){
        var body = json.decode(res.body);
        result = body;
      }
    } catch (e) {
      print(e);
    }

    return result;
  }

  Future<Map> fetchArtistData(userId) async {
    String params = "artist/data/$userId";
    Map result;
    try {
      final res = await getResponse(params);
      if(res.statusCode == 200){
        var body = json.decode(res.body);
        result = body;
      }
    } catch (e) {
      print(e);
    }

    return result;
  }

  Future<Map> registerOrLogin(data) async {
    String params = '/auth/check-login?$data';
    String fullUrl = 'https://'+baseUrl+apiStr+params;

    Map result;
    try {
      final res = await post(
          Uri.parse(fullUrl)
      );

      // if(res.statusCode == 200){
        final body = json.decode(res.body);
        result = body;
      // }

    } catch(e) {
      print(e);
    }
    return result;
  }
  Future<Map> logout(data) async {
    String params = '/auth/mobile-logout?$data';
    String fullUrl = 'https://'+baseUrl+apiStr+params;
    headers = {"Accept": "application/json", 'Authorization': 'Bearer $token'};

    Map result;
    try {
      final res = await post(
          Uri.parse(fullUrl),
        headers: headers
      );

      // if(res.statusCode == 200){
        final body = json.decode(res.body);
        result = body;
      // }

    } catch(e) {
      print(e);
    }
    return result;
  }

  Future<Map> authData(data) async {
    String params = '/auth/$data';
    String fullUrl = "https://$baseUrl$apiStr$params";

    Map result;
    try {
      final res = await post(
          Uri.parse(fullUrl),
        headers: {
          "Accept": "application/json",
          'Authorization': 'Bearer $token'
        }
      );

      if(res.statusCode == 200){
        final body = json.decode(res.body);
        result = body;
      }else{
        return json.decode(res.body);
      }

    } catch(e) {
      print(e);
    }
    return result;
  }

  Future<Map> playTrack(id, type) async {
    String params = '/auth/play/song/$id';
    String fullUrl = "https://$baseUrl$apiStr$params";

    Map result;
    try {
      final res = await post(
        Uri.parse(fullUrl),
        body: {
          'type': type
        },
        headers: {
          "Accept": "application/json",
          'Authorization': 'Bearer $token'
        }
      );
      if(res.statusCode == 200){
        final body = json.decode(res.body);
        result = body;
      }

    } catch(e) {
      print(e);
    }
    return result;
  }

  Future<Map> purchaseSong(data) async {
    String songId = data["id"].toString();
    String userId = Hive.box("settings").get("userID").toString();
    String type = data["type"].toString();
    String params = '/song/$songId/purchase?user_id=$userId&song_id=$songId&type=$type';
    String fullUrl = 'https://'+baseUrl+apiStr+params;

    Map result;
    try {
      final res = await post(
          Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        }
      );

      if(res.statusCode == 200){
        final body = json.decode(res.body);
        result = body;
      }



    } catch(e) {
      print(e);
    }

    return result;
  }

  Future<List> fetchGenreSongs(String genreId) async {
    List searchedList = [];
    String params = "discover/genre/$genreId/songs";
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      List responseList = json.decode(res.body);
      searchedList = await NewFormatResponse().formatSongsResponse(responseList, 'genre');
    }
    return searchedList;
  }

  Future<List> fetchUserAlbumSongs(String albumId) async {
    List searchedList = [];
    String params = "discover/album/$albumId/songs";
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      List responseList = json.decode(res.body);
      searchedList = await NewFormatResponse().formatSongsResponse(responseList, 'album');
    }
    return searchedList;
  }

  Future<List> fetchMoodSongs(String moodId) async {
    List searchedList = [];
    String params = "discover/mood/$moodId/songs";
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      List responseList = json.decode(res.body);
      searchedList = await NewFormatResponse().formatSongsResponse(responseList, 'mood');
    }
    return searchedList;
  }

  Future<List> getTopSearches() async {
    List result = [];
    String params = "top-search";
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final List getMain = json.decode(res.body);
        result = getMain.map((element) {
          return element["title"];
        }).toList();
      }
    } catch (e) {}
    return result;
  }

  Future<Map> fetchSongSearchResults(query) async {
    String params = "mobile-search/$query";
    Map result;
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        result = await NewFormatResponse().formatSearchData(data);
      }
    } catch (e) {
      print(e);
    }
    return result;
  }

  Future<List<Map>> fetchSearchResults(String searchQuery) async {
    Map<String, List> result = {};
    Map<int, String> position = {};
    List searchedAlbumList = [];
    List searchedPlaylistList = [];
    List searchedArtistList = [];
    List searchedTopQueryList = [];

    String params =
        "__call=autocomplete.get&cc=in&includeMetaTags=1&query=$searchQuery";

    final res = await getResponse(params, usev4: false, useProxy: true);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      List albumResponseList = getMain["albums"]["data"];
      position[getMain["albums"]["position"]] = 'Albums';
      List playlistResponseList = getMain["playlists"]["data"];
      position[getMain["playlists"]["position"]] = 'Playlists';
      List artistResponseList = getMain["artists"]["data"];
      position[getMain["artists"]["position"]] = 'Artists';
      List topQuery = getMain["topquery"]["data"];

      searchedAlbumList = await FormatResponse()
          .formatAlbumResponse(albumResponseList, 'album');
      if (searchedAlbumList.isNotEmpty) result['Albums'] = searchedAlbumList;

      searchedPlaylistList = await FormatResponse()
          .formatAlbumResponse(playlistResponseList, 'playlist');
      if (searchedPlaylistList.isNotEmpty)
        result['Playlists'] = searchedPlaylistList;

      searchedArtistList = await FormatResponse()
          .formatAlbumResponse(artistResponseList, 'artist');
      if (searchedArtistList.isNotEmpty) result['Artists'] = searchedArtistList;

      if (topQuery.isNotEmpty &&
          (topQuery[0]["type"] == 'playlist' ||
              topQuery[0]["type"] == 'artist' ||
              topQuery[0]["type"] == 'album')) {
        position[getMain["topquery"]["position"]] = 'Top Result';
        position[getMain["songs"]["position"]] = 'Songs';

        switch (topQuery[0]["type"]) {
          case ('artist'):
            searchedTopQueryList =
                await FormatResponse().formatAlbumResponse(topQuery, 'artist');
            break;
          case ('album'):
            searchedTopQueryList =
                await FormatResponse().formatAlbumResponse(topQuery, 'album');
            break;
          case ('playlist'):
            searchedTopQueryList = await FormatResponse()
                .formatAlbumResponse(topQuery, 'playlist');
            break;
          default:
            break;
        }
        if (searchedTopQueryList.isNotEmpty)
          result['Top Result'] = searchedTopQueryList;
      } else {
        if (topQuery.isNotEmpty && topQuery[0]["type"] == 'song') {
          position[getMain["topquery"]["position"]] = 'Songs';
        } else {
          position[getMain["songs"]["position"]] = 'Songs';
        }
      }
    }
    return [result, position];
  }

  Future<List> fetchAlbums(String searchQuery, String type) async {
    List searchedList = [];
    String params;
    if (type == 'playlist')
      params = "p=1&q=$searchQuery&n=20&__call=search.getPlaylistResults";
    if (type == 'album')
      params = "p=1&q=$searchQuery&n=20&__call=search.getAlbumResults";
    if (type == 'artist')
      params = "p=1&q=$searchQuery&n=20&__call=search.getArtistResults";

    final res = await getResponse(params);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      List responseList = getMain["results"];
      searchedList =
          await FormatResponse().formatAlbumResponse(responseList, type);
    }
    return searchedList;
  }

  Future<List> fetchAlbumSongs(String albumId) async {
    List data;
    String params = "auth/album/$albumId";
    final res = await getResponse(params);

    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      data = await NewFormatResponse().formatSongsInList(getMain["songs"], false);
    }
    return data;
  }

  Future<Map> fetchArtistSongs(String url, artId) async {
    Map data;
    String artistId = artId;
    if(artId == null) {
      artistId = Hive.box('settings').get('artistId', defaultValue: 0).toString();
    }

    String params = "$url/$artistId";
    final res = await getResponse(params);

    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      data = getMain["artist"];
      data["songs"]["data"] = await NewFormatResponse().formatSongsResponse(getMain["artist"]["songs"]["data"], 'artist');
    }


    return data;
  }

  Future<List> fetchPlaylistSongs(String playlistId) async {
    List searchedList = [];
    String params = "__call=playlist.getDetails&cc=in&listid=$playlistId";
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      List responseList = getMain["list"];
      searchedList =
          await FormatResponse().formatSongsResponse(responseList, 'playlist');
    }
    return searchedList;
  }

  Future<List> fetchTopSearchResult(String searchQuery) async {
    List searchedList = [];
    String params = "p=1&q=$searchQuery&n=10&__call=search.getResults";
    final res = await getResponse(params, useProxy: true);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      List responseList = getMain["results"];
      searchedList.add(
          await FormatResponse().formatSingleSongResponse(responseList[0]));
    }
    return searchedList;
  }

  Future<Map> fetchSongDetails(String songId) async {
    Map result;
    String params = "pids=$songId&__call=song.getDetails";
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        result =
            await FormatResponse().formatSingleSongResponse(data["songs"][0]);
      }
    } catch (err) {
      print(err);
    }
    return result;
  }
}
