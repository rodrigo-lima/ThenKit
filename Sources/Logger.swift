//
//  Logger.swift
//  ThenKit
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//
//  very simple logger

import Foundation

public struct Logger {
    // colors
    public enum Color: String {
        case red       = "0;31m"
        case green     = "1;32m"
        case blue      = "0;34m"
        case lightBlue = "1;34m"
        case yellow    = "1;33m"
        case orange    = "0;36m"
        case white     = "0;37m"
    }

    struct Escape {
        static let begin = "\u{001b}["
        static let reset = Escape.begin + ";"

        static func escaped(color: Color, _ someString: String) -> String {
            print("hello somestring [\(someString)]")
            return begin + color.rawValue + someString + reset
        }
    }

    /// Level of log message to aid in the filtering of logs
    public enum Level: Int {
        /// Messages intended only for debug mode
        case debug = 3
        /// Messages intended to warn of potential errors
        case warn =  2
        /// Critical error messagees
        case error = 1
        /// Log level to turn off all logging
        case none = 0
    }

    private static let timestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS zzz"
        return fmt
    }()

    private static func callerDetails(_ fn: String, _ file: String, _ ln: Int) -> String {
        let f = (file as NSString).lastPathComponent
        return "[\(f):\(fn):\(ln)]"
    }

    private static func prepareMessage(level: Level, callerDetails: String, message: String) -> String {
        let t = Thread.isMainThread ? "MAIN" : Thread.current.name ?? String(format: "%p", Thread.current)
        let l = "\(level)".uppercased()
        //let f = fileName
        let full = "\(l)|\(timestampFormatter.string(from: Date()))@\(t) >> \(callerDetails) > \(message)"
print("prepared = [\(full)]")
        return full
    }

    /// What is the max level to be logged
    ///
    /// Any logs under the given log level will be ignored
    public static var logLevel: Level = .debug// for now

    // log it
    public static func escaped(color: Color, _ messageBlock: @autoclosure () -> String?,
                               functionName: String=#function, fileName: String=#file, lineNumber: Int=#line) {
        if let msg = messageBlock() {
            let full = prepareMessage(level: Logger.logLevel,
                                      callerDetails: callerDetails(functionName, fileName, lineNumber),
                                      message: msg)
            print(Escape.escaped(color: color, full))
        }
    }

    public static func log(level: Level = Logger.logLevel, _ messageBlock: @autoclosure () -> String?,
                           functionName: String=#function, fileName: String=#file, lineNumber: Int=#line) {
        if level.rawValue <= Logger.logLevel.rawValue, let msg = messageBlock() {
            let full = prepareMessage(level: level,
                                      callerDetails: callerDetails(functionName, fileName, lineNumber),
                                      message: msg)
            switch level {
            case .debug:
                print(full)
            case .warn:
                print(Escape.escaped(color: .yellow, full))
            case .error:
                print(Escape.escaped(color: .red, full))
            default:
                print(full)
            }
        }
    }
}

/** EOF **/
