# ThenKit
Promises/A+ implementation in Swift 2 inspired by Pinky - http://lazd.github.io/Pinky/

When doing some research on [Promises/A+](https://promisesaplus.com), I was looking for a really simple implementation of the spec to better understand the data structures being using and how callbacks/closures/blocks were managed and fired during fulfilled / rejected.

[Pinky](http://lazd.github.io/Pinky/) is a really tiny and simple implementation of the spec. It is very well documented and it was easy to understand it.

I found a few implementations in Swift 1.x and some/most of the big frameworks are also being ported to Swift 2.0. (At time of this writing).

## Usage

TBD. Add Carthage support.
In the meantime, copy ThenKit.swift somewhere in our project.

### API
Start by creating a **Promise** which implements **Thenable** protocol and exposes a few helper functions:
- `name` -- to help with debug :)
- `then(onFulfilled:Function?) -> Thenable` -- simple call with optional *success/fulfill* block
- `then(onFulfilled:Function?, onRejected:RejectedFunction?) -> Thenable` -- provides *success/fulfill* and *failure/reject* blocks
- `then(onFulfilled:Function?, onCompleted: CompleteFunction?) -> Thenable` -- adds a *completion* block 
- `func then(onFulfilled:Function?, onRejected:RejectedFunction?, onCompleted: CompleteFunction?) -> Thenable` -- complete call with the 3 blocks

Simple Example would be:
```swift
let p = Promise()
p.name = "Promise_1" // give it a name so it's easier to find in logs
// only THEN / COMPLETE
p.then({ fulfillVal in
    print("PROMISE fulfilled with \(fulfillVal)")
}) {
    print("PROMISE - COMPLETE")
}

// wrapper on dispatch_after...
dispatch_after(1.second) { [weak p] in
    p?.fulfill("done")
}
```

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
        print("step1 just created with \(step1)")
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

        let step2 = someOtherPromise("__step2__")
        return step2 
    },
    // handle failures (in any step!!)
    onRejected: { someError
        print("Error \(someError)")
    })
    // on complete
    {
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
https://promisesaplus.com
https://github.com/promises-aplus/promises-spec
http://lazd.github.io/Pinky/
http://www.drewag.me/posts/practical-use-for-curried-functions-in-swift

### Additional
https://github.com/antitypical/Result
https://gist.github.com/softwaredoug/9044640
http://robnapier.net/functional-wish-fulfillment
http://robnapier.net/flatmap
https://github.com/thoughtbot/FunctionalJSON-swift/tree/d3fcf771c20813e57cb54472dd8c55ee33e87ae4/FunctionalJSON
http://www.sunsetlakesoftware.com/2015/06/12/swift-2-error-handling-practice
https://medium.com/@robringham/promises-in-swift-66f377c3e403
https://github.com/rringham/swift-promises/blob/master/promises/Promise.swift
https://www.promisejs.org/implementing/
http://eamodeorubio.github.io/tamingasync/#/
https://robots.thoughtbot.com/efficient-json-in-swift-with-functional-concepts-and-generics
https://robots.thoughtbot.com/real-world-json-parsing-with-swift

### Other Promises Frameworks in Swift
https://github.com/supertommy/craft
https://github.com/ReactKit/ReactKit
https://github.com/ReactiveCocoa/ReactiveCocoa
https://github.com/mxcl/PromiseKit
https://github.com/Thomvis/BrightFutures
