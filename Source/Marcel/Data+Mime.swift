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
			let lower = self.ranges[range.lowerBound].lowerBound
			let upper = self.ranges[range.upperBound - 1].upperBound
			
			return self.data[lower..<upper]
//			var result = Data()
//
//			for i in range.lowerBound..<range.upperBound {
//				let chunk = self.ranges[i]
//				result.append(self.data[chunk])
//			}
//
//			return result
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
	
	var mimeContentStart: Int? {
        if count <= 4 { return nil }
        return withUnsafeBytes { raw in
            let upper = self.count - 4
            for i in 0...upper {
                let byte1 = raw[byte: i]
                let byte2 = raw[byte: i + 1]
                if byte1 == 10 && byte2 == 10 { return i }
                if byte1 == 13 && byte2 == 13 { return i }

                let byte3 = raw[byte: i + 2]
                let byte4 = raw[byte: i + 3]
                if byte1 == 13 && byte2 == 10 && byte3 == 13 && byte4 == 10 { return i }
            }
            return nil
        }
	}
	
	func separated(by sep: String) -> [Data] {
        return withUnsafeBytes { raw in
			var results: [Data] = []
			let sepBytes = Data(bytes: [UInt8](sep.utf8), count: sep.count)
			let first = sepBytes.first
			let upper = self.count - sepBytes.count
			var last: Int?
			for i in 0...upper {
                let byte = raw[byte: i]
				if byte == first, self[i..<(i + sep.count)] == sepBytes {
					if let prev = last {
						let chunk = self[prev..<i]
						last = i + sep.count
						results.append(chunk)
					} else {
						last = i + sep.count
					}
				}
			}
			
			if let prev = last {
				let chunk = self[prev...]
				results.append(chunk)
			}
			return results
		}
	}
	
	func components() -> Components? {
		var ranges: [Range<Data.Index>] = []
		var i = 0
		let count = self.count
		var checkThese = ["\n", "\r"]
		
		if self.contains(string: "\r\n") { checkThese = ["\r\n"] }
		
		while i < count {
			let index = self.firstIndex(of: checkThese, startingAt: i) ?? count
			ranges.append(i..<index)
			i = index + 1
			if i < self.count, self[i - 1] != 10, self[i] == 10 { i += 1}
		}
		
		if ranges.count < 2 { return nil }
		return Components(data: self, ranges: ranges)
	}
	
	func contains(string: String) -> Bool { return self.firstIndex(of: [string]) != nil }
	func firstIndex(of strings: [String], startingAt: Int = 0) -> Int? {
		precondition(strings.count > 0)
		let byteArrays = strings.map { [UInt8]($0.utf8) }
		
		if self.count < byteArrays.first!.count { return nil }
        return withUnsafeBytes { raw in
			for i in startingAt..<(self.count - byteArrays.first!.count) {
				for bytes in byteArrays {
                    if raw[byte: i] == bytes[0] {
						var valid = true
						for j in 1..<bytes.count {
							if raw[byte: i + j] != bytes[j] {
								valid = false
								break
							}
						}
						
						if valid { return i }
					}
				}
			}
			return nil
		}
	}
	
	var usesCRLF: Bool {
        return withUnsafeBytes { raw in
			let length = self.count
			let cr = UInt8(firstCharacterOf: "\r")
			let newline = UInt8(firstCharacterOf: "\n")
			
			for i in 0..<(length - 1) {
                let byte = raw[byte: i]
				if byte == cr {
                    return raw[byte: i + 1] == newline
				} else if byte == newline {
					return false
				}
			}
			return false
		}
	}
	
	func unwrapFoldedHeadersAndStripOutCarriageReturns() -> Data {
        return withUnsafeBytes { raw in
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			var count = 0, i = 0
			let space = UInt8(firstCharacterOf: " ")
			let tab = UInt8(firstCharacterOf: "\t")
			let newline = UInt8(firstCharacterOf: "\n")
			
			while i < length {
                if raw[byte: i] == newline, (raw[byte: i + 1] == space || raw[byte: i + 1] == tab) {
					i += 2
				} else {
					output[count] = raw[byte: i]
					count += 1
				}
				i += 1
			}
			
			return Data(bytes: output, count: count)
		}
	}
	
	func unwrapTabs() -> Data {
		return withUnsafeBytes { raw in
			var count = 0, i = 0
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			let newline = UInt8(firstCharacterOf: "\n")
			let cr = UInt8(firstCharacterOf: "\r")
			let space = UInt8(firstCharacterOf: " ")
			let tab = UInt8(firstCharacterOf: "\t")
			
			while i < length {
				var isNewline = false
				if raw[byte: i] == cr {				//if it's a newline, check for CRLF and either remove the CR or replace it with an LF
//					if i == length - 1 { break }
//					if raw[byte: i + 1] == newline { i += 1 }
					isNewline = true
				} else if raw[byte: i] == newline {
					isNewline = true
				}

				output[count] = raw[byte: i]
				count += 1
				i += 1
				
				if i < length, isNewline, raw[byte: i] == space || raw[byte: i] == tab {
					count -=  1
					i += 1
				}
				
			}
			return Data(bytes: output, count: count)
		}
	}
	
	func unwrap7BitLineBreaks() -> Data {
		return withUnsafeBytes { raw in
			var count = 0, i = 0
			let length = self.count
			let output = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
			let newline = UInt8(firstCharacterOf: "\n")
			let equals = UInt8(firstCharacterOf: "=")
			let cr = UInt8(firstCharacterOf: "\r")
			let questionMark = UInt8(firstCharacterOf: "?")
			
			while i < length {
				if raw[byte: i] == cr || raw[byte: i] == newline {				//if it's a newline, check for CRLF and either remove the CR or replace it with an LF
					if i > 1 && raw[byte: i - 1] == equals && raw[byte: i - 2] != equals && raw[byte: i - 2] != questionMark {
						count -= 1
						i += 1
						continue
					}
				}
				output[count] = raw[byte: i]
				count += 1
				i += 1
			}
			return Data(bytes: output, count: count)
		}
	}
	
	func convertFromMangledUTF8() -> Data {
		/*
			if we look at three bytes, and ignore any runs longer than 2, then we miss stuff like References=20=2F=20A=20Case, which should be "References / A Case", but the =20A is throwing it for a loop

			if we look at only two bytes, then we catch that, but we miss URL parameters such as &ct=1507640404515657
		
			we're going to look at the next 8 characters. If they're all digits, we'll assume this is some sort of parameter and not convert it.
		*/
		return self.convertCheckingByteRuns(maxLength: 8)
	}
	
	func convertCheckingByteRuns(maxLength: Int) -> Data {
		return withUnsafeBytes { raw in
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
            let backSlash = UInt8(firstCharacterOf: "\\")
			let u = UInt8(firstCharacterOf: "u")
			let three = UInt8(firstCharacterOf: "3")
			let d = UInt8(firstCharacterOf: "d")
			let D = UInt8(firstCharacterOf: "D")
			let equals = UInt8(firstCharacterOf: "=")

			while i < length {
				let pointingToNewline = raw[byte: i] == newline || raw[byte: i] == cr
				
                if raw[byte: i] == backSlash, raw[byte: i + 1] == u, let bytes = raw.nextHexCharacters(from: i + 2, length: length), let chr = UInt32(hexBytes: bytes), let scalar = UnicodeScalar(chr) {
                    i += bytes.count + 2
                    let repl = String(Character(scalar)).utf8
                    for byte in repl {
                        output[count] = byte
                        count += 1
                    }
                    continue
				} else if i < (length - 1), raw[byte: i] == sentinel, i > 0, (raw[byte: i - 1] != questionMark || raw[byte: i + 1] != newline) {					//currently at an = character
					if lastWasSentinel {
						lastWasSentinel = false
						output[count] = raw[byte: i]
						count += 1
						i += 1
						continue
					} else {
						lastWasSentinel = true
					}
				} else if lastWasSentinel {				//last character was an =
					lastWasSentinel = false
					if pointingToNewline, i < (length - 1), i > 1, raw[byte: i - 2] != sentinel {					//newline. Might be a hard wrap
						count -= 1
						while i < length, (raw[byte: i] == newline || raw[byte: i] == cr) {
							i += 1
						}
						continue
					} else if raw[byte: i] == three && (raw[byte: i + 1] == d || raw[byte: i + 1] == D) {
						output[count - 1] = equals
						i += 2
						continue
					} else if let bytes = raw.nextHexCharacters(from: i, limitedTo: maxLength, length: length), bytes.count >= 2, bytes.count < 6, let escaped = UInt8(bytes: Array(bytes[0..<2])) {
						var translated = [escaped]
						var additionalOffset = 2
						while (i + additionalOffset + 2) < length {
							if raw[byte: i + additionalOffset] != sentinel { break }
							if raw[byte: i + additionalOffset + 1] == newline {
								additionalOffset += 2
								continue
							}
							guard let nextBytes = raw.nextHexCharacters(from: i + additionalOffset + 1, limitedTo: 2, length: length), nextBytes.count == 2, let escaped = UInt8(bytes: nextBytes) else { break }
							
							translated.append(escaped)
							additionalOffset += nextBytes.count + 1
						}

						count -= 1
						for byte in translated {
							output[count] = byte
							count += 1
						}
						i += additionalOffset
						continue
					}
				} else if pointingToNewline, i < (length - 1), (raw[byte: i + 1] == space || raw[byte: i + 1] == tab) {
					i += 2
					continue
				}
				
				output[count] = raw[byte: i]
				count += 1
				i += 1
				
//				if String(data: Data(bytes: output, count: count), encoding: .utf8) == nil {
//					print("Bad string")
//					return Data(bytes: output, count: count)
//				}
			}
			
			return Data(bytes: output, count: count)
		}
	}
}

extension UnsafeRawBufferPointer {
    subscript(byte byte: Int) -> UInt8 {
        load(fromByteOffset: byte, as: UInt8.self)
    }

    func nextHexCharacters(from startIndex: Int, limitedTo: Int = 4, length: Int) -> [UInt8]? {
        var results: [UInt8] = []
        var index = startIndex
        let max = Swift.min(startIndex + limitedTo, length)
        
        while index < max {
            guard let chr = UInt8(asciiChar: self[index]) else { break }
            results.append(chr)
            index += 1
        }
        
        return results
    }
}

