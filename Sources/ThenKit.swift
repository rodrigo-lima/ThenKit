//
//  ThenKit.swift
//  ThenKit
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

import Foundation

// -----------------------------------------------------------------------------------------------------------------
// for Testing
public var promisesCounter = 0 {
    didSet {
        if promisesCounter == 0 {
            let upDown = promisesCounter > oldValue ? "UP" : "DN"
            Logger.log("Promise>>> \(upDown) -- promisesCounter \(promisesCounter)")
        }
    }
}

// -----------------------------------------------------------------------------------------------------------------
// Enums
public enum PromisesError: Error {
    case pendingPromise
    case emptyPromise
    case cannotFulfillPromiseWithItself
    case error(String)
}

public enum PromiseState {
    case pending
    case fulfilled
    case rejected
}

// TypeAlias
public typealias PromiseFunction = ((Any?) throws -> (Any?))
public typealias RejectedFunction = ((Error) -> (Error))
public typealias CompleteFunction = ((Bool) -> Void)

// MARK: - Structs
struct CallbackInfo {
    var onFulfilled: PromiseFunction?
    var onRejected: RejectedFunction?
    var onCompleted: CompleteFunction?
    var promise: Promise
}
extension CallbackInfo: CustomStringConvertible {
    func setOrNot(someFunction: Any?) -> String {
        return someFunction != nil ? "set" : ""
    }
    var description: String {
        return "\n\t\t>>CallbackInfo - onFulfilled[\(setOrNot(someFunction: onFulfilled))] " +
            "- onRejected[\(setOrNot(someFunction: onRejected))] " +
            "- onCompleted[\(setOrNot(someFunction: onCompleted))] " +
        "- promise[\(promise)]"
    }
}

// -----------------------------------------------------------------------------------------------------------------
// MARK: - Thenable Protocol
public protocol Thenable {
    var name: String { set get }
    // Swift Protocols currently do not accept default parameter values, so let's define a few helper methods
    @discardableResult func then(onFulfilled: PromiseFunction?) -> Thenable
    @discardableResult func then(onFulfilled: PromiseFunction?, onRejected: RejectedFunction?) -> Thenable
    @discardableResult func then(onFulfilled: PromiseFunction?, onCompleted: CompleteFunction?) -> Thenable
    @discardableResult func then(onFulfilled: PromiseFunction?, onRejected: RejectedFunction?,
                                 onCompleted: CompleteFunction?) -> Thenable
}

// -----------------------------------------------------------------------------------------------------------------
// MARK: - Promise class

public class Promise: Thenable {
    var internalName: String?
    public var name: String {
        get {
            return internalName ?? "\(String(describing: self)) -- \(internalName)"
        }
        set (newValue) {
            internalName = newValue
        }
    }
    var state: PromiseState = .pending
    var value: Any?
    var reason: Error = PromisesError.pendingPromise

    var callbacks: [CallbackInfo] = []

    private lazy var queue: DispatchQueue = {
        DispatchQueue(label: "PROMISES.q", qos: .utility, attributes: .concurrent)
    }()
    func runBlock(block: () -> Void) {
        queue.sync {
            block()
        }
    }

    public var promise: Thenable {
        return self as Thenable
    }

    /**
     Convenience constructor with promise name
     - parameter promiseName: name for the new promise
     - returns: Named promise
     */
    public convenience init(_ promiseName: String) {
        self.init()
        //        #if TESTING
        internalName = "[#\(promisesCounter)] \(promiseName)"
        promisesCounter += 1
        //        internalName = promiseName
        //        Logger.orange("\t..HELLO HELLO -- '\(internalName!)'- \(self.state)")
    }

