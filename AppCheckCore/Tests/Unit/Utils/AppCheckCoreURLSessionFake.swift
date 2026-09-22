// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import AppCheckCore
import Foundation

class AppCheckCoreURLSessionFake {
  var resultResponse: AppCheckCoreURLSessionDataResponse?
  var resultError: Error?
  var lastRequest: URLRequest?
  var requestValidationBlock: ((URLRequest) -> Bool)?
  var isInvoked: Bool = false

  let session: URLSession

  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolMock.self]
    session = URLSession(configuration: configuration)

    URLProtocolMock.requestHandler = { [weak self] request in
      guard let self = self else {
        throw NSError(domain: "AppCheckCoreURLSessionFake", code: -1, userInfo: nil)
      }

      var finalRequest = request
      if finalRequest.httpBody == nil, let stream = finalRequest.httpBodyStream {
        let data = NSMutableData()
        stream.open()
        while stream.hasBytesAvailable {
          var buffer = [UInt8](repeating: 0, count: 1024)
          let len = stream.read(&buffer, maxLength: buffer.count)
          if len > 0 {
            data.append(buffer, length: len)
          } else if len < 0 {
            break
          }
        }
        stream.close()
        finalRequest.httpBody = data as Data
      }

      self.isInvoked = true
      self.lastRequest = finalRequest

      if let validationBlock = self.requestValidationBlock {
        _ = validationBlock(finalRequest)
      }

      if let resultError = self.resultError {
        throw resultError
      }

      if let resultResponse = self.resultResponse {
        return (resultResponse.httpResponse, resultResponse.httpBody)
      }

      throw NSError(domain: "AppCheckCoreURLSessionFake", code: -1, userInfo: nil)
    }
  }

  static func httpResponse(withCode statusCode: Int) -> HTTPURLResponse {
    return HTTPURLResponse(url: URL(string: "https://url.com")!,
                           statusCode: statusCode,
                           httpVersion: "HTTP/1.1",
                           headerFields: nil)!
  }
}

class URLProtocolMock: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (URLResponse, Data?))?

  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override class func canInit(with task: URLSessionTask) -> Bool {
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    if let handler = URLProtocolMock.requestHandler {
      do {
        let (response, data) = try handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = data {
          client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
      } catch {
        client?.urlProtocol(self, didFailWithError: error)
      }
    }
  }

  override func stopLoading() {}
}
