//
//  Data+Mime.swift
//  Marcel
//
//  Created by Ben Gottlieb on 8/31/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation

extension Data {
	struct Components {
		let data: Data
		var ranges: [Range<Data.Index>]
		var count: Int { return self.ranges.count }
		
		static let empty = Components(data: Data(), ranges: [])
		
		subscript(_ index: Int) -> String {
			let range = self.ranges[index]
			var data = self.data[range]
			
			if data.contains(string: "?utf-8?") { data = data.convertFromMangledUTF8() }
			return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
		}
		
		func index(of string: String) -> Int? {
			for i in 0..<self.count {
				if self[i] == string { return i }
			}
			return nil
		}
		
		subscript(_ range: Range<Int>) -> [String] {
			var results: [String] = []
			
			for i in range.lowerBound..<range.upperBound {
				results.append(self[i])
			}
			return results
		}
		
		var all: [String] {
			return self[0..<self.count]
		}
		
		var string: String {
			return self.all.joined(separator: "\n")
		}
		
		subscript(_ range: Range<Int>) -> Data {
			var result = Data()
			
			for i in range.lowerBound..<range.upperBound {
				let chunk = self.ranges[i]
				result.append(self.data[chunk])
			}
			
			return result
		}
		
		subscript(_ range: Range<Int>) -> Components {
			return Components(data: self.data, ranges: Array(self.ranges[range]))
		}
		
		func separated(by boundary: String) -> [Components] {
			var results: [Components] = []
			var start = 0
			let fullBoundary = "--" + boundary
			
			for i in 0..<self.count {
				let line = self[i]
				
				if line.hasPrefix(fullBoundary) {
					if i > start { results.append(self[start..<i]) }
					start = i + 1
				}
			}
			
			return results
		}
	}
	
	func components(separatedBy separator: String) -> Components? {
		var ranges: [Range<Data.Index>] = []
		var i = 0
		let count = self.count
		
		while i < count {
			let index = self.firstIndex(of: separator, startingAt: i) ?? count
			ranges.append(i..<index)
			i = index + separator.utf8.count
		}
		
		if ranges.count < 2 { return nil }
		return Components(data: self, ranges: ranges)
	}
	
	func contains(string: String) -> Bool { return self.firstIndex(of: string) != nil }
	func firstIndex(of string: String, startingAt: Int = 0) -> Int? {
		let bytes = [UInt8](string.utf8)
		
		if self.count < bytes.count { return nil }
		return self.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
			for i in startingAt..<(self.count - bytes.count) {
				if ptr[i] == bytes[0] {
					var valid = true
					for j in 1..<bytes.count {
						if ptr[i + j] != bytes[j] {
							valid = false
							break
						}
					}
					
					if valid { return i }
				}
			}
			return nil
		}
	}
	
	var usesCRLF: Bool {
		return self.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
			let length = self.count
			let cr = UInt8(firstCharacterOf: "\r")
			let newline = UInt8(firstCharacterOf: "\n")
			
			for i in 0..<(length - 1) {
				if ptr[i] == cr {
					return ptr[i + 1] == newline
				} else if ptr[i] == newline {
					return false
				}
			}
			return false
		}
	}
	
	func unwrapFoldedHeadersAndStripOutCarriageReturns() -> Data {
		return self.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			var count = 0, i = 0
			let space = UInt8(firstCharacterOf: " ")
			let tab = UInt8(firstCharacterOf: "\t")
			let newline = UInt8(firstCharacterOf: "\n")
			
			while i < length {
				if ptr[i] == newline, (ptr[i + 1] == space || ptr[i + 1] == tab) {
					i += 2
				} else {
					output[count] = ptr[i]
					count += 1
				}
				i += 1
			}
			
			return Data(bytes: output, count: count)
		}
	}
	
	func convertNewlines() -> Data {
		return self.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
			var count = 0, i = 0
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			let newline = UInt8(firstCharacterOf: "\n")
			let cr = UInt8(firstCharacterOf: "\r")
			let space = UInt8(firstCharacterOf: " ")
			let tab = UInt8(firstCharacterOf: "\t")

			while i < length {
				var isNewline = false
				if ptr[i] == cr {				//if it's a newline, check for CRLF and either remove the CR or replace it with an LF
					if i == length - 1 { break }
					if ptr[i + 1] == newline { i += 1 }
					isNewline = true
				} else if ptr[i] == newline {
					isNewline = true
				}
				output[count] = ptr[i]
				count += 1
				i += 1
				
				if isNewline, ptr[i] == space || ptr[i] == tab {
					count -=  1
					i += 1
				}
			}
			return Data(bytes: output, count: count)
		}
	}
	
	func convertFromMangledUTF8() -> Data {
		return self.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
			var count = 0, i = 0
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			let sentinel = UInt8(firstCharacterOf: "=")
			let newline = UInt8(firstCharacterOf: "\n")
			let cr = UInt8(firstCharacterOf: "\r")
			let questionMark = UInt8(firstCharacterOf: "?")
			let space = UInt8(firstCharacterOf: " ")
			let tab = UInt8(firstCharacterOf: "\t")
			var lastWasSentinel = false
			
			while i < length {
				let pointingToNewline = ptr[i] == newline || ptr[i] == cr
				
				if ptr[i] == sentinel, i > 0, ptr[i - 1] != questionMark {					//currently at an = character
					if lastWasSentinel {
						lastWasSentinel = false
						output[count] = ptr[i]
						count += 1
						i += 1
						continue
					} else {
						lastWasSentinel = true
					}
				} else if lastWasSentinel {				//last character was an =
					lastWasSentinel = false
					if pointingToNewline, i < (length - 1), i > 1, ptr[i - 2] != sentinel {					//newline. Might be a hard wrap
						count -= 1
						while (ptr[i] == newline || ptr[i] == cr), i < length {
							i += 1
						}
						continue
					} else if let escaped = UInt8(asciiChar: ptr[i], and: ptr[i + 1]) {
//						let unicode = UnicodeScalar(escaped)
//						count -= 1
//						for point in String(unicode).utf8 {
//							output[count] = point
//							count += 1
//						}
						output[count - 1] = escaped
						i += 2
						continue
					}
				} else if pointingToNewline, i < (length - 1), (ptr[i + 1] == space || ptr[i + 1] == tab) {
					i += 2
					continue
				}

				output[count] = ptr[i]
				count += 1
				i += 1
			}
			
			return Data(bytes: output, count: count)
		}
	}
}

