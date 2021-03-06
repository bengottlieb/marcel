//
//  MIMEBundleTests.swift
//  MarcelUnitTests
//
//  Created by Ben Gottlieb on 3/6/21.
//  Copyright © 2021 Stand Alone, inc. All rights reserved.
//

import XCTest
import Marcel

class MIMEBundleTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let boundary = "Boundary--1234567890"
        let content: [MIMEBundle.Chunk] = [
            .init(content: "Hello", name: "title", filename: nil, contentType: "TEXT/text"),
        ]
        
        let bundle = MIMEBundle(content: content, boundary: boundary)
        let data = bundle.data
        
        XCTAssert(data.count == 130, "Data mismatch")
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
