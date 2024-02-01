//
//  IndependentAlert.swift
//  HTMLEditor
//
//  Created by Slava Zubrin on 3/10/20.
//  Copyright © 2020 Slava Zubrin. All rights reserved.
//

import UIKit

class IndependentAlert: UIAlertController {

    private lazy var window: UIWindow = {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.windowLevel = UIWindow.Level.alert + 1
        window.backgroundColor = .clear
        window.rootViewController = ClearViewController()
        return window
    }()

    // MARK: - Public
    func show() {
        guard let rvc = window.rootViewController else { return }

        window.makeKeyAndVisible()
        rvc.present(self, animated: true, completion: nil)
    }
}

private class ClearViewController: UIViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIApplication.shared.statusBarStyle
    }

    override var prefersStatusBarHidden: Bool {
        return UIApplication.shared.isStatusBarHidden
    }
}
