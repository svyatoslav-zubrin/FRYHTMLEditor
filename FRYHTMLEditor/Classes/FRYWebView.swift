//
//  FRYWebView.swift
//  FRYHTMLEditor
//
//  Created by Slava Zubrin on 3/12/20.
//

import UIKit
import WebKit

protocol FRYWebViewWithInputAccessory {
    func addInputAccessoryView(toolbar: UIToolbar?)
}

// MARK: - FRYWebView

class FRYWebView: WKWebView, FRYWebViewWithInputAccessory {
    private var accessoryView: UIToolbar?

    public override var inputAccessoryView: UIView? {
        return accessoryView
    }

    func addInputAccessoryView(toolbar: UIToolbar?) {
        accessoryView = toolbar
    }
}
