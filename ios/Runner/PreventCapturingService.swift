//
//  PreventCapturingService.swift
//  Runner
//
//  Created by admin on 18/09/2021.
//

import Foundation
import UIKit

//final class ScreenRecordingProtoector {
//
//    private var window: UIWindow? {
//        if #available(iOS 13, *) {
//            return (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window
//        }
//        return (UIApplication.shared.delegate as? AppDelegate)?.window
//    }
//
//    func startPreventing() {
//        NotificationCenter.default.addObserver(self, selector: #selector(preventScreenShoot), name: UIScreen.capturedDidChangeNotification, object: nil)
//    }
//
//    @objc private func preventScreenShoot() {
//        if #available(iOS 13, *) {
//            if UIScreen.main.isCaptured {
//                window?.isHidden = true
//            } else {
//                window?.isHidden = false
//            }
//        }
//    }
//
//    // MARK: - Deinit
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//}
