//
//  Logger.swift
//  ThenKit
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//

// Thanks Andrew Wagner -- http://www.drewag.me/posts/practical-use-for-curried-functions-in-swift
//
// Adding additional information -- timestamp, thread, colors (works with XcodeColors)

import Foundation

public struct Logger {
    // colors
    static let ESCAPE = "\u{001b}["
    static let RESET_FG = ESCAPE + "fg;" // Clear any foreground color
    static let RESET_BG = ESCAPE + "bg;" // Clear any background color
    static let RESET = ESCAPE + ";"   // Clear any foreground or background color

    public static func red<T>(object:T) {
        print("\(ESCAPE)fg255,0,0;\(object)\(RESET)")
    }

    public static func green<T>(object:T) {
        print("\(ESCAPE)fg0,255,0;\(object)\(RESET)")
    }

    public static func blue<T>(object:T) {
        print("\(ESCAPE)fg0,255,255;\(object)\(RESET)")
    }

    public static func yellow<T>(object:T) {
        print("\(ESCAPE)fg255,255,0;\(object)\(RESET)")
    }

    /// Level of log message to aid in the filtering of logs
    enum Level: Int {
        /// Messages intended only for verbose mode
        case Verbose = 4

        /// Messages intended only for debug mode
        case Debug = 3

        /// Messages intended to warn of potential errors
        case Warn =  2

        /// Critical error messagees
        case Error = 1

        /// Log level to turn off all logging
        case None = 0
    }

    private static let timestampFormatter: NSDateFormatter = {
        let fmt = NSDateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS zzz"
        return fmt
    }()

    /// Log a message to the console
    ///
    /// :param: level What level this log message is for
    /// :param: name A name to group a set of logs by
    /// :param: message The message to log
    ///
    /// :returns: the logged message
    static func log
        (level level: Level)
        (@autoclosure name: () -> String)
        (@autoclosure _ message: () -> String) -> String
    {
        if level.rawValue <= Logger.logLevel.rawValue {
            let t:String = NSThread.isMainThread() ? "MAIN" :
                NSThread.currentThread().name != "" ? NSThread.currentThread().name! : String(format:"%p", NSThread.currentThread())

            let l = "\(level)".uppercaseString
            let full = "\(timestampFormatter.stringFromDate(NSDate()))-\(t)>> \(l): '\(name())' >> \(message())"

            switch(level) {
            case .Debug:
                blue(full)
            case .Warn:
                yellow(full)
            case .Error:
                red(full)
            default:
                print(full)
            }
            return full
        }
        return ""
    }

    /// What is the max level to be logged
    ///
    /// Any logs under the given log level will be ignored
    static var logLevel: Level = .Verbose

    /// Logger for debug messages
    static var verbose = Logger.log(level: .Verbose)

    /// Logger for debug messages
    static var debug = Logger.log(level: .Debug)

    /// Logger for warnings
    static var warn = Logger.log(level: .Warn)
    
    /// Logger for errors
    static var error = Logger.log(level: .Error)
}
