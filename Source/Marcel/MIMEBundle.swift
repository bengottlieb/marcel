//
//  MIMEBundle.swift
//  Marcel
//
//  Created by Ben Gottlieb on 3/6/21.
//  Copyright © 2021 Stand Alone, inc. All rights reserved.
//

import Foundation

public protocol MIMEEncodable {}

extension String: MIMEEncodable {}
extension Data: MIMEEncodable {}

public class MIMEBundle {
    var content: [Chunk]
    let boundary: String
    
    public init(content: [Chunk], boundary: String? = nil) {
        self.content = content
        self.boundary = boundary ?? MIMEBundle.randomBoundary
    }
    
    public var data: Data {
        var result = Data()
        
        for item in content {
            guard let data = item.encode() else { continue }
            result.append(string: "--\(boundary)\r\n")
            result.append(string: "Content-Disposition: \(item.contentDisposition)\r\n")
            result.append(string: "Content-Type: \(item.contentType)\r\n\r\n")
            result.append(data)
            result.append(string: "\r\n")
        }
        result.append(string: "--\(boundary)--\r\n")
        return result
    }
}

extension MIMEBundle {
    public struct Chunk {
        let content: MIMEEncodable
        let name: String
        let filename: String?
        let contentType: String
        
        public init(content: MIMEEncodable, name: String, filename: String? = nil, contentType: String) {
            self.content = content
            self.name = name
            self.filename = filename
            self.contentType = contentType
        }
        
        func encode() -> Data? {
            if let data = content as? Data {
                return data
            } else if let string = content as? String {
                return string.data(using: .utf8)
            }
            return nil
        }
        
        var contentDisposition: String {
            var string = "form-data; name=\"\(name)\""
            if let filename = filename {
                string.append("; filename=\"\(filename)\"")
            }
            return string
        }
    }
}

extension MIMEBundle {
    static var randomBoundary: String {
        var base = "Boundary-"
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        
        for _ in 0...30 {
            base += String(letters.randomElement()!)
        }
        
        return base
    }
}
extension Data {
    mutating func append(string: String) {
        append(string.data(using: .utf8)!)
    }
}
