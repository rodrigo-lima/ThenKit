//
//  ThenKitTests.swift
//  ThenKitTests
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

import XCTest
@testable import ThenKit

class ThenKitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        testDebugPrint("==============================================================================================")
    }

    override func tearDown() {
        super.tearDown()
        if promisesCounter == 0 {
            Logger.escaped(color: .green, "NO MEMORY LEAK -- Promise counter ==> \(promisesCounter)")
        } else {
            Logger.escaped(color: .red, "OPS!? MEMORY LEAK -- Promise counter ==> \(promisesCounter)")
        }
    }

    func testSimple() {
        let expect = expectation(description: "testSimple")
        let p = Promise()
        p.name = expect.description
        testDebugPrint("PROMISE - \(p)")

        p.then(onFulfilled: { fulfillVal in
            testDebugPrint("PROMISE - fulfillVal:\(fulfillVal)")
        }, onCompleted: { _ in
            testDebugPrint("PROMISE - COMPLETE")
        })
        dispatch_after(1.second) { [weak p] in
            p?.fulfill(fulfilledValue: "done")
            dispatch_after(1.second) {
                expect.fulfill()
                testDebugPrint("=======================")
            }
        }
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testExample() {
        let expect = expectation(description: "testExample")
        let fr = fetchRandom(expect.description)
        fr.then(onFulfilled: { value in
            testDebugPrint("SUCCESS \(value)")
            return value
        }, onRejected: { reasone in
            testDebugPrint("FAILURE \(reasone)")
            return reasone
        })
        .then(onFulfilled: nil, onRejected: nil) { success in
            testDebugPrint("FINAL COMPLETE = \(success)")
            expect.fulfill()
        }
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testBubbleSuccess() {
        let expect = expectation(description: "testBubbleSuccess")
        let testValue = 1234

        fetchNotSoRandom(expect.description, value: testValue)
        .then(onFulfilled: nil)
        .then { value in
            testDebugPrint("SUCCESS \(value)")
            XCTAssert(value as? Int == testValue)
            return value
        }
        .then(onFulfilled: nil,
              onCompleted: { success in
                testDebugPrint("complete - done - finished.... = \(success)")
                expect.fulfill()
        })
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testBubbleReject() {
        let expect = expectation(description: "testBubbleReject")
        let testValue = 1234
        fetchNotSoRandom(expect.description, value: testValue)
        .then { value in
            testDebugPrint("SUCCESS \(value)")
            XCTAssert(value as? Int == testValue)
            //now, throw an error here and see if it's caught below
            throw thenKitTestsError1
        }
        .then(onFulfilled: nil)
        .then(onFulfilled: { fulfilledValue in
            testDebugPrint("SHOULD NOT BE HERE = \(fulfilledValue)")
            XCTFail()
            return nil
        }, onRejected: { someError in
            testDebugPrint("SHOULD **BE** HERE -- \(someError)")
            if let nserr = someError as NSError?, nserr == thenKitTestsError1 {
                XCTAssertTrue(true)
            } else {
                XCTFail()
            }
            return someError
        })
        .then(onFulfilled: nil,
              onCompleted: { success in
            testDebugPrint("complete - done - finished....= \(success)")
            expect.fulfill()
        })

        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testPromiseThenWithSuccess() {
        let readyExpectation = expectation(description: "testPromiseThenWithSuccess")
        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")
        p.then { someResult in
            testDebugPrint("then some result ... \(someResult)")

            if someResult as? String == readyExpectation.description {
                XCTAssertTrue(true)
            } else {
                XCTFail()
            }
            readyExpectation.fulfill()
            return someResult
        }
        // SUBSCRIBE PROMISE
        p.fulfill(fulfilledValue: readyExpectation.description)
        // WAIT
        waitForExpectations(timeout: 2) { error in
            XCTAssertNil(error)
        }
    }

    func testPromiseWithFailure() {
        let readyExpectation = expectation(description: "testPromiseWithFailure")
        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")
        p.then(onFulfilled: nil,
               onRejected: { someResult in
            testDebugPrint("fail some result ... \(someResult)")

            if let nserr = someResult as NSError?, nserr == thenKitTestsError1 {
                XCTAssertTrue(true)
            } else {
                XCTFail()
            }
            return thenKitTestsError2
        })
        .then(onFulfilled: { ignored in
            testDebugPrint("should **NOT** Be here ... \(ignored)")
            XCTFail()
            return ignored
        }, onRejected: { rejection in
            testDebugPrint("fail 2 some result ... \(rejection)")

            if let nserr = rejection as NSError?, nserr == thenKitTestsError2 {
                XCTAssertTrue(true)
            } else {
                XCTFail()
            }
            return thenKitTestsError2
        }) { success in
            print ("completed = \(success)")
            readyExpectation.fulfill()
        }
        // SUBSCRIBE PROMISE
        p.reject(reasonRejected: thenKitTestsError1)
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testEmptyPromiseWithSuccess() {
        let readyExpectation = expectation(description: "testEmptyPromiseWithSuccess")
        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")
        // then / onFail / onComplete
        p.then(onFulfilled: { someResult in
            testDebugPrint("then some result ... \(someResult)")

            let worked = someResult == nil
            XCTAssertTrue(worked)
            return someResult

        }, onRejected: { failResult in
            testDebugPrint("FAILED -- \(failResult)")
            return failResult
        }) { success in
            testDebugPrint("COMPLETED!!!! = \(success)")
            readyExpectation.fulfill()
        }
        // SUBSCRIBE PROMISE
        p.fulfill(fulfilledValue: nil)
        // WAIT
        waitForExpectations(timeout: 2) { error in
            XCTAssertNil(error)
        }
    }

    func testPromiseThenAndCompleteWithSuccess() {
        let readyExpectation = expectation(description: "testPromiseThenAndCompleteWithSuccess")
        // FUTURE
        let p = Promise()
        p.name = readyExpectation.description
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")

        // then / then / complete
        p.then { someResult in
            testDebugPrint("then some result ... \(someResult)")

            let worked = (someResult as? String) == readyExpectation.description
            XCTAssertTrue(worked)

            return "hello other expectation"
        }
        .then(onFulfilled: { anotherResult in
            testDebugPrint("something else ... \(anotherResult)")

            let worked = (anotherResult as? String) == "hello other expectation"
            XCTAssertTrue(worked)

            return anotherResult
        }, onCompleted: { success in
            testDebugPrint("completed!!!! = \(success)")
            readyExpectation.fulfill()
        })
        // SUBSCRIBE PROMISE
        p.fulfill(fulfilledValue: readyExpectation.description)
        // WAIT
        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
        }
    }

    func testCompletedPromise() {
        let readyExpectation = expectation(description: "testCompletedPromise")
        // FUTURE
        let p = Promise()
        testDebugPrint("testCompletedPromise Promise ... \(p)")

        // first fulfill
        p.fulfill(fulfilledValue: readyExpectation.description)
        // then / onFail
        p.then(onFulfilled: { someResult in
            testDebugPrint("then some result on completed Promise ... \(someResult)")
            let worked = someResult as? String == readyExpectation.description
            XCTAssertTrue(worked)
            return someResult
        }, onCompleted: { success in
            testDebugPrint("COMPLETED!!!! = \(success)")
            readyExpectation.fulfill()
        })
        // WAIT
        waitForExpectations(timeout: 2) { error in
            XCTAssertNil(error)
        }
    }

    func testShouldNotChangeValueAfterFullfilled() {
        let readyExpectation = expectation(description: "testShouldNotChangeValueAfterFullfilled")
        // FUTURE
        let p1 = Promise()
        p1.name = "P1"
        testDebugPrint("\(readyExpectation.description) --- P = \(p1)")
        // first fulfill
        p1.fulfill(fulfilledValue: readyExpectation.description)
        // then
        let p2 = p1.then { someResult in
            testDebugPrint("1st THEN --- ... \(someResult)")
            let worked = someResult as? String == readyExpectation.description
            XCTAssertTrue(worked)
            return "this is what I expect now"
        }
        dispatch_after(1.second) {
            let test2 = "testing value should not change"
            testDebugPrint("BEFORE FULFILL P again --- ... P1 \(p1) -- P2 \(p2)")
            p1.fulfill(fulfilledValue: test2)
            testDebugPrint("AFTER FULFILL P again --- ... P1 \(p1) -- P2 \(p2)")

            // promise should actually retain "this is what I expect now" and **not** "testing value should not change"
            p1.then(onFulfilled: { anotherResult in
                testDebugPrint("2nd THEN for P1 ----  ... \(anotherResult)")
                let worked = anotherResult as? String == readyExpectation.description
                XCTAssertTrue(worked)
                return anotherResult
            }, onCompleted: { success in
                testDebugPrint("P1 --- completed!!!! = \(success)")
            })

            p2.then(onFulfilled: { anotherResult in
                testDebugPrint("2nd THEN for P2 ----  ... \(anotherResult)")
                let worked = anotherResult as? String == "this is what I expect now"
                XCTAssertTrue(worked)
                return anotherResult
            }, onCompleted: { success in
                testDebugPrint("P2 --- completed!!!! = \(success)")
                readyExpectation.fulfill()
            })
        }
        // WAIT
        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
        }
    }

    func testNilThenPomise() {
        let readyExpectation = expectation(description: "testNilThenPomise")
        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")
        // then - then
        p.then(onFulfilled: nil)
        .then(onFulfilled: { someResult in
            testDebugPrint("then some result ... \(someResult)")

            let worked = someResult as? String == readyExpectation.description
            XCTAssertTrue(worked)
            return someResult

        }, onRejected: { failResult in
            testDebugPrint("FAILED -- \(failResult)")
            return failResult
        }) { success in
            testDebugPrint("COMPLETED!!!! = \(success)")
            readyExpectation.fulfill()
        }
        // SUBSCRIBE PROMISE
        p.fulfill(fulfilledValue: readyExpectation.description)
        // WAIT
        waitForExpectations(timeout: 2) { error in
            XCTAssertNil(error)
        }
    }

    func testChainPromises() {
        let readyExpectation = expectation(description: "testChainPromises")
        // FUTURE
        let step0 = fetchRandom("__step0__")
        var p0 = step0.then { someResult in
            testDebugPrint("Step 0 -- done with \(someResult)")

            let step1 = fetchRandom("__step1__")
            testDebugPrint("step1 just created with \(step1)")
            return step1
        }
        p0.name = "__p0__"
        testDebugPrint("p0 just created with \(p0)")

        p0.then(onFulfilled: { someResult in
            testDebugPrint("Step 1 -- done with \(someResult)")

            return nil
        }, onCompleted: { success in
            testDebugPrint("Step 1 -- COMPLETE = \(success)")
            readyExpectation.fulfill()
        })
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testChainPromiseAndFail() {
        let readyExpectation = expectation(description: "testChainPromiseAndFail")
        // FUTURE
        let step0 = fetchRandom("__step0__")
        step0.then { someResult in
            testDebugPrint("Step 0 -- done with \(someResult)")

            let step1 = failRandom(name: "__step1__")
            testDebugPrint("step1 THAT FAILS .... ")
            return step1
        }
        .then(onFulfilled: { someResult in
            testDebugPrint("should not be here... \(someResult)")
            return nil

        }, onRejected: { someError in
            testDebugPrint("should **be** here ... \(someError)")
            if let nserr = someError as NSError?, nserr == thenKitTestsError1 {
                XCTAssertTrue(true)
            } else {
                XCTFail()
            }
            return thenKitTestsError2
        }) { success in
            testDebugPrint("Step 1 -- COMPLETE = \(success)")
            readyExpectation.fulfill()
        }
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testChainSamePromise() {
        let readyExpectation = expectation(description: "testChainSamePromises")
        // FUTURE
        let step0 = Promise()
        step0.name = "step0"
        let s0t = step0.then(onFulfilled: { [weak step0] fulfilled in
            testDebugPrint("1st THEN -- fulfilled \(fulfilled)")
            XCTFail()
            return step0
            },
        onRejected: { rejected in
            testDebugPrint("1st THEN -- rejected \(rejected)")
            XCTAssert(true)
            return rejected
        })
        .then(onFulfilled: { fulfilled in
            testDebugPrint("2nd THEN -- fulfilled \(fulfilled)")
            XCTFail()
            return nil
        }, onRejected: { rejected in
            testDebugPrint("2nd THEN -- rejected \(rejected)")
            XCTAssert(true)
            return rejected
        }) { success in
            testDebugPrint("2nd THEN -- complete = \(success)")
        }
        step0.fulfill(fulfilledValue: step0)

        dispatch_after(4.seconds) {
            testDebugPrint("hello completed - \n-- step0 \(step0)\n-- s0t \(s0t)")
            readyExpectation.fulfill()
        }
        // WAIT
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func testGithub() {
        let readyExpectation = expectation(description: "testGithub")
        // get a promise
        httpGetPromise(someURL: "http://github.com")
        .then(onFulfilled: { someResponse in
            testDebugPrint("got this response: \(someResponse)")
        }, onRejected: { someError in
            testDebugPrint("some Error: \(someError)")
            XCTFail()
            return someError
        }) { success in
            testDebugPrint("and we're done..= \(success)")
            dispatch_after(2.seconds) {
                readyExpectation.fulfill()
            }
        }
        // WAIT
        waitForExpectations(timeout: 40) { error in
            XCTAssertNil(error)
        }
    }

    static var allTests: [(String, (ThenKitTests) -> () throws -> Void)] {
        return [
            ("testSimple", testSimple),
            ("testExample", testExample),
            ("testBubbleSuccess", testBubbleSuccess),
            ("testBubbleReject", testBubbleReject),
            ("testPromiseThenWithSuccess", testPromiseThenWithSuccess),
            ("testPromiseWithFailure", testPromiseWithFailure),
            ("testEmptyPromiseWithSuccess", testEmptyPromiseWithSuccess),
            ("testPromiseThenAndCompleteWithSuccess", testPromiseThenAndCompleteWithSuccess),
            ("testCompletedPromise", testCompletedPromise),
            ("testShouldNotChangeValueAfterFullfilled", testShouldNotChangeValueAfterFullfilled),
            ("testNilThenPomise", testNilThenPomise),
            ("testChainPromises", testChainPromises),
            ("testChainPromiseAndFail", testChainPromiseAndFail),
            ("testChainSamePromise", testChainSamePromise),
            ("testGithub", testGithub)
        ]
    }
}
