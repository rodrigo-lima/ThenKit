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
        // Put setup code here. This method is called before the invocation of each test method in the class.
        testDebugPrint("==============================================================================================")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }


    func testSimple() {
        let expect = expectationWithDescription("testSimple")
        let p = Promise()
        p.name = expect.description
        testDebugPrint("PROMISE - \(p)")

        p.then({ fulfillVal in
            testDebugPrint("PROMISE - fulfillVal:\(fulfillVal)")
        }) {
            testDebugPrint("PROMISE - COMPLETE")
        }

        dispatch_after(1.second) { [weak p] in
            p?.fulfill("done")

            dispatch_after(1.second) {
                expect.fulfill()
                testDebugPrint("=======================")
            }
        }

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testExample() {
        let expect = expectationWithDescription("testExample")

        let fr = fetchRandom(expect.description)
        fr.then({ value in
            testDebugPrint("SUCCESS \(value)")
            return value
        }, onRejected: { reasone in
            testDebugPrint("FAILURE \(reasone)")
            return reasone
        })
        .then(nil, onRejected: nil) {
            testDebugPrint("FINAL COMPLETE BLOCK...")
            expect.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testBubbleSuccess() {
        let expect = expectationWithDescription("testBubbleSuccess")
        let testValue = 1234

        fetchNotSoRandom(expect.description, value: testValue)
        .then(nil)
        .then{ value in
            testDebugPrint("SUCCESS \(value)")
            XCTAssert(value as? Int == testValue)
            return value
        }
        .then(nil) {
            testDebugPrint("complete - done - finished....")
            expect.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testBubbleReject() {
        let expect = expectationWithDescription("testBubbleReject")
        let testValue = 1234

        fetchNotSoRandom(expect.description, value: testValue)
        .then { value in
            testDebugPrint("SUCCESS \(value)")
            XCTAssert(value as? Int == testValue)

            //now, throw an error here and see if it's caught below
            throw ThenKitTestsError1
        }
        .then(nil)
        .then({ fulfilledValue in
            testDebugPrint("SHOULD NOT BE HERE")
            XCTFail()
            return nil
        }, onRejected: { someError in
            testDebugPrint("SHOULD **BE** HERE -- \(someError)")

            if let nserr = someError as NSError? where nserr == ThenKitTestsError1 {
                XCTAssertTrue(true)
            }
            else {
                XCTFail()
            }
            return someError
        })
        .then(nil) {
            testDebugPrint("complete - done - finished....")
            expect.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testPromiseThenWithSuccess() {
        let readyExpectation = expectationWithDescription("testPromiseThenWithSuccess")

        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")
        p.then { someResult in
            testDebugPrint("then some result ... \(someResult)")

            if someResult as? String == readyExpectation.description {
                XCTAssertTrue(true)
            }
            else {
                XCTFail()
            }
            readyExpectation.fulfill()
            return someResult
        }

        // SUBSCRIBE PROMISE
        p.fulfill(readyExpectation.description)

        // WAIT
        waitForExpectationsWithTimeout(2) { error in
            XCTAssertNil(error)
        }
    }

    func testPromiseWithFailure() {
        let readyExpectation = expectationWithDescription("testPromiseWithFailure")

        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")

        p.then(nil, onRejected: { someResult in
            testDebugPrint("fail some result ... \(someResult)")

            if let nserr = someResult as NSError? where nserr == ThenKitTestsError1 {
                XCTAssertTrue(true)
            }
            else {
                XCTFail()
            }
            return ThenKitTestsError2
        })
        .then({ ignored in
            testDebugPrint("should **NOT** Be here ... \(ignored)")
            XCTFail()
            return ignored
        }, onRejected: { rejection in
            testDebugPrint("fail 2 some result ... \(rejection)")

            if let nserr = rejection as NSError? where nserr == ThenKitTestsError2 {
                XCTAssertTrue(true)
            }
            else {
                XCTFail()
            }

            return ThenKitTestsError2
        }) {
            print ("completed")
            readyExpectation.fulfill()
        }

        // SUBSCRIBE PROMISE
        //        let r = Result<String,NSError>(error: HCMCommonKitGenericError)
        p.reject(ThenKitTestsError1)

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testEmptyPromiseWithSuccess() {
        let readyExpectation = expectationWithDescription("testEmptyPromiseWithSuccess")

        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")

        // then / onFail / onComplete
        p.then({ someResult in
            testDebugPrint("then some result ... \(someResult)")

            let worked = someResult == nil
            XCTAssertTrue(worked)
            return someResult

        }, onRejected: { failResult in
            testDebugPrint("FAILED -- \(failResult)")
            return failResult
        }) {
            testDebugPrint("COMPLETED!!!!")
            readyExpectation.fulfill()
        }

        // SUBSCRIBE PROMISE
        p.fulfill(nil)

        // WAIT
        waitForExpectationsWithTimeout(2) { error in
            XCTAssertNil(error)
        }
    }

    func testPromiseThenAndCompleteWithSuccess() {
        let readyExpectation = expectationWithDescription("testPromiseThenAndCompleteWithSuccess")

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
        .then({ anotherResult in
            testDebugPrint("something else ... \(anotherResult)")

            let worked = (anotherResult as? String) == "hello other expectation"
            XCTAssertTrue(worked)

            return anotherResult
        }, onCompleted: {
            testDebugPrint("completed!!!!")
            readyExpectation.fulfill()
        })

        // SUBSCRIBE PROMISE
        p.fulfill(readyExpectation.description)

        // WAIT
        waitForExpectationsWithTimeout(5) { error in
            XCTAssertNil(error)
        }
    }

    func testCompletedPromise() {
        let readyExpectation = expectationWithDescription("testCompletedPromise")

        // FUTURE
        let p = Promise()
        testDebugPrint("testCompletedPromise Promise ... \(p)")

        // first fulfill
        p.fulfill(readyExpectation.description)

        // then / onFail
        p.then({ someResult in
            testDebugPrint("then some result on completed Promise ... \(someResult)")
            let worked = someResult as? String == readyExpectation.description
            XCTAssertTrue(worked)

            return someResult
        })
        {
            testDebugPrint("COMPLETED!!!!")
            readyExpectation.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(2) { error in
            XCTAssertNil(error)
        }
    }

    func testShouldNotChangeValueAfterFullfilled() {
        let readyExpectation = expectationWithDescription("testShouldNotChangeValueAfterFullfilled")

        // FUTURE
        let p1 = Promise()
        p1.name = "P1"
        testDebugPrint("\(readyExpectation.description) --- P = \(p1)")

        // first fulfill
        p1.fulfill(readyExpectation.description)

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
            p1.fulfill(test2)
            testDebugPrint("AFTER FULFILL P again --- ... P1 \(p1) -- P2 \(p2)")

            // promise should actually retain "this is what I expect now" and **not** "testing value should not change"
            p1.then({ anotherResult in
                testDebugPrint("2nd THEN for P1 ----  ... \(anotherResult)")
                let worked = anotherResult as? String == readyExpectation.description
                XCTAssertTrue(worked)
                return anotherResult
            })
            {
                testDebugPrint("P1 --- completed!!!!")
            }

            p2.then({ anotherResult in
                testDebugPrint("2nd THEN for P2 ----  ... \(anotherResult)")
                let worked = anotherResult as? String == "this is what I expect now"
                XCTAssertTrue(worked)
                return anotherResult
            })
            {
                testDebugPrint("P2 --- completed!!!!")
                readyExpectation.fulfill()
            }
        }

        // WAIT
        waitForExpectationsWithTimeout(5) { error in
            XCTAssertNil(error)
        }
    }

    func testNilThenPomise() {
        let readyExpectation = expectationWithDescription("testNilThenPomise")

        // FUTURE
        let p = Promise()
        testDebugPrint("\(readyExpectation.description) --- P = \(p)")

        // then - then
        p.then(nil){ testDebugPrint("RODRIGO -- completed???")} .then({ someResult in
            testDebugPrint("then some result ... \(someResult)")

            let worked = someResult as? String == readyExpectation.description
            XCTAssertTrue(worked)
            return someResult

        }, onRejected: { failResult in
            testDebugPrint("FAILED -- \(failResult)")
            return failResult
        }) {
            testDebugPrint("COMPLETED!!!!")
            readyExpectation.fulfill()
        }

        // SUBSCRIBE PROMISE
        p.fulfill(readyExpectation.description)

        // WAIT
        waitForExpectationsWithTimeout(2) { error in
            XCTAssertNil(error)
        }
    }

    func testChainPromises() {
        let readyExpectation = expectationWithDescription("testChainPromises")

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

        p0.then({ someResult in
            testDebugPrint("Step 1 -- done with \(someResult)")

            return nil
        }) {
            testDebugPrint("Step 1 -- COMPLETE")
            readyExpectation.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testChainPromiseAndFail() {
        let readyExpectation = expectationWithDescription("testChainPromiseAndFail")

        // FUTURE
        let step0 = fetchRandom("__step0__")
        step0.then { someResult in
            testDebugPrint("Step 0 -- done with \(someResult)")

            let step1 = failRandom("__step1__")
            testDebugPrint("step1 THAT FAILS .... ")
            return step1
        }
        .then({ someResult in
            testDebugPrint("should not be here... \(someResult)")
            return nil

        }, onRejected: { someError in
            testDebugPrint("should **be** here ... \(someError)")
            if let nserr = someError as NSError? where nserr == ThenKitTestsError1 {
                XCTAssertTrue(true)
            }
            else {
                XCTFail()
            }
            return ThenKitTestsError2
        }) {
            testDebugPrint("Step 1 -- COMPLETE")
            readyExpectation.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }
    
    func testChainSamePromise() {
        let readyExpectation = expectationWithDescription("testChainSamePromises")
        
        // FUTURE
        let step0 = Promise()
        step0.name = "step0"
        let s0t = step0.then({ [weak step0] fulfilled in
            testDebugPrint("1st THEN -- fulfilled \(fulfilled)")
            XCTFail()
            return step0
            },
        onRejected: { rejected in
            testDebugPrint("1st THEN -- rejected \(rejected)")
            XCTAssert(true)
            return rejected
        })
        .then({ fulfilled in
            testDebugPrint("2nd THEN -- fulfilled \(fulfilled)")
            XCTFail()
            return nil
        }, onRejected: { rejected in
            testDebugPrint("2nd THEN -- rejected \(rejected)")
            XCTAssert(true)
            return rejected
        }) {
            testDebugPrint("2nd THEN -- complete")
        }
        step0.fulfill(step0)
        
        dispatch_after(4.seconds) {
            testDebugPrint("hello completed - \n-- step0 \(step0)\n-- s0t \(s0t)")
            readyExpectation.fulfill()
        }
        
        // WAIT
        waitForExpectationsWithTimeout(10) { error in
            XCTAssertNil(error)
        }
    }

    func testGithub() {
        let readyExpectation = expectationWithDescription("testGithub")

        // get a promise
        httpGetPromise("http://github.com")
        .then({ someResponse in
            testDebugPrint("got this response: \(someResponse)")

        }, onRejected: { someError in
            testDebugPrint("some Error: \(someError)")
            XCTFail()
            return someError

        }) {
            testDebugPrint("and we're done..")
            readyExpectation.fulfill()
        }

        // WAIT
        waitForExpectationsWithTimeout(30) { error in
            XCTAssertNil(error)
        }

    }
}
