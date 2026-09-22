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

/// A wrapper around `CheckedContinuation` that ensures it is resumed exactly once.
/// If the underlying completion block is invoked multiple times (e.g. by a misbehaving
/// third-party provider), subsequent resumes are safely ignored instead of trapping.
/// Note: Like `CheckedContinuation`, this does not enforce that a resume is ever
/// called. If the underlying block never invokes the handler, the awaiting task will hang.
package final class SafeContinuation<T: Sendable, E: Error>: @unchecked Sendable {
  private var continuation: CheckedContinuation<T, E>?
  private let lock = NSLock()

  init(_ continuation: CheckedContinuation<T, E>) {
    self.continuation = continuation
  }

  package func resume(returning value: T) {
    lock.lock()
    let cont = continuation
    continuation = nil
    lock.unlock()
    cont?.resume(returning: value)
  }

  package func resume(throwing error: E) {
    lock.lock()
    let cont = continuation
    continuation = nil
    lock.unlock()
    cont?.resume(throwing: error)
  }
}

package func withSafeCheckedThrowingContinuation<T: Sendable>(_ body: (SafeContinuation<T, Error>)
  -> Void) async throws -> T {
  return try await withCheckedThrowingContinuation { continuation in
    let safeContinuation = SafeContinuation(continuation)
    body(safeContinuation)
  }
}
