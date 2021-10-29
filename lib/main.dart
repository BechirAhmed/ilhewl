/*
 * Copyright (c) 2021 Ankit Sangwan
 *
 * ilhewl is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * ilhewl is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with ilhewl.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_forbidshot/flutter_forbidshot.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ilhewl/Helpers/cache_provider.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:ilhewl/Screens/Artist/ClaimProfile.dart';
import 'package:ilhewl/Screens/Library/downloads.dart';
import 'package:ilhewl/Screens/Library/nowplaying.dart';
import 'package:ilhewl/Screens/Library/playlists.dart';
import 'package:ilhewl/Screens/Library/recent.dart';
import 'package:ilhewl/Screens/LocalMusic/localplaylists.dart';
import 'package:ilhewl/Screens/LocalMusic/my_music.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:ilhewl/Services/data_provider.dart';
import 'package:ilhewl/Services/song_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ilhewl/Screens/About/about.dart';
import 'package:ilhewl/Screens/Home/home.dart';
import 'package:ilhewl/Screens/Settings/setting.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ilhewl/Screens/Login/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:secure_application/secure_application.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  try {
    await Hive.openBox('settings');
  } catch (e) {
    print('Failed to open Settings Box');
    print("Error: $e");
    var dir = await getApplicationDocumentsDirectory();
    String dirPath = dir.path;
    String boxName = "settings";
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox("settings");
  }
  try {
    await Hive.openBox('downloads');
  } catch (e) {
    print('Failed to open downloads Box');
    print("Error: $e");
    var dir = await getApplicationDocumentsDirectory();
    String dirPath = dir.path;
    String boxName = "downloads";
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox("downloads");
  }
  try {
    await Hive.openBox('cache');
  } catch (e) {
    print('Failed to open Cache Box');
    print("Error: $e");
    var dir = await getApplicationDocumentsDirectory();
    String dirPath = dir.path;
    String boxName = "cache";
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox("cache");
  }
  try {
    await Hive.openBox('recentlyPlayed');
  } catch (e) {
    print('Failed to open Recent Box');
    print("Error: $e");
    var dir = await getApplicationDocumentsDirectory();
    String dirPath = dir.path;
    String boxName = "recentlyPlayed";
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox("recentlyPlayed");
  }
  try {
    final box = await Hive.openBox('songDetails');
    // clear box if it grows large
    // each song detail is about 3.9KB so it's <5MB
    if (box.length > 1200) {
      box.clear();
    }
    await Hive.openBox('songDetails');
  } catch (e) {
    print('Failed to open songDetails Box');
    print("Error: $e");
    var dir = await getApplicationDocumentsDirectory();
    String dirPath = dir.path;
    String boxName = "songDetails";
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox("songDetails");
  }
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Failed to initialize Firebase');
  }

  Paint.enableDithering = true;
  runApp(
      MultiProvider(
        providers: _providers,
        child: MyApp()
      )
  );
  configLoading();
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.light
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.black54
    ..backgroundColor = Colors.cyan
    ..indicatorColor = Colors.black54
    ..textColor = Colors.black54
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  bool failedAuth;
  double blurr = 20;
  double opacity = 0.6;
  Locale _locale = const Locale('en', '');
  bool isCaptured = false;
  StreamSubscription<void> subscription;

  @override
  void initState() {
    init();
    super.initState();
    final String lang = Hive.box('settings').get('lang', defaultValue: 'English') as String;
    final Map<String, String> codes = {
      'English': 'en',
      'Arabic': 'ar',
      'French': 'fr',
    };
    _locale = Locale(codes[lang]);
    currentTheme.addListener(() {
      setState(() {});
    });
  }

  void setLocale(Locale value) {
    setState(() {
      _locale = value;
    });
  }

  init() async {
    FlutterForbidshot.setAndroidForbidOn();

    bool isCapture = await FlutterForbidshot.iosIsCaptured;
    setState(() {
      isCaptured = isCapture;
    });
    if(isCapture){
      AudioService.customAction("setVolume", 0.0);
    }else{
      AudioService.customAction("setVolume", 1.0);
    }
    subscription = FlutterForbidshot.iosShotChange.listen((event) {
      setState(() {
        isCaptured = !isCaptured;
      });
      if(isCaptured){
        AudioService.customAction("setVolume", 0.0);
      }else{
        AudioService.customAction("setVolume", 1.0);
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  initialFuntion() {
    return Hive.box('settings').get('token') != null
        ? AudioServiceWidget(child: HomePage())
        : AuthScreen();
  }

  Future disableCapture() async {
    //disable screenshots and record screen in current screen
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      title: 'ilhewl',
      debugShowCheckedModeBanner: false,
      themeMode: currentTheme.currentTheme(), //system,
      theme: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          selectionHandleColor: currentTheme.currentColor(),
          cursorColor: currentTheme.currentColor(),
          selectionColor: currentTheme.currentColor(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: UnderlineInputBorder(
              borderSide:
              BorderSide(width: 1.5, color: currentTheme.currentColor())),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: currentTheme.currentColor(),
        ),
        iconTheme: IconThemeData(color: Colors.grey[800]),
        disabledColor: Colors.grey[600],
        brightness: Brightness.light,
        accentColor: currentTheme.currentColor(),
      ),
      builder: EasyLoading.init(),
      darkTheme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            }
        ),
        textSelectionTheme: TextSelectionThemeData(
          selectionHandleColor: currentTheme.currentColor(),
          cursorColor: currentTheme.currentColor(),
          selectionColor: currentTheme.currentColor(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(width: 1.5, color: currentTheme.currentColor())),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(color: currentTheme.getCanvasColor()),
        canvasColor: currentTheme.getCanvasColor(),
        cardColor: currentTheme.getCardColor(),
        dialogBackgroundColor: currentTheme.getCardColor(),
        accentColor: currentTheme.currentColor(),
      ),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('ar', ''), // Arabic
        Locale('fr', ''), // French, no country code
      ],
      routes: {
        '/': (context) => initialFuntion(),
        '/setting': (context) => SettingPage(),
        '/wallet': (context) => WalletPage(),
        '/about': (context) => AboutScreen(),
        '/playlists': (context) => PlaylistScreen(),
        '/localplaylists': (context) => LocalPlaylistScreen(),
        '/mymusic': (context) => MyMusicPage(),
        '/nowplaying': (context) => NowPlaying(),
        '/recent': (context) => RecentlyPlayed(),
        '/downloads': (context) => const Downloads(),
        '/claim_artist_profile': (context) => ClaimArtistProfile(),
      },
    );
  }
}

List<SingleChildWidget> _providers = [

  ChangeNotifierProvider(create: (_) => CacheProvider()),
  Provider(
    create: (context) => SongProvider(
      cacheProvider: context.read<CacheProvider>(),
    ),
  ),
  ChangeNotifierProvider(
    create: (context) => DataProvider(
      songProvider: context.read<SongProvider>(),
    ),
  ),
];
