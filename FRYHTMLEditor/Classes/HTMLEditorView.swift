//
//  HTMLEditorView.swift
//  HTMLEditor
//
//  Created by Slava Zubrin on 3/7/20.
//  Copyright © 2020 Slava Zubrin. All rights reserved.
//

import UIKit
import WebKit

@objc
public protocol HTMLEditorContentDelegate {
    @objc optional func contentUpdated(_ html: String)
}

public protocol HTMLEditorToolbarDelegate: class {
    func selectedTagsUpdated(_ tags: [HTMLEditorView.Tag])
}

public class HTMLEditorView: UIView {

    public weak var delegate: HTMLEditorContentDelegate? = nil
    public weak var toolbarDelegate: HTMLEditorToolbarDelegate? = nil

    public enum HTMLEditorError: Error {
        case general
    }

    // configuration
    public struct LinkDialogConfig {
        let dialogTitle: String
        let namePlacehooleder: String
        let linkPlaceholder: String
        let insertButtonTitle: String
        let updateButtonTitle: String
        let removeButtonTitle: String
        let cancelButtonTitle: String

        static var `default`: LinkDialogConfig {
            return LinkDialogConfig(dialogTitle: "Insert link",
                                    namePlacehooleder: "name ...",
                                    linkPlaceholder: "URL (required) ...",
                                    insertButtonTitle: "Insert",
                                    updateButtonTitle: "Update",
                                    removeButtonTitle: "Remove",
                                    cancelButtonTitle: "Cancel")
        }
    }
    public var linkDialogConfig: LinkDialogConfig = .default

    private var customCSS: String?
    private var internalHTML: String?

    // setup state
    private var isResourcesLoaded = false
    private var isEditorLoaded = false

    // internal state
    private var selectedLinkTitle: String?
    private var selectedLinkURLString: String?

    private lazy var webView: WKWebView & FRYWebViewWithInputAccessory = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []

        let contentController = WKUserContentController()
        contentController.add(self, name: "jsm")
        let scriptString = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
        let script = WKUserScript(source: scriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(script)
        config.userContentController = contentController

        let wv: WKWebView & FRYWebViewWithInputAccessory
        if #available(iOS 13, *) {
            wv = FRYWebView(frame: .zero, configuration: config)
        } else {
            wv = FRYWebViewObsolete(frame: .zero, configuration: config)
        }
        wv.navigationDelegate = self
        wv.scrollView.bounces = true
        wv.backgroundColor = .white
        return wv
    }()

    // MARK: - Lifecycle

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: topAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
        webView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
        webView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true

        if !isResourcesLoaded {
            loadResources()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - Public

    public func setInputAccessoryView(_ toolbar: UIToolbar) {
        webView.addInputAccessoryView(toolbar: toolbar)
    }

    public func set(css: String) {
        customCSS = css

        if isEditorLoaded {
            updateCSS()
        }
    }

    /// Sets the HTML for the entire editor
    /// - Parameter html: html to be set
    public func set(html: String) {
        internalHTML = html
        if isEditorLoaded {
            updateHTML()
        }
    }

    /// Inserts HTML at the carret position
    /// - Parameter html: HTML to be inserted
    public func insert(html: String) {
        let cleanedHTML = removeQuotes(from: html)
        let js = "zss_editor.insertHTML(\"\(cleanedHTML)\");"
        webView.evaluateJavaScript(js) { [weak self] (_, _) in
            self?.informContentDelegate()
        }
    }

    /// Fetches HTML from the editor
    /// - Parameter completion: completion block
    public func fetchHTML(completion: @escaping (Result<String, Error>)->()) {
        webView.evaluateJavaScript("zss_editor.getHTML();") { [weak self] (value, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let self = self, let value = value as? String else {
                completion(.failure(HTMLEditorError.general))
                return
            }

            //let html = self.removeQuotes(from: value)
            completion(.success(self.tidy(html: value)))
        }
    }

    /// Fetches plain text from the editor
    /// - Parameter completion: completion block
    public func fetchText(completion: @escaping (Result<String, Error>)->()) {
        webView.evaluateJavaScript("zss_editor.getText();") { (value, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let value = value as? String else {
                completion(.failure(HTMLEditorError.general))
                return
            }

            completion(.success(value))
        }
    }

    // ---

    public enum Tag {
        case bold, italic, underline, orderedList, bulletList, link

        public init?(jsId: String) {
            var tag: Tag? = nil
            switch jsId {
            case "bold":          tag = .bold
            case "italic":        tag = .italic
            case "underline":     tag = .underline
            case "orderedList":   tag = .orderedList
            case "unorderedList": tag = .bulletList
            default: break
            }

            // try to construct link
            if tag == nil, jsId.hasPrefix("link") {
                tag = .link
            }

            if let _tag = tag {
                self = _tag
            } else {
                return nil
            }
        }
    }

    /// Send formatting command to the editor
    /// - Parameter tag: tag that determines the desired formatting style
    public func send(tag: Tag) {
        let trigger: String
        switch tag {
        case .bold:         trigger = "zss_editor.setBold();"
        case .italic:       trigger = "zss_editor.setItalic();"
        case .underline:    trigger = "zss_editor.setUnderline();"
        case .orderedList:  trigger = "zss_editor.setOrderedList();"
        case .bulletList:   trigger = "zss_editor.setUnorderedList();"
        case .link:         trigger = "zss_editor.prepareInsert();"
        }

        webView.evaluateJavaScript(trigger) { [weak self] (_, _) in
            self?.informContentDelegate()
        }

        if tag == .link {
            showInsertLinkDialog(url: selectedLinkURLString, title: selectedLinkTitle)
        }
    }

    // MARK: - Private
    // MARK: Setup

    private func loadResources() {
        let bundle = Bundle(for: HTMLEditorView.self)

        guard let editorPath = bundle.path(forResource: "editor", ofType: "html"),
            let editorData = try? Data(contentsOf: URL(fileURLWithPath: editorPath)),
            var editorHTML = String(data: editorData, encoding: .utf8) else {
            fatalError("Can't find or read 'editor.html' file")
        }

        guard let jqueryPath = bundle.path(forResource: "jQuery", ofType: "js"),
            let jqueryData = try? Data(contentsOf: URL(fileURLWithPath: jqueryPath)),
            let jqueryHTML = String(data: jqueryData, encoding: .utf8) else {
            fatalError("Can't find or read 'jQuery.js' file")
        }
        editorHTML = editorHTML.replacingOccurrences(of: "<!-- jQuery -->", with: jqueryHTML)

        guard let beautifierPath = bundle.path(forResource: "JSBeautifier", ofType: "js"),
            let beautifierData = try? Data(contentsOf: URL(fileURLWithPath: beautifierPath)),
            let beautifierHTML = String(data: beautifierData, encoding: .utf8) else {
            fatalError("Can't find or read 'JSBeautifier.js' file")
        }
        editorHTML = editorHTML.replacingOccurrences(of: "<!-- jsbeautifier -->", with: beautifierHTML)

        guard let rtePath = bundle.path(forResource: "ZSSRichTextEditor", ofType: "js"),
            let rteData = try? Data(contentsOf: URL(fileURLWithPath: rtePath)),
            let rteHTML = String(data: rteData, encoding: .utf8) else {
            fatalError("Can't find or read 'ZSSRichTextEditor.js' file")
        }
        editorHTML = editorHTML.replacingOccurrences(of: "<!--editor-->", with: rteHTML)

        webView.loadHTMLString(editorHTML, baseURL: nil)

        isResourcesLoaded = true
    }

    private func updateCSS() {
        guard let customCSS = customCSS, !customCSS.isEmpty else { return }

        let js = "zss_editor.setCustomCSS(\"\(customCSS)\");"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func updateHTML() {
        guard let html = internalHTML else { return }

        let cleanedHTML = removeQuotes(from: html)
        let js = "zss_editor.setHTML(\"\(cleanedHTML)\");"
        webView.evaluateJavaScript(js) { [weak self] (_, _) in
            self?.informContentDelegate()
        }
    }

    // MARK: Link-related routines

    private func showInsertLinkDialog(url: String?, title: String?) {
        let alert = IndependentAlert(title: linkDialogConfig.dialogTitle, message: nil, preferredStyle: .alert)
        // name text field
        alert.addTextField { [weak self] (textField) in
            textField.placeholder = self?.linkDialogConfig.namePlacehooleder
            textField.text = title ?? nil
        }
        // url text field
        alert.addTextField { [weak self] (textField) in
            textField.placeholder = self?.linkDialogConfig.linkPlaceholder
            textField.text = url ?? nil
        }
        // ok action
        let hasPredefinedLinkURL = selectedLinkURLString != nil
        let okTitle = hasPredefinedLinkURL ? linkDialogConfig.updateButtonTitle : linkDialogConfig.insertButtonTitle
        let okAction = UIAlertAction(title: okTitle, style: .default) { [weak self, weak alert] action in
            guard let alert = alert else { return }
            guard let urlString = alert.textFields?.last?.text,
                let url = self?.constructURLFromUserInput(urlString) else {
                    return
            }

            let _title = alert.textFields?.first?.text

            if hasPredefinedLinkURL {
                self?.updateLink(url: url, title: _title)
            } else {
                self?.insertLink(url: url, title: _title)
            }
        }
        alert.addAction(okAction)
        // remove action
        if hasPredefinedLinkURL {
            let removeAction = UIAlertAction(title: linkDialogConfig.removeButtonTitle, style: .destructive) { [weak self] _ in
                self?.removeLink()
            }
            alert.addAction(removeAction)
        }
        // cancel action
        let cancel = UIAlertAction(title: linkDialogConfig.cancelButtonTitle, style: .cancel, handler: nil)
        alert.addAction(cancel)
        alert.show()
    }

    private func constructURLFromUserInput(_ string: String) -> URL? {
        guard !string.isEmpty, var urlComponent = URLComponents(string: string) else { return nil }

        // make sure scheme is not empty
        if urlComponent.scheme == nil
            || (urlComponent.scheme != "http"
                && urlComponent.scheme != "https"
                && urlComponent.scheme != "andfrankly") {
            urlComponent.scheme = "http"
        }

        // make sure host is not empty
        if urlComponent.host == nil {
            var pathParts = urlComponent.path.components(separatedBy: "/")

            if !pathParts.isEmpty {
                urlComponent.host = pathParts.removeFirst()
                urlComponent.path = "/" + pathParts.joined(separator: "/")
            } else {
                urlComponent.host = urlComponent.path
                urlComponent.path = ""
            }
        }

        return urlComponent.url
    }

    private func insertLink(url: URL, title: String?) {
        let trigger = "zss_editor.insertLink(\"\(url.absoluteString)\", \"\(title ?? "")\");"
        webView.evaluateJavaScript(trigger) { [weak self] (_, _) in
            self?.informContentDelegate()
        }
    }

    private func updateLink(url: URL, title: String?) {
        let trigger = "zss_editor.updateLink(\"\(url.absoluteString)\", \"\(title ?? "")\");"
        webView.evaluateJavaScript(trigger) { [weak self] (_, _) in
            self?.informContentDelegate()
        }
    }

    private func removeLink() {
        let trigger = "zss_editor.unlink();"
        webView.evaluateJavaScript(trigger) { [weak self] (_, _) in
            self?.informContentDelegate()
        }
    }

    // MARK: HTML Helpers

    private func removeQuotes(from html: String) -> String {
        return html.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "“", with: "&quot;")
            .replacingOccurrences(of: "”", with: "&quot;")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func tidy(html: String) -> String {
        return html.replacingOccurrences(of: "<br>", with: "<br />")
            .replacingOccurrences(of: "<hr>", with: "<hr />")
    }

    private func stringByDecodingURLFormat(_ string: String) -> String {
        return string.replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding ?? string
    }

    // MARK: Toolbar items management

    private func updateToolbarButton(_ namesString: String) {
        let names = namesString.components(separatedBy: ",")

        typealias TagInfo = (tag: Tag, source: String)
        let selectedTagsInfo = names.compactMap({ source -> TagInfo? in
            if let tag = Tag(jsId: source) {
                return (tag: tag, source: source)
            }
            return nil
        })

        // fetch link data if any
        var foundLinkURLString: String? = nil
        var foundLinkTitle: String? = nil
        if selectedTagsInfo.contains(where: { $0.tag == .link }) {
            let linksInfo = selectedTagsInfo.filter { $0.tag == .link }
            for tagInfo in linksInfo {
                if tagInfo.source.hasPrefix("link:") {
                    foundLinkURLString = tagInfo.source.replacingOccurrences(of: "link:", with: "")
                } else if tagInfo.source.hasPrefix("link-title:") {
                    foundLinkTitle = stringByDecodingURLFormat(tagInfo.source.replacingOccurrences(of: "link-title:", with: ""))
                }
            }
        }
        self.selectedLinkURLString = foundLinkURLString
        self.selectedLinkTitle = foundLinkTitle

        toolbarDelegate?.selectedTagsUpdated(selectedTagsInfo.map({ $0.tag }))
    }

    // MARK: Helpers

    private func informContentDelegate() {
        guard let contentDelegate = delegate else { return }

        fetchHTML { (result) in
            guard case let .success(html) = result else { return }
            contentDelegate.contentUpdated?(html)
        }
    }
}

// MARK: - WKScriptMessageHandler

extension HTMLEditorView: WKScriptMessageHandler {

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let msg = message.body as? String else { return }

        if msg == "input" {
            informContentDelegate()
        }
    }
}

// MARK: - WKNavigationDelegate

extension HTMLEditorView: WKNavigationDelegate {

    public func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        var policy: WKNavigationActionPolicy = .allow
        if navigationAction.navigationType == .linkActivated {
            policy = .cancel
        } else if url.absoluteString.range(of: "callback://0/") != nil { // callback received
            let name = url.absoluteString.replacingOccurrences(of: "callback://0/", with: "")
            updateToolbarButton(name)
        } else if url.absoluteString.range(of: "debug://") != nil { // debug event
            let message = url.absoluteString.replacingOccurrences(of: "debug://", with: "")
            print(message.removingPercentEncoding ?? message)
        }

        decisionHandler(policy)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isEditorLoaded = true

        if internalHTML == nil {
            internalHTML = ""
        }
        updateHTML()

        if let _ = customCSS {
            updateCSS()
        }

        let inputListener = "document.getElementById('zss_editor_content').addEventListener('input', function() {window.webkit.messageHandlers.jsm.postMessage('input');});";
        webView.evaluateJavaScript(inputListener, completionHandler: nil)

        let pasteListener = "document.getElementById('zss_editor_content').addEventListener('paste', function() {window.webkit.messageHandlers.jsm.postMessage('paste');});";
        webView.evaluateJavaScript(pasteListener, completionHandler: nil)
    }
}
