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
    public static func runningTest<T>(_ object: T, newLine: Bool = false) {
        if newLine { print("") }  // or it will not escape correctly
        print(Escape.escaped(color: .cyan, ".🏃. \(object)"))
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// MARK: -
let thenKitTestsError1 = NSError(domain: "ThenKitTests.Error.1", code: 1, userInfo: nil)
let thenKitTestsError2 = NSError(domain: "ThenKitTests.Error.2", code: 2, userInfo: nil)

// MARK: -
public func dispatch_after(_ interval: TimeInterval, _ block: @escaping () -> Void) {
    // millisec or sec ?
    dispatch_after(interval, DispatchQueue.main, block)
}
public func dispatch_after(_ interval: TimeInterval, _ queue: DispatchQueue, _ block: @escaping () -> Void) {
    // millisec or sec ?
    let precision = interval < 1 ? Double(NSEC_PER_MSEC) : Double(NSEC_PER_SEC)
    let adjusted_interval = interval < 1 ? interval * 1000 : interval
    let when = DispatchTime.now() + Double(Int64(adjusted_interval * precision)) / Double(NSEC_PER_SEC)
    queue.asyncAfter(deadline: when, execute: block)
}

// ---------------------------------------------------------------------------------------------------------------------
// MARK: -

func testDebugPrint(_ someMsg: @autoclosure () -> String?) {
    if let msg = someMsg() {
        Logger.runningTest(">> \(msg) <<")
    }
}

func fetchRandom(_ name: String) -> Thenable {
    let p = Promise()
    p.name = name

    dispatch_after(2) {
        testDebugPrint(".... FULFILL fetchRandom \(p)")
        p.fulfill(fulfilledValue: arc4random()/100000)
    }
    testDebugPrint(".... created fetchRandom \(p)")
    return p.promise
}

func fetchNotSoRandom(_ name: String, value: Int) -> Thenable {
    let p = Promise()
    p.name = name

    dispatch_after(2) {
        testDebugPrint(".... FULFILL fetchNotSoRandom \(p)")
        p.fulfill(fulfilledValue: value)
    }
    testDebugPrint(".... created fetchNotSoRandom \(p)")
    return p.promise
}

func failRandom(name: String) -> Thenable {
    let p = Promise()
    p.name = name

    dispatch_after(2) {
        testDebugPrint(".... REJECT failRandom \(p)")
        p.reject(reasonRejected: thenKitTestsError1)
    }
    testDebugPrint(".... created failRandom \(p)")
    return p.promise
}

func httpGetPromise(someURL: String) -> Thenable {
    let p = Promise("HTTP_GET_PROMISE")

    guard let url = URL(string: someURL) else {
        let badURLErr = NSError(domain: "ThenKitTests.Error.BadURL", code: 100, userInfo: nil)
        p.reject(reasonRejected: badURLErr)
        return p.promise // rejected promise
    }

    let request = URLRequest(url: url)
    let session = URLSession.shared
    let task = session.dataTask(with: request) { (_, response, error) in
        if error != nil {
            p.reject(reasonRejected: error!)
        } else if let r = response as? HTTPURLResponse, r.statusCode < 300 {
            // wraps NSData & NSHTTPURLResponse to return
            p.fulfill(fulfilledValue: response)
        } else {
            let r = response as? HTTPURLResponse
            let code = r?.statusCode ?? -1
            let e = NSError(domain: NSURLErrorDomain, code: code, userInfo: nil)
            p.reject(reasonRejected: e)
        }
    }
    task.resume()
    return p.promise
}

/** EOF **/
