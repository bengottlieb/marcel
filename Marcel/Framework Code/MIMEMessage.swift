//
//  MIMEMessage.swift
//  Marcel
//
//  Created by Ben Gottlieb on 8/31/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation

public class MIMEMessage {
	public var raw: Data
	var data: Data
	var string: String
	var mainPart: Part!
	
	public var htmlBody: String? {
		if let html = self.mainPart.part(ofType: "text/html")?.bodyString { return html }
		if let text = self.mainPart.part(ofType: "text/plain")?.bodyString { return "<html><body>\(text)</body></html>" }
		return nil
	}
	
	public subscript(_ field: MIMEMessage.Part.Header.Kind) -> String? {
		return self.mainPart[field]
	}
	
	enum BoundaryType: String { case alternative, related }
	
	public init?(data: Data) {
		guard let string = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else {
			self.data = Data()
			self.string = ""
			
			return nil
		}
		
		self.raw = data
		self.data = data.convertFromQuotedPrintable().unwrapFoldedHeaders()
		self.string = string
		if !self.setup() { return nil }
	}
	
	var fieldSeparator = "\r\n"
	
	public init?(string: String) {
		guard let data = string.data(using: .utf8) else {
			self.data = Data()
			self.raw = Data()
			self.string = ""
			
			return nil
		}
		self.string = string
		self.data = data.convertFromQuotedPrintable().unwrapFoldedHeaders()
		self.raw = self.data
		if !self.setup() { return nil }
	}
	
	func setup() -> Bool {
		guard let components = self.data.components(separatedBy: "\r\n") ?? self.data.components(separatedBy: "\n") ?? self.data.components(separatedBy: "\r") else { return false }
		
		self.mainPart = Part(components: components)

		return true
	}
}
