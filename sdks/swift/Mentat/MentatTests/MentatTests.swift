/* Copyright 2018 Mozilla
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of the
 * License at http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License. */

import XCTest

@testable import Mentat

@MainActor
class MentatTests: XCTestCase {

    var citiesSchema: String?
    var seattleData: String?
    var store: Mentat?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // test that a store can be opened in memory
    func testOpenInMemoryStore() {
        XCTAssertNotNil(try Mentat.open().raw)
    }

    // test that a store can be opened in a specific location
    func testOpenStoreInLocation() {
        let documentsURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
        let storeURI = documentsURL.appendingPathComponent("test.db", isDirectory: false)!.absoluteString
        XCTAssertNotNil(try Mentat.open(storeURI: storeURI).raw)
    }

    func readFile(forResource resource: String, withExtension ext: String, subdirectory: String ) throws -> String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: type(of: self))
        #endif
        let schemaUrl = bundle.url(forResource: resource, withExtension: ext, subdirectory: subdirectory)!
        let contents = try String(contentsOf: schemaUrl)
        return contents
    }

    func readCitiesSchema() throws -> String {
        guard let schema = self.citiesSchema else {
            self.citiesSchema = try self.readFile(forResource: "cities", withExtension: "schema", subdirectory: "fixtures")
            return self.citiesSchema!
        }

        return schema
    }

    func readSeattleData() throws -> String {
        guard let data = self.seattleData else {
            self.seattleData = try self.readFile(forResource: "all_seattle", withExtension: "edn", subdirectory: "fixtures")
            return self.seattleData!
        }

        return data
    }

    func transactCitiesSchema(mentat: Mentat) throws -> TxReport {
        let vocab = try readCitiesSchema()
        let report = try mentat.transact(transaction: vocab)
        return report
    }

    func transactSeattleData(mentat: Mentat) throws -> TxReport {
        let data = try readSeattleData()
        let report = try mentat.transact(transaction: data)
        return report
    }

    func openAndInitializeCitiesStore() -> Mentat {
        guard let mentat = self.store else {
            let mentat = try! Mentat.open()
            let _ = try! self.transactCitiesSchema(mentat: mentat)
            let _ = try! self.transactSeattleData(mentat: mentat)
            self.store = mentat
            return mentat
        }

        return mentat
    }

    func populateWithTypesSchema(mentat: Mentat) -> (TxReport?, TxReport?) {
        do {
            let schema = """
            [
                [:db/add "b" :db/ident :foo/boolean]
                [:db/add "b" :db/valueType :db.type/boolean]
                [:db/add "b" :db/cardinality :db.cardinality/one]
                [:db/add "l" :db/ident :foo/long]
                [:db/add "l" :db/valueType :db.type/long]
                [:db/add "l" :db/cardinality :db.cardinality/one]
                [:db/add "r" :db/ident :foo/ref]
                [:db/add "r" :db/valueType :db.type/ref]
                [:db/add "r" :db/cardinality :db.cardinality/one]
                [:db/add "i" :db/ident :foo/instant]
                [:db/add "i" :db/valueType :db.type/instant]
                [:db/add "i" :db/cardinality :db.cardinality/one]
                [:db/add "d" :db/ident :foo/double]
                [:db/add "d" :db/valueType :db.type/double]
                [:db/add "d" :db/cardinality :db.cardinality/one]
                [:db/add "s" :db/ident :foo/string]
                [:db/add "s" :db/valueType :db.type/string]
                [:db/add "s" :db/cardinality :db.cardinality/one]
                [:db/add "k" :db/ident :foo/keyword]
                [:db/add "k" :db/valueType :db.type/keyword]
                [:db/add "k" :db/cardinality :db.cardinality/one]
                [:db/add "u" :db/ident :foo/uuid]
                [:db/add "u" :db/valueType :db.type/uuid]
                [:db/add "u" :db/cardinality :db.cardinality/one]
            ]
            """
            let transaction = try mentat.beginTransaction();
            let report = try transaction.transact(transaction: schema)
            let stringEntid = report.entid(forTempId: "s")!

            let data = """
            [
                [:db/add "a" :foo/boolean true]
                [:db/add "a" :foo/long 25]
                [:db/add "a" :foo/instant #inst "2017-01-01T11:00:00.000Z"]
                [:db/add "a" :foo/double 11.23]
                [:db/add "a" :foo/string "The higher we soar the smaller we appear to those who cannot fly."]
                [:db/add "a" :foo/keyword :foo/string]
                [:db/add "a" :foo/uuid #uuid "550e8400-e29b-41d4-a716-446655440000"]
                [:db/add "b" :foo/boolean false]
                [:db/add "b" :foo/ref \(stringEntid)]
                [:db/add "b" :foo/keyword :foo/string]
                [:db/add "b" :foo/long 50]
                [:db/add "b" :foo/instant #inst "2018-01-01T11:00:00.000Z"]
                [:db/add "b" :foo/double 22.46]
                [:db/add "b" :foo/string "Silence is worse; all truths that are kept silent become poisonous."]
                [:db/add "b" :foo/uuid #uuid "4cb3f828-752d-497a-90c9-b1fd516d5644"]
            ]
            """
            let dataReport = try transaction.transact(transaction: data)
            try transaction.commit();
            return (report, dataReport)
        } catch {
            assertionFailure(error.localizedDescription)
        }
        return (nil, nil)
    }

    func test1TransactVocabulary() {
        do {
            let mentat = try Mentat.open()
            let vocab = try readCitiesSchema()
            let report = try mentat.transact(transaction: vocab)
            XCTAssertNotNil(report)
            assert(report.txId > 0)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    func test2TransactEntities() {
        do {
            let mentat = try Mentat.open()
            let vocab = try readCitiesSchema()
            let _ = try mentat.transact(transaction: vocab)
            let data = try readSeattleData()
            let report = try mentat.transact(transaction: data)
            XCTAssertNotNil(report)
            assert(report.txId > 0)
            let entid = report.entid(forTempId: "a17592186045438")
            assert(entid == 65566)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    func testQueryScalar() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = "[:find ?n . :in ?name :where [(fulltext $ :community/name ?name) [[?e ?n]]]]"
        let result = try mentat.query(query: query)
            .bind(varName: "?name", toString: "Wallingford")
            .runScalar()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.asString(), "KOMO Communities - Wallingford")
    }

    func testQueryColl() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = "[:find [?when ...] :where [_ :db/txInstant ?when] :order (asc ?when)]"
        let rows = try mentat.query(query: query).runColl()
        XCTAssertNotNil(rows)
        // we are expecting 3 results
        for i in 0..<3 {
            XCTAssertNotNil(rows?.asDate(index: i))
        }
    }

    func testQueryCollResultIterator() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = "[:find [?when ...] :where [_ :db/txInstant ?when] :order (asc ?when)]"
        let rows = try mentat.query(query: query).runColl()
        XCTAssertNotNil(rows)
        rows?.forEach { value in
            XCTAssertEqual(value.valueType.rawValue, 2)
        }
    }

    func testQueryTuple() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = """
        [:find [?name ?cat]
        :where
        [?c :community/name ?name]
        [?c :community/type :community.type/website]
        [(fulltext $ :community/category "food") [[?c ?cat]]]]
        """
        let tuple = try mentat.query(query: query).runTuple()
        XCTAssertNotNil(tuple)
        XCTAssertEqual(tuple?.asString(index: 0), "Community Harvest of Southwest Seattle")
        XCTAssertEqual(tuple?.asString(index: 1), "sustainable food")
    }

    func testQueryRel() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = """
        [:find ?name ?cat
        :where
        [?c :community/name ?name]
        [?c :community/type :community.type/website]
        [(fulltext $ :community/category "food") [[?c ?cat]]]]
        """
        let expectedResults: Set<String> = [
            "InBallard|food",
            "Seattle Chinatown Guide|food",
            "Community Harvest of Southwest Seattle|sustainable food",
            "University District Food Bank|food bank"
        ]
        let rows = try mentat.query(query: query).run()
        XCTAssertNotNil(rows)
        var actualResults: Set<String> = []
        for row in rows! {
            let name = row.asString(index: 0)
            let category = row.asString(index: 1)
            actualResults.insert("\(name)|\(category)")
        }
        XCTAssertEqual(actualResults, expectedResults)
    }

    func testQueryRelResultIterator() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = """
        [:find ?name ?cat
        :where
        [?c :community/name ?name]
        [?c :community/type :community.type/website]
        [(fulltext $ :community/category "food") [[?c ?cat]]]]
        """
        let expectedResults: Set<String> = [
            "InBallard|food",
            "Seattle Chinatown Guide|food",
            "Community Harvest of Southwest Seattle|sustainable food",
            "University District Food Bank|food bank"
        ]
        let rows = try mentat.query(query: query).run()
        XCTAssertNotNil(rows)
        var actualResults: Set<String> = []
        rows?.forEach { row in
            let name = row.asString(index: 0)
            let category = row.asString(index: 1)
            actualResults.insert("\(name)|\(category)")
        }
        XCTAssertEqual(actualResults.count, 4)
        XCTAssertEqual(actualResults, expectedResults)
    }

    func testBindLong() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")
        let query = "[:find ?e . :in ?long :where [?e :foo/long ?long]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?long", toLong: 25)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), aEntid)
    }

    func testBindRef() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let stringEntid = mentat.entidForAttribute(attribute: ":foo/string")
        let bEntid = report!.entid(forTempId: "b")
        let query = "[:find ?e . :in ?ref :where [?e :foo/ref ?ref]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?ref", toReference: stringEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), bEntid)
    }

    func testBindKwRef() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let bEntid = report!.entid(forTempId: "b")
        let query = "[:find ?e . :in ?ref :where [?e :foo/ref ?ref]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?ref", toReference: ":foo/string")
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), bEntid)
    }

    func testBindKw() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")
        let query = "[:find ?e . :in ?kw :where [?e :foo/keyword ?kw]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?kw", toKeyword: ":foo/string")
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), aEntid)
    }

    func testBindDate() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")
        let query = "[:find [?e ?d] :in ?now :where [?e :foo/instant ?d] [(< ?d ?now)]]"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let boundDate = formatter.date(from: "2018-04-16T16:39:18+00:00")!
        let row = try mentat.query(query: query)
            .bind(varName: "?now", toDate: boundDate)
            .runTuple()
        XCTAssertNotNil(row)
        XCTAssertEqual(row?.asEntid(index: 0), aEntid)
    }

    func testBindString() throws {
        let mentat = openAndInitializeCitiesStore()
        let query = "[:find ?n . :in ?name :where [(fulltext $ :community/name ?name) [[?e ?n]]]]"
        let result = try mentat.query(query: query)
            .bind(varName: "?name", toString: "Wallingford")
            .runScalar()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.asString(), "KOMO Communities - Wallingford")
    }

    func testBindUuid() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")
        let query = "[:find ?e . :in ?uuid :where [?e :foo/uuid ?uuid]]"
        let uuid = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let value = try mentat.query(query: query)
            .bind(varName: "?uuid", toUuid: uuid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), aEntid)
    }

    func testBindBoolean() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")
        let query = "[:find ?e . :in ?bool :where [?e :foo/boolean ?bool]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?bool", toBoolean: true)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), aEntid)
    }

    func testBindDouble() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")
        let query = "[:find ?e . :in ?double :where [?e :foo/double ?double]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?double", toDouble: 11.23)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), aEntid)
    }

    func testTypedValueAsLong() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/long ?v]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asLong(), 25)
    }

    func testTypedValueAsRef() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?e . :where [?e :foo/long 25]]"
        let value = try mentat.query(query: query).runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asEntid(), aEntid)
    }

    func testTypedValueAsKw() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/keyword ?v]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asKeyword(), ":foo/string")
    }

    func testTypedValueAsBoolean() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/boolean ?v]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asBool(), true)
    }

    func testTypedValueAsDouble() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/double ?v]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asDouble(), 11.23)
    }

    func testTypedValueAsDate() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/instant ?v]]"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let expectedDate = formatter.date(from: "2017-01-01T11:00:00+00:00")

        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asDate(), expectedDate)
    }

    func testTypedValueAsString() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/string ?v]]"
        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asString(), "The higher we soar the smaller we appear to those who cannot fly.")
    }

    func testTypedValueAsUuid() throws {
        let mentat = try Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        let query = "[:find ?v . :in ?e :where [?e :foo/uuid ?v]]"
        let expectedUuid = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let value = try mentat.query(query: query)
            .bind(varName: "?e", toReference: aEntid)
            .runScalar()
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.asUUID(), expectedUuid)
    }

    func testValueForAttributeOfEntity() {
        let mentat = try! Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = report!.entid(forTempId: "a")!
        var value: TypedValue? = nil;
        XCTAssertNoThrow(value = try mentat.value(forAttribute: ":foo/long", ofEntity: aEntid))
        XCTAssertNotNil(value)
        assert(value?.asLong() == 25)
    }

    func testEntidForAttribute() {
        let mentat = try! Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)
        let entid = mentat.entidForAttribute(attribute: ":foo/long")
        assert(entid == 65540)
    }

    func testMultipleQueries() throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        let results1 = try mentat.query(query: "[:find ?x :where [?x _ _]]").run()
        XCTAssertNotNil(results1)

        let results2 = try mentat.query(query: "[:find ?x :where [_ _ ?x]]").run()
        XCTAssertNotNil(results2)
    }

    func testNestedQueries() throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        let results1 = try mentat.query(query: "[:find ?x :where [?x _ _]]").run()
        XCTAssertNotNil(results1)

        let results2 = try mentat.query(query: "[:find ?x :where [_ _ ?x]]").run()
        XCTAssertNotNil(results2)
    }

    func test3InProgressTransact() {
        let mentat = try! Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        XCTAssertNotNil(report)
    }

    func testInProgressRollback() {
        let mentat = try! Mentat.open()
        let (_, report) = self.populateWithTypesSchema(mentat: mentat)
        XCTAssertNotNil(report)
        let aEntid = report!.entid(forTempId: "a")!

        let preLongValue = try! mentat.value(forAttribute: ":foo/long", ofEntity: aEntid)
        XCTAssertEqual(25, preLongValue?.asLong())

        let inProgress = try! mentat.beginTransaction()
        XCTAssertNoThrow(try inProgress.transact(transaction: "[[:db/add \(aEntid) :foo/long 22]]"))
        XCTAssertNoThrow(try inProgress.rollback())

        let postLongValue = try! mentat.value(forAttribute: ":foo/long", ofEntity: aEntid)
        XCTAssertEqual(25, postLongValue?.asLong())

    }

    func testInProgressEntityBuilder() throws {
        let mentat = try Mentat.open()
        let (schemaReport, dataReport) = self.populateWithTypesSchema(mentat: mentat)
        let bEntid = dataReport!.entid(forTempId: "b")!
        let longEntid = schemaReport!.entid(forTempId: "l")!
        let stringEntid = schemaReport!.entid(forTempId: "s")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        // Check initial values
        let initialResult = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(initialResult)
        XCTAssertEqual(false, initialResult?.asBool(index: 0))

        let previousDate = formatter.date(from: "2018-01-01T11:00:00+00:00")
        XCTAssertEqual(previousDate, initialResult?.asDate(index: 1))

        let previousUuid = UUID(uuidString: "4cb3f828-752d-497a-90c9-b1fd516d5644")!
        XCTAssertEqual(previousUuid, initialResult?.asUUID(index: 2))

        XCTAssertEqual(50, initialResult?.asLong(index: 3))
        XCTAssertEqual(22.46, initialResult?.asDouble(index: 4))
        XCTAssertEqual("Silence is worse; all truths that are kept silent become poisonous.", initialResult?.asString(index: 5))
        XCTAssertEqual(":foo/string", initialResult?.asKeyword(index: 6))
        XCTAssertEqual(stringEntid, initialResult?.asEntid(index: 7))

        let builder = try mentat.entityBuilder()
        try builder.add(entid: bEntid, keyword: ":foo/boolean", boolean: true)
        let newDate = Date()
        try builder.add(entid: bEntid, keyword: ":foo/instant", date: newDate)
        let newUUID = UUID()
        try builder.add(entid: bEntid, keyword: ":foo/uuid", uuid: newUUID)
        try builder.add(entid: bEntid, keyword: ":foo/long", long: 75)
        try builder.add(entid: bEntid, keyword: ":foo/double", double: 81.3)
        try builder.add(entid: bEntid, keyword: ":foo/string", string: "Become who you are!")
        try builder.add(entid: bEntid, keyword: ":foo/keyword", keyword: ":foo/long")
        try builder.add(entid: bEntid, keyword: ":foo/ref", reference: longEntid)
        _ = try builder.commit()

        // test that the values have changed
        let result = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(result)
        XCTAssertEqual(true, result?.asBool(index: 0))
        XCTAssertEqual(formatter.string(from: newDate), formatter.string(from: result!.asDate(index: 1)))
        XCTAssertEqual(newUUID, result?.asUUID(index: 2))
        XCTAssertEqual(75, result?.asLong(index: 3))
        XCTAssertEqual(81.3, result?.asDouble(index: 4))
        XCTAssertEqual("Become who you are!", result?.asString(index: 5))
        XCTAssertEqual(":foo/long", result?.asKeyword(index: 6))
        XCTAssertEqual(longEntid, result?.asEntid(index: 7))
    }

    func testEntityBuilderForEntid() throws {
        let mentat = try Mentat.open()
        let (schemaReport, dataReport) = self.populateWithTypesSchema(mentat: mentat)
        let bEntid = dataReport!.entid(forTempId: "b")!
        let longEntid = schemaReport!.entid(forTempId: "l")!
        let stringEntid = schemaReport!.entid(forTempId: "s")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        // Check initial values
        let initialResult = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(initialResult)
        XCTAssertEqual(false, initialResult?.asBool(index: 0))

        let previousDate = formatter.date(from: "2018-01-01T11:00:00+00:00")
        XCTAssertEqual(previousDate, initialResult?.asDate(index: 1))

        let previousUuid = UUID(uuidString: "4cb3f828-752d-497a-90c9-b1fd516d5644")!
        XCTAssertEqual(previousUuid, initialResult?.asUUID(index: 2))

        XCTAssertEqual(50, initialResult?.asLong(index: 3))
        XCTAssertEqual(22.46, initialResult?.asDouble(index: 4))
        XCTAssertEqual("Silence is worse; all truths that are kept silent become poisonous.", initialResult?.asString(index: 5))
        XCTAssertEqual(":foo/string", initialResult?.asKeyword(index: 6))
        XCTAssertEqual(stringEntid, initialResult?.asEntid(index: 7))

        let builder = try mentat.entityBuilder(forEntid: bEntid)
        try builder.add(keyword: ":foo/boolean", boolean: true)
        let newDate = Date()
        try builder.add(keyword: ":foo/instant", date: newDate)
        let newUUID = UUID()
        try builder.add(keyword: ":foo/uuid", uuid: newUUID)
        try builder.add(keyword: ":foo/long", long: 75)
        try builder.add(keyword: ":foo/double", double: 81.3)
        try builder.add(keyword: ":foo/string", string: "Become who you are!")
        try builder.add(keyword: ":foo/keyword", keyword: ":foo/long")
        try builder.add(keyword: ":foo/ref", reference: longEntid)
        _ = try builder.commit()

        // test that the values have changed
        let result = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(result)
        XCTAssertEqual(true, result?.asBool(index: 0))
        XCTAssertEqual(formatter.string(from: newDate), formatter.string(from: result!.asDate(index: 1)))
        XCTAssertEqual(newUUID, result?.asUUID(index: 2))
        XCTAssertEqual(75, result?.asLong(index: 3))
        XCTAssertEqual(81.3, result?.asDouble(index: 4))
        XCTAssertEqual("Become who you are!", result?.asString(index: 5))
        XCTAssertEqual(":foo/long", result?.asKeyword(index: 6))
        XCTAssertEqual(longEntid, result?.asEntid(index: 7))
    }

    func testEntityBuilderForTempid() throws {
        let mentat = try Mentat.open()
        let (schemaReport, _) = self.populateWithTypesSchema(mentat: mentat)
        let longEntid = schemaReport!.entid(forTempId: "l")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        let builder = try mentat.entityBuilder(forTempId: "c")
        try builder.add(keyword: ":foo/boolean", boolean: true)
        let newDate = Date()
        try builder.add(keyword: ":foo/instant", date: newDate)
        let newUUID = UUID()
        try builder.add(keyword: ":foo/uuid", uuid: newUUID)
        try builder.add(keyword: ":foo/long", long: 75)
        try builder.add(keyword: ":foo/double", double: 81.3)
        try builder.add(keyword: ":foo/string", string: "Become who you are!")
        try builder.add(keyword: ":foo/keyword", keyword: ":foo/long")
        try builder.add(keyword: ":foo/ref", reference: longEntid)
        let report = try builder.commit()
        let cEntid = report.entid(forTempId: "c")!

        // test that the values have changed
        let result = try mentat.query(query: query).bind(varName: "?e", toReference: cEntid).runTuple()
        XCTAssertNotNil(result)
        XCTAssertEqual(true, result?.asBool(index: 0))
        XCTAssertEqual(formatter.string(from: newDate), formatter.string(from: result!.asDate(index: 1)))
        XCTAssertEqual(newUUID, result?.asUUID(index: 2))
        XCTAssertEqual(75, result?.asLong(index: 3))
        XCTAssertEqual(81.3, result?.asDouble(index: 4))
        XCTAssertEqual("Become who you are!", result?.asString(index: 5))
        XCTAssertEqual(":foo/long", result?.asKeyword(index: 6))
        XCTAssertEqual(longEntid, result?.asEntid(index: 7))
    }

    func testInProgressBuilderTransact() throws {
        let mentat = try Mentat.open()
        let (schemaReport, dataReport) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = dataReport!.entid(forTempId: "a")!
        let bEntid = dataReport!.entid(forTempId: "b")!
        let longEntid = schemaReport!.entid(forTempId: "l")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        let builder = try mentat.entityBuilder()
        try builder.add(entid: bEntid, keyword: ":foo/boolean", boolean: true)
        let newDate = Date()
        try builder.add(entid: bEntid, keyword: ":foo/instant", date: newDate)
        let newUUID = UUID()
        try builder.add(entid: bEntid, keyword: ":foo/uuid", uuid: newUUID)
        try builder.add(entid: bEntid, keyword: ":foo/long", long: 75)
        try builder.add(entid: bEntid, keyword: ":foo/double", double: 81.3)
        try builder.add(entid: bEntid, keyword: ":foo/string", string: "Become who you are!")
        try builder.add(entid: bEntid, keyword: ":foo/keyword", keyword: ":foo/long")
        try builder.add(entid: bEntid, keyword: ":foo/ref", reference: longEntid)
        let (inProgress, report) = try builder.transact()
        XCTAssertNotNil(report)
        _ = try inProgress.transact(transaction: "[[:db/add \(aEntid) :foo/long 22]]")
        try inProgress.commit()

        // test that the values have changed
        let result = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(result)
        XCTAssertEqual(true, result?.asBool(index: 0))
        XCTAssertEqual(formatter.string(from: newDate), formatter.string(from: result!.asDate(index: 1)))
        XCTAssertEqual(newUUID, result?.asUUID(index: 2))
        XCTAssertEqual(75, result?.asLong(index: 3))
        XCTAssertEqual(81.3, result?.asDouble(index: 4))
        XCTAssertEqual("Become who you are!", result?.asString(index: 5))
        XCTAssertEqual(":foo/long", result?.asKeyword(index: 6))
        XCTAssertEqual(longEntid, result?.asEntid(index: 7))

        let longValue = try mentat.value(forAttribute: ":foo/long", ofEntity: aEntid)
        XCTAssertEqual(22, longValue?.asLong())
    }

    func testEntityBuilderTransact() throws {
        let mentat = try Mentat.open()
        let (schemaReport, dataReport) = self.populateWithTypesSchema(mentat: mentat)
        let aEntid = dataReport!.entid(forTempId: "a")!
        let bEntid = dataReport!.entid(forTempId: "b")!
        let longEntid = schemaReport!.entid(forTempId: "l")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        let builder = try mentat.entityBuilder(forEntid: bEntid)
        try builder.add(keyword: ":foo/boolean", boolean: true)
        let newDate = Date()
        try builder.add(keyword: ":foo/instant", date: newDate)
        let newUUID = UUID()
        try builder.add(keyword: ":foo/uuid", uuid: newUUID)
        try builder.add(keyword: ":foo/long", long: 75)
        try builder.add(keyword: ":foo/double", double: 81.3)
        try builder.add(keyword: ":foo/string", string: "Become who you are!")
        try builder.add(keyword: ":foo/keyword", keyword: ":foo/long")
        try builder.add(keyword: ":foo/ref", reference: longEntid)
        let (inProgress, report) = try builder.transact()
        XCTAssertNotNil(report)
        _ = try inProgress.transact(transaction: "[[:db/add \(aEntid) :foo/long 22]]")
        try inProgress.commit()

        // test that the values have changed
        let result = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(result)
        XCTAssertEqual(true, result?.asBool(index: 0))
        XCTAssertEqual(formatter.string(from: newDate), formatter.string(from: result!.asDate(index: 1)))
        XCTAssertEqual(newUUID, result?.asUUID(index: 2))
        XCTAssertEqual(75, result?.asLong(index: 3))
        XCTAssertEqual(81.3, result?.asDouble(index: 4))
        XCTAssertEqual("Become who you are!", result?.asString(index: 5))
        XCTAssertEqual(":foo/long", result?.asKeyword(index: 6))
        XCTAssertEqual(longEntid, result?.asEntid(index: 7))

        let longValue = try mentat.value(forAttribute: ":foo/long", ofEntity: aEntid)
        XCTAssertEqual(22, longValue?.asLong())
    }

    func testEntityBuilderRetract() throws {
        let mentat = try Mentat.open()
        let (schemaReport, dataReport) = self.populateWithTypesSchema(mentat: mentat)
        let bEntid = dataReport!.entid(forTempId: "b")!
        let stringEntid = schemaReport!.entid(forTempId: "s")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let previousDate = formatter.date(from: "2018-01-01T11:00:00+00:00")!
        let previousUuid = UUID(uuidString: "4cb3f828-752d-497a-90c9-b1fd516d5644")!

        // Check initial values
        let initialResult = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(initialResult)
        XCTAssertEqual(false, initialResult?.asBool(index: 0))
        XCTAssertEqual(previousDate, initialResult?.asDate(index: 1))
        XCTAssertEqual(previousUuid, initialResult?.asUUID(index: 2))
        XCTAssertEqual(50, initialResult?.asLong(index: 3))
        XCTAssertEqual(22.46, initialResult?.asDouble(index: 4))
        XCTAssertEqual("Silence is worse; all truths that are kept silent become poisonous.", initialResult?.asString(index: 5))
        XCTAssertEqual(":foo/string", initialResult?.asKeyword(index: 6))
        XCTAssertEqual(stringEntid, initialResult?.asEntid(index: 7))

        let builder = try mentat.entityBuilder(forEntid: bEntid)
        try builder.retract(keyword: ":foo/boolean", boolean: false)
        try builder.retract(keyword: ":foo/instant", date: previousDate)
        try builder.retract(keyword: ":foo/uuid", uuid: previousUuid)
        try builder.retract(keyword: ":foo/long", long: 50)
        try builder.retract(keyword: ":foo/double", double: 22.46)
        try builder.retract(keyword: ":foo/string", string: "Silence is worse; all truths that are kept silent become poisonous.")
        try builder.retract(keyword: ":foo/keyword", keyword: ":foo/string")
        try builder.retract(keyword: ":foo/ref", reference: stringEntid)
        _ = try builder.commit()

        let result = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNil(result)
    }

    func testInProgressEntityBuilderRetract() throws {
        let mentat = try Mentat.open()
        let (schemaReport, dataReport) = self.populateWithTypesSchema(mentat: mentat)
        let bEntid = dataReport!.entid(forTempId: "b")!
        let stringEntid = schemaReport!.entid(forTempId: "s")!
        // test that the values are as expected
        let query = """
                    [:find [?b ?i ?u ?l ?d ?s ?k ?r]
                     :in ?e
                     :where [?e :foo/boolean ?b]
                            [?e :foo/instant ?i]
                            [?e :foo/uuid ?u]
                            [?e :foo/long ?l]
                            [?e :foo/double ?d]
                            [?e :foo/string ?s]
                            [?e :foo/keyword ?k]
                            [?e :foo/ref ?r]]
                    """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let previousDate = formatter.date(from: "2018-01-01T11:00:00+00:00")!
        let previousUuid = UUID(uuidString: "4cb3f828-752d-497a-90c9-b1fd516d5644")!

        // Check initial values
        let initialResult = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNotNil(initialResult)
        XCTAssertEqual(false, initialResult?.asBool(index: 0))
        XCTAssertEqual(previousDate, initialResult?.asDate(index: 1))
        XCTAssertEqual(previousUuid, initialResult?.asUUID(index: 2))
        XCTAssertEqual(50, initialResult?.asLong(index: 3))
        XCTAssertEqual(22.46, initialResult?.asDouble(index: 4))
        XCTAssertEqual("Silence is worse; all truths that are kept silent become poisonous.", initialResult?.asString(index: 5))
        XCTAssertEqual(":foo/string", initialResult?.asKeyword(index: 6))
        XCTAssertEqual(stringEntid, initialResult?.asEntid(index: 7))

        let builder = try mentat.entityBuilder()
        try builder.retract(entid: bEntid, keyword: ":foo/boolean", boolean: false)
        try builder.retract(entid: bEntid, keyword: ":foo/instant", date: previousDate)
        try builder.retract(entid: bEntid, keyword: ":foo/uuid", uuid: previousUuid)
        try builder.retract(entid: bEntid, keyword: ":foo/long", long: 50)
        try builder.retract(entid: bEntid, keyword: ":foo/double", double: 22.46)
        try builder.retract(entid: bEntid, keyword: ":foo/string", string: "Silence is worse; all truths that are kept silent become poisonous.")
        try builder.retract(entid: bEntid, keyword: ":foo/keyword", keyword: ":foo/string")
        try builder.retract(entid: bEntid, keyword: ":foo/ref", reference: stringEntid)
        _ = try builder.commit()

        let result = try mentat.query(query: query).bind(varName: "?e", toReference: bEntid).runTuple()
        XCTAssertNil(result)
    }

    func testCaching() throws {
        let query = """
                [:find ?district :where
                [?neighborhood :neighborhood/name \"Beacon Hill\"]
                [?neighborhood :neighborhood/district ?d]
                [?d :district/name ?district]]
                """

        let mentat = openAndInitializeCitiesStore()

        struct QueryTimer {
            private var _start: UInt64
            private var _end: UInt64

            init() {
                self._start = 0
                self._end = 0
            }

            private func currentTimeNanos() -> UInt64 {
                var info = mach_timebase_info()
                guard mach_timebase_info(&info) == KERN_SUCCESS else { return 0 }
                let currentTime = mach_absolute_time()
                return currentTime * UInt64(info.numer) / UInt64(info.denom)
            }


            mutating func start() {
                self._start = self.currentTimeNanos()
            }

            mutating func end() {
                self._end = self.currentTimeNanos()
            }

            func duration() -> UInt64 {
                return self._end - self._start
            }
        }

        var uncachedTimer = QueryTimer()
        uncachedTimer.start()
        let uncachedResult = try mentat.query(query: query).run()
        uncachedTimer.end()
        XCTAssertNotNil(uncachedResult)

        try mentat.cache(attribute: ":neighborhood/name", direction: CacheDirection.reverse)
        try mentat.cache(attribute: ":neighborhood/district", direction: CacheDirection.forward)

        var cachedTimer = QueryTimer()
        cachedTimer.start()
        let cachedResult = try mentat.query(query: query).run()
        cachedTimer.end()
        XCTAssertNotNil(cachedResult)

        let timingDifference = uncachedTimer.duration() - cachedTimer.duration()
        print("Cached query is \(timingDifference) nanoseconds faster than the uncached query")

        XCTAssertLessThan(cachedTimer.duration(), uncachedTimer.duration())
    }

    // TODO: Add tests for transaction observation

    // MARK: - AsyncSequence Tests

    @available(iOS 13.0, *)
    func testAsyncRelResultSequence() async throws {
        let mentat = openAndInitializeCitiesStore()
        let query = """
        [:find ?name ?cat
        :where
        [?c :community/name ?name]
        [?c :community/type :community.type/website]
        [(fulltext $ :community/category "food") [[?c ?cat]]]]
        """
        let rows = try mentat.query(query: query).run()
        XCTAssertNotNil(rows)

        // Test async iteration using for await
        var count = 0
        for await row in rows!.async {
            XCTAssertNotNil(row.asString(index: 0))
            XCTAssertNotNil(row.asString(index: 1))
            count += 1
        }
        XCTAssertEqual(count, 4)
    }

    @available(iOS 13.0, *)
    func testAsyncColResultSequence() async throws {
        let mentat = openAndInitializeCitiesStore()
        let query = "[:find [?when ...] :where [_ :db/txInstant ?when] :order (asc ?when)]"
        let coll = try mentat.query(query: query).runColl()
        XCTAssertNotNil(coll)

        // Test async iteration using for await
        var count = 0
        for await value in coll!.async {
            // Each value should be a date (instant)
            XCTAssertNotNil(value.asDate())
            count += 1
        }
        XCTAssertEqual(count, 3)
    }

    @available(iOS 13.0, *)
    func testAsyncRelResultSequenceWithBinding() async throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        let query = "[:find ?e ?v :where [?e :foo/long ?v]]"
        let rows = try mentat.query(query: query).run()
        XCTAssertNotNil(rows)

        var results: [(Entid, Int64)] = []
        for await row in rows!.async {
            let entid = row.asEntid(index: 0)
            let value = row.asLong(index: 1)
            results.append((entid, value))
        }

        // We should have 2 results from populateWithTypesSchema (a and b entities)
        XCTAssertEqual(results.count, 2)
        // Values should be 25 and 50
        let values = Set(results.map { $0.1 })
        XCTAssertTrue(values.contains(25))
        XCTAssertTrue(values.contains(50))
    }

    @available(iOS 13.0, *)
    func testAsyncColResultSequenceMultipleTypes() async throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        let query = "[:find [?v ...] :where [_ :foo/string ?v]]"
        let coll = try mentat.query(query: query).runColl()
        XCTAssertNotNil(coll)

        var strings: [String] = []
        for await value in coll!.async {
            strings.append(value.asString())
        }

        XCTAssertEqual(strings.count, 2)
        XCTAssertTrue(strings.contains("The higher we soar the smaller we appear to those who cannot fly."))
        XCTAssertTrue(strings.contains("Silence is worse; all truths that are kept silent become poisonous."))
    }

    // MARK: - Edge Case Tests

    @available(iOS 13.0, *)
    func testAsyncEmptyRelResult() async throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        // Query that returns no results
        let query = "[:find ?e :where [?e :foo/long 999999]]"
        let rows = try mentat.query(query: query).run()
        XCTAssertNotNil(rows)

        var count = 0
        for await _ in rows!.async {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }

    @available(iOS 13.0, *)
    func testAsyncEmptyColResult() async throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        // Query that returns no results
        let query = "[:find [?v ...] :where [_ :foo/long ?v] [(> ?v 1000000)]]"
        let coll = try mentat.query(query: query).runColl()

        // Result may be nil or empty for no matches
        if let result = coll {
            var count = 0
            for await _ in result.async {
                count += 1
            }
            XCTAssertEqual(count, 0)
        }
    }

    @available(iOS 13.0, *)
    func testAsyncNilScalarResult() async throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        // Query that returns no scalar result
        let query = "[:find ?v . :where [_ :foo/long ?v] [(> ?v 1000000)]]"
        let value = try mentat.query(query: query).runScalar()
        XCTAssertNil(value)
    }

    @available(iOS 13.0, *)
    func testAsyncNilTupleResult() async throws {
        let mentat = try Mentat.open()
        let _ = self.populateWithTypesSchema(mentat: mentat)

        // Query that returns no tuple result
        let query = "[:find [?e ?v] :where [?e :foo/long ?v] [(> ?v 1000000)]]"
        let tuple = try mentat.query(query: query).runTuple()
        XCTAssertNil(tuple)
    }
}
