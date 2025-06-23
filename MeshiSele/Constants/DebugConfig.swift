import Foundation
import os.log
import OSLog

struct DebugConfig {
    static let isDebugMode = true // Set to false for production
    static let enableVerboseLogging = true
    static let enableMemoryWarnings = true
    static let enableThreadSafetyChecks = true
    
    // MARK: - Logging Configuration
    static let logNetworkRequests = false // Disable in simulator to reduce noise
    
    // MARK: - Simulator Detection
    static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Network Logging Control
    static var shouldLogNetworkWarnings: Bool {
        // Reduce network logging in simulator to prevent console spam
        return !isRunningInSimulator
    }
    
    // MARK: - AdMob Configuration
    static var shouldUseTestAds: Bool {
        return isDebugMode || isRunningInSimulator
    }
    
    // MARK: - Console Noise Reduction
    static func configureConsoleLogging() {
        if isRunningInSimulator {
            // Suppress network-related logging in simulator
            setenv("OS_ACTIVITY_MODE", "disable", 1)
            setenv("CFNETWORK_DIAGNOSTICS", "0", 1)
            setenv("NW_CONNECTION_DEBUG", "0", 1)
        }
    }
    
    // MARK: - Logger Factory
    static func createLogger(category: String) -> Logger {
        return Logger(subsystem: "MeshiSele", category: category)
    }
    
    // Logging categories
    static let logger = Logger(subsystem: "com.meshisele", category: "debug")
    
    static func logMemoryWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        if enableMemoryWarnings {
            let filename = (file as NSString).lastPathComponent
            print("🧠⚠️ MEMORY WARNING [\(filename):\(line) \(function)]: \(message)")
            logger.warning("MEMORY WARNING [\(filename):\(line) \(function)]: \(message)")
        }
    }
    
    static func logThreadSafety(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        if enableThreadSafetyChecks {
            let filename = (file as NSString).lastPathComponent
            let currentThread = Thread.current.isMainThread ? "MAIN" : "BACKGROUND"
            print("🧵⚠️ THREAD SAFETY [\(currentThread)] [\(filename):\(line) \(function)]: \(message)")
            logger.warning("THREAD SAFETY [\(currentThread)] [\(filename):\(line) \(function)]: \(message)")
        }
    }
    
    static func logCriticalOperation(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let currentThread = Thread.current.isMainThread ? "MAIN" : "BACKGROUND"
        print("🔥 CRITICAL [\(currentThread)] [\(filename):\(line) \(function)]: \(message)")
        logger.critical("CRITICAL [\(currentThread)] [\(filename):\(line) \(function)]: \(message)")
    }
    
    static func assertMainThread(file: String = #file, function: String = #function, line: Int = #line) {
        if enableThreadSafetyChecks && !Thread.current.isMainThread {
            let filename = (file as NSString).lastPathComponent
            let message = "❌ MAIN THREAD VIOLATION: This operation must be performed on the main thread!"
            print("🧵❌ [\(filename):\(line) \(function)]: \(message)")
            logger.fault("[\(filename):\(line) \(function)]: \(message)")
            
            // In debug mode, crash immediately to catch the issue
            if isDebugMode {
                fatalError("Main thread violation detected at \(filename):\(line) in \(function)")
            }
        }
    }
    
    static func recordAsyncOperation(_ operation: String, file: String = #file, function: String = #function, line: Int = #line) {
        if enableVerboseLogging {
            let filename = (file as NSString).lastPathComponent
            let currentThread = Thread.current.isMainThread ? "MAIN" : "BACKGROUND"
            print("⚡ ASYNC [\(currentThread)] [\(filename):\(line) \(function)]: \(operation)")
        }
    }
}

// MARK: - Global Configuration
extension DebugConfig {
    static func setupGlobalConfiguration() {
        configureConsoleLogging()
        
        if isRunningInSimulator {
            print("🎭 Running in iOS Simulator - Network warnings suppressed")
        }
    }
} 