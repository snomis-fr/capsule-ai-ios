//
//  UIApplication+RootViewController.swift
//  CapsuleAI
//

import UIKit

extension UIApplication {
    var rootViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
