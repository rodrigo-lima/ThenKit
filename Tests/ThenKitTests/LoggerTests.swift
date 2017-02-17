//
//  LoggerTests.swift
//  ThenKitTests
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

import XCTest
@testable import ThenKit

class LoggerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        testDebugPrint("==============================================================================================")
    }

    func testSimple() {
        Logger.log("wasup")
    }

    static var allTests: [(String, (LoggerTests) -> () throws -> Void)] {
        return [
            ("testSimple", testSimple)
        ]
    }

}
