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
	
	func testConvertURL() {
		let raw = "https://www.quora.com/qemail/track_click?al_imp=eyJ0eXBlIjogMzMsICJoYXNoIjogIjE1MjI1MzI4OTM5MDU4MjA4MDB8NHwxfDU2NTgwOTc2In0%3D&al_pri=ItemContentClickthrough&aoid=MSFwwm5jZyH&aoty=1&aty=4&click_pos=4&ct=1507640404515657&et=2&id=1RLMyqrDISFqYDPGrr4tig%3D%3D&request_id=1522532893905820800&source=1&src=1&st=1507640404515657&stories=1_oQ0lBwKygi%7C1_4ODPXU3BCDP%7C1_9UUAynodhIy%7C1_MSFwwm5jZyH%7C1_ybVBfQHtWa%7C1_boWwxcdMIPx%7C1_z5RIDmcFY3i%7C1_4qsZIBCeQAA%7C1_Yy9rtKCvwf6%7C1_IHalzIudoDm&ty=1&ty_data=MSFwwm5jZyH&uid=8Vt33HsJOFH&v=0&ref=inbox"
		let data = raw.data(using: .ascii)!
		let converted = data.convertFromMangledUTF8()
		let unpacked = String(data: converted, encoding: .utf8)
		XCTAssertEqual(raw, unpacked, "Failed to extract URL \(raw) \n->\n\(unpacked!)")
	}
	
    func testSlashUEncoding() {
        let data = "d\\u2019s d".data(using: .ascii)
        let converted = data?.convertFromMangledUTF8()
        let result = String(data: converted!, encoding: .utf8)
        //let plain = "d’s d".data(using: .utf8)
        XCTAssertEqual(result, "d’s d", "Failed to properly extract slash-u encoded apostrophe")
    }
	
	func testMoreSlashUEncoding() {
		let data = """
		Are the US soldiers\\u2019 bank accounts fr=
		ozen while they\\u2019re deployed in Iraq?
		""".data(using: .ascii)
		let converted = data?.convertFromMangledUTF8()
		let result = String(data: converted!, encoding: .utf8)
		//let plain = "d’s d".data(using: .utf8)
		XCTAssertEqual(result, "Are the US soldiers’ bank accounts frozen while they’re deployed in Iraq?", "Failed to properly extract slash-u encoded apostrophe")
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
		let checkSubject = "What is the craziest element in the periodic table? - Quora"
		let subject = parser!.subject
		XCTAssertEqual(subject, checkSubject, "Failed to properly extract email title")
		XCTAssertNotNil(parser!.htmlBody, "Failed to properly extract HTML")
	}
	
	func testLineBreakDataConversion2() {
		let url = Bundle(for: StringConversionTests.self).url(forResource: "second-encoding", withExtension: "eml")!
		let data = try! Data(contentsOf: url)
		let parser = MIMEMessage(data: data)
		let body = parser!.htmlBody!
		let checkContent = "and on that same note, here are the new Human Interface Guidelines"
		XCTAssertTrue(body.contains(checkContent), "Failed to properly extract email body")
	}
	
	func testLineBreakStringConversion() {
		let starters = [
			"Subject: =?utf-8?Q?Thread=20Safe=20Networking=20=2F=20Swift=20Weak=20References=20=2F=20A=20Case=20for=20Using=20Storyboards?=",
			"a=E2=\n=80=99re test =E2=80=9CFair share,=E2=80=9D as in, =E2=80=9Cthe",
			"Subject: =?utf-8?q?Are_the_US_soldiers=E2=80=99_bank_accounts_frozen_while_they?==?utf-8?q?=E2=80=99re_deployed_in_Iraq=3F_-_Quora?=", "Codable articles are all over the place lately=2C but this one talks about=\r\n handling dates a dateEncodingStrategy that can handle many=2C many format=\r\ns. =F0=9F=8E=89"]
		let checks = [
			"Subject: =?utf-8?Q?Thread Safe Networking / Swift Weak References / A Case for Using Storyboards?=",
			"a’re test “Fair share,” as in, “the",
			"Subject: =?utf-8?q?Are_the_US_soldiers’_bank_accounts_frozen_while_they?==?utf-8?q?’re_deployed_in_Iraq?_-_Quora?=", "Codable articles are all over the place lately, but this one talks about handling dates a dateEncodingStrategy that can handle many, many formats. 🎉"]
		
		for i in 0..<starters.count {
			let starter = starters[i]
			let data = starter.data(using: .ascii)!
			let converted = data.convertFromMangledUTF8()
		
			let result = String(data: converted, encoding: .utf8)!
			XCTAssertEqual(result, checks[i], "Failed to properly convert initial string: \(starter)")
		}
	}

	func testQuotablePrintedDecoding() {
		let text = """
<"http://www=
.w3.org/tr/xhtml1/dtd/xhtml1-transitional.dtd">
"""
		let data = text.data(using: .ascii)!
		let converted = data.unwrapTabs().unwrap7BitLineBreaks()
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
		
		let check = "Subject: What do you think about Barack Obama's departing letter to Donald Trump? - Quora"
		let data = starter.data(using: .ascii)!
		let converted = data.convertFromMangledUTF8()
		
		let result = String(data: converted, encoding: .utf8)
		XCTAssertNotNil(converted, "Failed to convert data to UTF-8 encoded string: \(starter)")
		let decoded = result?.decodedFromUTF8Wrapping ?? ""
		XCTAssertEqual(decoded, check, "Failed to properly convert initial string: \(starter)")
		
		let components = converted.components()!
		XCTAssert(components.count == 4, "Wrong number of components in split-string, expected 4, got \(components.count)")

		let checkSubject = "Subject: What do you think about Barack Obama's departing letter to Donald Trump? - Quora"
		XCTAssert(components[0].decodedFromUTF8Wrapping == checkSubject, "Failed to parse the email title (got \(components[0].decodedFromUTF8Wrapping), expected \(checkSubject)")
    }
	
}
