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

public enum QueryError: Error, Sendable {
    case invalidKeyword(message: String)
    case executionFailed(message: String)
}

public struct MentatError: Error, Sendable {
    let message: String
}

public enum PointerError: Error, Sendable {
    case pointerConsumed
}

public enum ResultError: Error, Sendable {
    case error(message: String)
    case empty
}
