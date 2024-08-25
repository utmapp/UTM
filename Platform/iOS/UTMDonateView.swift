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

import SwiftUI
import StoreKit

struct UTMDonateView: View {
    @Environment(\.presentationMode) var presentationMode

    private var appIcon: String? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconFileName = iconFiles.last else {
            return nil
        }
        return iconFileName
    }

    var body: some View {
        NavigationView {
            VStack {
                if let appIcon = appIcon, let image = UIImage(named: appIcon) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12.632, style: .continuous))
                        .frame(width: 72, height: 72)
                }
                Text("Your support is the driving force that helps UTM stay independent. Your contribution, no matter the size, makes a significant difference. It enables us to develop new features and maintain existing ones. Thank you for considering a donation to support us.")
                    .padding()
                if #available(iOS 15, *) {
                    StoreView()
                } else {
                    List {
                        Link("GitHub Sponsors", destination: URL(string: "https://github.com/sponsors/utmapp")!)
                    }
                }
            }.navigationTitle("Support UTM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }.navigationViewStyle(.stack)
    }
}

@available(iOS 15, *)
private struct StoreView: View {
    @StateObject private var store = UTMDonateStore()

    var body: some View {
        if !store.isLoaded {
            ProgressView()
            Spacer()
        } else {
            List {
                if !store.consumables.isEmpty {
                    Section("One Time Donation") {
                        ForEach(store.consumables) { item in
                            ListCellView(store: store, product: item)
                        }
                    }
                    .listStyle(.grouped)
                }
                if !store.subscriptions.isEmpty {
                    Section("Recurring Donation") {
                        ForEach(store.subscriptions) { item in
                            ListCellView(store: store, product: item)
                        }
                        Link("Manage Subscriptions…", destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!)
                    }
                    .listStyle(.grouped)
                }
                if store.consumables.isEmpty && store.subscriptions.isEmpty {
                    Link("GitHub Sponsors", destination: URL(string: "https://github.com/sponsors/utmapp")!)
                } else if !store.subscriptions.isEmpty {
                    Button("Restore Purchases") {
                        Task {
                            try? await AppStore.sync()
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 15, *)
private struct ListCellView: View {
    @ObservedObject var store: UTMDonateStore
    @State var isPurchased: Bool = false
    @State var errorTitle = ""
    @State var isShowingError: Bool = false
    @State var isLoaded: Bool = false

    #if os(visionOS)
    @Environment(\.purchase) var purchase
    #endif

    let product: Product
    let purchasingEnabled: Bool

    var systemImage: String? {
        store.productImages[product.id]
    }

    init(store: UTMDonateStore, product: Product, purchasingEnabled: Bool = true) {
        self.store = store
        self.product = product
        self.purchasingEnabled = purchasingEnabled
    }

    var body: some View {
        HStack {
            Image(systemName: systemImage ?? "heart.fill")
                .font(.system(size: 36))
                .frame(width: 48, height: 48)
                .padding(.trailing, 20)
            if purchasingEnabled {
                productDetail
                Spacer()
                buyButton
                    .buttonStyle(BuyButtonStyle(isPurchased: isPurchased))
                    .disabled(isPurchased)
            } else {
                productDetail
            }
        }
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("OK")))
        })
    }

    @ViewBuilder
    var productDetail: some View {
        VStack(alignment: .leading) {
            Text(product.displayName)
                .bold()
            Text(product.description)
        }
    }

    func subscribeButton(_ subscription: Product.SubscriptionInfo) -> some View {
        let unit: String
        let plural = 1 < subscription.subscriptionPeriod.value
            switch subscription.subscriptionPeriod.unit {
        case .day:
                unit = plural ? String.localizedStringWithFormat(NSLocalizedString("%d days", comment: "UTMDonateView"), subscription.subscriptionPeriod.value) : NSLocalizedString("day", comment: "UTMDonateView")
        case .week:
            unit = plural ? String.localizedStringWithFormat(NSLocalizedString("%d weeks", comment: "UTMDonateView"), subscription.subscriptionPeriod.value) : NSLocalizedString("week", comment: "UTMDonateView")
        case .month:
            unit = plural ? String.localizedStringWithFormat(NSLocalizedString("%d months", comment: "UTMDonateView"), subscription.subscriptionPeriod.value) : NSLocalizedString("month", comment: "UTMDonateView")
        case .year:
            unit = plural ? String.localizedStringWithFormat(NSLocalizedString("%d years", comment: "UTMDonateView"), subscription.subscriptionPeriod.value) : NSLocalizedString("year", comment: "UTMDonateView")
        @unknown default:
            unit = NSLocalizedString("period", comment: "UTMDonateView")
        }

        return VStack {
            Text(product.displayPrice)
                .foregroundColor(.white)
                .bold()
                .padding(EdgeInsets(top: -4.0, leading: 0.0, bottom: -8.0, trailing: 0.0))
            Divider()
                .background(Color.white)
            Text(unit)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .padding(EdgeInsets(top: -8.0, leading: 0.0, bottom: -4.0, trailing: 0.0))
        }
    }

    var buyButton: some View {
        Button(action: {
            Task {
                await buy()
            }
        }) {
            if !isLoaded {
                ProgressView()
                    .tint(.white)
            } else if isPurchased {
                Text(Image(systemName: "checkmark"))
                    .bold()
                    .foregroundColor(.white)
            } else {
                if let subscription = product.subscription {
                    subscribeButton(subscription)
                } else {
                    Text(product.displayPrice)
                        .foregroundColor(.white)
                        .bold()
                }
            }
        }
        .onAppear {
            Task {
                isPurchased = (try? await store.isPurchased(product)) ?? false
                isLoaded = true
            }
        }
        .onChange(of: store.purchasedSubscriptions) { _ in
            Task {
                isPurchased = (try? await store.isPurchased(product)) ?? false
            }
        }
    }

    func buy() async {
        do {
            if try await store.purchase(with: {
                #if os(visionOS)
                try await purchase(product)
                #else
                try await product.purchase()
                #endif
            }) != nil {
                withAnimation {
                    isPurchased = true
                }
            }
        } catch UTMDonateStore.StoreError.failedVerification {
            errorTitle = NSLocalizedString("Your purchase could not be verified by the App Store.", comment: "UTMDonateView")
            isShowingError = true
        } catch {
            logger.error("Failed purchase for \(product.id): \(error)")
        }
    }
}

private struct BuyButtonStyle: ButtonStyle {
    let isPurchased: Bool

    init(isPurchased: Bool = false) {
        self.isPurchased = isPurchased
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        var bgColor: Color = isPurchased ? Color.green : Color.blue
        bgColor = configuration.isPressed ? bgColor.opacity(0.7) : bgColor.opacity(1)

        return configuration.label
            .frame(width: 50)
            .padding(10)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    UTMDonateView()
}
