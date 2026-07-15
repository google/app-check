# Review Guidelines

## Concurrency & Thread Safety

When reviewing Objective-C code, particularly test fakes, you MUST strictly enforce the following thread safety rules for concurrent test execution:

1. **State Mutation Synchronization**: All state mutations (e.g., incrementing counters like `counter++`, setting properties, or adding to arrays) MUST be wrapped in a `@synchronized(self)` block to prevent data races and TSAN (Thread Sanitizer) failures.
2. **Proper Use of `atomic` vs `nonatomic`**: The `atomic` property modifier does NOT make read-modify-write operations (like `++`) thread-safe. Properties that require compound operations should be declared `nonatomic` to avoid misleading expectations, and their getters/setters must be manually synchronized in the implementation file (or accessed directly via ivar within a synchronized block).
