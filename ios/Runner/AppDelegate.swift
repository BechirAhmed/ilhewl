import UIKit
import Flutter
import Firebase


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
//    private let preventService = PreventCapturingService()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
//    preventService.startPreventScreenRecording()
    UIScreen.main.addObserver(self, forKeyPath: "captured", options: .new, context: nil)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "captured") {
            let isCaptured = UIScreen.main.isCaptured
//             if(isCaptured){
//                 self.window.isHidden = true
//             }else{
//                  self.window.isHidden = false
//              }

//             print(isCaptured)
        }
    }
    
}


