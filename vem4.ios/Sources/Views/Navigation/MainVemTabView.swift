import SwiftUI

// MARK: - Main 5-Tab Navigation & Global Sheets for Viple & Moi

public struct MainVemTabView: View {
    @Bindable var store: VemStoreViewModel

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                DashboardHomeView(store: store)
            }
            .tabItem {
                Label("Accueil", systemImage: "sparkles.rectangle.stack.fill")
            }
            .tag(VemTab.home)

            NavigationStack {
                ServicesHubView(store: store)
            }
            .tabItem {
                Label("Services", systemImage: "square.stack.3d.up.fill")
            }
            .tag(VemTab.services)

            NavigationStack {
                FamilyHouseholdView(store: store)
            }
            .tabItem {
                Label("Famille", systemImage: "person.3.fill")
            }
            .badge(store.pendingRequestsCount)
            .tag(VemTab.family)

            NavigationStack {
                BillingAndInvoicesView(store: store)
            }
            .tabItem {
                Label("Factures", systemImage: "creditcard.and.123")
            }
            .tag(VemTab.billing)

            NavigationStack {
                AccountAndHelpHubView(store: store)
            }
            .tabItem {
                Label("Compte & Aide", systemImage: "person.crop.circle.badge.questionmark")
            }
            .tag(VemTab.more)
        }
        .tint(VemTheme.vipleEmerald)
        // Service Detail Cockpit Sheet
        .sheet(
            isPresented: Binding(
                get: { store.activeServiceDetailID != nil },
                set: { if !$0 { store.activeServiceDetailID = nil } }
            )
        ) {
            if let sid = store.activeServiceDetailID, let svc = store.subscription(withID: sid) {
                ServiceDetailSheet(store: store, subscriptionId: svc.id)
            }
        }
        // Boutique 1-Tap Order Sheet
        .sheet(item: $store.orderingProduct) { product in
            BoutiqueOrderSheet(store: store, product: product)
        }
        // Certified 2D-DOC Invoice Viewer Sheet
        .sheet(item: $store.selectedInvoiceForDetail) { invoice in
            CertifiedInvoiceSheet(store: store, invoice: invoice)
        }
        // Livria Store & Viple Delivery Parcel Tracking Sheet
        .sheet(isPresented: $store.showOrdersSheet) {
            NavigationStack {
                OrdersAndDeliveryView(store: store, isPresentedModally: true)
            }
        }
        // Embedded Customer Course (guide-espace-client-v4) Sheet
        .sheet(isPresented: $store.showGuideSheet) {
            NavigationStack {
                NativeClientGuideView(store: store, isPresentedModally: true)
            }
        }
    }
}
