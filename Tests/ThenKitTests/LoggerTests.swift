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
        Logger.logLevel = .debug
        testDebugPrint("==============================================================================================")
    }

    func testDebug() {
        // default
        Logger.log(level: .debug, "hello debug")
    }

    func testWarn() {
        // default
        Logger.log(level: .warn, "hello warning")
    }

    func testError() {
        // default
        Logger.log(level: .error, "hello error")
    }

    func testAllColors() {
        // test all colors
        Logger.escaped(color: .black, "Hello color [black] ")
        Logger.escaped(color: .blue, "Hello color [blue] ")
        Logger.escaped(color: .green, "Hello color [green] ")
        Logger.escaped(color: .cyan, "Hello color [cyan] ")
        Logger.escaped(color: .red, "Hello color [red] ")
        Logger.escaped(color: .purple, "Hello color [purple] ")
        Logger.escaped(color: .brown, "Hello color [brown] ")
        Logger.escaped(color: .gray, "Hello color [gray] ")
        Logger.escaped(color: .darkGray, "Hello color [darkGray] ")
        Logger.escaped(color: .lightBlue, "Hello color [lightBlue] ")
        Logger.escaped(color: .lightGreen, "Hello color [lightGreen] ")
        Logger.escaped(color: .lightCyan, "Hello color [lightCyan] ")
        Logger.escaped(color: .lightRed, "Hello color [lightRed] ")
        Logger.escaped(color: .lightPurple, "Hello color [lightPurple] ")
        Logger.escaped(color: .yellow, "Hello color [yellow] ")
        Logger.escaped(color: .white, "Hello color [white] ")
    }

    static var allTests: [(String, (LoggerTests) -> () throws -> Void)] {
        return [
            ("testDebug", testDebug),
            ("testWarn", testWarn),
            ("testError", testError),
            ("testAllColors", testAllColors)
        ]
    }

}
