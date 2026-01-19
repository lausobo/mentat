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

public typealias Entid = Int64

/**
 Protocol to be implemented by any object that wishes to register for transaction observation.

 - Note: This protocol is deprecated. Use `transactionStream(for:)` for modern async/await observation.
 */
@available(*, deprecated, message: "Use transactionStream(for:) instead")
public protocol Observing: Sendable {
    func transactionDidOccur(key: String, reports: [TxChange])
}

/**
 Protocol to be implemented by any object that provides an interface to Mentat's transaction observers.

 - Note: This protocol is deprecated. Use `transactionStream(for:)` for modern async/await observation.
 */
@available(*, deprecated, message: "Use transactionStream(for:) instead")
public protocol Observable {
    @available(*, deprecated, message: "Use transactionStream(for:) instead")
    func register(key: String, observer: Observing, attributes: [String])
    @available(*, deprecated, message: "Use transactionStream(for:) instead")
    func unregister(key: String)
}

public enum CacheDirection {
    case forward;
    case reverse;
    case both;
}

/// Thread-safe storage for transaction observers (deprecated pattern)
private final class ObserverStorage: @unchecked Sendable {
    private var observers = [String: any Observing]()
    private let lock = NSLock()

    func get(_ key: String) -> (any Observing)? {
        lock.lock()
        defer { lock.unlock() }
        return observers[key]
    }

    func set(_ key: String, observer: any Observing) {
        lock.lock()
        defer { lock.unlock() }
        observers[key] = observer
    }

    func remove(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeValue(forKey: key)
    }
}

/// Thread-safe storage for AsyncStream continuations (modern pattern)
private final class StreamContinuationStorage: @unchecked Sendable {
    private var continuations = [String: AsyncStream<[TxChange]>.Continuation]()
    private let lock = NSLock()

    func get(_ key: String) -> AsyncStream<[TxChange]>.Continuation? {
        lock.lock()
        defer { lock.unlock() }
        return continuations[key]
    }

    func set(_ key: String, continuation: AsyncStream<[TxChange]>.Continuation) {
        lock.lock()
        defer { lock.unlock() }
        continuations[key] = continuation
    }

    func remove(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        continuations.removeValue(forKey: key)
    }
}

/**
 The primary class for accessing Mentat's API.

 This class provides all of the basic API that can be found in Mentat's Store struct.
 The raw pointer it holds is a pointer to a Store.

 ## Opening a Store

 ```swift
 // In-memory store
 let mentat = try Mentat.open()

 // File-based store
 let mentat = try Mentat.open(storeURI: "path/to/store.db")
 ```

 ## Querying (async/await)

 ```swift
 let query = "[:find ?name :where [?e :user/name ?name]]"
 let result = try await mentat.query(query: query).run()

 for row in result ?? [] {
     print(row.asString(index: 0))
 }
 ```

 ## Transactions

 ```swift
 // Simple transaction
 let report = try mentat.transact(transaction: """
     [[:db/add "tempid" :user/name "Alice"]]
     """)

 // Multi-step transaction
 let inProgress = try mentat.beginTransaction()
 try inProgress.transact(transaction: "[[:db/add \"a\" :user/name \"Bob\"]]")
 try inProgress.commit()
 ```

 ## Thread Safety

 This class conforms to `Sendable` and can be safely used across actor boundaries.
*/
open class Mentat: RustObject, @unchecked Sendable {
    fileprivate static let observerStorage = ObserverStorage()
    fileprivate static let streamStorage = StreamContinuationStorage()

    /// Counter for generating unique stream keys (access protected by streamKeyLock)
    nonisolated(unsafe) private static var streamKeyCounter: UInt64 = 0
    private static let streamKeyLock = NSLock()

    private static func nextStreamKey() -> String {
        streamKeyLock.lock()
        defer { streamKeyLock.unlock() }
        streamKeyCounter += 1
        return "stream_\(streamKeyCounter)"
    }

    /**
     Create a new Mentat with the provided pointer to a Mentat Store
     - Parameter raw: A pointer to a Mentat Store.
    */
    public required override init(raw: OpaquePointer) {
        super.init(raw: raw)
    }

    /**
     Open a connection to a Store in a given location.
     If the store does not already exist, one will be created.

     - Parameter storeURI: The URI as a String of the store to open.
        If no store URI is provided, an in-memory store will be opened.
    */
    public class func open(storeURI: String = "") throws -> Mentat {
        return Mentat(raw: try RustError.unwrap({err in store_open(storeURI, err) }))
    }

