/*
 * Copyright 2020 Google LLC
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

import Foundation

private let kResponseFieldToken = "token"
private let kResponseFieldTTL = "ttl"

public extension GACAppCheckToken {
    @objc(initWithTokenExchangeResponse:requestDate:error:)
    convenience init(tokenExchangeResponse response: Data, requestDate: Date) throws {
        guard !response.isEmpty else {
            throw GACAppCheckErrorUtil.error(withFailureReason: "Empty server response body.")
        }
        
        let responseDict: [String: Any]
        do {
            guard let dict = try JSONSerialization.jsonObject(with: response, options: []) as? [String: Any] else {
                throw GACAppCheckErrorUtil.jsonSerializationError(nil)
            }
            responseDict = dict
        } catch {
            throw GACAppCheckErrorUtil.jsonSerializationError(error)
        }
        
        try self.init(responseDict: responseDict, requestDate: requestDate)
    }

    @objc(initWithResponseDict:requestDate:error:)
    convenience init(responseDict: [String: Any], requestDate: Date) throws {
        guard let token = responseDict[kResponseFieldToken] as? String else {
            throw GACAppCheckErrorUtil.appCheckTokenResponseError(withMissingField: kResponseFieldToken)
        }
        
        guard let timeToLiveString = responseDict[kResponseFieldTTL] as? String, !timeToLiveString.isEmpty else {
            throw GACAppCheckErrorUtil.appCheckTokenResponseError(withMissingField: kResponseFieldTTL)
        }
        
        let timeToLiveValueString = timeToLiveString.replacingOccurrences(of: "s", with: "")
        guard let secondsToLive = TimeInterval(timeToLiveValueString), secondsToLive > 0 else {
            throw GACAppCheckErrorUtil.appCheckTokenResponseError(withMissingField: kResponseFieldTTL)
        }
        
        let expirationDate = requestDate.addingTimeInterval(secondsToLive)
        
        self.init(token: token, expirationDate: expirationDate, receivedAtDate: requestDate)
    }
}
