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
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_forbidshot/flutter_forbidshot.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/cache_provider.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:ilhewl/Helpers/route_handler.dart';
import 'package:ilhewl/Screens/Artist/ClaimProfile.dart';
import 'package:ilhewl/Screens/Library/downloads.dart';
import 'package:ilhewl/Screens/Library/nowplaying.dart';
import 'package:ilhewl/Screens/Library/playlists.dart';
import 'package:ilhewl/Screens/Library/recent.dart';
import 'package:ilhewl/Screens/LocalMusic/localplaylists.dart';
import 'package:ilhewl/Screens/Home/allSongs.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ilhewl/Services/audioService.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ilhewl/Screens/About/about.dart';
import 'package:ilhewl/Screens/Home/home.dart';
import 'package:ilhewl/Screens/Settings/setting.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ilhewl/Screens/Login/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:secure_application/secure_application.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

AudioPlayerHandler audioHandler;

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();

  await openHiveBox('settings');
  await openHiveBox('downloads');
  await openHiveBox('Favorite Songs');
  await openHiveBox('cache', limit: true);

  Paint.enableDithering = true;
  await startService();

  FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
  );
  FirebaseMessaging.onMessage.listen((RemoteMessage event) async {
    print(event.notification.body);

    if (event.data['data'] != null) {
      final data = jsonDecode(event.data['data']);

    }
  });

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('Message clicked!');
    if (message.data['data'] != null) {
      final data = jsonDecode(message.data['data']);
      if (data['screen'] != null) {
        navigatorKey.currentState.pushNamed(
          data['screen'],
          arguments: {'id': data['id']},
        );
      }
    }
  });

  runApp(MyApp());
  configLoading();
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  //NotificationService().showNotification(message);
}

Future<void> startService() async {
  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandlerImpl(),
    config: AudioServiceConfig(
      // androidNotificationChannelId: 'com.shadow.ilhewl.channel.audio',
      // androidNotificationChannelName: 'ilhewl',
      // androidNotificationOngoing: true,
      // androidNotificationIcon: 'drawable/ic_stat_music_note',
      // androidShowNotificationBadge: true,
      // androidStopForegroundOnPause: Hive.box('settings')
      // .get('stopServiceOnPause', defaultValue: true) as bool,
      notificationColor: Colors.grey[900],
    ),
  );
}

Future<void> openHiveBox(String boxName, {bool limit = false}) async {
  if (limit) {
    final box = await Hive.openBox(boxName).onError((error, stackTrace) async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String dirPath = dir.path;
      final File dbFile = File('$dirPath/$boxName.hive');
      final File lockFile = File('$dirPath/$boxName.lock');
      await dbFile.delete();
      await lockFile.delete();
      await Hive.openBox(boxName);
      throw 'Failed to open $boxName Box\nError: $error';
    });
    // clear box if it grows large
    if (box.length > 500) {
      box.clear();
    }
    await Hive.openBox(boxName);
  } else {
    await Hive.openBox(boxName).onError((error, stackTrace) async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String dirPath = dir.path;
      final File dbFile = File('$dirPath/$boxName.hive');
      final File lockFile = File('$dirPath/$boxName.lock');
      await dbFile.delete();
      await lockFile.delete();
      await Hive.openBox(boxName);
      throw 'Failed to open $boxName Box\nError: $error';
    });
  }
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

  static _MyAppState of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {

  bool failedAuth;
  double blurr = 20;
  double opacity = 0.6;
  Locale _locale = const Locale('en', '');
  bool isCaptured = false;
  StreamSubscription<void> subscription;
  FirebaseMessaging messaging;

  @override
  void initState() {
    init();
    messaging = FirebaseMessaging.instance;
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
      audioHandler.setVolume(0.0);
    }

    subscription = FlutterForbidshot.iosShotChange.listen((event) {
      setState(() {
        isCaptured = !isCaptured;
      });
      if(isCaptured){
        audioHandler.setVolume(0.0);
      }else{
        audioHandler.setVolume(1.0);
      }
    });

    String fbDeviceToken;
    final savedDeviceToken = Hive.box('cache').get('deviceToken');
    try {
      fbDeviceToken = await messaging.getToken();
      if (fbDeviceToken != savedDeviceToken) {
        Hive.box('cache').put('deviceToken', fbDeviceToken);
        var future = Hive.box('settings').get('token') != null ? Api().updateDevice(
            data: {
              "device_id": fbDeviceToken,
              "device_type": Platform.isIOS ? "1" : "2"
            }
        ): null;
      }
    } catch(e) {
      print(e);
    }

  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  initialFuntion() {
    return Hive.box('settings').get('token') != null
        ? HomePage()
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
      restorationScopeId: 'ilhewl',
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
        '/nowplaying': (context) => NowPlaying(),
        '/recent': (context) => RecentlyPlayed(),
        '/playlists': (context) => PlaylistScreen(),
        '/downloads': (context) => const Downloads(),
        '/claim_artist_profile': (context) => ClaimArtistProfile(),
        '/all_songs': (context) => AllSongs(),
      },
      onGenerateRoute: (RouteSettings settings) {
        return HandleRoute().handleRoute(settings.name);
      },
    );
  }
}
