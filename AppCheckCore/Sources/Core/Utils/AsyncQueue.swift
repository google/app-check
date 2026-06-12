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

/// An actor that serializes asynchronous work, running tasks in a FIFO order.
/// Because Swift actors are reentrant, awaiting inside an actor method allows
/// other tasks to execute. `AsyncQueue` prevents this reentrancy for enqueued tasks.
actor AsyncQueue {
  private var lastTask: Task<Void, Never>?

  /// Enqueues an operation to be run sequentially.
  /// - Parameter operation: The asynchronous operation to run.
  /// - Returns: The result of the operation.
  func enqueue<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws
    -> T {
    let previousTask = lastTask
    let newTask = Task { [previousTask] in
      _ = await previousTask?.result
      return try await operation()
    }
    lastTask = Task {
      _ = await newTask.result
    }
    return try await newTask.value
  }
}