    /**
     Add an attribute to the cache. The {@link CacheDirection} determines how that attribute can be
     looked up.

     - Parameter attribute: The attribute to cache
     - Parameter direction: The direction the attribute should be keyed.
        `forward` caches values for an attribute keyed by entity
        (i.e. find values and entities that have this attribute, or find values of attribute for an entity)
        `reverse` caches entities for an attribute keyed by value.
        (i.e. find entities that have a particular value for an attribute).
        `both` adds an attribute such that it is cached in both directions.

     - Throws: `ResultError.error` if an error occured while trying to cache the attribute.
     */
    open func cache(attribute: String, direction: CacheDirection) throws {
        try RustError.withErrorCheck({err in
            switch direction {
            case .forward:
                store_cache_attribute_forward(self.raw, attribute, err)
            case .reverse:
                store_cache_attribute_reverse(self.raw, attribute, err)
            case .both:
                store_cache_attribute_bi_directional(self.raw, attribute, err)
            }
        });
    }

    /**
    Simple transact of an EDN string.
     - Parameter transaction: The string, as EDN, to be transacted

     - Throws: `ResultError.error` if the an error occured during the transaction, or the TxReport is nil.

     - Returns: The `TxReport` of the completed transaction
    */
    open func transact(transaction: String) throws -> TxReport {
        return TxReport(raw: try RustError.unwrap({err in store_transact(self.raw, transaction, err) }))
    }

    /**
     Start a new transaction.

     - Throws: `ResultError.error` if the creation of the transaction fails.
     - Throws: `ResultError.empty` if no `InProgress` is created.

     - Returns: The `InProgress` used to manage the transaction
     */
    open func beginTransaction() throws -> InProgress {
        return InProgress(raw: try RustError.unwrap({err in store_begin_transaction(self.raw, err) }));
    }

    /**
     Creates a new transaction (`InProgress`) and returns an `InProgressBuilder` for that transaction.

     - Throws: `ResultError.error` if the creation of the transaction fails.
     - Throws: `ResultError.empty` if no `InProgressBuilder` is created.

     - Returns: an `InProgressBuilder` for this `InProgress`
     */
    open func entityBuilder() throws -> InProgressBuilder {
        return InProgressBuilder(raw: try RustError.unwrap({err in store_in_progress_builder(self.raw, err) }))
    }

    /**
     Creates a new transaction (`InProgress`) and returns an `EntityBuilder` for the entity with `entid`
    for that transaction.

     - Parameter entid: The `Entid` for this entity.

     - Throws: `ResultError.error` if the creation of the transaction fails.
     - Throws: `ResultError.empty` if no `EntityBuilder` is created.

     - Returns: an `EntityBuilder` for this `InProgress`
     */
    open func entityBuilder(forEntid entid: Entid) throws -> EntityBuilder {
        return EntityBuilder(raw: try RustError.unwrap({err in
            store_entity_builder_from_entid(self.raw, entid, err) }))
    }

    /**
     Creates a new transaction (`InProgress`) and returns an `EntityBuilder` for a new entity with `tempId`
    for that transaction.

     - Parameter tempId: The temporary identifier for this entity.

     - Throws: `ResultError.error` if the creation of the transaction fails.
     - Throws: `ResultError.empty` if no `EntityBuilder` is created.

     - Returns: an `EntityBuilder` for this `InProgress`
     */
    open func entityBuilder(forTempId tempId: String) throws -> EntityBuilder {
        return EntityBuilder(raw: try RustError.unwrap({err in
            store_entity_builder_from_temp_id(self.raw, tempId, err)
        }))
    }

    /**
     Get the the `Entid` of the attribute.

     - Parameter attribute: The string represeting the attribute whose `Entid` we are after.
     The string is represented as `:namespace/name`.

     - Returns: The `Entid` associated with the attribute.
     */
    open func entidForAttribute(attribute: String) -> Entid {
        return Entid(store_entid_for_attribute(self.raw, attribute))
    }

    /**
     Start a query.
     - Parameter query: The string represeting the the query to be executed.

     - Returns: The `Query` representing the query that can be executed.
     */
    open func query(query: String) -> Query {
        return Query(raw: store_query(self.raw, query))
    }

    /**
     Retrieve a single value of an attribute for an Entity
     - Parameter attribute: The string the attribute whose value is to be returned.
     The string is represented as `:namespace/name`.
     - Parameter entid: The `Entid` of the entity we want the value from.

     - Returns: The `TypedValue` containing the value of the attribute for the entity.
     */
    open func value(forAttribute attribute: String, ofEntity entid: Entid) throws -> TypedValue? {
        return TypedValue(raw: try RustError.unwrap({err in
            store_value_for_attribute(self.raw, entid, attribute, err)
        }));
    }

    // MARK: - Transaction Observation (Modern AsyncStream API)

