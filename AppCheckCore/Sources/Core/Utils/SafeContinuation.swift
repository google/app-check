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
class SafeContinuation<T, E: Error> {
  private var continuation: CheckedContinuation<T, E>?
  private let lock = NSLock()

  init(_ continuation: CheckedContinuation<T, E>) {
    self.continuation = continuation
  }

  func resume(returning value: T) {
    lock.lock()
    let cont = continuation
    continuation = nil
    lock.unlock()
    cont?.resume(returning: value)
  }

  func resume(throwing error: E) {
    lock.lock()
    let cont = continuation
    continuation = nil
    lock.unlock()
    cont?.resume(throwing: error)
  }
}

func withSafeCheckedThrowingContinuation<T>(_ body: (SafeContinuation<T, Error>)
  -> Void) async throws -> T {
  return try await withCheckedThrowingContinuation { continuation in
    let safeContinuation = SafeContinuation(continuation)
    body(safeContinuation)
  }
}
