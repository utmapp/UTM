//
// Copyright © 2025 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import AppIntents

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
struct UTMVirtualMachineEntityQuery: EntityQuery, EntityStringQuery {
    @Dependency
    var data: UTMData

    func entities(for identifiers: [UUID]) async throws -> [UTMVirtualMachineEntity] {
        await MainActor.run {
            data
                .virtualMachines
                .filter({ identifiers.contains($0.id) })
                .map({ UTMVirtualMachineEntity(from: $0) })
        }
    }

    func entities(matching: String) async throws -> [UTMVirtualMachineEntity] {
        await MainActor.run {
            data
                .virtualMachines
                .filter({ $0.detailsTitleLabel.localizedCaseInsensitiveContains(matching) })
                .map({ UTMVirtualMachineEntity(from: $0) })
        }
    }

    func suggestedEntities() async throws -> [UTMVirtualMachineEntity] {
        await MainActor.run {
            data
                .virtualMachines
                .map({ UTMVirtualMachineEntity(from: $0) })
        }
    }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension UTMVirtualMachineEntityQuery: EntityPropertyQuery {

    /**
     The type of the comparator to use for the property query. This sample uses `Predicate`, but other apps could use `NSPredicate` (for
     Core Data) or an entirely custom comparator that works with an existing data model.
     */
    typealias ComparatorMappingType = Predicate<UTMVirtualMachineEntity>

    /**
     Declare the entity properties that are available for queries and in the Find intent, along with the comparator the app uses when querying the
     property.
     */
    static let properties = QueryProperties {
        Property(\UTMVirtualMachineEntity.$name) {
            ContainsComparator { searchValue in
                #Predicate<UTMVirtualMachineEntity> { $0.name.localizedStandardContains(searchValue) }
            }
            EqualToComparator { searchValue in
                #Predicate<UTMVirtualMachineEntity> { $0.name == searchValue }
            }
            NotEqualToComparator { searchValue in
                #Predicate<UTMVirtualMachineEntity> { $0.name != searchValue }
            }
        }
        Property(\UTMVirtualMachineEntity.$state) {
            EqualToComparator { searchValue in
                #Predicate<UTMVirtualMachineEntity> { $0.state == searchValue }
            }
            NotEqualToComparator { searchValue in
                #Predicate<UTMVirtualMachineEntity> { $0.state != searchValue }
            }
        }
    }

    /// Declare the entity properties available as sort criteria in the Find intent.
    static let sortingOptions = SortingOptions {
        SortableBy(\UTMVirtualMachineEntity.$name)
    }

    /// The text that people see in the Shortcuts app, describing what this intent does.
    static var findIntentDescription: IntentDescription? {
        IntentDescription("Search for a virtual machine.",
                          searchKeywords: ["virtual machine", "vm"],
                          resultValueName: "Virtual Machines")
    }

    /// Performs the Find intent using the predicates that the individual enters in the Shortcuts app.
    func entities(matching comparators: [Predicate<UTMVirtualMachineEntity>],
                  mode: ComparatorMode,
                  sortedBy: [EntityQuerySort<UTMVirtualMachineEntity>],
                  limit: Int?) async throws -> [UTMVirtualMachineEntity] {

        logger.debug("[UTMVirtualMachineEntityQuery] Property query started")

        /// Get the trail entities that meet the criteria of the comparators.
        var matchedVms = try await virtualMachines(matching: comparators, mode: mode)

        /**
         Apply the requested sort. `EntityQuerySort` specifies the value to sort by using a `PartialKeyPath`. This key path builds a
         `KeyPathComparator` to use default sorting implementations for the value that the key path provides. For example, this approach uses
         `SortComparator.localizedStandard` when sorting key paths with a `String` value.
         */
        logger.debug("[UTMVirtualMachineEntityQuery] Sorting results")
        for sortOperation in sortedBy {
            switch sortOperation.by {
            case \.$name:
                matchedVms.sort(using: KeyPathComparator(\UTMVirtualMachineEntity.name, order: sortOperation.order.sortOrder))
            default:
                break
            }
        }

        /**
         People can optionally customize a limit to the number of results that a query returns.
         If your data model supports query limits, you can also use the limit parameter when querying
         your data model, to allow for faster searches.
         */
        if let limit, matchedVms.count > limit {
            logger.debug("[UTMVirtualMachineEntityQuery] Limiting results to \(limit)")
            matchedVms.removeLast(matchedVms.count - limit)
        }

        logger.debug("[UTMVirtualMachineEntityQuery] Property query complete")
        return matchedVms
    }

    /// - Returns: The trail entities that meet the criteria of `comparators` and `mode`.
    @MainActor
    private func virtualMachines(matching comparators: [Predicate<UTMVirtualMachineEntity>], mode: ComparatorMode) throws -> [UTMVirtualMachineEntity] {
        try data.virtualMachines.compactMap { vm in
            let entity = UTMVirtualMachineEntity(from: vm)

            /**
             For an AND search (criteria1 AND criteria2 AND ...), this variable starts as `true`.
             If any of the comparators don't match, the app sets it to `false`, allowing the comparator loop to break early because a comparator
             doesn't satisfy the AND requirement.

             For an OR search (criteria1 OR criteria2 OR ...), this variable starts as `false`.
             If any of the comparators match, the app sets it to `true`, allowing the comparator loop to break early because any comparator that
             matches satisfies the OR requirement.
             */
            var includeAsResult = mode == .and ? true : false
            let earlyBreakCondition = includeAsResult
            logger.debug("[UTMVirtualMachineEntityQuery] Starting to evaluate predicates for \(entity.name)")
            for comparator in comparators {
                guard includeAsResult == earlyBreakCondition else {
                    logger.debug("[UTMVirtualMachineEntityQuery] Predicates matched? \(includeAsResult)")
                    break
                }

                /// Runs the `Predicate` expression with the specific `TrailEntity` to determine whether the entity matches the conditions.
                includeAsResult = try comparator.evaluate(entity)
            }

            logger.debug("[UTMVirtualMachineEntityQuery] Predicates matched? \(includeAsResult)")
            return includeAsResult ? entity : nil
        }
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
private extension EntityQuerySort.Ordering {
    /// Convert sort information from `EntityQuerySort` to  Foundation's `SortOrder`.
    var sortOrder: SortOrder {
        switch self {
        case .ascending:
            return SortOrder.forward
        case .descending:
            return SortOrder.reverse
        }
    }
}
