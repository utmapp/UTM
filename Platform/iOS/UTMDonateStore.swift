//
// Copyright © 2024 osy. All rights reserved.
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
import StoreKit

@available(iOS 15, *)
class UTMDonateStore: ObservableObject {
    typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

    enum StoreError: Error {
        case failedVerification
    }

    let productImages: [String: String] = [
        "consumable.small": "switch.2",
        "consumable.medium": "memorychip",
        "consumable.large": "pc",
        "subscription.small": "sum",
        "subscription.medium": "function",
        "subscription.large": "opticaldisc",
    ]

    @Published private(set) var consumables: [Product]
    @Published private(set) var subscriptions: [Product]

    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?

    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var id: UUID = UUID()

    var updateListenerTask: Task<Void, Error>? = nil

    init() {
        //Initialize empty products, and then do a product request asynchronously to fill them in.
        consumables = []
        subscriptions = []

        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            //During store initialization, request products from the App Store.
            await requestProducts()

            //Deliver products that the customer purchases.
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    //Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    logger.error("Transaction failed verification")
                }
            }
        }
    }

    @MainActor
    func requestProducts() async {
        isLoaded = false
        do {
            let storeProducts = try await Product.products(for: productImages.keys)

            var newConsumables: [Product] = []
            var newSubscriptions: [Product] = []

            //Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    newConsumables.append(product)
                case .autoRenewable:
                    newSubscriptions.append(product)
                default:
                    //Ignore this product.
                    logger.error("Unknown product: \(product)")
                }
            }

            //Sort each product category by price, lowest to highest, to update the store.
            consumables = sortByPrice(newConsumables)
            subscriptions = sortByPrice(newSubscriptions)
        } catch {
            logger.error("Failed product request from the App Store server: \(error)")
        }
        isLoaded = true
    }

    func purchase(with action: () async throws -> Product.PurchaseResult) async throws -> Transaction? {
        //Begin purchasing the `Product` the user selects.
        let result = try await action()

        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try checkVerified(verification)

            //The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()

            //Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    func isPurchased(_ product: Product) async throws -> Bool {
        //Determine whether the user purchases a given product.
        switch product.type {
        case .autoRenewable:
            return purchasedSubscriptions.contains(product)
        default:
            return false
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }

    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []

        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)

                //Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                default:
                    break
                }
            } catch {
                logger.error("failed to update product status: \(error)")
            }
        }

        //Update the store information with auto-renewable subscription products.
        self.purchasedSubscriptions = purchasedSubscriptions

        //Check the `subscriptionGroupStatus` to learn the auto-renewable subscription state to determine whether the customer
        //is new (never subscribed), active, or inactive (expired subscription). This app has only one subscription
        //group, so products in the subscriptions array all belong to the same group. The statuses that
        //`product.subscription.status` returns apply to the entire subscription group.
        subscriptionGroupStatus = try? await subscriptions.first?.subscription?.status.first?.state
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }
}
