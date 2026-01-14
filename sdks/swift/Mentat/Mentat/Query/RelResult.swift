/* Copyright 2018 Mozilla
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of the
 * License at http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License. */

import Foundation
import MentatStore

/**
 Wraps a `Rel` result from a Mentat query.

 A `Rel` result is a list of rows of `TypedValue`s.
 Individual rows can be fetched or the set can be iterated.

 ## Fetching Individual Rows

 To fetch individual rows from a `RelResult` use `row(index:)`:

 ```swift
 let result = try await mentat.query(query: query).run()
 if let rows = result {
     let row1 = try rows.row(index: 0)
     let row2 = try rows.row(index: 1)
 }
 ```

 ## Iterating Over Results

 To iterate over the result set use standard iteration:

 ```swift
 let result = try await mentat.query(query: query).run()
 for row in result ?? [] {
     let name = row.asString(index: 0)
     let value = row.asLong(index: 1)
     print("\(name): \(value)")
 }
 ```

 - Note: Iteration is consuming and can only be done once.

 ## Thread Safety

 This class conforms to `Sendable` and can be safely used across actor boundaries.
 */
open class RelResult: OptionalRustObject, @unchecked Sendable {

    /**
     Fetch the row at the requested index.

     - Parameter index: the index of the row to be fetched

     - Throws: `PointerError.pointerConsumed` if the result set has already been iterated.

     - Returns: The row at the requested index as a `TupleResult`, if present, or nil if there is no row at that index.
     */
    open func row(index: Int32) throws -> TupleResult? {
        guard let row = row_at_index(try self.validPointer(), index) else {
            return nil
        }
        return TupleResult(raw: row)
    }

    override open func cleanup(pointer: OpaquePointer) {
        typed_value_result_set_destroy(pointer)
    }
}

/**
 Iterator for `RelResult`.

 To iterate over the result set use standard Swift iteration:

 ```swift
 let result = try await mentat.query(query: query).run()
 for row in result ?? [] {
     // Process each row
 }
 ```

 - Note: Iteration is consuming and can only be done once.
 */
open class RelResultIterator: OptionalRustObject, IteratorProtocol, @unchecked Sendable {
    public typealias Element = TupleResult

    init(iter: OpaquePointer?) {
        super.init(raw: iter)
    }

    open func next() -> Element? {
        guard let iter = self.raw,
            let rowPtr = typed_value_result_set_iter_next(iter) else {
            return nil
        }
        return TupleResult(raw: rowPtr)
    }

    override open func cleanup(pointer: OpaquePointer) {
        typed_value_result_set_iter_destroy(pointer)
    }
}

extension RelResult: Sequence {
    public func makeIterator() -> RelResultIterator {
        do {
            let rowIter = typed_value_result_set_into_iter(try self.validPointer())
            self.raw = nil
            return RelResultIterator(iter: rowIter)
        } catch {
            return RelResultIterator(iter: nil)
        }
    }
}

// MARK: - AsyncSequence Conformance

/**
 Async iterator for `RelResult`.

 Enables async iteration over query results using `for await`:

 ```swift
 let result = try await mentat.query(query: query).run()
 if let rows = result {
     for await row in rows.async {
         // Process each row asynchronously
     }
 }
 ```
 */
public struct AsyncRelResultIterator: AsyncIteratorProtocol {
    public typealias Element = TupleResult

    private var iterator: RelResultIterator

    init(iterator: RelResultIterator) {
        self.iterator = iterator
    }

    public mutating func next() async -> Element? {
        return iterator.next()
    }
}

/**
 Async sequence wrapper for `RelResult`.

 Access via the `.async` property on `RelResult`:

 ```swift
 for await row in result.async {
     // Process row
 }
 ```
 */
public struct AsyncRelResultSequence: AsyncSequence, Sendable {
    public typealias Element = TupleResult
    public typealias AsyncIterator = AsyncRelResultIterator

    private let result: RelResult

    init(result: RelResult) {
        self.result = result
    }

    public func makeAsyncIterator() -> AsyncRelResultIterator {
        return AsyncRelResultIterator(iterator: result.makeIterator())
    }
}

extension RelResult {
    /// Returns an async sequence wrapper for iterating over results using `for await`.
    ///
    /// ```swift
    /// let result = try await mentat.query(query: query).run()
    /// for await row in result?.async ?? AsyncRelResultSequence(result: RelResult(raw: nil)) {
    ///     print(row.asString(index: 0))
    /// }
    /// ```
    public var async: AsyncRelResultSequence {
        return AsyncRelResultSequence(result: self)
    }
}
