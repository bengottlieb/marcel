//
//  MIMEMessage.Part.Header.swift
//  Marcel
//
//  Created by Ben Gottlieb on 9/1/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation

extension MIMEMessage.Part {
	public struct Header: CustomStringConvertible, CustomDebugStringConvertible {
		public enum Kind: String {
			case returnPath = "return-path"
			case received = "received"
			case authenticationResults = "authentication-results"
			case receivedSPF = "received-spf"
			case subject, from, to, date, sender
			case replyTo = "reply-to"
			case messageID = "message-id"
			case mailer = "x-mailer"
			case listUnsubscribe = "list-unsubscribe"
			case contentType = "content-type"
			case contentTransferEncoding = "content-transfer-encoding"
			case dkimSignature = "DKIM-Signature"
		}

		let raw: String
		let name: String
		let kind: Kind?
		let body: String
		
		var cleanedBody: String { return self.body.decodedFromUTF8Wrapping }
		
		init(_ string: String) {
			let components = string.components(separatedBy: ":")
			self.name = components.first ?? ""
			self.body = Array(components[1...]).joined(separator: ":").trimmingCharacters(in: .whitespaces)
			self.kind = Kind(rawValue: self.name.lowercased())
			self.raw = string
		}
		
		var keyValues: [String: String] {
			let components = self.body.components(separatedBy: ",")
			var results: [String: String] = [:]
			
			for component in components {
				let pieces = component.components(separatedBy: "=")
				guard pieces.count >= 2 else { continue }
				let key = pieces[0].trimmingCharacters(in: .quotes).components(separatedBy: .whitespaces).last!
				results[key] = Array(pieces[1...]).joined(separator: "=").trimmingCharacters(in: .quotes)
			}
			return results
		}
		
		var boundaryValue: String? {
			for (key, value) in self.keyValues {
				if key.contains("boundary") { return value }
			}
			return nil
		}
		
		public var description: String {
			if let kind = self.kind {
				return "\(kind.rawValue): \(self.body)"
			}
			return "\"\(self.name)\": \(self.body)"
		}
		
		public var debugDescription: String { return self.description }
	}
}

extension Array where Element == MIMEMessage.Part.Header {
	func allHeaders(ofKind kind: MIMEMessage.Part.Header.Kind) -> [MIMEMessage.Part.Header] {
		return self.filter { header in return header.kind == kind }
	}

	subscript(_ kind: MIMEMessage.Part.Header.Kind) -> MIMEMessage.Part.Header? {
		for header in self { if header.kind == kind { return header }}
		return nil
	}
}

extension CharacterSet {
	static let quotes = CharacterSet(charactersIn: "\"'")
}
