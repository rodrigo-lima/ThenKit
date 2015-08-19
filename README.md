# ThenKit
Promises/A+ implementation in Swift 2 inspired by Pinky - http://lazd.github.io/Pinky/

When researching [Promises/A+](https://promisesaplus.com), I was looking for a really simple implementation of the spec to better understand the data structures being using and how callbacks/closures/blocks were managed and fired during fulfilled / rejected.

There are [several implementations](https://promisesaplus.com/implementations) of the spec and I look at several of them and ended up using [Pinky](http://lazd.github.io/Pinky/) as a starting point.

From their page - [Pinky](http://lazd.github.io/Pinky/) is a no-nonsense Promises/A+ 1.1 implementation. Pinky is written to be very readable and easy to follow, with references to the relevant sections of the spec for each operation. *As such, Pinky can be used as an academic example of a promises implementation.* -- exactly what I was looking for!

## Keeping It Simple

There are several existing frameworks for Promises/A+, Reactive, RX, you name it. I've used [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) before and it's very powerful. But again, the existing frameworks were either *too big* for my use-cas, or not yet fully ported to *Swift 2*.

My main interest was to orchestrate asynchronous into synchronous steps. Example is a upload media service, where you have a sequence of networks requests that need to happen in specific sequence.

**Promises/A+** seemed like a good option, as *"a **promise** represents the eventual result of an asynchronous operation."*

**ThenKit** implements *Promises/A+* and adds a *Completion* block to be executed after all blocks are fulfilled/rejected. It's supposed to be very simple so it might not resolve all your uses cases, i.e. no cancellable or scheduled promises, hot/cold signals, etc... There are more complete frameworks for that.

## Usage

TBD. Add Carthage support.
In the meantime, copy **ThenKit.swift** somewhere in our project.

### API

As this implementation is based on **Pinky**, the API is very similar:

Create a `Promise` that will eventually be *Fulfilled* or *Rejected*:

- *Promises* could have a name -- which helps a lot during debug

```swift
let p = Promise()
p.name = "Promise_1"    // look for me in the debug logs
return p.promise
```

After executing some asynchronous work, this promise will be either *fulfilled* or *rejected* -- say, depending on the network operation result:

```swift
func httpGetPromise(someURL: String) -> Thenable {
    let p = Promise()
    p.name = "HTTP_GET_PROMISE"    // look for me in the debug logs

    guard let url = NSURL(string: someURL) else {
        let badURLErr = NSError(domain: "ThenKitTests.Error.BadURL", code: 100, userInfo: nil)
        p.reject(badURLErr)
        return p.promise // rejected promise
    }
    let request = NSURLRequest(URL: url)
    let session = NSURLSession.sharedSession()
    let task = session.dataTaskWithRequest(request) { (data, response, error) in
        if error != nil {
            p.reject(error!)
        }
        else {
            // wraps NSData & NSHTTPURLResponse to return
            let responseWrapper = HTTPResponseWrapper(data: data, urlResponse: response)
            p.fulfill(responseWrapper)
        }
    }
    task.resume()
    return p.promise    // this is *Thenable* object you'll be working with
}

// somewhere else in the code, let's GET some URL
httpGetPromise("http://google.com")
.then({ httpResponse in
    print("got this response \(httpResponse)")

    // optionally, we could return a value to chain promises together

}, onRejected: { error in
    print("some error ocurred \(error)")
    return error

}) {
    print("and we're done..")
}
```

These are the additional helper *then* methods of *Thenable* protocol:

##### `then(onFulfilled:Function?) -> Thenable`
- simple call with optional *success/fulfill* block

##### `then(onFulfilled:Function?, onRejected:RejectedFunction?) -> Thenable`
- provides *success/fulfill* and *failure/reject* blocks

##### `then(onFulfilled:Function?, onCompleted: CompleteFunction?) -> Thenable`
- adds a *completion* block

##### `then(onFulfilled:Function?, onRejected:RejectedFunction?, onCompleted: CompleteFunction?) -> Thenable`
- complete call with the 3 blocks - success, failure, complete. Note that *onCompleted* is invoked in both cases.

### Chaining

The really interesting functionality is to be able to synchronize asynchronous calls:

```swift
func fetchRandom(name:String) -> Thenable {
    let p = Promise()
    p.name = name
    dispatch_after(2.seconds) {
        print(".... FULFILL fetchRandom \(p)")
        p.fulfill(random()/100000)
    }
    return p.promise
}

func testChainPromises() {
    let readyExpectation = expectationWithDescription("testChainPromises")

    // FUTURE
    let step0 = fetchRandom("__step0__")
    step0.then { someResult in
        print("Step 0 -- complete with \(someResult)")

        // notice that we are returning another promise here!
        let step1 = fetchRandom("__step1__")
        return step1
    }
    .then { someResult in
        print("Step 1 -- complete with \(someResult)")

        // and another promise
        let step2 = someOtherPromise("__step2__")
        return step2
    }
    .then({ someResult in
        print("Step 2 -- complete with \(someResult)")
        // last step - does not need to return anything if we don't want to
    },
    // handle failures (in any step!!)
    onRejected: { someError
        print("Error \(someError)")
    }) {
        // on complete
        print("All steps completed")
        readyExpectation.fulfill()
    }

    // WAIT
    waitForExpectationsWithTimeout(10) { error in
        XCTAssertNil(error)
    }
}
```

### Resources
- https://promisesaplus.com
- https://github.com/promises-aplus/promises-spec
- http://lazd.github.io/Pinky/
- http://www.drewag.me/posts/practical-use-for-curried-functions-in-swift

### Additional
- https://github.com/antitypical/Result
- https://gist.github.com/softwaredoug/9044640
- http://robnapier.net/functional-wish-fulfillment
- http://robnapier.net/flatmap
- https://github.com/thoughtbot/FunctionalJSON-swift/tree/d3fcf771c20813e57cb54472dd8c55ee33e87ae4/FunctionalJSON
- http://www.sunsetlakesoftware.com/2015/06/12/swift-2-error-handling-practice
- https://medium.com/@robringham/promises-in-swift-66f377c3e403
- https://github.com/rringham/swift-promises/blob/master/promises/Promise.swift
- https://www.promisejs.org/implementing/
- http://eamodeorubio.github.io/tamingasync/#/
- https://robots.thoughtbot.com/efficient-json-in-swift-with-functional-concepts-and-generics
- https://robots.thoughtbot.com/real-world-json-parsing-with-swift

### Other Promises Frameworks in Swift
- https://github.com/ReactiveX/RxSwift
- https://github.com/ReactiveCocoa/ReactiveCocoa
- https://github.com/mxcl/PromiseKit
- https://github.com/ReactKit/ReactKit
- https://github.com/supertommy/craft
- https://github.com/Thomvis/BrightFutures
