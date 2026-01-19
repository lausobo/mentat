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
 This class allows you to construct a query, bind values to variables and run those queries against a Mentat DB.

 This class cannot be created directly, but must be created through `Mentat.query(String:)`.

 ## Binding Values

 The types of values you can bind are:
 - `Int64`
 - `Entid`
 - `Keyword`
 - `Bool`
 - `Double`
 - `Date`
 - `String`
 - `UUID`

 Each bound variable must have a corresponding value in the query string used to create this query.

 ## Basic Usage

 ```swift
 let query = """
     [:find ?name ?cat
      :in ?type
      :where
      [?c :community/name ?name]
      [?c :community/type ?type]
      [?c :community/category ?cat]]
     """

 let result = try mentat.query(query: query)
     .bind(varName: "?type", toKeyword: ":community.type/website")
     .run()

 for row in result ?? [] {
     let name = row.asString(index: 0)
     let category = row.asString(index: 1)
     print("\(name): \(category)")
 }
 ```

 ## Async Usage (off main thread)

 For long-running queries, use the async variants to avoid blocking:
 ```swift
 let result = try await mentat.query(query: query)
     .bind(varName: "?type", toKeyword: ":community.type/website")
     .runAsync()
 ```

 ## Result Formats

 Queries can return results in different formats. Individual result values are returned as `TypedValue`s
 and the format differences relate to the number and structure of those values.

 ### Rel (default)
 Returns a list of rows of values. Use `run()`:
 ```swift
 let query = "[:find ?a ?b ?c :where ...]"
 let result = try mentat.query(query: query).run()
 ```

 ### Scalar
 Returns a single value (optional). Use `runScalar()`:
 ```swift
 let query = "[:find ?a . :where ...]"
 let value = try mentat.query(query: query).runScalar()
 ```

 ### Coll
 Returns a list of single values. Use `runColl()`:
 ```swift
 let query = "[:find [?a ...] :where ...]"
 let values = try mentat.query(query: query).runColl()
 ```

 ### Tuple
 Returns a single row of values. Use `runTuple()`:
 ```swift
 let query = "[:find [?a ?b ?c] :where ...]"
 let tuple = try mentat.query(query: query).runTuple()
 ```

 ## Thread Safety

 Query objects are single-use builders - after calling a run method, the query is consumed.
 For thread-safe usage, create a new Query for each thread or use the async variants.
 */
open class Query: OptionalRustObject, @unchecked Sendable {

    /**
     Binds a `Int64` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toLong value: Int64) throws -> Query {
        query_builder_bind_long(try self.validPointer(), varName, value)
        return self
    }

    /**
     Binds a `Entid` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toReference value: Entid) throws -> Query {
        query_builder_bind_ref(try self.validPointer(), varName, value)
        return self
    }

    /**
     Binds a `String` value representing a keyword for an attribute to the provided variable name.
     Keywords take the format `:namespace/name`.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toReference value: String) throws -> Query {
        query_builder_bind_ref_kw(try self.validPointer(), varName, value)
        return self
    }

    /**
     Binds a keyword `String` value to the provided variable name.
     Keywords take the format `:namespace/name`.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toKeyword value: String) throws -> Query {
        query_builder_bind_kw(try self.validPointer(), varName, value)
        return self
    }

    /**
     Binds a `Bool` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toBoolean value: Bool) throws -> Query {
        query_builder_bind_boolean(try self.validPointer(), varName, value ? 1 : 0)
        return self
    }

    /**
     Binds a `Double` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toDouble value: Double) throws -> Query {
        query_builder_bind_double(try self.validPointer(), varName, value)
        return self
    }

    /**
     Binds a `Date` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toDate value: Date) throws -> Query {
        query_builder_bind_timestamp(try self.validPointer(), varName, value.toMicroseconds())
        return self
    }

    /**
     Binds a `String` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toString value: String) throws -> Query {
        query_builder_bind_string(try self.validPointer(), varName, value)
        return self
    }

    /**
     Binds a `UUID` value to the provided variable name.

     - Parameter varName: The name of the variable in the format `?name`.
     - Parameter value: The value to be bound

     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has already been executed.

     - Returns: This `Query` such that further function can be called.
     */
    open func bind(varName: String, toUuid value: UUID) throws -> Query {
        let pointer = try self.validPointer()
        var rawUuid = value.uuid
        withUnsafePointer(to: &rawUuid) { uuidPtr in
            query_builder_bind_uuid(pointer, varName, uuidPtr)
        }
        return self
    }

    // MARK: - Query Execution (Synchronous)

    /**
     Execute the query with the values bound associated with this `Query` and return the results as a list of rows.

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, or that
     variables were incorrectly bound, or that the query provided was not `Rel`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Returns: A `RelResult` containing the query results, or `nil` if no results.
     */
    open func run() throws -> RelResult? {
        var error = RustError(message: nil)
        let result = query_builder_execute(try self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            throw QueryError.executionFailed(message: String(destroyingRustString: err))
        }
        return result.map { RelResult(raw: $0) }
    }

