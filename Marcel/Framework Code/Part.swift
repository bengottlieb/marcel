//
//  MIMEMessage.Part.swift
//  Marcel
//
//  Created by Ben Gottlieb on 9/1/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation

extension MIMEMessage {
	public struct Part: CustomStringConvertible {
		public enum ContentEncoding: String { case base64 }
		
		public let headers: [MIMEMessage.Part.Header]
		public let body: Data
		let subParts: [Part]
		
		public subscript(_ header: Header.Kind) -> String? {
			return self.headers[header]?.cleanedBody
		}

		public func bodyString(convertingFromUTF8: Bool) -> String {
			var data = self.data.unwrap7BitLineBreaks()
			let ascii = String(data: data, encoding: .ascii) ?? ""
			
			if ascii.contains("=3D") { data = data.convertFromMangledUTF8() }
			
			guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return "\(data.count) bytes" }
			
			return string
		}
		
		public var contentType: String? { return self.headers[.contentType]?.body }
		public var contentEncoding: ContentEncoding? { return ContentEncoding(rawValue: self.headers[.contentTransferEncoding]?.body ?? "") }
		func part(ofType type: String) -> Part? {
			if self.contentType?.contains(type) == true { return self }
			
			for part in self.subParts {
				if let sub = part.part(ofType: type) { return sub }
			}
			return nil
		}
		
		var data: Data {
			if self.contentEncoding == .base64,
			   let string = String(data: self.body, encoding: .ascii),
			   let decoded = Data(base64Encoded: string) {
				return decoded
			}
			return self.body
		}
		
		init(components: Data.Components) {
			if let blankIndex = components.index(of: "") {
				self.headers = components[0..<blankIndex].map { MIMEMessage.Part.Header($0) }
				self.body = components[blankIndex..<components.count].unwrap7BitLineBreaks()
				
				var parts: [Part] = []
				if let boundary = headers.allHeaders(ofKind: .contentType).flatMap({ $0.boundaryValue}).first {
					let groups = components.separated(by: boundary)
					
					for i in 1..<groups.count {
						let group = groups[i]
						let subpart = Part(components: group)
						parts.append(subpart)
					}
				}
				self.subParts = parts
			} else {
				self.headers = components.all.map { MIMEMessage.Part.Header($0) }
				self.subParts = []
				self.body = Data()
			}
		}
		
		public var description: String {
			var string = ""
			
			for header in self.headers {
				string += "\(header)\n"
			}
			
			string += "\n"
			string += self.bodyString(convertingFromUTF8: true)
			return string
		}
	}
}
