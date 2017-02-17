//
//  Logger.swift
//  ThenKit
//
//  Created by Rodrigo Lima on 8/18/15.
//  Copyright © 2015 Rodrigo. All rights reserved.
//
//  very simple logger

import Foundation

extension String {
    var NS: NSString { return (self as NSString) }
}

public struct Logger {
    // colors
    public enum Color: String {
        case black = "0;30m"
        case blue = "0;34m"
        case green = "0;32m"
        case cyan = "0;36m"
        case red = "0;31m"
        case purple = "0;35m"
        case brown = "0;33m"
        case gray = "0;37m"
        case darkGray = "1;30m"
        case lightBlue = "1;34m"
        case lightGreen = "1;32m"
        case lightCyan = "1;36m"
        case lightRed = "1;31m"
        case lightPurple = "1;35m"
        case yellow = "1;33m"
        case white = "1;37m"
    }

    struct Escape {
        static let begin = "\u{001b}["
        static let reset = Escape.begin + "0m"

        static func escaped(color: Color, _ someString: String) -> String {
            return begin + color.rawValue + someString + reset
        }
    }

    /// Level of log message to aid in the filtering of logs
    public enum Level: Int, CustomStringConvertible {
        /// Messages intended only for debug mode
        case debug = 3
        /// Messages intended to warn of potential errors
        case warn =  2
        /// Critical error messagees
        case error = 1
        /// Log level to turn off all logging
        case none = 0

        public var description: String {
            switch self {
            case .debug:    return "DEBG"
            case .warn:     return "WARN"
            case .error:    return "ERRR"
            case .none:     return "...."
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS zzz"
        return fmt
    }()

    private static func callerDetails(_ fn: String, _ file: String, _ ln: Int) -> String {
        let f = file.NS.lastPathComponent.NS.deletingPathExtension
        return "[\(f):\(fn):\(ln)]"
    }

    private static func prepareMessage(level: Level, callerDetails: String, message: String) -> String {
        let t = Thread.isMainThread ? "MAIN" : Thread.current.name ?? String(format: "%p", Thread.current)
        return "\(level)|\(timestampFormatter.string(from: Date()))@\(t) | \(callerDetails) | \(message) "
    }

    /// What is the max level to be logged
    ///
    /// Any logs under the given log level will be ignored
    public static var logLevel: Level = .debug// for now

    // log it
    public static func escaped(color: Color, _ messageBlock: @autoclosure () -> String?,
                               functionName: String=#function, fileName: String=#file, lineNumber: Int=#line) {
        if let msg = messageBlock() {
            let full = prepareMessage(level: .none, // for colored messages, just skip log level
                                      callerDetails: callerDetails(functionName, fileName, lineNumber),
                                      message: msg)
            print(Escape.escaped(color: color, full))
        }
    }

    // when no specific log level is passed, let's assume .DEBUG
    public static func log(level: Level = .debug, _ messageBlock: @autoclosure () -> String?,
                           functionName: String=#function, fileName: String=#file, lineNumber: Int=#line) {
        if level.rawValue <= Logger.logLevel.rawValue, let msg = messageBlock() {
            let full = prepareMessage(level: level,
                                      callerDetails: callerDetails(functionName, fileName, lineNumber),
                                      message: msg)
            switch level {
            case .warn:
                print(Escape.escaped(color: .yellow, full))
            case .error:
                print(Escape.escaped(color: .red, full))
            default:
                print(Escape.reset + full)
            }
        }
    }
}

/** EOF **/
