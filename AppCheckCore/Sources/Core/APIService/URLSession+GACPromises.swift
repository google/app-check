/*
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FBLPromises
import Foundation

public extension URLSession {
  @objc(gac_dataTaskPromiseWithRequest:)
  func gac_dataTaskPromise(with request: URLRequest)
    -> FBLPromise<AppCheckCoreURLSessionDataResponse> {
    let promise = FBLPromise<AppCheckCoreURLSessionDataResponse>.__pending()
    let task = dataTask(with: request) { data, response, error in
      if let error = error {
        promise.__reject(error as NSError)
      } else {
        let httpResponse = response as? HTTPURLResponse ?? HTTPURLResponse()
        let body = data ?? Data()
        promise.__fulfill(AppCheckCoreURLSessionDataResponse(
          response: httpResponse,
          httpBody: body
        ))
      }
    }
    task.resume()
    return promise
  }
}