    /**
     Observe transactions affecting the specified attributes using modern Swift concurrency.

     This method returns an `AsyncStream` that yields arrays of `TxChange` whenever a transaction
     occurs that affects any of the specified attributes.

     ## Usage

     ```swift
     let stream = mentat.transactionStream(for: [":user/name", ":user/email"])

     Task {
         for await changes in stream {
             for change in changes {
                 print("Entity \(change.entid) was modified")
             }
         }
     }
     ```

     ## Cancellation

     The stream automatically unregisters from transaction observation when:
     - The `Task` consuming the stream is cancelled
     - The stream is no longer being iterated

     - Parameter attributes: An array of attribute keywords to observe (e.g., `":user/name"`)
     - Returns: An `AsyncStream` that yields `[TxChange]` arrays when transactions occur
     */
    open func transactionStream(for attributes: [String]) -> AsyncStream<[TxChange]> {
        let streamKey = Mentat.nextStreamKey()
        let mentatRaw = self.raw

        // Wrap the raw pointer for safe capture in @Sendable closure
        // This is safe because the Mentat instance manages the pointer lifecycle
        nonisolated(unsafe) let sendableRaw = mentatRaw

        return AsyncStream { continuation in
            // Convert attribute keywords to entids
            let attrEntIds = attributes.map { kw -> Entid in
                Entid(store_entid_for_attribute(mentatRaw, kw))
            }

            let ptr = UnsafeMutablePointer<Entid>.allocate(capacity: attrEntIds.count)
            let entidPointer = UnsafeMutableBufferPointer(start: ptr, count: attrEntIds.count)
            _ = entidPointer.initialize(from: attrEntIds)

            guard let firstElement = entidPointer.baseAddress else {
                ptr.deallocate()
                continuation.finish()
                return
            }

            // Store the continuation for the callback to use
            Mentat.streamStorage.set(streamKey, continuation: continuation)

            // Register with Rust FFI
            store_register_observer(mentatRaw, streamKey, firstElement, Entid(attributes.count), transactionStreamCallback)

            // Capture ptr for cleanup in @Sendable closure
            nonisolated(unsafe) let sendablePtr = ptr

            // Handle cancellation and cleanup
            continuation.onTermination = { @Sendable _ in
                sendablePtr.deallocate()
                Mentat.streamStorage.remove(streamKey)
                store_unregister_observer(sendableRaw, streamKey)
            }
        }
    }

    // Destroys the pointer by passing it back into Rust to be cleaned up
    override open func cleanup(pointer: OpaquePointer) {
        store_destroy(pointer)
    }

    // MARK: - CustomDebugStringConvertible

    override open var debugDescription: String {
        let pointer = String(format: "%p", Int(bitPattern: raw))
        return "<Mentat pointer=\(pointer)>"
    }
}

/**
 Set up `Mentat` to provide an interface to Mentat's transaction observation
 */
extension Mentat: Observable {
     /**
     Register an `Observing` and a set of attributes to observer for transaction observation.
     The `transactionDidOccur(String: [TxChange]:)` function is called when a transaction
     occurs in the `Store` that this `Mentat` is connected to that affects the attributes that an
     `Observing` has registered for.

     - Parameter key: `String` representing an identifier for the `Observing`.
     - Parameter observer: The `Observing` to be notified when a transaction occurs.
     - Parameter attributes: An `Array` of `Strings` representing the attributes that the `Observing`
     wishes to be notified about if they are referenced in a transaction.
     */
    public func register(key: String, observer: Observing, attributes: [String]) {
        let attrEntIds = attributes.map({ (kw) -> Entid in
            let entid = Entid(self.entidForAttribute(attribute: kw));
            return entid
        })

        let ptr = UnsafeMutablePointer<Entid>.allocate(capacity: attrEntIds.count)
        let entidPointer = UnsafeMutableBufferPointer(start: ptr, count: attrEntIds.count)
        var _ = entidPointer.initialize(from: attrEntIds)

        guard let firstElement = entidPointer.baseAddress else {
            return
        }
        Mentat.observerStorage.set(key, observer: observer)
        store_register_observer(self.raw, key, firstElement, Entid(attributes.count), transactionObserverCallback)

    }

    /**
     Unregister the `Observing` that was registered with the provided key such that it will no longer be called
     if a transaction occurs that affects the attributes that `Observing` was registered to observe.

     The `Observing` will need to re-register if it wants to start observing again.

     - Parameter key: `String` representing an identifier for the `Observing`.
     */
    public func unregister(key: String) {
        Mentat.observerStorage.remove(key)
        store_unregister_observer(self.raw, key)
    }
}


/**
 This function needs to be static as callbacks passed into Rust from Swift cannot contain state. Therefore the observers are static, as is
 the function that we pass into Rust to receive the callback.
 */
private func transactionObserverCallback(key: UnsafePointer<CChar>, reports: UnsafePointer<TxChangeList>) {
    let key = String(cString: key)
    guard let observer = Mentat.observerStorage.get(key) else { return }
    DispatchQueue.global(qos: .background).async {
        observer.transactionDidOccur(key: key, reports: [TxChange]())
    }
}

/**
 Callback function for AsyncStream-based transaction observation.
 This function yields values to the stored continuation when transactions occur.
 */
private func transactionStreamCallback(key: UnsafePointer<CChar>, reports: UnsafePointer<TxChangeList>) {
    let key = String(cString: key)
    guard let continuation = Mentat.streamStorage.get(key) else { return }
    // TODO: Parse TxChangeList into [TxChange] when FFI support is available
    continuation.yield([TxChange]())
}