    deinit {
        //        #if TESTING
        promisesCounter -= 1
        //        Logger.orange("\t..BYE BYE -- '\(self.name)' - \(self.state)")
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK: - Callbacks
    func storeCallbacks(onFulfilled: PromiseFunction?, onRejected: RejectedFunction?, onCompleted: CompleteFunction?, promise: Promise) {
        Logger.log("\t..storeCallbacks -  onFulfilled: \(onFulfilled) - onRejected: \(onRejected) - onCompleted: \(onCompleted)\n" +
                   "\tPROMISE_2: \(promise)")
        // 2.2.6.1: Push onFulfilled callbacks in the order of calls to then
        // 2.2.6.2: Push onRejected callbacks in the order of calls to then
        callbacks += [CallbackInfo(onFulfilled: onFulfilled, onRejected: onRejected, onCompleted: onCompleted, promise: promise)]
    }

    func evaluateOnFulfilled(callback: PromiseFunction, promise promise2: Promise, argument: Any?) {
        Logger.log("\t..evaluateOnFulfilled -  callback: \(callback) - argument: \(argument)-\n\t\tPROMISE_2: \(promise2)-\n\t\tPROMISE_1: \(self)")
        var result: Any? = nil
        do {
            try result = callback(argument)
            Logger.log("\t....evaluateOnFulfilled -  GOT RESULT \(result)")
        } catch let e {
            // 2.2.7.2: If either onFulfilled or onRejected throws an exception e, promise must be rejected with e as the reason.
            Logger.log("\t....evaluateOnFulfilled -  GOT EXCEPTION \(e)")
            promise2.reject(reasonRejected: e)
            return
        }
        // 2.2.7.2: If either onFulfilled or onRejected throws an exception e -- or return error --, promise must be rejected with e as the reason.
        if let err = result as? Error {
            promise2.reject(reasonRejected: err)
            return
        }
        // final test
        if shouldRejectSamePromise(promise: self, x: result) {
            // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
            promise2.reject(reasonRejected: PromisesError.cannotFulfillPromiseWithItself)
            return
        } else {
            // 2.2.7.1: If either onFulfilled or onRejected returns a value x, run the Promise Resolution Procedure [[Resolve]](promise2, x).
            resolve(promise: promise2, x: result)
        }
    }

    // ---
    func executeOnFulfilledCallback(callbackInfo: CallbackInfo) {
        Logger.log("\t..execute_ONFULFILLED -- <<\(self.name)>> -- callbackInfo.onFulfilled: " +
                   callbackInfo.setOrNot(someFunction: callbackInfo.onFulfilled))
        if let cbF = callbackInfo.onFulfilled {
            evaluateOnFulfilled(callback: cbF, promise: callbackInfo.promise, argument: value)
        } else {
            // 2.2.7.3: If onFulfilled is not a function and promise1 is fulfilled, promise2 must be fulfilled with the same value.
            callbackInfo.promise.fulfill(fulfilledValue: value)
        }
    }

    func executeOnRejectedCallback(callbackInfo: CallbackInfo) {
        Logger.log("\t..execute_ONREJECTED -- <<\(self.name)>> -- callbackInfo.onRejected: " +
                   callbackInfo.setOrNot(someFunction: callbackInfo.onRejected))
        var rejectReason = reason
        if let cbR = callbackInfo.onRejected {
            rejectReason = cbR(reason)
            Logger.log("\t....execute_ONREJECTED -  GOT RESULT \(rejectReason)")
        }
        // 2.2.7.4: If onRejected is not a function and promise1 is rejected, promise2 must be rejected with the same reason.
        callbackInfo.promise.reject(reasonRejected: rejectReason)
    }

    func executeOnCompletedCallback(callbackInfo: CallbackInfo) {
        Logger.log("\t..execute_ONCOMPLETED -- <<\(self.name)>> -- callbackInfo.onCompleted: " +
                   callbackInfo.setOrNot(someFunction: callbackInfo.onCompleted))
        callbackInfo.onCompleted?(state == .fulfilled)
    }

    func executeCallbacks(promiseState: PromiseState) {
        Logger.log("\t..executeCallbacks -  STATE: \(promiseState) -- PROMISE: \(self)\ncallbacks: \(callbacks)")
        let cbacks = callbacks
        // 2.2.2.3: Do not call onFulfilled callbacks more than once
        // 2.2.3.3: Do not call onRejected callbacks more than once
        callbacks.removeAll()

        switch promiseState {
        case .fulfilled:
            // 2.2.6.1: If/when promise is fulfilled, all respective onFulfilled callbacks must execute in order of their originating calls.
            cbacks.forEach { executeOnFulfilledCallback(callbackInfo: $0) }

        case .rejected:
            // 2.2.6.2: If/when promise is rejected, all respective onRejected callbacks must execute in order of their originating calls.
            cbacks.forEach { executeOnRejectedCallback(callbackInfo: $0) }

        default:
            return
        }
        // run ON COMPLETION
        cbacks.forEach { executeOnCompletedCallback(callbackInfo: $0) }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK: - fulfill / reject

    public func fulfill(fulfilledValue: Any?) {
        Logger.log("\n!!INI--FULFILL!! --- PROMISE_1: \(self.name) -- \(self.state)")
        // 2.1.1.1: When pending, a promise may transition to the fulfilled state.
        // 2.1.2.1: When fulfilled, a promise must not transition to any other state.
        if state != .pending {
            Logger.log("!!ABORT FULFILL!! -  NOT PENDING")
            return
        }
        // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
        if shouldRejectSamePromise(promise: self, x: fulfilledValue) {
            return
        }
            // are we fulfilling it with an Error? then it should actually be rejected
        else if let err = fulfilledValue as? Error {
            reject(reasonRejected: err)
        }

        // 2.1.2.2: When in fulfilled, a promise must have a value, which must not change.
        state = .fulfilled
        value = fulfilledValue

        // 2.2.2.1 Call each onFulfilled after promise is fulfilled, with promise’s fulfillment value as its first argument.
        // 2.2.4: onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
        if callbacks.count > 0 {
            Logger.log("!!PROC--FULFILL!! --- executing #[\(callbacks.count)] callbacks now...")
            runBlock { [weak self] in self?.executeCallbacks(promiseState: .fulfilled) }
        }
        Logger.log("\n!!END--FULFILL!! --- PROMISE_1: \(self)\n")
    }

    public func reject(reasonRejected: Error) {
        Logger.log("\n!!INI--REJECT!! --- PROMISE_1: \(self.name) -- \(self.state)")
        // 2.1.1.1: When pending, a promise may transition to the fulfilled state.
        // 2.1.3.1: When rejected, a promise must not transition to any other state.
        if state != .pending {
            Logger.log("!!ABORT REJECT!! -  NOT PENDING")
            return
        }

        // 2.1.3.2: When rejected, a promise must have a reason, which must not change.
        state = .rejected
        reason = reasonRejected

        // 2.2.3.1 Call each onRejected after promise is rejected, with promise’s reason value as its first argument.
        // 2.2.4: onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
        runBlock { [weak self] in self?.executeCallbacks(promiseState: .rejected) }

        Logger.log("\n!!END--REJECT!! --- PROMISE_1: \(self)\n")
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK: - Protocol methods
    @discardableResult public func then(onFulfilled: PromiseFunction?) -> Thenable {
        return then(onFulfilled: onFulfilled, onRejected: nil, onCompleted: nil)
    }

    @discardableResult public func then(onFulfilled: PromiseFunction?, onRejected: RejectedFunction?) -> Thenable {
        return then(onFulfilled: onFulfilled, onRejected: onRejected, onCompleted: nil)
    }

    @discardableResult public func then(onFulfilled: PromiseFunction?, onCompleted: CompleteFunction?) -> Thenable {
        return then(onFulfilled: onFulfilled, onRejected: nil, onCompleted: onCompleted)
    }

    @discardableResult public func then(onFulfilled: PromiseFunction?, onRejected: RejectedFunction?, onCompleted: CompleteFunction?) -> Thenable {
        Logger.log("!!THEN-INI!! - onFulfilled: \(onFulfilled) - onRejected: \(onRejected) --\n\tPROMISE_1: \(self)")
        let promise2 = Promise("_\(name).THEN__")
        let v = value

        switch state {
        case .pending:
            // 2.2.1: Both onFulfilled and onRejected are optional arguments
            // We need to store them even if they're undefined so we can fulfill the newly created promise in the right order
            storeCallbacks(onFulfilled: onFulfilled, onRejected: onRejected, onCompleted: onCompleted, promise: promise2)

        case .fulfilled:
            if onFulfilled != nil {
                // 2.2.4: onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
                runBlock { [weak self] in
                    self?.evaluateOnFulfilled(callback: onFulfilled!, promise: promise2, argument: v)
                }
            } else {
                // 2.2.7.3: If onFulfilled is not a function and promise1 is fulfilled, promise must be fulfilled with the same value.
                promise2.fulfill(fulfilledValue: value)
            }
            runBlock { onCompleted?(promise2.state == .fulfilled) }

        case .rejected:
            var r = reason
            if let cbR = onRejected {
                r = cbR(reason)
            }
            // 2.2.7.3: If onFulfilled is not a function and promise1 is fulfilled, promise must be fulfilled with the same value.
            promise2.reject(reasonRejected: r)

            runBlock { onCompleted?(promise2.state == .fulfilled) }
        }
        // 2.2.7: then must return a promise
        let thenable: Thenable = promise2
        Logger.log("!!THEN-END!! -- RETURNING:\n\tPROMISE_2: \(thenable) -- \n\tPROMISE_1: \(self)")
        return thenable
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// MARK: -
extension Promise : CustomStringConvertible {
    public var description: String {
        var v: String
        if let vp = value as? Promise {
            v = vp.name
        } else if value != nil {
            v = "\([value].flatMap { $0 })"
        } else {
            v = "nil"
        }
        return ">>~~~~//\(name)// - state[\(state)]  - value: \(v)  -- reason: \(reason) -- callbacks<\(callbacks.count)> ~~~~<<"
    }
}

public extension Promise {
    // empty signal - just an empty signal
    public static func fulfilledEmptyPromise(named: String = "Empty.Promise.Fulfilled") -> Thenable {
        let p = Promise(named)
        p.then(onFulfilled: { someResult in
            return someResult
        })
        p.fulfill(fulfilledValue: "")
        return p.promise
    }
    // empty signal - just an empty signal
    public static func emptyPromise(named: String = "Empty.Promise") -> Thenable {
        let p = Promise(named)
        p.then(onFulfilled: { someResult in
            return someResult
        })
        p.reject(reasonRejected: PromisesError.emptyPromise)
        return p.promise
    }

    // rejected promise with given error
    public static func rejectedPromise(named: String = "Rejected.Promise", error: Error) -> Thenable {
        let p = Promise(named)
        p.reject(reasonRejected: error)
        return p.promise
    }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - helper funcs

fileprivate func shouldRejectSamePromise(promise: Promise, x: Any?) -> Bool {
    // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
    if let p = x as? Promise {
        // callbacks array will be emptied before arriving here, so let's compare memory address
        if Unmanaged.passUnretained(p).toOpaque() == Unmanaged.passUnretained(promise).toOpaque() {
            promise.value = nil // so we avoid retain cycle
            Logger.log("\n..shouldRejectSamePromise - REJECT -- P cannot be X\n")
            promise.reject(reasonRejected: PromisesError.cannotFulfillPromiseWithItself)
            return true
        }
    }
    return false
}

fileprivate func resolve(promise: Promise, x: Any?) {
    Logger.log("\n.$.$.$.$.resolve - X: \(x) -- PROMISE: \(promise)\n")

    // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
    if shouldRejectSamePromise(promise: promise, x: x) {
        return
    }

    // 2.3.3.1: Let then be x.then. 3.5
    if var thenableX = x as? Thenable {
        thenableX.name = "_TX_\(thenableX.name)"
        var called = false
        // 2.3.2: If x is a promise, adopt its state. 3.4
        // 2.3.2.1: If x is pending, promise must remain pending until x is fulfilled or rejected.
        // 2.3.3.3: If then is a function, call it with x as this, first argument resolvePromise, and second argument rejectPromise
        Logger.log("\n\t.$.$.$.$.resolve....CREATING THEN FOR THENABLE_X ----\n\t\t\tPROMISE \(promise) --\n" +
                   "\t\t\tthenableX \(thenableX)--\n\t\t\tX \(x)\n")
        thenableX.then(onFulfilled: { y in
            Logger.log("\n\t.$.$.$.$.resolve....thenableX.on_FULFILL with Y [\(y)] ----\n\t\t\tPROMISE \(promise) --\n\t\t\tX \(x)")
            // 2.3.3.3.3: If both resolvePromise and rejectPromise are called, or multiple calls to the same argument are made,
            // the first call takes precedence, and any further calls are ignored.
            if called {
                Logger.log("\t.$.$.$.$.resolve....then.onfulfill already called")
                return y
            }
            // 2.3.2.2:  If/when x is fulfilled, fulfill promise with the same value.
            // 2.3.3.3.1: If/when resolvePromise is called with a value y, run [[Resolve]](promise, y).
            resolve(promise: promise, x: y)
            called = true
            return y
            },
        onRejected: { r in
            Logger.log("\n\t.$.$.$.$.resolve....thenableX.on_REJECT with R [\(r)] ----\n\t\t\tPROMISE \(promise) --\n\t\t\tX \(x)")
            // 2.3.3.3.3: If both resolvePromise and rejectPromise are called, or multiple calls to the same argument are made,
            // the first call takes precedence, and any further calls are ignored.
            if called {
                Logger.log("\t.$.$.$.$.resolve....then.onRejected already called")
            }
            // 2.3.2.3: If/when x is rejected, reject promise with the same reason..
            // 2.3.3.3.2: If/when rejectPromise is called with a reason r, reject promise with r.
            promise.reject(reasonRejected: r)
            called = true
            return r
        })
    } else {
        // 2.3.4: If x is not an object or function, fulfill promise with x.
        Logger.log("\n\t.$.$.$.$.resolve....INVOKING FULLFILL on PROMISE with X ----\n\t\t\tPROMISE \(promise) --\n\t\t\tX \(x)")
        promise.fulfill(fulfilledValue: x)
    }
}

/** EOF **/
