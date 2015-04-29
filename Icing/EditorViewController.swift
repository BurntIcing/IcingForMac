//
//  EditorViewController.swift
//  BurntIcing
//
//  Created by Patrick Smith on 14/02/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import WebKit
import BurntIcingModel


class EditorViewController: NSViewController {
	internal var webViewController: EditorWebViewController!
	
	var editorConfiguration: EditorConfiguration = EditorConfiguration.localEditorCopiedFromBundle!
	//var editorConfiguration: EditorConfiguration = EditorConfiguration.burntCaramelDevEditor
	
	var minimumWidth: CGFloat = 600.0
	var minimumHeight: CGFloat = 450.0

    override func viewDidLoad() {
        super.viewDidLoad()
		
		view.addConstraint(NSLayoutConstraint(item: view, attribute: .Width, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: minimumWidth))
		view.addConstraint(NSLayoutConstraint(item: view, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: minimumHeight))
    }
	
	func prepareWebViewController(webViewController: EditorWebViewController) {
		webViewController.setUpWebViewWithEditorConfiguration(editorConfiguration)
	}
	
	func setContentController(contentController: DocumentContentController) {
		webViewController.contentController = contentController
	}
	
	override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "webViewController" {
			webViewController = segue.destinationController as! EditorWebViewController
			prepareWebViewController(webViewController)
		}
	}
}


let EditorWebViewController_icingReceiveContentJSONMessageIdentifier = "icingReceiveContentJSON"

class EditorWebViewController: NSViewController, DocumentContentEditor, WKNavigationDelegate, WKScriptMessageHandler {
	internal var editorConfiguration: EditorConfiguration!
	internal var webView: WKWebView!
	internal var latestCopiedJSONData: NSData!
	
	func setUpWebViewWithEditorConfiguration(editorConfiguration: EditorConfiguration) {
		self.editorConfiguration = editorConfiguration
		
		let preferences = WKPreferences()
		preferences.javaEnabled = false
		preferences.plugInsEnabled = false
		
		#if DEBUG
			preferences.setValue(true, forKey: "developerExtrasEnabled")
		#endif
		
		let webViewConfiguration = WKWebViewConfiguration()
		webViewConfiguration.preferences = preferences
		
		let userContentController = WKUserContentController()
		userContentController.addScriptMessageHandler(self, name: EditorWebViewController_icingReceiveContentJSONMessageIdentifier)

		// console.log etc
		userContentController.addBundledUserScript("console", injectAtStart: true)
		userContentController.addScriptMessageHandler(self, name: "console")
		
		
		webViewConfiguration.userContentController = userContentController
		
		webView = WKWebView(frame: NSRect.zeroRect, configuration: webViewConfiguration)
		webView.navigationDelegate = self
		self.fillViewWithChildView(webView)
		
		#if DEBUG
			println("Loading \(editorConfiguration.editorURL)")
		#endif
		let URLRequest = NSURLRequest(URL: editorConfiguration.editorURL)
		webView.loadRequest(URLRequest)
	}
	
	var contentController: DocumentContentController! {
		didSet {
			#if DEBUG
				println("did set contentController \(webView.loading)")
			#endif
			if !webView.loading {
				self.setUpWithJSONContent()
			}
		}
	}
	
	var hasSetUpContent = false
	
	func setUpWithJSONContent() {
		#if DEBUG
			println("setUpWithJSONContent")
		#endif
		
		if hasSetUpContent {
			return
		}
		
		if contentController == nil {
			return
		}
		
		// TODO: escape IDs properly
		
		var documentID = "untitled"
		var sectionID = "main"
		
		contentController.useLatestJSONDataOnMainQueue { (contentJSONData) -> Void in
			var javaScriptString: String!
			
			#if DEBUG && false
				println("Using content JSON Data \(contentJSONData) to set up web view")
			#endif
			if contentJSONData != nil {
				if let JSONString = NSString(data: contentJSONData!, encoding: NSUTF8StringEncoding) {
					javaScriptString = "window.burntIcing.setInitialDocumentJSON(\(JSONString));"
					//let javaScriptString = "document.getElementsByTagName('body')[0].style.setProperty('background-color', 'red');"
				}
			}
			
			if javaScriptString == nil {
				javaScriptString = "window.burntIcing.setInitialDocumentJSON(null);"
			}
			
			#if DEBUG && false
				println("JavaScript String \(javaScriptString)")
			#endif
			
			self.webView.evaluateJavaScript(javaScriptString) { (result, error) -> Void in
				if error != nil {
					println("error \(error)")
				}
			}
			
			self.contentController.editor = self
			self.hasSetUpContent = true
		}
	}
	
	func useLatestDocumentJSONDataOnMainQueue(callback: (NSData?) -> Void) {
		#if DEBUG
			println("useLatestDocumentJSONDataOnMainQueue")
		#endif
		
		let javaScriptString = "window.burntIcing.copyJSONForCurrentDocument()"
		
		#if DEBUG
			println("JavaScript String \(javaScriptString)")
		#endif
		
		webView.evaluateJavaScript(javaScriptString) { (result, error) in
			var contentJSONData: NSData?
			
			if let contentJSON: AnyObject = result {
				contentJSONData = NSJSONSerialization.dataWithJSONObject(contentJSON, options: NSJSONWritingOptions(0), error: nil)!
			}
			else {
				println("error \(error)")
			}
			
			NSOperationQueue.mainQueue().addOperationWithBlock {
				callback(contentJSONData)
			}
		}
	}
	
	func usePreviewHTMLStringOnMainQueue(callback: (String?) -> Void) {
		let javaScriptString = "window.burntIcing.copyPreviewHTMLForCurrentDocumentSection()"
		#if DEBUG
			println("JavaScript String \(javaScriptString)")
		#endif
		webView.evaluateJavaScript(javaScriptString) { (result, error) in
			var previewHTMLString = result as? String
			
			if previewHTMLString == nil {
				println("error \(error)")
			}
			
			NSOperationQueue.mainQueue().addOperationWithBlock {
				callback(previewHTMLString)
			}
		}
	}
	
	@IBAction func reload(sender: AnyObject) {
		webView.reload()
	}
	
	func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
		#if DEBUG
			println("didFinishNavigation")
		#endif
		self.setUpWithJSONContent()
	}
	
	func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
		#if DEBUG
			println("didReceiveScriptMessage \(message)")
		#endif
		if message.name == EditorWebViewController_icingReceiveContentJSONMessageIdentifier {
			if let messageBody = message.body as? [String: AnyObject] {
				if let contentJSON = messageBody["contentJSON"] as? [String: AnyObject] {
					//latestCopiedJSONData = NSJSONSerialization.dataWithJSONObject(contentJSON, options: NSJSONWritingOptions(0), error: nil)
				}
			}
		}
		else if message.name == "console" {
			#if DEBUG
				println("CONSOLE")
				if let messageBody = message.body as? [String: AnyObject] {
					println("CONSOLE \(messageBody)")
				}
			#endif
		}
		else {
			#if DEBUG
				println("Unhandled script message \(message.name)")
			#endif
		}
	}
}
