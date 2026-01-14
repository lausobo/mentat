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
 Wraps a `Tuple` result from a Mentat query.

 A `Tuple` result is a single row of `TypedValue`s.
 Individual values can be fetched as `TypedValue`s or converted into a requested type.

 ## Usage

 ```swift
 let query = "[:find [?name ?age] :where [?e :user/name ?name] [?e :user/age ?age]]"
 let tuple = try await mentat.query(query: query).runTuple()

 if let result = tuple {
     let name = result.asString(index: 0)
     let age = result.asLong(index: 1)
     print("\(name) is \(age) years old")
 }
 ```

 ## Supported Types

 Values can be fetched as one of the following types:
 - `TypedValue` - via `get(index:)`
 - `Int64` - via `asLong(index:)`
 - `Entid` - via `asEntid(index:)`
 - `Keyword` - via `asKeyword(index:)`
 - `Bool` - via `asBool(index:)`
 - `Double` - via `asDouble(index:)`
 - `Date` - via `asDate(index:)`
 - `String` - via `asString(index:)`
 - `UUID` - via `asUUID(index:)`

 ## Thread Safety

 This class conforms to `Sendable` and can be safely used across actor boundaries.
 */
open class TupleResult: OptionalRustObject, @unchecked Sendable {

    /**
     Return the `TypedValue` at the specified index.
     If the index is greater than the number of values then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `TypedValue` at that index.
     */
    open func get(index: Int) -> TypedValue {
        return TypedValue(raw: value_at_index(self.raw!, Int32(index)))
    }

    /**
     Return the `Int64` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Long` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `Int64` at that index.
     */
    open func asLong(index: Int) -> Int64 {
        return value_at_index_into_long(self.raw!, Int32(index))
    }

    /**
     Return the `Entid` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Ref` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `Entid` at that index.
     */
    open func asEntid(index: Int) -> Entid {
        return value_at_index_into_entid(self.raw!, Int32(index))
    }

    /**
     Return the keyword `String` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Keyword` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The keyword `String` at that index.
     */
    open func asKeyword(index: Int) -> String {
        let str = value_at_index_into_kw(self.raw!, Int32(index));
        return String(destroyingRustString: str);
    }

    /**
     Return the `Bool` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Boolean` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `Bool` at that index.
     */
    open func asBool(index: Int) -> Bool {
        return value_at_index_into_boolean(self.raw!, Int32(index)) == 0 ? false : true
    }

    /**
     Return the `Double` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Double` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `Double` at that index.
     */
    open func asDouble(index: Int) -> Double {
        return value_at_index_into_double(self.raw!, Int32(index))
    }

    /**
     Return the `Date` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Instant` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `Date` at that index.
     */
    open func asDate(index: Int) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(value_at_index_into_timestamp(self.raw!, Int32(index))))
    }

    /**
     Return the `String` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `String` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `String` at that index.
     */
    open func asString(index: Int) -> String {
        let str = value_at_index_into_string(self.raw!, Int32(index));
        return String(destroyingRustString: str)
    }

    /**
     Return the `UUID` at the specified index.
     If the index is greater than the number of values then this function will crash.
     If the value type if the `TypedValue` at this index is not `Uuid` then this function will crash.

     - Parameter index: The index of the value to fetch.

     - Returns: The `UUID` at that index.
     */
    open func asUUID(index: Int) -> UUID? {
        let uuid = value_at_index_into_uuid(self.raw!, Int32(index));
        return UUID(destroyingRustUUID: uuid)
    }

    override open func cleanup(pointer: OpaquePointer) {
        typed_value_list_destroy(pointer)
    }

    // MARK: - CustomDebugStringConvertible

    override open var debugDescription: String {
        if let raw = raw {
            let pointer = String(format: "%p", Int(bitPattern: raw))
            return "<TupleResult pointer=\(pointer)>"
        } else {
            return "<TupleResult pointer=nil (consumed)>"
        }
    }
}

