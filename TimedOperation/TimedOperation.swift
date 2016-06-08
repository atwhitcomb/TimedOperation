//
//  TimedOperation.swift
//  TimedOperation
//
//  Created by Andrew James Whitcomb on 6/6/16.
//  Copyright © 2016 Andrew James Thomas Whitcomb. All rights reserved.
//

import Foundation

public class TimedOperation : NSOperation
{
    // MARK: Defines
    
    ///Define to indicate a TimedOperation has not started.
    static let TimedOperationNotExecutingStartTime : NSTimeInterval = 0
    
    ///Define to indicate the error domain that TimedOperation uses to indicate a timed out operation.
    static let TimedOperationErrorDomain = "TimedOperationErrorDomain"
    
    ///Defines timeout function block type.
    typealias TimedOperationTimeoutBlock = (Void) -> Void
    
    // MARK: Class variables
    
    ///The thread in which NSTimer creation/destruction operations are called for TimedOperation.
    static var timerOperationThread : NSThread {
        let timerOperationThread : NSThread = NSThread(target: self, selector: #selector(TimedOperation.timerOperationThreadEntryPoint(_:)), object: nil)
        timerOperationThread.start()
        return timerOperationThread
    }
    
    // MARK : Public variables
    
    ///Indicates the timeout period for the operation.
    var timeoutPeriod : NSTimeInterval? {
        willSet {
            if newValue < 0 {
                NSException(name: NSInvalidArgumentException, reason: "timeoutPeriod cannot be set less than 0.", userInfo: nil).raise()
            }
        }
    }
    
    ///The queue that completion block and/or timeout block should be called on.
    var completionQueue : dispatch_queue_t = dispatch_get_main_queue()
    
    ///Block to be called upon timeout. Cleanup work, delegate callbacks, and completion blocks should be called here.
    var timeoutBlock : TimedOperationTimeoutBlock?
    
    ///Error property for the operation. This class will put a timeout error if a timeout occurs. Subclasses can use this property for their own errors.
    var error : NSError?
    
    ///Toggle to allow the calling of the completion block after a timeout has occurred. Defaults to true.
    var callsCompletionBlockAfterTimeout : Bool = true
    
    ///Property to indicate if the operation has already started (i.e. the start() function has already been called).
    private(set) public var hasStarted : Bool = false
    
    ///Property to indicate if this operation is paused.
    private(set) public var paused : Bool = true
    
    ///Read-only property to indicate whether or not the operation timed out. Subclasses can override setter to do cleanup.
    private(set) public var didTimeout : Bool = false {
        willSet {
            if newValue {
                self.error = NSError(domain: TimedOperation.TimedOperationErrorDomain, code: 0, userInfo: nil)
            }
        }
    }
    
    // MARK : Private Variables
    
    ///NSTimer object to determine timeout.
    private var timeoutTimer : NSTimer? {
        willSet {
            if timeoutTimer?.valid == true {
                timeoutTimer!.invalidate()
            }
        }
    }
    
    ///Indicates the time remaining for the operation since the resuming of the operation.
    private var timeRemaining : NSTimeInterval?
    
    ///Timemarker for last time the operation was executing.
    private var lastStartTime : NSTimeInterval?
    
    ///dispatch_once token so that the completion block and timeout block cannot execute simutaniously if callsCompletionBlockAfterTimeout is false.
    private var completionToken : dispatch_once_t = 0
    
    // MARK : Initializers
    
    override init() {
        self.timeoutPeriod = self.dynamicType.defaultTimeoutPeriod()
    }
    
    init(timeoutPeriod: NSTimeInterval) {
        self.timeoutPeriod = timeoutPeriod
    }
    
    // MARK : Overrides
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.timeRemaining = nil
        self.performSelector(#selector(TimedOperation.destroyTimer), onThread: TimedOperation.timerOperationThread, withObject: nil, waitUntilDone: true)
    }
    
    override public var completionBlock: (() -> Void)? {
        get {
            return super.completionBlock
        }
        set {
            let swizzledCompletionBlock : (() -> Void)? = {
                [unowned self] in
                let completionQueue = self.completionQueue
                if self.didTimeout {
                    dispatch_once(&self.completionToken, {
                        dispatch_async(completionQueue, {
                            self.timeoutBlock?()
                        })
                    })
                }
                
                if self.callsCompletionBlockAfterTimeout {
                    dispatch_async(completionQueue, {
                        newValue?()
                    })
                }
                else {
                    dispatch_once(&self.completionToken, {
                        dispatch_async(completionQueue, {
                            newValue?()
                        })
                    })
                }
            }
            super.completionBlock = swizzledCompletionBlock
        }
    }
    
    override public func start() {
        self.timeRemaining = self.timeoutPeriod
        self.hasStarted = true
        self.resume()
    }
    
    private var _executing: Bool = false
    override private(set) public var executing: Bool {
        get {
            return _executing
        }
        set {
            if _executing != newValue {
                willChangeValueForKey("isExecuting")
                _executing = newValue
                didChangeValueForKey("isExecuting")
            }
        }
    }
    
    private var _finished: Bool = false;
    override private(set) public var finished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValueForKey("isFinished")
                _finished = newValue
                didChangeValueForKey("isFinished")
            }
        }
    }
    
    // MARK : Public Methods
    
    ///Function to resume the functionality of this operation. Subclasses should override this class to provide the logic to execute. All subclasses should call super.resume and take the return value to determine if additional logic should be executed.
    public func resume() -> Bool {
        let shouldResume : Bool = !self.cancelled && !self.executing && self.hasStarted
        if shouldResume {
            self.paused = false
            self.performSelector(#selector(TimedOperation.createTimer), onThread: TimedOperation.timerOperationThread, withObject: nil, waitUntilDone: true)
            self.executing = true
        }
        return shouldResume
    }
    
    ///Function to pause execution of this operation.
    public func pause() {
        if self.executing {
            self.paused = true
            self.executing = false
            self.performSelector(#selector(TimedOperation.destroyTimer), onThread: TimedOperation.timerOperationThread, withObject: nil, waitUntilDone: true)
        }
    }
    
    // MARK : Private Methods (Standard)
    
    ///Creates the timeout timer based on the amount of time remaining for this operation to complete.
    internal func createTimer() {
        guard self.timeRemaining != nil else {
            return;
        }
        self.lastStartTime = NSDate.timeIntervalSinceReferenceDate()
        self.timeoutTimer = NSTimer(timeInterval: self.timeRemaining!, target: self, selector: #selector(TimedOperation.destroyTimer), userInfo: nil, repeats: false)
    }
    
    
    ///Destroys the current timeout timer and decrements the amount of time remaining based on the elapsed time since the timer was created.
    internal func destroyTimer() {
        self.timeoutTimer = nil
        guard self.timeRemaining != nil else {
            return;
        }
        let currentTime : NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        let elapsedTime : NSTimeInterval = currentTime - self.lastStartTime!
        self.timeRemaining = self.timeRemaining! - elapsedTime
    }
    
    ///Method that is called when the operation times out.
    private func handleTimeout() {
        if !self.finished {
            self.didTimeout = true
            self.cancel()
        }
    }
    
    ///Method to determine the default amount of time instances of this class has to complete. Defaults to nil if not overriden.
    private class func defaultTimeoutPeriod() -> NSTimeInterval? {
        return nil
    }
    
    // MARK : Private Methods (Timer Thread)
    
    class internal func timerOperationThreadEntryPoint(_: AnyObject) {
        NSThread.currentThread().name = "TimerOperation"
        let runLoop : NSRunLoop = NSRunLoop.currentRunLoop()
        runLoop.addPort(NSPort(), forMode: NSDefaultRunLoopMode)
        runLoop.run()
    }
}