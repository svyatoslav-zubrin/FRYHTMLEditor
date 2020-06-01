//
//  ViewController.swift
//  HTMLEditor
//
//  Created by Slava Zubrin on 3/7/20.
//  Copyright © 2020 Slava Zubrin. All rights reserved.
//

import UIKit
import FRYHTMLEditor

class ViewController: UIViewController {

    @IBOutlet private weak var editorContainer: UIView!
    @IBOutlet private weak var textView: UITextView!
    private weak var editor: HTMLEditorView!

    // toolbar items
    @IBOutlet private weak var boldBBI: UIBarButtonItem!
    @IBOutlet private weak var italicBBI: UIBarButtonItem!
    @IBOutlet private weak var underlineBBI: UIBarButtonItem!
    @IBOutlet private weak var orderdListBBI: UIBarButtonItem!
    @IBOutlet private weak var bulletListBBI: UIBarButtonItem!
    @IBOutlet private weak var linkBBI: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        constructEditor()
    }

    @IBAction func insertHTML() {
        let html = "Some <i>italic</i> text"
        editor.set(html: html)
    }

    @IBAction func readHTML() {
        editor.fetchHTML { [weak self] result in
            switch result {
            case .success(let html):
                let doc = "<!DOCTYPE html><html><head><title></title></head><body>\(html)</body></html>"
                print(doc)
                let data = doc.data(using: .utf8)
                let attrString = try? NSAttributedString(
                    data: data ?? Data(),
                    options: [.documentType : NSAttributedString.DocumentType.html],
                    documentAttributes: nil)
                print(attrString?.string)
                print(attrString)
                self?.textView.attributedText = attrString

            case .failure(let error):
                print("Failed: \(error)")
                self?.textView.text = "Failed \(error)"
            }
        }
    }

    @IBAction func bbiTapped(bbi: UIBarButtonItem) {
        var tag: HTMLEditorView.Tag? = nil
        switch bbi {
        case boldBBI:       tag = .bold
        case italicBBI:     tag = .italic
        case underlineBBI:  tag = .underline
        case orderdListBBI: tag = .orderedList
        case bulletListBBI: tag = .bulletList
        case linkBBI:       tag = .link
        default: break
        }

        guard let t = tag else { return }

        editor.send(tag: t)
    }

    private func constructEditor() {
        let editor = HTMLEditorView()

        editor.layer.borderColor = UIColor.red.cgColor
        editor.layer.borderWidth = 1

        editor.setVerticalScrollIndicatorInsets(UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0))
        editor.set(placeholder: "Type here...")

        editorContainer.addSubview(editor)

        editor.translatesAutoresizingMaskIntoConstraints = false
        editor.topAnchor.constraint(equalTo: editorContainer.topAnchor, constant: 0).isActive = true
        editor.bottomAnchor.constraint(equalTo: editorContainer.bottomAnchor, constant: 0).isActive = true
        editor.leadingAnchor.constraint(equalTo: editorContainer.leadingAnchor, constant: 0).isActive = true
        editor.trailingAnchor.constraint(equalTo: editorContainer.trailingAnchor, constant: 0).isActive = true

        self.editor = editor

        let css = "body {" +
            "    margin: 0.0px 0.0px 0.0px 0.0px;" +
            "    font-family: Avenir-Roman;" +
            "    font-weight: normal;" +
            "    font-style: normal;" +
            "    font-size: 16.00px;" +
            "    color: #696969;" +
            "}" +
            "h1,h2,h3,h4,h5,h6 {" +
            "    font-family: Avenir-Black;" +
            "    color: #4A4A4A;" +
            "}" +
            "h1 { font-size: 20.00px; }" +
            "h2 { font-size: 18.68px; }" +
            "h3 { font-size: 17.36px; }" +
            "h4 { font-size: 16.00px; }" +
            "h5 { font-size: 16.00px; }" +
            "h6 { font-size: 16.00px; }" +
            "tt,code,pre {" +
            "    font-family: Menlo-Regular;" +
            "    font-size: 14.00px;" +
            "    background: #F3F3F3;" +
            "}" +
            "blockquote {" +
            "    background: #F3F3F3;" +
            "}" +
            "[placeholder]:empty:before {" +
            "    color: red;" +
            "}"
        self.editor.set(css: css)

        self.editor.setInputAccessoryView(constructToolbar())

        self.editor.toolbarDelegate = self
        self.editor.delegate = self
    }

    private func constructToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        let boldItem = UIBarButtonItem(title: "Bold", style: .plain, target: self, action: #selector(boldTapped))
        toolbar.setItems([boldItem], animated: false)
        return toolbar
    }

    @objc func boldTapped() {
        print("Bold tapped")
    }
}

extension ViewController: HTMLEditorToolbarDelegate {

    func selectedTagsUpdated(_ tags: [HTMLEditorView.Tag]) {
        print("selected tags: \(tags)")
    }
}

extension ViewController: HTMLEditorContentDelegate {

    func contentUpdated(_ html: String) {
        print(html)
    }
}
