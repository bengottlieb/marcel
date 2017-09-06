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
			let subset = self.data[range]
			return String(data: subset, encoding: .utf8) ?? String(data: subset, encoding: .ascii) ?? ""
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
			let cr = UInt8(firstCharacterOf: "\r")
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
	
	func convertFromMangledUTF8() -> Data {
		return self.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
			var count = 0, i = 0
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			let sentinel = UInt8(firstCharacterOf: "=")
			let question = UInt8(firstCharacterOf: "?")
			let newline = UInt8(firstCharacterOf: "\r")
			let cr = UInt8(firstCharacterOf: "\n")
			let space = UInt8(firstCharacterOf: " ")
			let tab = UInt8(firstCharacterOf: "\t")
			let hasCRLF = self.usesCRLF
			var lastWasSentinel = false

			while i < length {
				var pointingToNewline = ptr[i] == newline
				
				if ptr[i] == cr {				//if it's a newline, check for CRLF and either remove the CR or replace it with an LF
					if i == length - 1 { break }
					output[count] = newline
					pointingToNewline = true
					if ptr[i + 1] == newline { i += 1 }
				}
				
				if ptr[i] == sentinel {					//currently at an = character
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
					if pointingToNewline, i < (length - 1) {					//newline. Might be a hard wrap
						if ptr[i + 1] == space || ptr[i + 1] == tab {				//hard wrap. Remove the newline and the space
							i += 2
							continue
						}
					} else if let escaped = UInt8(asciiChar: ptr[i], and: ptr[i + 1]) {
						output[count - 1] = escaped
						i += 2
						continue
					}
				}
				
				output[count] = ptr[i]
				i += 1
				count += 1
			}
			
			return Data(bytes: output, count: count)
		}
	}
}

