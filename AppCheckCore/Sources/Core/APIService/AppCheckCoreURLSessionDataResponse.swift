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

/// The class represents HTTP response received from `URLSession`.
@objc(GACAppCheckURLSessionDataResponse)
public class AppCheckCoreURLSessionDataResponse: NSObject {
  public let httpResponse: HTTPURLResponse
  public let httpBody: Data?
  public let requestDate: Date

  public init(response: HTTPURLResponse, httpBody: Data?, requestDate: Date) {
    httpResponse = response
    self.httpBody = httpBody
    self.requestDate = requestDate
    super.init()
  }

  public convenience init(response: HTTPURLResponse, httpBody: Data?) {
    self.init(response: response, httpBody: httpBody, requestDate: Date())
  }
}
