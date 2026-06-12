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

import Foundation

@objc(GACAppCheckHTTPError)
public final class GACAppCheckHTTPError: NSError, @unchecked Sendable {
  @objc public let httpResponse: HTTPURLResponse
  @objc public let data: Data

  @objc(initWithHTTPResponse:data:) public init(httpResponse: HTTPURLResponse, data: Data?) {
    self.httpResponse = httpResponse
    let actualData = data ?? Data()
    self.data = actualData
    let userInfo = Self.userInfo(with: httpResponse, data: actualData)
    super.init(
      domain: AppCheckCoreErrorDomain,
      code: AppCheckCoreErrorCode.unknown.rawValue,
      userInfo: userInfo
    )
  }

  @objc public required init?(coder: NSCoder) {
    guard let response = coder.decodeObject(of: HTTPURLResponse.self, forKey: "HTTPResponse") else {
      return nil
    }
    httpResponse = response
    data = coder.decodeObject(of: NSData.self, forKey: "data") as Data? ?? Data()
    let userInfo = Self.userInfo(with: response, data: data)
    super.init(
      domain: AppCheckCoreErrorDomain,
      code: AppCheckCoreErrorCode.unknown.rawValue,
      userInfo: userInfo
    )
  }

  @objc override public func encode(with coder: NSCoder) {
    coder.encode(httpResponse, forKey: "HTTPResponse")
    coder.encode(data, forKey: "data")
  }

  @objc override public static var supportsSecureCoding: Bool {
    return true
  }

  private static func userInfo(with response: HTTPURLResponse, data: Data) -> [String: Any] {
    let responseString = String(data: data, encoding: .utf8) ?? ""
    let urlString = response.url?.absoluteString ?? "nil"
    let failureReason =
      "The server responded with an error: \n - URL: \(urlString) \n - HTTP status code: \(response.statusCode) \n - Response body: \(responseString)"
    return [NSLocalizedFailureReasonErrorKey: failureReason]
  }

  @objc override public func copy(with zone: NSZone? = nil) -> Any {
    return GACAppCheckHTTPError(httpResponse: httpResponse, data: data)
  }
}
