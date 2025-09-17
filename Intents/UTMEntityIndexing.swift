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

import Foundation
import AppIntents
import CoreSpotlight

enum UTMEntityIndexer {
    /// Rebuild the Spotlight index for all VM entities (macOS 15+/iOS 18+).
    @MainActor
    static func reindexAll(with data: UTMData) async {
        guard #available(iOS 18, macOS 15, tvOS 18, watchOS 11, *) else {
            return
        }
        let entities: [UTMVirtualMachineEntity] = data.virtualMachines.map { UTMVirtualMachineEntity(from: $0) }
        do {
            let index = CSSearchableIndex.default()
            try await index.deleteAppEntities(ofType: UTMVirtualMachineEntity.self)
            if !entities.isEmpty {
                try await index.indexAppEntities(entities)
                logger.debug("[Indexing] Indexed \(entities.count) VM entities for Spotlight")
            } else {
                logger.debug("[Indexing] Cleared VM entity index (no entities)")
            }
        } catch {
            logger.error("[Indexing] Failed to (re)index VM entities: \(error.localizedDescription)")
        }
    }
}

