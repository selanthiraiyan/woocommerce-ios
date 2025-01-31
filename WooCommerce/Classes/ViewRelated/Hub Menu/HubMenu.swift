import SwiftUI
import Kingfisher
import Yosemite

/// This view will be embedded inside the `HubMenuViewController`
/// and will be the entry point of the `Menu` Tab.
///
struct HubMenu: View {
    @ObservedObject private var viewModel: HubMenuViewModel
    @State private var showingWooCommerceAdmin = false
    @State private var showingViewStore = false
    @State private var showingReviews = false
    @State private var showingCoupons = false

    init(siteID: Int64, navigationController: UINavigationController? = nil) {
        viewModel = HubMenuViewModel(siteID: siteID, navigationController: navigationController)
    }

    var body: some View {
        VStack {
            TopBar(avatarURL: viewModel.avatarURL,
                   storeTitle: viewModel.storeTitle,
                   storeURL: viewModel.storeURL.absoluteString) {
                viewModel.presentSwitchStore()
            }
                   .padding([.leading, .trailing], Constants.padding)

            ScrollView {
                let gridItemLayout = [GridItem(.adaptive(minimum: Constants.itemSize), spacing: Constants.itemSpacing)]

                LazyVGrid(columns: gridItemLayout, spacing: Constants.itemSpacing) {
                    ForEach(viewModel.menuElements, id: \.self) { menu in
                        // Currently the badge is always zero, because we are not handling push notifications count
                        // correctly due to the first behavior described here p91TBi-66O:
                        // AppDelegate’s `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
                        // can be called twice for the same push notification when receiving it
                        // and tapping on it to open the app. This means that some push notifications are incrementing the badge number by 2, and some by 1.
                        HubMenuElement(image: menu.icon, imageColor: menu.iconColor, text: menu.title, badge: 0, onTapGesture: {
                            switch menu {
                            case .woocommerceAdmin:
                                ServiceLocator.analytics.track(.hubMenuOptionTapped, withProperties: [Constants.option: "admin_menu"])
                                showingWooCommerceAdmin = true
                            case .viewStore:
                                ServiceLocator.analytics.track(.hubMenuOptionTapped, withProperties: [Constants.option: "view_store"])
                                showingViewStore = true
                            case .reviews:
                                ServiceLocator.analytics.track(.hubMenuOptionTapped, withProperties: [Constants.option: "reviews"])
                                showingReviews = true
                            case .coupons:
                                ServiceLocator.analytics.track(.hubMenuOptionTapped, withProperties: [Constants.option: "coupons"])
                                showingCoupons = true
                            }
                        })
                    }
                    .background(Color(.listForeground))
                    .cornerRadius(Constants.cornerRadius)
                    .padding([.bottom], Constants.padding)
                }
                .padding(Constants.padding)
                .background(Color(.listBackground))
            }
            .safariSheet(isPresented: $showingWooCommerceAdmin, url: viewModel.woocommerceAdminURL)
            .safariSheet(isPresented: $showingViewStore, url: viewModel.storeURL)
            NavigationLink(destination:
                            ReviewsView(siteID: viewModel.siteID),
                           isActive: $showingReviews) {
                EmptyView()
            }.hidden()
            NavigationLink(destination: CouponListView(siteID: viewModel.siteID), isActive: $showingCoupons) {
                EmptyView()
            }.hidden()
            LazyNavigationLink(destination: viewModel.getReviewDetailDestination(), isActive: $viewModel.showingReviewDetail) {
                EmptyView()
            }
        }
        .navigationBarHidden(true)
        .background(Color(.listBackground).edgesIgnoringSafeArea(.all))
    }

    func pushReviewDetailsView(using parcel: ProductReviewFromNoteParcel) {
        viewModel.showReviewDetails(using: parcel)
    }

    private struct TopBar: View {
        let avatarURL: URL?
        let storeTitle: String
        let storeURL: String?
        var switchStoreHandler: (() -> Void)?

        @State private var showSettings = false
        @ScaledMetric var settingsSize: CGFloat = 28
        @ScaledMetric var settingsIconSize: CGFloat = 20

        var body: some View {
            HStack(spacing: Constants.padding) {
                if let avatarURL = avatarURL {
                    VStack {
                        KFImage(avatarURL)
                            .resizable()
                            .clipShape(Circle())
                            .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                        Spacer()
                    }
                    .fixedSize()
                }

                VStack(alignment: .leading,
                       spacing: Constants.topBarSpacing) {
                    Text(storeTitle)
                        .headlineStyle()
                        .lineLimit(1)
                    if let storeURL = storeURL {
                        Text(storeURL)
                            .subheadlineStyle()
                            .lineLimit(1)
                    }
                    Button(Localization.switchStore) {
                        switchStoreHandler?()
                    }
                    .linkStyle()
                }
                Spacer()
                VStack {
                    Button {
                        ServiceLocator.analytics.track(.hubMenuSettingsTapped)
                        showSettings = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(UIColor(light: .white,
                                                    dark: .secondaryButtonBackground)))
                                .frame(width: settingsSize,
                                       height: settingsSize)
                            if let cogImage = UIImage.cogImage.imageWithTintColor(.accent) {
                                Image(uiImage: cogImage)
                                    .resizable()
                                    .frame(width: settingsIconSize,
                                           height: settingsIconSize)
                            }
                        }
                    }
                    Spacer()
                }
                .fixedSize()
            }
            .padding([.top, .leading, .trailing], Constants.padding)

            NavigationLink(destination:
                            SettingsView(),
                           isActive: $showSettings) {
                EmptyView()
            }.hidden()
        }
    }

    private enum Constants {
        static let cornerRadius: CGFloat = 10
        static let itemSpacing: CGFloat = 12
        static let itemSize: CGFloat = 160
        static let padding: CGFloat = 16
        static let topBarSpacing: CGFloat = 2
        static let avatarSize: CGFloat = 40
        static let option = "option"
    }

    private enum Localization {
        static let switchStore = NSLocalizedString("Switch store",
                                                   comment: "Switch store option in the hub menu")
    }
}

struct HubMenu_Previews: PreviewProvider {
    static var previews: some View {
        HubMenu(siteID: 123)
            .environment(\.colorScheme, .light)

        HubMenu(siteID: 123)
            .environment(\.colorScheme, .dark)

        HubMenu(siteID: 123)
            .previewLayout(.fixed(width: 312, height: 528))
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

        HubMenu(siteID: 123)
            .previewLayout(.fixed(width: 1024, height: 768))
    }
}
