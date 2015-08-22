//
//  ThenKitTestHelpers.swift
//  ThenKit
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

import Foundation
@testable import ThenKit

extension Logger {
    public static func runningTest<T>(object:T, appendNewLine: Bool = false) {
        print("\(ESCAPE)fg255,255,255;.🏃.\(object)\(RESET)")
        if appendNewLine { print("") }  // or it will not escape correctly
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// MARK: -
public let ThenKitTestsError1 = NSError(domain: "ThenKitTests.Error.1", code: 1, userInfo: nil)
public let ThenKitTestsError2 = NSError(domain: "ThenKitTests.Error.2", code: 2, userInfo: nil)

// MARK: -
public extension Int {
    var second:  NSTimeInterval { return NSTimeInterval(self) }
    var seconds: NSTimeInterval { return NSTimeInterval(self) }
//    var minute:  NSTimeInterval { return NSTimeInterval(self * 60) }
//    var minutes: NSTimeInterval { return NSTimeInterval(self * 60) }
//    var hour:    NSTimeInterval { return NSTimeInterval(self * 3600) }
//    var hours:   NSTimeInterval { return NSTimeInterval(self * 3600) }
}

public func dispatch_after(interval: NSTimeInterval, _ block: dispatch_block_t) {
    // millisec or sec ?
    let precision = interval < 1 ? Double(NSEC_PER_MSEC) : Double(NSEC_PER_SEC)
    let adjusted_interval = interval < 1 ? interval * 1000 : interval
    let when = dispatch_time(DISPATCH_TIME_NOW, Int64(adjusted_interval * precision))
    dispatch_after(when, dispatch_get_main_queue(), block)
}

// ---------------------------------------------------------------------------------------------------------------------
// MARK: -

func testDebugPrint(someMsg: String) {
    Logger.runningTest(">> \(someMsg) <<", appendNewLine: true)
}

func fetchRandom(name:String) -> Thenable {
    let p = Promise()
    p.name = name

    dispatch_after(2.seconds) {
        testDebugPrint(".... FULFILL fetchRandom \(p)")
        p.fulfill(random()/100000)
    }
    testDebugPrint(".... created fetchRandom \(p)")
    return p.promise()
}

func fetchNotSoRandom(name:String, value:Int) -> Thenable {
    let p = Promise()
    p.name = name

    dispatch_after(2.seconds) {
        testDebugPrint(".... FULFILL fetchNotSoRandom \(p)")
        p.fulfill(value)
    }
    testDebugPrint(".... created fetchNotSoRandom \(p)")
    return p.promise()
}

func failRandom(name:String) -> Thenable {
    let p = Promise()
    p.name = name

    dispatch_after(2.seconds) {
        testDebugPrint(".... REJECT failRandom \(p)")
        p.reject(ThenKitTestsError1)
    }
    testDebugPrint(".... created failRandom \(p)")
    return p.promise()
}


func httpGetPromise(someURL: String) -> Thenable {
    let p = Promise("HTTP_GET_PROMISE")

    guard let url = NSURL(string: someURL) else {
        let badURLErr = NSError(domain: "ThenKitTests.Error.BadURL", code: 100, userInfo: nil)
        p.reject(badURLErr)
        return p.promise() // rejected promise
    }

    let request = NSURLRequest(URL: url)
    let session = NSURLSession.sharedSession()
    let task = session.dataTaskWithRequest(request) { (data, response, error) in
        if error != nil {
            p.reject(error!)
        }
        else if let r = response as? NSHTTPURLResponse where r.statusCode < 300 {
            // wraps NSData & NSHTTPURLResponse to return
            p.fulfill(response)
        }
        else {
            let r = response as? NSHTTPURLResponse
            let code = r?.statusCode ?? -1
            let e = NSError(domain: NSURLErrorDomain, code: code, userInfo: nil)
            p.reject(e)
        }
    }
    task.resume()
    return p.promise()
}

