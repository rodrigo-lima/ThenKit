//
//  ThenKitSingleTests.swift
//  ThenKitSingleTests
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

import XCTest
@testable import ThenKit

class ThenKitSingleTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Logger.logLevel = .debug
        Logger.runningTest(">> -------------------- INIT TEST \(self) -------------------- <<", newLine: true)
    }

    override func tearDown() {
        super.tearDown()
        if promisesCounter == 0 {
            Logger.escaped(color: .lightGreen, "NO MEMORY LEAK -- Promise counter ==> \(promisesCounter)\n")
        } else {
            Logger.escaped(color: .lightRed, "OPS!? MEMORY LEAK -- Promise counter ==> \(promisesCounter)\n")
        }
    }

    func waitForPromise(p: Thenable, expect: XCTestExpectation, timeout: TimeInterval) {
        testDebugPrint("PROMISE - \(p)")
        p.then(onFulfilled: { fulfillVal in
            testDebugPrint("PROMISE - FULFILLED:\(fulfillVal)")
            return ""
        },
        onRejected: { error in
            testDebugPrint("PROMISE - REJECTED:\(error)")
            return error
        },
        onCompleted: { _ in
            testDebugPrint("PROMISE - COMPLETE")
            dispatch_after(0.5) {
                expect.fulfill()
                testDebugPrint("=== \(expect.description) DONE ===")
            }
        })
        // WAIT
        waitForExpectations(timeout: timeout) { error in
            XCTAssertNil(error)
        }
    }

    func testSimple() {
        let expect = expectation(description: "testSimple")
        let p = Promise()
        p.name = expect.description

        testDebugPrint("PROMISE - \(p)")
        p.then(onFulfilled: { fulfillVal in
            testDebugPrint("PROMISE - FULFILLED:\(fulfillVal)")
            return ""
        },
        onRejected: { error in
            testDebugPrint("PROMISE - REJECTED:\(error)")
            return error
        },
        onCompleted: { _ in
            testDebugPrint("PROMISE - COMPLETE")
        })
        // should we auto-fulfill this?
        dispatch_after(1) { [weak p] in
            p?.fulfill(fulfilledValue: "done")
            dispatch_after(1) {
                expect.fulfill()
                testDebugPrint("=== \(expect.description) DONE ===")
            }
        }
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testStaticPromisesFulfilled() {
        let expect = expectation(description: "testStaticPromisesFulfilled")
        let p = Promise.fulfilledEmptyPromise()
        waitForPromise(p: p, expect: expect, timeout: 10)
    }

    func testStaticPromisesEmpty() {
        let expect = expectation(description: "testStaticPromisesEmpty")
        let p = Promise.emptyPromise()
        waitForPromise(p: p, expect: expect, timeout: 10)
    }

    func testStaticPromisesRejected() {
        let expect = expectation(description: "testStaticPromisesRejected")
        let p = Promise.rejectedPromise(error: thenKitTestsError1)
        waitForPromise(p: p, expect: expect, timeout: 10)
    }

    static var allTests: [(String, (ThenKitSingleTests) -> () throws -> Void)] {
        return [
            ("testSimple", testSimple),
            ("testStaticPromisesFulfilled", testStaticPromisesFulfilled),
            ("testStaticPromisesEmpty", testStaticPromisesEmpty),
            ("testStaticPromisesRejected", testStaticPromisesRejected)
        ]
    }
}
