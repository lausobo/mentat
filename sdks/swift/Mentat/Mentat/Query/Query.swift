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

 ## Basic Usage (async/await)

 ```swift
 let query = """
     [:find ?name ?cat
      :in ?type
      :where
      [?c :community/name ?name]
      [?c :community/type ?type]
      [?c :community/category ?cat]]
     """

 let result = try await mentat.query(query: query)
     .bind(varName: "?type", toKeyword: ":community.type/website")
     .run()

 for row in result ?? [] {
     let name = row.asString(index: 0)
     let category = row.asString(index: 1)
     print("\(name): \(category)")
 }
 ```

 ## Result Formats

 Queries can return results in different formats. Individual result values are returned as `TypedValue`s
 and the format differences relate to the number and structure of those values.

 ### Rel (default)
 Returns a list of rows of values. Use `run()`:
 ```swift
 let query = "[:find ?a ?b ?c :where ...]"
 let result = try await mentat.query(query: query).run()
 ```

 ### Scalar
 Returns a single value (optional). Use `runScalar()`:
 ```swift
 let query = "[:find ?a . :where ...]"
 let value = try await mentat.query(query: query).runScalar()
 ```

 ### Coll
 Returns a list of single values. Use `runColl()`:
 ```swift
 let query = "[:find [?a ...] :where ...]"
 let values = try await mentat.query(query: query).runColl()
 ```

 ### Tuple
 Returns a single row of values. Use `runTuple()`:
 ```swift
 let query = "[:find [?a ?b ?c] :where ...]"
 let tuple = try await mentat.query(query: query).runTuple()
 ```

 ## Thread Safety

 This class conforms to `Sendable` and can be safely used across actor boundaries.
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

    /**
     Execute the query with the values bound associated with this `Query` and call the provided callback function with the results as a list of rows of `TypedValues`.

     - Parameter callback: the function to call with the results of this query

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, or that
     variable we incorrectly bound, or that the query provided was not `Rel`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Note: This method is deprecated. Use the async version `run() async throws` instead.
     */
    @available(*, deprecated, message: "Use async run() instead")
    open func run(callback: @escaping (RelResult?) -> Void) throws {
        var error = RustError(message: nil)
        let result = query_builder_execute(try! self.validPointer(), &error);
        self.raw = nil

        if let err = error.message {
            let message = String(destroyingRustString: err)
            throw QueryError.executionFailed(message: message)
        }
        guard let results = result else {
            callback(nil)
            return
        }
        callback(RelResult(raw: results))
    }

    /// Execute the query asynchronously and return the results as a list of rows.
    ///
    /// - Returns: A `RelResult` containing the query results, or `nil` if no results.
    /// - Throws: `QueryError.executionFailed` if the query fails to execute.
    open func run() async throws -> RelResult? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RelResult?, Error>) in
            do {
                try run { result in
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /**
     Execute the query with the values bound associated with this `Query` and call the provided callback function with the result as a single `TypedValue`.

     - Parameter callback: the function to call with the results of this query

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, that
     variable we incorrectly bound, or that the query provided was not `Scalar`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Note: This method is deprecated. Use the async version `runScalar() async throws` instead.
     */
    @available(*, deprecated, message: "Use async runScalar() instead")
    open func runScalar(callback: @escaping (TypedValue?) -> Void) throws {
        var error = RustError(message: nil)
        let result = query_builder_execute_scalar(try! self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            let message = String(destroyingRustString: err)
            throw QueryError.executionFailed(message: message)
        }
        guard let results = result else {
            callback(nil)
            return
        }
        callback(TypedValue(raw: results))
    }

    /// Execute the query asynchronously and return a single scalar value.
    ///
    /// - Returns: A `TypedValue` containing the scalar result, or `nil` if no result.
    /// - Throws: `QueryError.executionFailed` if the query fails to execute.
    open func runScalar() async throws -> TypedValue? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TypedValue?, Error>) in
            do {
                try runScalar { result in
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }


    /**
     Execute the query with the values bound associated with this `Query` and call the provided callback function with the result as a list of single `TypedValues`.

     - Parameter callback: the function to call with the results of this query

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, that
     variable we incorrectly bound, or that the query provided was not `Coll`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Note: This method is deprecated. Use the async version `runColl() async throws` instead.
     */
    @available(*, deprecated, message: "Use async runColl() instead")
    open func runColl(callback: @escaping (ColResult?) -> Void) throws {
        var error = RustError(message: nil)
        let result = query_builder_execute_coll(try! self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            let message = String(destroyingRustString: err)
            throw QueryError.executionFailed(message: message)
        }
        guard let results = result else {
            callback(nil)
            return
        }
        callback(ColResult(raw: results))
    }

    /// Execute the query asynchronously and return a collection of single values.
    ///
    /// - Returns: A `ColResult` containing the collection results, or `nil` if no results.
    /// - Throws: `QueryError.executionFailed` if the query fails to execute.
    open func runColl() async throws -> ColResult? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ColResult?, Error>) in
            do {
                try runColl { result in
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /**
     Execute the query with the values bound associated with this `Query` and call the provided callback function with the result as a list of single `TypedValues`.

     - Parameter callback: the function to call with the results of this query

     - Throws: `QueryError.executionFailed` if the query fails to execute. This could be because the provided query did not parse, that
     variable we incorrectly bound, or that the query provided was not `Tuple`.
     - Throws: `PointerError.pointerConsumed` if the underlying raw pointer has already consumed, which will occur if the query has previously been executed.

     - Note: This method is deprecated. Use the async version `runTuple() async throws` instead.
     */
    @available(*, deprecated, message: "Use async runTuple() instead")
    open func runTuple(callback: @escaping (TupleResult?) -> Void) throws {
        var error = RustError(message: nil)
        let result = query_builder_execute_tuple(try! self.validPointer(), &error)
        self.raw = nil

        if let err = error.message {
            let message = String(destroyingRustString: err)
            throw QueryError.executionFailed(message: message)
        }
        guard let results = result else {
            callback(nil)
            return
        }
        callback(TupleResult(raw: results))
    }

    /// Execute the query asynchronously and return a single tuple of values.
    ///
    /// - Returns: A `TupleResult` containing the tuple result, or `nil` if no result.
    /// - Throws: `QueryError.executionFailed` if the query fails to execute.
    open func runTuple() async throws -> TupleResult? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TupleResult?, Error>) in
            do {
                try runTuple { result in
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
