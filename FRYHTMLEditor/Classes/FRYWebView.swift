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

// MARK: - FRYWebViewObsolete

@available(iOS, deprecated: 13, obsoleted: 13, message: "Use FRYWebView class instead which benefits from native API usage in favor of swizzling under the hood")
class FRYWebViewObsolete: WKWebView {}

var ToolbarHandle: UInt8 = 0

extension FRYWebViewObsolete: FRYWebViewWithInputAccessory {

    func addInputAccessoryView(toolbar: UIToolbar?) {
        guard let toolbar = toolbar else {return}
        objc_setAssociatedObject(self, &ToolbarHandle, toolbar, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        var candidateView: UIView? = nil
        for view in self.scrollView.subviews {
            let description : String = String(describing: type(of: view))
            if description.hasPrefix("WKContent") {
                candidateView = view
                break
            }
        }
        guard let targetView = candidateView else {return}
        let newClass: AnyClass? = classWithCustomAccessoryView(targetView: targetView)

        guard let targetNewClass = newClass else {return}

        object_setClass(targetView, targetNewClass)
    }

    func classWithCustomAccessoryView(targetView: UIView) -> AnyClass? {
        guard let _ = targetView.superclass else {return nil}
        let customInputAccesoryViewClassName = "_CustomInputAccessoryView"

        var newClass: AnyClass? = NSClassFromString(customInputAccesoryViewClassName)
        if newClass == nil {
            newClass = objc_allocateClassPair(object_getClass(targetView), customInputAccesoryViewClassName, 0)
        } else {
            return newClass
        }

        let newMethod = class_getInstanceMethod(FRYWebViewObsolete.self, #selector(FRYWebViewObsolete.getCustomInputAccessoryView))
        class_addMethod(newClass.self, #selector(getter: FRYWebViewObsolete.inputAccessoryView), method_getImplementation(newMethod!), method_getTypeEncoding(newMethod!))

        objc_registerClassPair(newClass!)

        return newClass
    }

    @objc func getCustomInputAccessoryView() -> UIToolbar? {
        var superWebView: UIView? = self
        while (superWebView != nil) && !(superWebView is FRYWebViewObsolete) {
            superWebView = superWebView?.superview
        }

        guard let webView = superWebView else {return nil}

        let customInputAccessory = objc_getAssociatedObject(webView, &ToolbarHandle)
        return customInputAccessory as? UIToolbar
    }
}
