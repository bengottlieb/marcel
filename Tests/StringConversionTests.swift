//
//  StringConversionTests.swift
//  Marcel
//
//  Created by Ben Gottlieb on 9/5/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import XCTest
@testable import Marcel

class StringConversionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testFullDataConversion() {
		let url = Bundle(for: StringConversionTests.self).url(forResource: "plain", withExtension: "eml")!
		let data = try! Data(contentsOf: url)
		let parser = MIMEMessage(data: data)
		let subject = parser!.subject
		let checkSubject = "What do you think about Barack Obama's departing letter to Donald Trump? - Quora"
		XCTAssertEqual(subject, checkSubject, "Failed to properly extract email title")
		XCTAssertNotNil(parser!.htmlBody, "Failed to properly extract HTML")
	}
	
	func testLineBreakDataConversion() {
		let url = Bundle(for: StringConversionTests.self).url(forResource: "equal-sign-encoding", withExtension: "eml")!
		let data = try! Data(contentsOf: url)
		let parser = MIMEMessage(data: data)
		let subject = parser!.subject
		let checkSubject = "Concurrency in Swift / State / WTF Auto Layout?"
		XCTAssertEqual(subject, checkSubject, "Failed to properly extract email title")
		XCTAssertNotNil(parser!.htmlBody, "Failed to properly extract HTML")
	}
	
	func testHTMLExtraction() {
		let url = Bundle(for: StringConversionTests.self).url(forResource: "failed-html", withExtension: "eml")!
		let data = try! Data(contentsOf: url)
		let parser = MIMEMessage(data: data)
		let subject = parser!.subject
	//	XCTAssertEqual(subject, checkSubject, "Failed to properly extract email title")
		XCTAssertNotNil(parser!.htmlBody, "Failed to properly extract HTML")
	}
	
	func testLineBreakDataConversion2() {
		let url = Bundle(for: StringConversionTests.self).url(forResource: "second-encoding", withExtension: "eml")!
		let data = try! Data(contentsOf: url)
		let parser = MIMEMessage(data: data)
		let body = parser!.htmlBody!
		let checkContent = "If you haven’t thought"
		XCTAssertTrue(body.contains(checkContent) != nil, "Failed to properly extract email body")
	}
	
	func testLineBreakStringConversion() {

		let starter = "Codable articles are all over the place lately=2C but this one talks about=\r\n handling dates a dateEncodingStrategy that can handle many=2C many format=\r\ns. =F0=9F=8E=89"
		let data = starter.data(using: .ascii)!
		let converted = data.convertFromMangledUTF8()
		let check = "Codable articles are all over the place lately, but this one talks about handling dates a dateEncodingStrategy that can handle many, many formats. 🎉"
		
		let result = String(data: converted, encoding: .utf8)!
		XCTAssertEqual(result, check, "Failed to properly convert initial string")
	}

	func testQuotablePrintedDecoding() {
		let text = """
<"http://www=
.w3.org/tr/xhtml1/dtd/xhtml1-transitional.dtd">
"""
		let data = text.data(using: .ascii)!
		let converted = data.convertNewlines()
		let result = String(data: converted, encoding: .utf8)!
		let check = "<\"http://www.w3.org/tr/xhtml1/dtd/xhtml1-transitional.dtd\">"
		XCTAssertEqual(result, check, "Failed to properly unwrap newlines")
	}
	
    func testSimpleStringConversion() {
		let starter = """
Subject: =?utf-8?q?What_do_you_think_about_Barack_Obama=27s_departing_letter_to_Donal?=
 =?utf-8?q?d_Trump=3F_-_Quora?=
List-Unsubscribe: <http://www.quora.com/email_optout/qemail_optout?code=81c26ad52a28f52b4b3c4a9e9f008633&email=redacted%40redacted.com&email_track_id=nqfcqCRLGqvRHT4AgjqhoA%3D%3D&type=2>
Message-ID: <monWoZaVXXXvgS-xX3Aq9Q@ismtpd0036p1mdw1.sendgrid.net>
Date: Tue, 05 Sep 2017 12:49:37 +0000 (UTC)
"""
		
		let check = """
Subject: =?utf-8?q?What_do_you_think_about_Barack_Obama's_departing_letter_to_Donal?==?utf-8?q?d_Trump?_-_Quora?=
List-Unsubscribe: <http://www.quora.com/email_optout/qemail_optout?codec26ad52a28f52b4b3c4a9e9f008633&email=redacted%40redacted.com&email_track_id=nqfcqCRLGqvRHT4AgjqhoA%3D%3D&type=2>
Message-ID: <monWoZaVXXXvgS-xX3Aq9Q@ismtpd0036p1mdw1.sendgrid.net>
Date: Tue, 05 Sep 2017 12:49:37 +0000 (UTC)
"""
		let data = starter.data(using: .ascii)!
		let converted = data.convertFromMangledUTF8()
		
		let result = String(data: converted, encoding: .ascii)!
		XCTAssertEqual(result, check, "Failed to properly convert initial string")
		
		let components = converted.components(separatedBy: "\n")!
		XCTAssert(components.count == 4, "Wrong number of components in split-string, expected 4, got \(components.count)")

		let checkSubject = "Subject: What do you think about Barack Obama's departing letter to Donald Trump? - Quora"
		XCTAssert(components[0].decodedFromUTF8Wrapping == checkSubject, "Failed to parse the email title (got \(components[0].decodedFromUTF8Wrapping), expected \(checkSubject)")
    }
	
}
