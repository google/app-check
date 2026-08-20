import Foundation

public typealias GACAppCheckToken = AppCheckCoreToken
public typealias GACAppCheckTokenResult = AppCheckCoreTokenResult
public typealias GACAppCheckProvider = AppCheckCoreProvider
public typealias GACAppCheckAPIRequestHook = @convention(block) (NSMutableURLRequest) -> Void
public typealias _GACAppCheckBackoffWrapperProtocol = AppCheckBackoffWrapperProtocol
public typealias _GACAppCheckBackoffWrapper = GACAppCheckBackoffWrapper
public typealias _GACAppCheckAPIServiceProtocol = GACAppCheckAPIServiceProtocol
public typealias _GACAppCheckAPIService = GACAppCheckAPIService
public typealias _GACAppCheckErrorUtil = GACAppCheckErrorUtil
public func GACAppCheckLogInfo(_ code: AppCheckCoreMessageCode, _ message: String) { AppCheckCoreLogger.log(code: code, logLevel: .info, message: message) }
public func GACAppCheckLogDebug(_ code: AppCheckCoreMessageCode, _ message: String) { AppCheckCoreLogger.log(code: code, logLevel: .debug, message: message) }
public func GACAppCheckLogError(_ code: AppCheckCoreMessageCode, _ message: String) { AppCheckCoreLogger.log(code: code, logLevel: .error, message: message) }
public func GACAppCheckLogWarning(_ code: AppCheckCoreMessageCode, _ message: String) { AppCheckCoreLogger.log(code: code, logLevel: .warning, message: message) }
