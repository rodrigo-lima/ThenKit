//
//  ThenKit.swift
//  ThenKit
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

import Foundation

// -----------------------------------------------------------------------------------------------------------------
// Enums
public enum PromisesError : ErrorType {
    case PendingPromise
    case CannotFulfillPromiseWithItself
    case Error(String)
}

public enum PromiseState {
    case Pending
    case Fulfilled
    case Rejected
}

// TypeAlias
typealias Function = (Any?) throws -> (Any?)
typealias RejectedFunction = (ErrorType) -> (ErrorType)
typealias CompleteFunction = () -> ()

// MARK:- Structs
struct CallbackInfo {
    var onFulfilled: Function?
    var onRejected: RejectedFunction?
    var onCompleted: CompleteFunction?
    var promise: Promise
}
extension CallbackInfo : CustomStringConvertible {
    func setOrNot(someFunction: Any?) -> String {
        return someFunction != nil ? "isSet" : ""
    }
    var description: String {
        return "CallbackInfo - onFulfilled[\(setOrNot(onFulfilled))] - onRejected[\(setOrNot(onRejected))] - onCompleted[\(setOrNot(onCompleted))] - promise[\(promise)]"
    }
}

// -----------------------------------------------------------------------------------------------------------------
// MARK:- Thenable Protocol
protocol Thenable {
    var name: String { set get }
    // Swift Protocols currently do not accept default parameter values, so let's define a few helper methods
    func then(onFulfilled:Function?) -> Thenable
    func then(onFulfilled:Function?, onRejected:RejectedFunction?) -> Thenable
    func then(onFulfilled:Function?, onCompleted: CompleteFunction?) -> Thenable
    func then(onFulfilled:Function?, onRejected:RejectedFunction?, onCompleted: CompleteFunction?) -> Thenable
}

// -----------------------------------------------------------------------------------------------------------------
// MARK:- Promise class

class Promise: Thenable {
    static let logger = Logger.verbose(name: "ThenKit") // default / verbose logger
    static let errorL = Logger.error(name: "ThenKit")   // for errors

    var internalName: String? = nil
    var name: String {
        get {
            return internalName ?? "\(unsafeAddressOf(self)) -- \(internalName)"
        }
        set (newValue) {
            internalName = newValue
        }
    }
    var state: PromiseState = .Pending
    var value: Any? = nil
    var reason: ErrorType = PromisesError.PendingPromise

    lazy var promise: Thenable = { [weak self] in
        let p: Thenable = self ?? Promise()
        return p
        }()

    var callbacks:[CallbackInfo] = []

    let q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    func runBlock(block:()->()) {
        dispatch_async(q) {
//            dispatch_async(dispatch_get_main_queue()) {
            block()
//            }
        }
    }