/**
 Wraps a `Coll` result from a Mentat query.

 A `Coll` result is a collection of single values of type `TypedValue`.
 Values can be fetched by index or iterated over.

 ## Usage

 ```swift
 let query = "[:find [?name ...] :where [?e :user/name ?name]]"
 let coll = try await mentat.query(query: query).runColl()

 // Iterate over values
 for value in coll ?? [] {
     print(value.asString())
 }

 // Or access by index
 if let result = coll {
     let firstName = result.asString(index: 0)
 }
 ```

 ## Supported Types

 Values can be fetched as one of the following types:
 - `TypedValue` - via `get(index:)`
 - `Int64` - via `asLong(index:)`
 - `Entid` - via `asEntid(index:)`
 - `Keyword` - via `asKeyword(index:)`
 - `Bool` - via `asBool(index:)`
 - `Double` - via `asDouble(index:)`
 - `Date` - via `asDate(index:)`
 - `String` - via `asString(index:)`
 - `UUID` - via `asUUID(index:)`

 ## Thread Safety

 This class conforms to `Sendable` and can be safely used across actor boundaries.
 */
open class ColResult: TupleResult, @unchecked Sendable {

    // MARK: - CustomDebugStringConvertible

    override open var debugDescription: String {
        if let raw = raw {
            let pointer = String(format: "%p", Int(bitPattern: raw))
            return "<ColResult pointer=\(pointer)>"
        } else {
            return "<ColResult pointer=nil (iterated)>"
        }
    }
}

/**
 Iterator for `ColResult`.

 To iterate over the result set use standard Swift iteration:

 ```swift
 let coll = try await mentat.query(query: query).runColl()
 for value in coll ?? [] {
     print(value.asString())
 }
 ```

 - Note: Iteration is consuming and can only be done once.
 */
open class ColResultIterator: OptionalRustObject, IteratorProtocol, @unchecked Sendable {
    public typealias Element = TypedValue

    init(iter: OpaquePointer?) {
        super.init(raw: iter)
    }

    open func next() -> Element? {
        guard let iter = self.raw,
            let rowPtr = typed_value_list_iter_next(iter) else {
                return nil
        }
        return TypedValue(raw: rowPtr)
    }

    override open func cleanup(pointer: OpaquePointer) {
        typed_value_list_iter_destroy(pointer)
    }

    // MARK: - CustomDebugStringConvertible

    override open var debugDescription: String {
        if let raw = raw {
            let pointer = String(format: "%p", Int(bitPattern: raw))
            return "<ColResultIterator pointer=\(pointer)>"
        } else {
            return "<ColResultIterator pointer=nil (exhausted)>"
        }
    }
}

extension ColResult: Sequence {
    public func makeIterator() -> ColResultIterator {
        defer {
            self.raw = nil
        }
        guard let raw = self.raw else {
            return ColResultIterator(iter: nil)
        }
        let rowIter = typed_value_list_into_iter(raw)
        return ColResultIterator(iter: rowIter)
    }
}

// MARK: - AsyncSequence Conformance

/**
 Async iterator for `ColResult`.

 Enables async iteration over collection results using `for await`:

 ```swift
 let result = try await mentat.query(query: query).runColl()
 if let values = result {
     for await value in values.async {
         print(value.asString())
     }
 }
 ```
 */
public struct AsyncColResultIterator: AsyncIteratorProtocol {
    public typealias Element = TypedValue

    private var iterator: ColResultIterator

    init(iterator: ColResultIterator) {
        self.iterator = iterator
    }

    public mutating func next() async -> Element? {
        return iterator.next()
    }
}

/**
 Async sequence wrapper for `ColResult`.

 Access via the `.async` property on `ColResult`:

 ```swift
 for await value in result.async {
     print(value.asString())
 }
 ```
 */
public struct AsyncColResultSequence: AsyncSequence, Sendable {
    public typealias Element = TypedValue
    public typealias AsyncIterator = AsyncColResultIterator

    private let result: ColResult

    init(result: ColResult) {
        self.result = result
    }

    public func makeAsyncIterator() -> AsyncColResultIterator {
        return AsyncColResultIterator(iterator: result.makeIterator())
    }
}

extension ColResult {
    /// Returns an async sequence wrapper for iterating over values using `for await`.
    ///
    /// ```swift
    /// let result = try await mentat.query(query: query).runColl()
    /// for await value in result?.async ?? AsyncColResultSequence(result: ColResult(raw: nil)) {
    ///     print(value.asString())
    /// }
    /// ```
    public var async: AsyncColResultSequence {
        return AsyncColResultSequence(result: self)
    }
}
