import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String appVersion;

  @override
  void initState() {
    main();
    super.initState();
  }

  void main() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Stack(
        children: [
          Positioned(
            left: MediaQuery.of(context).size.width / 2,
            top: MediaQuery.of(context).size.width / 5,
            child: Container(
              width: MediaQuery.of(context).size.width,
              child: Image(
                fit: BoxFit.fill,
                image: AssetImage(
                  'assets/logo.png',
                ),
              ),
            ),
          ),
          GradientContainer(
            child: null,
            opacity: true,
          ),
          Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Theme.of(context).accentColor,
              elevation: 0,
              title: Text(
                'About',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
            ),
            backgroundColor: Colors.transparent,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: 20,
                    ),
                    SizedBox(
                        width: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                            child: Image(image: AssetImage('assets/logo.png'))
                        )
                    ),
                    SizedBox(height: 20),
                    Text(
                      'ilhewl',
                      style:
                          TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
                    ),
                    Text('v$appVersion'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                  child: Column(
                    children: [
                      Text(
                        'ilhewl The first music store in west Africa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     TextButton(
                      //         child: Container(
                      //           width: MediaQuery.of(context).size.width / 4,
                      //           child: Image(
                      //             image: Theme.of(context).brightness == Brightness.dark
                      //                 ? AssetImage('assets/appstore.png')
                      //                 : AssetImage('assets/appstore.png'),
                      //           ),
                      //         ),
                      //         onPressed: () {
                      //           launch("https://ilhewl.com");
                      //         }
                      //     ),
                      //     TextButton(
                      //         child: Container(
                      //           width: MediaQuery.of(context).size.width / 4,
                      //           child: Image(
                      //             image: Theme.of(context).brightness == Brightness.dark
                      //                 ? AssetImage('assets/playstore.png')
                      //                 : AssetImage('assets/playstore.png'),
                      //           ),
                      //         ),
                      //         onPressed: () {
                      //           launch("https://ilhewl.com");
                      //         }),
                      //   ],
                      // ),
                      Text(
                        "If you liked the app\nshow some ♥ and ⭐ rate it",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                  child: Center(
                    child: Text(
                      'Made with ♥ by Mauritanian Artists',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
