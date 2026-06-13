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

@objc(_GACURLSessionDataResponse)
public final class AppCheckCoreURLSessionDataResponse: NSObject, Sendable {
  @objc(HTTPResponse) public let httpResponse: HTTPURLResponse
  @objc(HTTPBody) public let httpBody: Data?

  @objc(initWithResponse:HTTPBody:) public init(response: HTTPURLResponse, httpBody: Data?) {
    httpResponse = response
    self.httpBody = httpBody
    super.init()
  }
}
