import Foundation
@testable import AppCheckCore

class GACURLSessionFake: URLSession {
  var resultResponse: _GACURLSessionDataResponse?
  var resultError: Error?
  var lastRequest: URLRequest?
  var requestValidationBlock: ((URLRequest) -> Bool)?
  var isInvoked: Bool = false
  
  override init() {
    super.init()
  }
  
  // This might be called if the migrated Swift code expects `gac_dataTask(with:)`
  func gac_dataTask(with request: URLRequest) async throws -> _GACURLSessionDataResponse {
    isInvoked = true
    lastRequest = request
    
    if let validationBlock = requestValidationBlock {
      _ = validationBlock(request)
    }
    
    if let resultError = resultError {
      throw resultError
    }
    
    if let resultResponse = resultResponse {
      return resultResponse
    }
    
    // Default fallback
    throw NSError(domain: "GACURLSessionFake", code: -1, userInfo: nil)
  }
  
  // This might be called if the migrated Swift code uses native `data(for:)`
  override func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
    let response = try await gac_dataTask(with: request)
    return (response.httpBody ?? Data(), response.httpResponse ?? URLResponse())
  }
  
  static func httpResponse(withCode statusCode: Int) -> HTTPURLResponse {
    return HTTPURLResponse(url: URL(string: "https://url.com")!,
                           statusCode: statusCode,
                           httpVersion: "HTTP/1.1",
                           headerFields: nil)!
  }
}