    /**
     Execute the query with the values bound associated with this `Query` and return a single scalar value.

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, that
     variables were incorrectly bound, or that the query provided was not `Scalar`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Returns: A `TypedValue` containing the scalar result, or `nil` if no result.
     */
    open func runScalar() throws -> TypedValue? {
        var error = RustError(message: nil)
        let result = query_builder_execute_scalar(try self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            throw QueryError.executionFailed(message: String(destroyingRustString: err))
        }
        return result.map { TypedValue(raw: $0) }
    }

    /**
     Execute the query with the values bound associated with this `Query` and return a collection of single values.

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, that
     variables were incorrectly bound, or that the query provided was not `Coll`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Returns: A `ColResult` containing the collection results, or `nil` if no results.
     */
    open func runColl() throws -> ColResult? {
        var error = RustError(message: nil)
        let result = query_builder_execute_coll(try self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            throw QueryError.executionFailed(message: String(destroyingRustString: err))
        }
        return result.map { ColResult(raw: $0) }
    }

    /**
     Execute the query with the values bound associated with this `Query` and return a single tuple of values.

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, that
     variables were incorrectly bound, or that the query provided was not `Tuple`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Returns: A `TupleResult` containing the tuple result, or `nil` if no result.
     */
    open func runTuple() throws -> TupleResult? {
        var error = RustError(message: nil)
        let result = query_builder_execute_tuple(try self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            throw QueryError.executionFailed(message: String(destroyingRustString: err))
        }
        return result.map { TupleResult(raw: $0) }
    }

    // MARK: - Query Execution (Async - runs off main thread)

    /**
     Execute the query asynchronously, running the FFI call off the main thread.

     Use this variant for potentially long-running queries to avoid blocking the main thread.

     - Returns: A `RelResult` containing the query results, or `nil` if no results.
     - Throws: `QueryError.executionFailed` if the query fails to execute.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed.
     */
    open func runAsync() async throws -> RelResult? {
        // Capture and consume pointer on caller thread to avoid races
        let pointer = try self.validPointer()
        self.raw = nil

        return try await Task.detached(priority: .userInitiated) {
            var error = RustError(message: nil)
            let result = query_builder_execute(pointer, &error)
            if let err = error.message {
                throw QueryError.executionFailed(message: String(destroyingRustString: err))
            }
            return result.map { RelResult(raw: $0) }
        }.value
    }

    /**
     Execute the query asynchronously, running the FFI call off the main thread.

     Use this variant for potentially long-running queries to avoid blocking the main thread.

     - Returns: A `TypedValue` containing the scalar result, or `nil` if no result.
     - Throws: `QueryError.executionFailed` if the query fails to execute.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed.
     */
    open func runScalarAsync() async throws -> TypedValue? {
        // Capture and consume pointer on caller thread to avoid races
        let pointer = try self.validPointer()
        self.raw = nil

        return try await Task.detached(priority: .userInitiated) {
            var error = RustError(message: nil)
            let result = query_builder_execute_scalar(pointer, &error)
            if let err = error.message {
                throw QueryError.executionFailed(message: String(destroyingRustString: err))
            }
            return result.map { TypedValue(raw: $0) }
        }.value
    }

    /**
     Execute the query asynchronously, running the FFI call off the main thread.

     Use this variant for potentially long-running queries to avoid blocking the main thread.

     - Returns: A `ColResult` containing the collection results, or `nil` if no results.
     - Throws: `QueryError.executionFailed` if the query fails to execute.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed.
     */
    open func runCollAsync() async throws -> ColResult? {
        // Capture and consume pointer on caller thread to avoid races
        let pointer = try self.validPointer()
        self.raw = nil

        return try await Task.detached(priority: .userInitiated) {
            var error = RustError(message: nil)
            let result = query_builder_execute_coll(pointer, &error)
            if let err = error.message {
                throw QueryError.executionFailed(message: String(destroyingRustString: err))
            }
            return result.map { ColResult(raw: $0) }
        }.value
    }

    /**
     Execute the query asynchronously, running the FFI call off the main thread.

     Use this variant for potentially long-running queries to avoid blocking the main thread.

     - Returns: A `TupleResult` containing the tuple result, or `nil` if no result.
     - Throws: `QueryError.executionFailed` if the query fails to execute.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed.
     */
    open func runTupleAsync() async throws -> TupleResult? {
        // Capture and consume pointer on caller thread to avoid races
        let pointer = try self.validPointer()
        self.raw = nil

        return try await Task.detached(priority: .userInitiated) {
            var error = RustError(message: nil)
            let result = query_builder_execute_tuple(pointer, &error)
            if let err = error.message {
                throw QueryError.executionFailed(message: String(destroyingRustString: err))
            }
            return result.map { TupleResult(raw: $0) }
        }.value
    }

    override open func cleanup(pointer: OpaquePointer) {
        query_builder_destroy(pointer)
    }

    // MARK: - CustomDebugStringConvertible

    override open var debugDescription: String {
        if let raw = raw {
            let pointer = String(format: "%p", Int(bitPattern: raw))
            return "<Query pointer=\(pointer)>"
        } else {
            return "<Query pointer=nil (executed)>"
        }
    }
}
