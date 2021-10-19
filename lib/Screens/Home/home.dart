import 'package:cached_network_image/cached_network_image.dart';
import 'package:ilhewl/CustomWidgets/custom_physics.dart';
import 'package:ilhewl/CustomWidgets/snackbar.dart';
import 'package:ilhewl/Helpers/app_config.dart';
import 'package:ilhewl/Helpers/countrycodes.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Screens/Home/homeData.dart';
import 'package:ilhewl/Screens/Home/saavn.dart';
import 'package:ilhewl/Screens/Library/downloaded.dart';
import 'package:ilhewl/Screens/Library/library.dart';
import 'package:ilhewl/Screens/Search/search.dart';
import 'package:ilhewl/Screens/Settings/profile.dart';
import 'package:ilhewl/Screens/Settings/setting.dart';
import 'package:ilhewl/Screens/Wallet/wallet.dart';
import 'package:device_info/device_info.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:ilhewl/CustomWidgets/miniplayer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ilhewl/Screens/Collections/collection.dart';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info/package_info.dart';
import 'package:ilhewl/Screens/Artist/artistSongs.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Box settingsBox;
  int appVersion;
  bool checked = false;
  bool update = false;
  DateTime backButtonPressTime;
  String name = Hive.box("settings").get('name', defaultValue: 'Guest');
  int artistId = Hive.box("settings").get('artistId', defaultValue: 0);
  String artworkUrl = Hive.box("settings").get('artwork_url', defaultValue: 'https://www.ilhewl.com/skins/default/images/small-logo.png');

  String capitalize(String msg) {
    return "${msg[0].toUpperCase()}${msg.substring(1)}";
  }

  void callback() {
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      pageController.animateToPage(index,
          duration: Duration(milliseconds: 400), curve: Curves.ease);
    });
  }

  updateUserDetails(String key, dynamic value) {
    final userID = Hive.box('settings').get('userID');
    final dbRef = FirebaseDatabase.instance.reference().child("Users");
    dbRef.child(userID.toString()).update({"$key": "$value"});
  }

  Widget checkVersion() {
    if (!checked && Theme.of(context).platform == TargetPlatform.android) {
      print('checking for update..');
      checked = true;
      DateTime now = DateTime.now();
      List lastLogin = now
          .toUtc()
          .add(Duration(hours: 5, minutes: 30))
          .toString()
          .split('.');
      lastLogin.removeLast();
      updateUserDetails('lastLogin', '${lastLogin.join('.')} IST');
      List offset = now.timeZoneOffset.toString().split('.');
      offset.removeLast();
      updateUserDetails(
          'timeZone', 'Zone: ${now.timeZoneName}, Offset: ${offset.join('.')}');
      final dbRef =
      FirebaseDatabase.instance.reference().child("LatestVersion");

      PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
        appVersion = int.parse(packageInfo.version.replaceAll('.', ''));
        updateUserDetails('version', packageInfo.version);
      });
      DeviceInfoPlugin info = DeviceInfoPlugin();
      info.androidInfo.then((AndroidDeviceInfo androidInfo) {
        Map deviceInfo = {
          'Brand': androidInfo.brand,
          'Manufacturer': androidInfo.manufacturer,
          'Device': androidInfo.device,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'Fingerprint': androidInfo.fingerprint,
          'Model': androidInfo.model,
          'Build': androidInfo.display,
          'Product': androidInfo.product,
          'androidVersion': androidInfo.version.release,
          'supportedAbis': androidInfo.supportedAbis,
        };
        Hive.box('settings').put('deviceInfo', deviceInfo);
        updateUserDetails('deviceInfo', deviceInfo);
      });

      dbRef.once().then((DataSnapshot snapshot) {
        if (int.parse(snapshot.value.toString().replaceAll('.', '')) >
            appVersion) {
          print('UPDATE IS AVAILABLE');
          return ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 15),
              margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 5.0),
              elevation: 6,
              backgroundColor: Colors.grey[900],
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Update Available!',
                style: TextStyle(color: Colors.white),
              ),
              action: SnackBarAction(
                textColor: Theme.of(context).accentColor,
                label: 'Update',
                onPressed: () {
                  Navigator.pop(context);
                  final dLink =
                  FirebaseDatabase.instance.reference().child("LatestLink");
                  dLink.once().then((DataSnapshot linkSnapshot) {
                    launch(linkSnapshot.value);
                  });
                },
              ),
            ),
          );
        }
      });
      // if (Hive.box('settings').get('proxyIp') == null)
      //   Hive.box('settings').put('proxyIp', "103.47.67.134");
      // if (Hive.box('settings').get('proxyPort') == null)
      //   Hive.box('settings').put('proxyPort', 8080);
      return SizedBox();
    } else {
      // print('platform not android or already checked');
      return SizedBox();
    }
  }

  ScrollController _scrollController;
  double _size = 0.0;

  void _scrollListener() {
    setState(() {
      _size = _scrollController.offset;
    });
  }

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<bool> handleWillPop(BuildContext context) async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed = backButtonPressTime == null || now.difference(backButtonPressTime) > const Duration(seconds: 3);

    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ShowSnackBar().showSnackBar(
        context,
        'Press Back Again to Exit App',
        duration: const Duration(seconds: 2),
        noAction: true,
      );
      return false;
    }
    return true;
  }

  PageController pageController = PageController(initialPage: 0);

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          drawer: Drawer(
            child: GradientContainer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomScrollView(
                    shrinkWrap: true,
                    physics: BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        automaticallyImplyLeading: false,
                        elevation: 0,
                        stretch: true,
                        pinned: false,
                        expandedHeight: MediaQuery.of(context).size.height * 0.2,
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            "ilhewl",
                            style: TextStyle(
                              fontSize: 30.0,
                            ),
                          ),
                          titlePadding: EdgeInsets.only(bottom: 40.0),
                          centerTitle: true,
                          stretchModes: [StretchMode.zoomBackground],
                          background: ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black, Colors.transparent],
                              ).createShader(
                                  Rect.fromLTRB(0, 0, rect.width, rect.height));
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image(
                                alignment: Alignment.topCenter,
                                image: AssetImage(
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? 'assets/header-dark.jpg'
                                        : 'assets/header.jpg')),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            ListTile(
                              title: Text(
                                'Home',
                                style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                ),
                              ),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 20.0),
                              leading: Icon(
                                Icons.home_rounded,
                                color: Theme.of(context).accentColor,
                              ),
                              selected: true,
                              onTap: () {
                                Navigator.pop(context);
                              },
                            ),
                            // artistId != 0 ? ListTile(
                            //   title: Text('My Music'),
                            //   contentPadding:
                            //   EdgeInsets.symmetric(horizontal: 20.0),
                            //   leading: Icon(
                            //     MdiIcons.folderMusic,
                            //     color: Theme.of(context).iconTheme.color,
                            //   ),
                            //   onTap: () {
                            //     Navigator.pop(context);
                            //     Navigator.push(
                            //         context,
                            //         MaterialPageRoute(
                            //             builder: (context) =>
                            //           artistId != 0 ? ArtistSongs(type: 'all',) : DownloadedSongs(type: 'all',)
                            //       ));
                            //   },
                            // ) : SizedBox(),
                            ListTile(
                              title: Text('Wallet'),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 20.0),
                              leading: Icon(
                                Icons
                                    .account_balance_wallet, // miscellaneous_services_rounded,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            WalletPage(callback: callback)));
                              },
                            ),
                            ListTile(
                              title: Text('Settings'),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 20.0),
                              leading: Icon(
                                Icons
                                    .settings_rounded, // miscellaneous_services_rounded,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            SettingPage(callback: callback)));
                              },
                            ),
                            ListTile(
                              title: Text('Logout'),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 20.0),
                              leading: Icon(
                                Icons
                                    .logout, // miscellaneous_services_rounded,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onTap: () {
                                _logout();
                              },
                            ),
                            ListTile(
                              title: Text('About'),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 20.0),
                              leading: Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/about');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                    child: Center(
                      child: Text(
                        'Made with ♥ by Foryts',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: WillPopScope(
            onWillPop: () => handleWillPop(context),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      physics: CustomPhysics(),
                      onPageChanged: (indx) {
                        setState(() {
                          _selectedIndex = indx;
                          if (indx == 0) {
                            _size = 0;
                          }
                        });
                      },
                      controller: pageController,
                      children: [
                        Stack(
                          children: [
                            checkVersion(),
                            NotificationListener<OverscrollIndicatorNotification>(
                              onNotification: (overScroll) {
                                overScroll.disallowGlow();
                                return;
                              },
                              child: NestedScrollView(
                                physics: BouncingScrollPhysics(),
                                controller: _scrollController,
                                headerSliverBuilder: (BuildContext context, bool innerBoxScrolled) {
                                  final controller = TextEditingController();
                                  return <Widget>[
                                    SliverAppBar(
                                      expandedHeight: 120,
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      // pinned: true,
                                      toolbarHeight: 45,
                                      // floating: true,
                                      automaticallyImplyLeading: false,
                                      flexibleSpace: LayoutBuilder(
                                        builder: (BuildContext context,
                                            BoxConstraints constraints) {
                                          return FlexibleSpaceBar(
                                            // collapseMode: CollapseMode.parallax,
                                            background: GestureDetector(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  SizedBox(
                                                    height: 60,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets.only(
                                                            left: 15.0),
                                                        child: Text(
                                                          'Hi There,',
                                                          style: TextStyle(
                                                              letterSpacing: 2,
                                                              color: Theme.of(
                                                                  context)
                                                                  .accentColor,
                                                              fontSize: 30,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Padding(
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 15.0),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                      children: [
                                                        ValueListenableBuilder(
                                                            valueListenable:
                                                            Hive.box(
                                                                'settings')
                                                                .listenable(),
                                                            builder: (BuildContext
                                                            context,
                                                                Box box,
                                                                widget) {
                                                              return Text(
                                                                (box.get('name') ==
                                                                    null ||
                                                                    box.get('name') ==
                                                                        '')
                                                                    ? 'Guest'
                                                                    : capitalize(box
                                                                    .get(
                                                                    'name')
                                                                    .split(
                                                                    ' ')[0]),
                                                                style: TextStyle(
                                                                    letterSpacing:
                                                                    2,
                                                                    fontSize: 20,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                              );
                                                            }),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    final _controller =
                                                    TextEditingController(
                                                        text: name);
                                                    return AlertDialog(
                                                      content: Column(
                                                        mainAxisSize:
                                                        MainAxisSize.min,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Name',
                                                                style: TextStyle(
                                                                    color: Theme.of(
                                                                        context)
                                                                        .accentColor),
                                                              ),
                                                            ],
                                                          ),
                                                          TextField(
                                                              autofocus: true,
                                                              textAlignVertical:
                                                              TextAlignVertical
                                                                  .bottom,
                                                              controller:
                                                              _controller,
                                                              onSubmitted:
                                                                  (value) {
                                                                Hive.box(
                                                                    'settings')
                                                                    .put(
                                                                    'name',
                                                                    value
                                                                        .trim());
                                                                name =
                                                                    value.trim();
                                                                Navigator.pop(
                                                                    context);
                                                                updateUserDetails(
                                                                    'name',
                                                                    value.trim());
                                                                setState(() {});
                                                              }),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          style: TextButton
                                                              .styleFrom(
                                                            primary: Theme.of(
                                                                context)
                                                                .brightness ==
                                                                Brightness
                                                                    .dark
                                                                ? Colors.white
                                                                : Colors
                                                                .grey[700],
                                                          ),
                                                          child: Text("Cancel"),
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                        ),
                                                        TextButton(
                                                          style: TextButton
                                                              .styleFrom(
                                                            primary: Colors.white,
                                                            backgroundColor:
                                                            Theme.of(context)
                                                                .accentColor,
                                                          ),
                                                          child: Text(
                                                            "Ok",
                                                            style: TextStyle(
                                                                color:
                                                                Colors.white),
                                                          ),
                                                          onPressed: () {
                                                            Hive.box("settings")
                                                                .put(
                                                                'name',
                                                                _controller
                                                                    .text
                                                                    .trim());

                                                            Navigator.pop(
                                                                context);
                                                            updateUserDetails(
                                                                'name',
                                                                _controller.text
                                                                    .trim());
                                                            name = _controller
                                                                .text
                                                                .trim();
                                                            setState(() {});
                                                          },
                                                        ),
                                                        SizedBox(
                                                          width: 5,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ];
                                },
                                body: HomeData(),
                              ),
                            ),
                            Builder(
                              builder: (context) => Padding(
                                padding:
                                const EdgeInsets.only(top: 8.0, left: 4.0),
                                child: Transform.rotate(
                                  angle: 22 / 7 * 2,
                                  child: IconButton(
                                    icon: const Icon(
                                        Icons.horizontal_split_rounded),
                                    color: Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? null
                                        : Colors.grey[700],
                                    onPressed: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                    tooltip: MaterialLocalizations.of(context)
                                        .openAppDrawerTooltip,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            checkVersion(),
                            NotificationListener<OverscrollIndicatorNotification>(
                              onNotification: (overScroll) {
                                overScroll.disallowGlow();
                                return;
                              },
                              child: NestedScrollView(
                                physics: BouncingScrollPhysics(),
                                controller: _scrollController,
                                headerSliverBuilder: (BuildContext context, bool innerBoxScrolled) {
                                  final controller = TextEditingController();
                                  return <Widget>[
                                    SliverAppBar(
                                      title: Text(
                                        'Collections',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Theme.of(context).textTheme.bodyText1.color,
                                        ),
                                      ),
                                      expandedHeight: 70,
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      // pinned: true,
                                      toolbarHeight: 45,
                                      // floating: true,
                                      automaticallyImplyLeading: false,
                                      flexibleSpace: LayoutBuilder(
                                        builder: (BuildContext context,
                                            BoxConstraints constraints) {
                                          return FlexibleSpaceBar(
                                            // collapseMode: CollapseMode.parallax,
                                            background: GestureDetector(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  // SizedBox(
                                                  //   height: 60,
                                                  // ),
                                                  // Row(
                                                  //   children: [
                                                  //     Padding(
                                                  //       padding:
                                                  //       const EdgeInsets.only(
                                                  //           left: 15.0),
                                                  //       child: Text(
                                                  //         'Hi There,',
                                                  //         style: TextStyle(
                                                  //             letterSpacing: 2,
                                                  //             color: Theme.of(
                                                  //                 context)
                                                  //                 .accentColor,
                                                  //             fontSize: 30,
                                                  //             fontWeight:
                                                  //             FontWeight
                                                  //                 .bold),
                                                  //       ),
                                                  //     ),
                                                  //   ],
                                                  // ),
                                                  // Padding(
                                                  //   padding:
                                                  //   const EdgeInsets.only(
                                                  //       left: 15.0),
                                                  //   child: Row(
                                                  //     crossAxisAlignment:
                                                  //     CrossAxisAlignment.end,
                                                  //     children: [
                                                  //       ValueListenableBuilder(
                                                  //           valueListenable:
                                                  //           Hive.box(
                                                  //               'settings')
                                                  //               .listenable(),
                                                  //           builder: (BuildContext
                                                  //           context,
                                                  //               Box box,
                                                  //               widget) {
                                                  //             return Text(
                                                  //               (box.get('name') ==
                                                  //                   null ||
                                                  //                   box.get('name') ==
                                                  //                       '')
                                                  //                   ? 'Guest'
                                                  //                   : capitalize(box
                                                  //                   .get(
                                                  //                   'name')
                                                  //                   .split(
                                                  //                   ' ')[0]),
                                                  //               style: TextStyle(
                                                  //                   letterSpacing:
                                                  //                   2,
                                                  //                   fontSize: 20,
                                                  //                   fontWeight:
                                                  //                   FontWeight
                                                  //                       .w500),
                                                  //             );
                                                  //           }),
                                                  //     ],
                                                  //   ),
                                                  // ),
                                                ],
                                              ),
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    final _controller =
                                                    TextEditingController(
                                                        text: name);
                                                    return AlertDialog(
                                                      content: Column(
                                                        mainAxisSize:
                                                        MainAxisSize.min,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Name',
                                                                style: TextStyle(
                                                                    color: Theme.of(
                                                                        context)
                                                                        .accentColor),
                                                              ),
                                                            ],
                                                          ),
                                                          TextField(
                                                              autofocus: true,
                                                              textAlignVertical:
                                                              TextAlignVertical
                                                                  .bottom,
                                                              controller:
                                                              _controller,
                                                              onSubmitted:
                                                                  (value) {
                                                                Hive.box(
                                                                    'settings')
                                                                    .put(
                                                                    'name',
                                                                    value
                                                                        .trim());
                                                                name =
                                                                    value.trim();
                                                                Navigator.pop(
                                                                    context);
                                                                updateUserDetails(
                                                                    'name',
                                                                    value.trim());
                                                                setState(() {});
                                                              }),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          style: TextButton
                                                              .styleFrom(
                                                            primary: Theme.of(
                                                                context)
                                                                .brightness ==
                                                                Brightness
                                                                    .dark
                                                                ? Colors.white
                                                                : Colors
                                                                .grey[700],
                                                          ),
                                                          child: Text("Cancel"),
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                        ),
                                                        TextButton(
                                                          style: TextButton
                                                              .styleFrom(
                                                            primary: Colors.white,
                                                            backgroundColor:
                                                            Theme.of(context)
                                                                .accentColor,
                                                          ),
                                                          child: Text(
                                                            "Ok",
                                                            style: TextStyle(
                                                                color:
                                                                Colors.white),
                                                          ),
                                                          onPressed: () {
                                                            Hive.box("settings")
                                                                .put(
                                                                'name',
                                                                _controller
                                                                    .text
                                                                    .trim());

                                                            Navigator.pop(
                                                                context);
                                                            updateUserDetails(
                                                                'name',
                                                                _controller.text
                                                                    .trim());
                                                            name = _controller
                                                                .text
                                                                .trim();
                                                            setState(() {});
                                                          },
                                                        ),
                                                        SizedBox(
                                                          width: 5,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SliverAppBar(
                                      automaticallyImplyLeading: false,
                                      pinned: true,
                                      floating: false,
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      stretch: true,
                                      toolbarHeight: 65,
                                      title: Align(
                                        alignment: Alignment.centerRight,
                                        child: AnimatedContainer(
                                          width: max(
                                              MediaQuery.of(context).size.width -
                                                  _size,
                                              MediaQuery.of(context).size.width -
                                                  75),

                                          duration: Duration(milliseconds: 300),
                                          padding: EdgeInsets.all(2.0),
                                          // margin: EdgeInsets.zero,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(10.0),
                                            color: Theme.of(context).cardColor,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 5.0,
                                                spreadRadius: 0.0,
                                                offset: Offset(0.0, 3.0),
                                                // shadow direction: bottom right
                                              )
                                            ],
                                          ),
                                          child: TextField(
                                            controller: controller,
                                            textAlignVertical:
                                            TextAlignVertical.center,
                                            decoration: InputDecoration(
                                              focusedBorder: UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    width: 1.5,
                                                    color: Colors.transparent),
                                              ),
                                              fillColor:
                                              Theme.of(context).accentColor,
                                              prefixIcon: Icon(
                                                CupertinoIcons.search,
                                                color:
                                                Theme.of(context).accentColor,
                                              ),
                                              border: InputBorder.none,
                                              hintText:
                                              "Songs, albums or artists",
                                            ),
                                            autofocus: false,
                                            onSubmitted: (query) {
                                              if (query.trim() == '') {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: Text(
                                                        'Invalid search',
                                                        style: TextStyle(
                                                            color:
                                                            Theme.of(context)
                                                                .accentColor),
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                        MainAxisSize.min,
                                                        children: [
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                          Text(
                                                              'Please enter a valid search query'),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                            style: TextButton
                                                                .styleFrom(
                                                              primary: Theme.of(
                                                                  context)
                                                                  .accentColor,
                                                            ),
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: Text('Ok'))
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                List search = Hive.box('settings')
                                                    .get('search',
                                                    defaultValue: []);
                                                if (search.contains(query))
                                                  search.remove(query);
                                                search.insert(0, query);
                                                if (search.length > 10)
                                                  search = search.sublist(0, 10);
                                                Hive.box('settings')
                                                    .put('search', search);
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            SearchPage(
                                                                query: query)));
                                              }
                                              controller.text = '';
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ];
                                },
                                body: Collections(),
                              ),
                            ),
                            Builder(
                              builder: (context) => Padding(
                                padding:
                                const EdgeInsets.only(top: 8.0, left: 4.0),
                                child: Transform.rotate(
                                  angle: 22 / 7 * 2,
                                  child: IconButton(
                                    icon: const Icon(
                                        Icons.horizontal_split_rounded),
                                    color: Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? null
                                        : Colors.grey[700],
                                    onPressed: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                    tooltip: MaterialLocalizations.of(context)
                                        .openAppDrawerTooltip,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Collections(),
                        LibraryPage(),
                        artistId != 0 ? ArtistSongs(type: 'all',) : ProfileScreen(),
                      ],
                    ),
                  ),
                  MiniPlayer()
                ],
              ),
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder(
              valueListenable: playerExpandProgress,
              builder: (BuildContext context, double value, Widget child) {
                return SafeArea(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 100),
                    height: 60 *
                        (MediaQuery.of(context).size.height - value) /
                        (MediaQuery.of(context).size.height - 76),
                    child: SalomonBottomBar(
                      currentIndex: _selectedIndex,
                      onTap: (index) {
                        _onItemTapped(index);
                      },
                      items: [
                        /// Home
                        SalomonBottomBarItem(
                          icon: Icon(Icons.home_rounded),
                          title: Text("Home"),
                          selectedColor: Theme.of(context).accentColor,
                        ),

                        SalomonBottomBarItem(
                          icon: Icon(Icons.search),
                          title: Text("Search"),
                          selectedColor: Theme.of(context).accentColor,
                        ),
                        SalomonBottomBarItem(
                          icon: const Icon(MdiIcons.music),
                          title: const Text('Library'),
                          selectedColor: Theme.of(context).accentColor,
                        ),
                        SalomonBottomBarItem(
                          icon: ClipRRect(
                            borderRadius: BorderRadius.circular(20.0),
                            child: CachedNetworkImage(
                              fit: BoxFit.cover,
                              errorWidget: (context, _, __) =>
                                  Image(
                                    image: AssetImage('assets/logo.png'),
                                    fit: BoxFit.cover,
                                  ),
                              imageUrl: artworkUrl.replaceAll('http:', 'https:'),
                              placeholder: (context, url) =>
                                  Image(
                                    image: AssetImage('assets/logo.png'),
                                    fit: BoxFit.cover,
                                  ),
                            ),
                          ),
                          title: Text("Profile"),
                          selectedColor: Theme.of(context).accentColor,
                        ),
                      ],
                    ),
                  ),
                );
              })),
    );
  }

  void _logout() async {
    EasyLoading.show(status: "Loading...");
    Hive.box('settings').delete('userID');
    Hive.box('settings').delete('artistId');
    Hive.box('settings').delete('name');
    Hive.box('settings').delete('phone');
    Hive.box('settings').delete('token');
    Hive.box('settings').delete('currency');
    EasyLoading.dismiss();
    Navigator.popAndPushNamed(context, '/');
  }
}