    deinit {
        Promise.logger("\t..BYE BYE -- \(self)")
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:- Callbacks
    func storeCallbacks(onFulfilled:Function?, onRejected:RejectedFunction?, onCompleted:CompleteFunction?, promise: Promise) {
        Promise.logger("\t..storeCallbacks -  onFulfilled: \(onFulfilled) - onRejected: \(onRejected) - onCompleted: \(onCompleted)\n\tPROMISE_2: \(promise)")
        // 2.2.6.1: Push onFulfilled callbacks in the order of calls to then
        // 2.2.6.2: Push onRejected callbacks in the order of calls to then
        callbacks += [CallbackInfo(onFulfilled: onFulfilled, onRejected: onRejected, onCompleted: onCompleted, promise: promise)]
    }

    func evaluateOnFulfilled(callback:Function, promise promise2:Promise, argument:Any?) {
        Promise.logger("\t..evaluateOnFulfilled -  callback: \(callback) - argument: \(argument)-\n\t\tPROMISE_2: \(promise2)-\n\t\tPROMISE_1: \(self)")
        var result:Any? = nil
        do {
            try result = callback(argument)
            Promise.logger("\t....evaluateOnFulfilled -  GOT RESULT \(result)")
        }
        catch let e {
            // 2.2.7.2: If either onFulfilled or onRejected throws an exception e, promise must be rejected with e as the reason.
            Promise.logger("\t....evaluateOnFulfilled -  GOT EXCEPTION \(e)")
            promise2.reject(e)
            return
        }
        // 2.2.7.2: If either onFulfilled or onRejected throws an exception e -- or return error --, promise must be rejected with e as the reason.
        if let err = result as? ErrorType {
            promise2.reject(err)
            return
        }

        // final test
        if shouldRejectSamePromise(self, x: result) {
            // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
            promise2.reject(PromisesError.CannotFulfillPromiseWithItself)
            return
        }
        else {
            // 2.2.7.1: If either onFulfilled or onRejected returns a value x, run the Promise Resolution Procedure [[Resolve]](promise2, x).
            resolve(promise2, x: result)
        }
    }

    // ---
    func executeOnFulfilledCallback(callbackInfo:CallbackInfo) {
        Promise.logger("\t..execute_ONFULFILLED -- <<\(self.name)>> -- callbackInfo.onFulfilled: \(callbackInfo.setOrNot(callbackInfo.onFulfilled))")
        if let cbF = callbackInfo.onFulfilled {
            evaluateOnFulfilled(cbF, promise: callbackInfo.promise, argument: value)
        }
        else {
            // 2.2.7.3: If onFulfilled is not a function and promise1 is fulfilled, promise2 must be fulfilled with the same value.
            callbackInfo.promise.fulfill(value)
        }
    }

    func executeOnRejectedCallback(callbackInfo:CallbackInfo) {
        Promise.logger("\t..execute_ONREJECTED -- <<\(self.name)>> -- callbackInfo.onRejected: \(callbackInfo.setOrNot(callbackInfo.onRejected))")
        var rejectReason = reason
        if let cbR = callbackInfo.onRejected {
            rejectReason = cbR(reason)
            Promise.logger("\t....execute_ONREJECTED -  GOT RESULT \(rejectReason)")
        }
        // 2.2.7.4: If onRejected is not a function and promise1 is rejected, promise2 must be rejected with the same reason.
        callbackInfo.promise.reject(rejectReason)
    }

    func executeOnCompletedCallback(callbackInfo:CallbackInfo) {
        Promise.logger("\t..execute_ONCOMPLETED -- <<\(self.name)>> -- callbackInfo.onCompleted: \(callbackInfo.setOrNot(callbackInfo.onCompleted))")
        callbackInfo.onCompleted?()
    }

    func executeCallbacks(promiseState: PromiseState) {
        Promise.logger("\t..executeCallbacks -  STATE: \(promiseState) -- PROMISE: \(self)\ncallbacks: \(callbacks)")
        let cbacks = callbacks
        // 2.2.2.3: Do not call onFulfilled callbacks more than once
        // 2.2.3.3: Do not call onRejected callbacks more than once
        callbacks.removeAll()

        switch (promiseState) {
        case .Fulfilled:
            // 2.2.6.1: If/when promise is fulfilled, all respective onFulfilled callbacks must execute in the order of their originating calls to then.
            cbacks.forEach { executeOnFulfilledCallback($0) }

        case .Rejected:
            // 2.2.6.2: If/when promise is rejected, all respective onRejected callbacks must execute in the order of their originating calls to then.
            cbacks.forEach { executeOnRejectedCallback($0) }

        default:
            return
        }
        // run ON COMPLETION
        cbacks.forEach { executeOnCompletedCallback($0) }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:- fulfill / reject

    func fulfill(fulfilledValue: Any?) {
        Promise.logger("\n!!INI--FULFILL!! --- PROMISE_1: \(self.name) -- \(self.state)")
        // 2.1.1.1: When pending, a promise may transition to the fulfilled state.
        // 2.1.2.1: When fulfilled, a promise must not transition to any other state.
        if state != .Pending {
            Promise.errorL("!!ABORT FULFILL!! -  NOT PENDING")
            return
        }
        // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
        if shouldRejectSamePromise(self, x: fulfilledValue) {
            return
        }
            // are we fulfilling it with an Error? then it should actually be rejected
        else if let err = fulfilledValue as? ErrorType {
            reject(err)
        }

        // 2.1.2.2: When in fulfilled, a promise must have a value, which must not change.
        state = .Fulfilled
        value = fulfilledValue

        // 2.2.2.1 Call each onFulfilled after promise is fulfilled, with promise’s fulfillment value as its first argument.
        // 2.2.4: onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
        runBlock { [weak self] in self?.executeCallbacks(.Fulfilled) }

        Promise.logger("\n!!END--FULFILL!! --- RETURNING: PROMISE_1: \(self)\n")
    }

    func reject(reasonRejected: ErrorType) {
        Promise.logger("\n!!INI--REJECT!! --- PROMISE_1: \(self.name) -- \(self.state)")
        // 2.1.1.1: When pending, a promise may transition to the fulfilled state.
        // 2.1.3.1: When rejected, a promise must not transition to any other state.
        if state != .Pending {
            Promise.errorL("!!ABORT REJECT!! -  NOT PENDING")
            return
        }

        // 2.1.3.2: When rejected, a promise must have a reason, which must not change.
        state = .Rejected
        reason = reasonRejected

        // 2.2.3.1 Call each onRejected after promise is rejected, with promise’s reason value as its first argument.
        // 2.2.4: onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
        runBlock { [weak self] in self?.executeCallbacks(.Rejected) }

        Promise.logger("\n!!END--REJECT!! --- RETURNING:\n\tPROMISE_1: \(self)\n")
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:- Protocol methods
    func then(onFulfilled:Function?) -> Thenable {
        return then(onFulfilled, onRejected: nil, onCompleted: nil)
    }

    func then(onFulfilled:Function?, onRejected:RejectedFunction?) -> Thenable {
        return then(onFulfilled, onRejected: onRejected, onCompleted: nil)
    }

    func then(onFulfilled:Function?, onCompleted: CompleteFunction?) -> Thenable {
        return then(onFulfilled, onRejected: nil, onCompleted: onCompleted)
    }

    func then(onFulfilled:Function?, onRejected:RejectedFunction?, onCompleted:CompleteFunction?) -> Thenable {
        Promise.logger("!!THEN-INI!! - onFulfilled: \(onFulfilled) - onRejected: \(onRejected) --\n\tPROMISE_1: \(self)")
        let promise2 = Promise()
        promise2.name = "__THEN.\(name).then__"
        let v = value

        switch (state) {
        case .Pending:
            // 2.2.1: Both onFulfilled and onRejected are optional arguments
            // We need to store them even if they're undefined so we can fulfill the newly created promise in the right order
            storeCallbacks(onFulfilled, onRejected: onRejected, onCompleted: onCompleted, promise: promise2)

        case .Fulfilled:
            if onFulfilled != nil {
                // 2.2.4: onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
                runBlock { [weak self] in
                    self?.evaluateOnFulfilled(onFulfilled!, promise: promise2, argument: v)
                }
            }
            else {
                // 2.2.7.3: If onFulfilled is not a function and promise1 is fulfilled, promise must be fulfilled with the same value.
                promise2.fulfill(value)
            }
            runBlock { onCompleted?() }

        case .Rejected:
            var r = reason
            if let cbR = onRejected {
                r = cbR(reason)
            }
            // 2.2.7.3: If onFulfilled is not a function and promise1 is fulfilled, promise must be fulfilled with the same value.
            promise2.reject(r)

            runBlock { onCompleted?() }
        }
        // 2.2.7: then must return a promise
        let thenable: Thenable = promise2
        Promise.logger("!!THEN-END!! -- RETURNING:\n\tPROMISE_2: \(thenable) -- \n\tPROMISE_1: \(self)")
        return thenable
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// MARK:-
extension Promise : CustomStringConvertible {
    var description: String {
        var v: String
        if let vp = value as? Promise {
            v = vp.name
        }
        else if value != nil {
            v = "\([value].flatMap{$0})"
        }
        else {
            v = "nil"
        }
        return ">>~~~~//\(name)// - state[\(state)]  - value: \(v)  -- reason: \(reason) -- callbacks<\(callbacks.count)> ~~~~<<"
    }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK:- helper funcs

func shouldRejectSamePromise(promise: Promise, x: Any?) -> Bool {
    // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
    if let p = x as? Promise {
        // callbacks array will be emptied before arriving here, so let's compare memory address
        if unsafeAddressOf(p) == unsafeAddressOf(promise) {
            promise.value = nil // so we avoid retain cycle
            Promise.logger("\n..shouldRejectSamePromise - REJECT -- P cannot be X\n")
            promise.reject(PromisesError.CannotFulfillPromiseWithItself)
            return true
        }
    }
    return false
}

func resolve(promise: Promise, x: Any?) {
    Promise.logger("\n.$.$.$.$.resolve - X: \(x) -- PROMISE: \(promise)\n")

    // 2.3.1: If promise and x refer to the same object, reject promise with a TypeError as the reason.
    if shouldRejectSamePromise(promise, x: x) {
        return
    }

    // 2.3.3.1: Let then be x.then. 3.5
    if var thenableX = x as? Thenable {
        thenableX.name = "_TX_\(thenableX.name)"
        var called = false
        // 2.3.2: If x is a promise, adopt its state. 3.4
        // 2.3.2.1: If x is pending, promise must remain pending until x is fulfilled or rejected.
        // 2.3.3.3: If then is a function, call it with x as this, first argument resolvePromise, and second argument rejectPromise
        Promise.logger("\n\t.$.$.$.$.resolve....CREATING THEN FOR THENABLE_X ----\n\t\t\tPROMISE \(promise) --\n\t\t\tthenableX \(thenableX)--\n\t\t\tX \(x)\n")
        thenableX.then({ y in
            Promise.logger("\n\t.$.$.$.$.resolve....thenableX.on_FULFILL with Y [\(y)] ----\n\t\t\tPROMISE \(promise) --\n\t\t\tX \(x)")
            // 2.3.3.3.3: If both resolvePromise and rejectPromise are called, or multiple calls to the same argument are made, the first call takes precedence, and any further calls are ignored.
            if (called) {
                Promise.logger("\t.$.$.$.$.resolve....then.onfulfill already called")
                return y
            }
            // 2.3.2.2:  If/when x is fulfilled, fulfill promise with the same value.
            // 2.3.3.3.1: If/when resolvePromise is called with a value y, run [[Resolve]](promise, y).
            resolve(promise, x: y)
            called = true
            return y
            },
            onRejected: { r in
                Promise.logger("\n\t.$.$.$.$.resolve....thenableX.on_REJECT with R [\(r)] ----\n\t\t\tPROMISE \(promise) --\n\t\t\tX \(x)")
                // 2.3.3.3.3: If both resolvePromise and rejectPromise are called, or multiple calls to the same argument are made, the first call takes precedence, and any further calls are ignored.
                if (called) {
                    Promise.logger("\t.$.$.$.$.resolve....then.onRejected already called")
                }
                // 2.3.2.3: If/when x is rejected, reject promise with the same reason..
                // 2.3.3.3.2: If/when rejectPromise is called with a reason r, reject promise with r.
                promise.reject(r)
                called = true
                return r
        })
    }
    else {
        // 2.3.4: If x is not an object or function, fulfill promise with x.
        Promise.logger("\n\t.$.$.$.$.resolve....INVOKING FULLFILL on PROMISE with X ----\n\t\t\tPROMISE \(promise) --\n\t\t\tX \(x)")
        promise.fulfill(x)
    }
}