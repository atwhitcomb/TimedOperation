//
//  TimedOperationTests.swift
//  TimedOperationTests
//
//  Created by Andrew James Whitcomb on 6/8/16.
//  Copyright © 2016 Andrew James Thomas Whitcomb. All rights reserved.
//

import XCTest
@testable import TimedOperation

internal class TestTimedOperation : TimedOperation {
    override func commonInit(timeoutPeriod: NSTimeInterval?) {
        super.commonInit(timeoutPeriod)
        self.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
    }
    
    internal func forceTimeout() {
        self.handleTimeout()
    }
    
    override internal class func defaultTimeoutPeriod() -> NSTimeInterval? {
        return 10
    }
}

class TimedOperationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTimedOperationDefault() {
        let testOperation : TimedOperation = TimedOperation()
        
        XCTAssert(testOperation.timeoutPeriod == nil)
        XCTAssert(testOperation.hasStarted == false)
        XCTAssert(testOperation.paused == false)
        XCTAssert(testOperation.executing == false)
        XCTAssert(testOperation.finished == false)
        XCTAssert(testOperation.cancelled == false)
        XCTAssert(testOperation.didTimeout == false)
        XCTAssert(testOperation.timeoutBlock == nil)
        XCTAssert(testOperation.error == nil)
        XCTAssert(testOperation.callsCompletionBlockAfterTimeout == true)
    }
    
    func testTimedOperationInitializer() {
        let testOperation1 : TestTimedOperation = TestTimedOperation()
        XCTAssert(testOperation1.timeoutPeriod == 10)
        
        let testOperation2 : TestTimedOperation = TestTimedOperation(nil)
        XCTAssert(testOperation2.timeoutPeriod == nil)
        
        let testOperation3 : TestTimedOperation = TestTimedOperation(20)
        XCTAssert(testOperation3.timeoutPeriod == 20)
        
        let testOperation4 : TestTimedOperation = TestTimedOperation(-10)
        XCTAssert(testOperation4.timeoutPeriod == nil)
    }
    
    func testTimedOperationStart() {
        let testOperation : TestTimedOperation = TestTimedOperation()
        testOperation.start()
        
        XCTAssert(testOperation.hasStarted == true)
        XCTAssert(testOperation.paused == false)
        XCTAssert(testOperation.executing == true)
        XCTAssert(testOperation.finished == false)
        XCTAssert(testOperation.cancelled == false)
        XCTAssert(testOperation.didTimeout == false)
    }
    
    func testTimedOperationPause() {
        let testOperation1 : TestTimedOperation = TestTimedOperation()
        XCTAssert(testOperation1.pause() == false, "Operations cannot pause without start() being called first.")
        
        testOperation1.start()
        XCTAssert(testOperation1.pause() == true, "Failed to pause operation after calling start().")
        XCTAssert(testOperation1.pause() == false, "Operations cannot pause when they are not executing.")
    
        testOperation1.didFinish()
        XCTAssert(testOperation1.pause() == false, "Operations cannot pause after they are completed.")
        
        let testOperation2: TestTimedOperation = TestTimedOperation()
        testOperation2.start()
        testOperation2.cancel()
        XCTAssert(testOperation2.pause() == false, "Operations cannot pause after they are cancelled.")
        
        let testOperation3: TestTimedOperation = TestTimedOperation()
        testOperation3.start()
        testOperation3.forceTimeout()
        XCTAssert(testOperation3.pause() == false, "Operations cannot pause after they timeout.")
    }
    
    func testTimedOperationPauseStatus() {
        let testOperation : TimedOperation = TimedOperation()
        testOperation.start()
        testOperation.pause()
        
        XCTAssert(testOperation.hasStarted == true)
        XCTAssert(testOperation.paused == true)
        XCTAssert(testOperation.executing == false)
        XCTAssert(testOperation.finished == false)
        XCTAssert(testOperation.cancelled == false)
        XCTAssert(testOperation.didTimeout == false)
    }
    
    func testTimedOperationResume() {
        let testOperation1 : TestTimedOperation = TestTimedOperation()
        XCTAssert(testOperation1.resume() == false, "Operations cannot resume without start() being called first.")
        
        testOperation1.start()
        XCTAssert(testOperation1.resume() == false, "Operations cannot resume while executing.")
        
        testOperation1.pause()
        XCTAssert(testOperation1.resume() == true, "Failed to resume operation after pausing.")
        XCTAssert(testOperation1.resume() == false, "Operations cannot resume immediately after resuming.")
        
        testOperation1.didFinish()
        XCTAssert(testOperation1.resume() == false, "Operations cannot resume after they are completed.")
        
        let testOperation2: TestTimedOperation = TestTimedOperation()
        testOperation2.start()
        testOperation2.cancel()
        XCTAssert(testOperation2.resume() == false, "Operations cannot resume after they are cancelled.")
        
        let testOperation3: TestTimedOperation = TestTimedOperation()
        testOperation3.start()
        testOperation3.forceTimeout()
        XCTAssert(testOperation3.resume() == false, "Operations cannot resume after they timeout.")
    }
    
    func testTimedOperationResumeStatus() {
        let testOperation : TimedOperation = TimedOperation()
        testOperation.start()
        testOperation.pause()
        testOperation.resume()
        
        XCTAssert(testOperation.hasStarted == true)
        XCTAssert(testOperation.paused == false)
        XCTAssert(testOperation.executing == true)
        XCTAssert(testOperation.finished == false)
        XCTAssert(testOperation.cancelled == false)
        XCTAssert(testOperation.didTimeout == false)
    }
    
    func testTimedOperationHasFinishedStatus() {
        let testOperation : TestTimedOperation = TestTimedOperation(1)
        testOperation.start()
        testOperation.didFinish()
        testOperation.forceTimeout()
        
        XCTAssert(testOperation.hasStarted == true)
        XCTAssert(testOperation.paused == false)
        XCTAssert(testOperation.executing == false)
        XCTAssert(testOperation.finished == true)
        XCTAssert(testOperation.cancelled == false)
        XCTAssert(testOperation.didTimeout == false)
    }
    
    func testTimedOperationCancelStatus() {
        let testOperation : TestTimedOperation = TestTimedOperation(1)
        testOperation.start()
        testOperation.cancel()
        testOperation.forceTimeout()
        
        XCTAssert(testOperation.hasStarted == true)
        XCTAssert(testOperation.paused == false)
        XCTAssert(testOperation.executing == false)
        XCTAssert(testOperation.finished == true)
        XCTAssert(testOperation.cancelled == true)
        XCTAssert(testOperation.didTimeout == false)
    }
    
    func testTimedOperationTimeoutStatus() {
        let testOperation : TestTimedOperation = TestTimedOperation(1)
        testOperation.start()
        testOperation.forceTimeout()
        
        XCTAssert(testOperation.hasStarted == true)
        XCTAssert(testOperation.paused == false)
        XCTAssert(testOperation.executing == false)
        XCTAssert(testOperation.finished == true)
        XCTAssert(testOperation.cancelled == true)
        XCTAssert(testOperation.didTimeout == true)
    }
    
    func testTimedOperationCompletionBlockHandling() {
        let completionBlockExpectation : XCTestExpectation = expectationWithDescription("Completion is not properly called upon operation completion.")
        
        let testOperation: TestTimedOperation = TestTimedOperation(1)
        testOperation.completionBlock = {
            completionBlockExpectation.fulfill()
        }
        testOperation.start()
        testOperation.didFinish()
        waitForExpectationsWithTimeout(0.1) { error in
            if error == nil {
                XCTAssert(testOperation.error == nil)
            }
        }
    }
    
    func testTimedOperationTimeoutHandling() {
        let timeoutExpectation : XCTestExpectation = expectationWithDescription("Timeout block is not properly called upon forcing timeout.")
        
        let testOperation: TestTimedOperation = TestTimedOperation(1)
        testOperation.timeoutBlock = {
            timeoutExpectation.fulfill()
        }
        testOperation.start()
        testOperation.forceTimeout()
        waitForExpectationsWithTimeout(0.1) { error in
            if error == nil {
                XCTAssert(testOperation.error?.domain == TimedOperation.TimedOperationErrorDomain)
            }
        }
    }
    
    func testTimedOperationCompletionBlockAndTimeoutHandling() {
        let timeoutExpectation : XCTestExpectation = expectationWithDescription("Timeout block is not properly called upon forcing timeout.")
        let completionBlockExpectation : XCTestExpectation = expectationWithDescription("Completion is not properly called upon forcing timeout.")
        
        let testOperation: TestTimedOperation = TestTimedOperation(1)
        testOperation.callsCompletionBlockAfterTimeout = true
        testOperation.completionBlock = {
            completionBlockExpectation.fulfill()
        }
        testOperation.timeoutBlock = {
            timeoutExpectation.fulfill()
        }
        testOperation.start()
        testOperation.forceTimeout()
        waitForExpectationsWithTimeout(0.1) { error in
            if error == nil {
                XCTAssert(testOperation.error?.domain == TimedOperation.TimedOperationErrorDomain)
            }
        }
    }
    
    func testTimedOperationTimeoutWithoutCompletionBlockHandling() {
        let timeoutExpectation : XCTestExpectation = expectationWithDescription("Timeout block is not properly called upon forcing timeout.")
        
        let testOperation: TestTimedOperation = TestTimedOperation(1)
        testOperation.callsCompletionBlockAfterTimeout = false
        testOperation.completionBlock = {
            XCTFail()
        }
        testOperation.timeoutBlock = {
            timeoutExpectation.fulfill()
        }
        testOperation.start()
        testOperation.forceTimeout()
        waitForExpectationsWithTimeout(0.1) { error in
            if error == nil {
                XCTAssert(testOperation.error?.domain == TimedOperation.TimedOperationErrorDomain)
            }
        }
    }
}
