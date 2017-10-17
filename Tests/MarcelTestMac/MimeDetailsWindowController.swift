//
//  MimeDetailsWindowController.swift
//  MarcelTestMac
//
//  Created by Ben Gottlieb on 8/31/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Cocoa
import Marcel
import WebKit

class MimeDetailsWindowController: NSWindowController {
	static var windows: [MimeDetailsWindowController] = []
	
	var data: Data!
	var parser: MIMEMessage!
	var webView: WebView!
	
	convenience init(path: String) {
		self.init(windowNibName: NSNib.Name("MimeDetailsWindowController"))
		self.data = try! Data(contentsOf: URL(fileURLWithPath: path))
		self.parser = MIMEMessage(data: self.data)
		
		MimeDetailsWindowController.windows.append(self)
	}
	
    override func windowDidLoad() {
        super.windowDidLoad()
		
		self.webView = WebView(frame: self.window?.contentView?.bounds ?? .zero)
		self.window?.contentView?.addSubview(self.webView)
		self.webView.autoresizingMask = [.width, .height]
		
		self.webView.frameLoadDelegate = self
		self.window?.title = self.parser.subject ?? "Untitled"
		
		let html = self.parser.htmlBody ?? "<html><body>NONE FOUND</body></html>"
		self.webView.mainFrame.loadHTMLString(html, baseURL: nil)
		
//		self.webView.load(URLRequest(url: URL(string: "https://cnn.com")!))
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
}

extension MimeDetailsWindowController: WebFrameLoadDelegate {
	public func webView(_ sender: WebView!, didStartProvisionalLoadFor frame: WebFrame!) {
	}
	
	public func webView(_ sender: WebView!, didFailProvisionalLoadWithError error: Error!, for frame: WebFrame!) {
		
	}
	
	public func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!) {
		
	}
	
	public func webView(_ sender: WebView!, didFailLoadWithError error: Error!, for frame: WebFrame!) {
		
	}
}
