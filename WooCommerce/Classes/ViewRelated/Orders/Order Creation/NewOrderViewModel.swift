import Yosemite
import Combine
import protocol Storage.StorageManagerType

/// View model for `NewOrder`.
///
final class NewOrderViewModel: ObservableObject {
    let siteID: Int64
    private let stores: StoresManager
    private let storageManager: StorageManagerType

    /// Order details used to create the order
    ///
    @Published var orderDetails = OrderDetails()

    /// Active navigation bar trailing item.
    /// Defaults to no visible button.
    ///
    @Published private(set) var navigationTrailingItem: NavigationItem = .none

    /// Tracks if a network request is being performed.
    ///
    @Published private(set) var performingNetworkRequest = false

    /// Defines the current notice that should be shown.
    /// Defaults to `nil`.
    ///
    @Published var presentNotice: NewOrderNotice?

    // MARK: Status properties

    /// Order creation date. For new order flow it's always current date.
    ///
    let dateString: String = {
        DateFormatter.mediumLengthLocalizedDateFormatter.string(from: Date())
    }()

    /// Representation of order status display properties.
    ///
    @Published private(set) var statusBadgeViewModel: StatusBadgeViewModel = .init(orderStatusEnum: .pending)

    /// Indicates if the order status list (selector) should be shown or not.
    ///
    @Published var shouldShowOrderStatusList: Bool = false

    /// Assign this closure to be notified when a new order is created
    ///
    var onOrderCreated: (Order) -> Void = { _ in }

    /// Status Results Controller.
    ///
    private lazy var statusResultsController: ResultsController<StorageOrderStatus> = {
        let predicate = NSPredicate(format: "siteID == %lld", siteID)
        let descriptor = NSSortDescriptor(key: "slug", ascending: true)
        let resultsController = ResultsController<StorageOrderStatus>(storageManager: storageManager, matching: predicate, sortedBy: [descriptor])

        do {
            try resultsController.performFetch()
        } catch {
            DDLogError("⛔️ Error fetching order statuses: \(error)")
        }

        return resultsController
    }()

    /// Order statuses list
    ///
    private var currentSiteStatuses: [OrderStatus] {
        return statusResultsController.fetchedObjects
    }

    // MARK: Products properties

    /// View model for the product list
    ///
    lazy var addProductViewModel = {
        AddProductToOrderViewModel(siteID: siteID, storageManager: storageManager, stores: stores) { [weak self] product in
            guard let self = self else { return }
            self.addProductToOrder(product)
        }
    }()

    /// View models for each product row in the order
    ///
    var productRows: [ProductRowViewModel] = []

    init(siteID: Int64, stores: StoresManager = ServiceLocator.stores, storageManager: StorageManagerType = ServiceLocator.storageManager) {
        self.siteID = siteID
        self.stores = stores
        self.storageManager = storageManager

        configureNavigationTrailingItem()
        configureStatusBadgeViewModel()
    }

    // MARK: - API Requests
    /// Creates an order remotely using the provided order details.
    ///
    func createOrder() {
        performingNetworkRequest = true

        let action = OrderAction.createOrder(siteID: siteID, order: orderDetails.toOrder()) { [weak self] result in
            guard let self = self else { return }
            self.performingNetworkRequest = false

            switch result {
            case .success(let newOrder):
                // TODO: Handle newly created order / remove success logging
                DDLogInfo("New order created successfully!")
                self.onOrderCreated(newOrder)
            case .failure(let error):
                self.presentNotice = .error
                DDLogError("⛔️ Error creating new order: \(error)")
            }
        }
        stores.dispatch(action)
    }
}

// MARK: - Types
extension NewOrderViewModel {
    /// Representation of possible navigation bar trailing buttons
    ///
    enum NavigationItem: Equatable {
        case none
        case create
        case loading
    }

    /// Type to hold all order detail values
    ///
    struct OrderDetails {
        var status: OrderStatusEnum = .pending
        var items: [OrderItem] = []
        var billingAddress: Address?
        var shippingAddress: Address?

        /// Used to create `Order` and check if order details have changed from empty/default values.
        /// Required because `Order` has `Date` properties that have to be the same to be Equatable.
        ///
        let emptyOrder = Order.empty

        func toOrder() -> Order {
            emptyOrder.copy(status: status,
                            items: items,
                            billingAddress: billingAddress,
                            shippingAddress: shippingAddress)
        }
    }

    /// Representation of possible notices that can be displayed
    ///
    enum NewOrderNotice {
        case error
    }

    /// Representation of order status display properties
    ///
    struct StatusBadgeViewModel {
        let title: String
        let color: UIColor

        init(orderStatus: OrderStatus) {
            title = orderStatus.name ?? orderStatus.slug
            color = {
                switch orderStatus.status {
                case .pending, .completed, .cancelled, .refunded, .custom:
                    return .gray(.shade5)
                case .onHold:
                    return .withColorStudio(.orange, shade: .shade5)
                case .processing:
                    return .withColorStudio(.green, shade: .shade5)
                case .failed:
                    return .withColorStudio(.red, shade: .shade5)
                }
            }()
        }

        init(orderStatusEnum: OrderStatusEnum) {
            let siteOrderStatus = OrderStatus(name: nil, siteID: 0, slug: orderStatusEnum.rawValue, total: 0)
            self.init(orderStatus: siteOrderStatus)
        }
    }
}

// MARK: - Helpers
private extension NewOrderViewModel {
    /// Calculates what navigation trailing item should be shown depending on our internal state.
    ///
    func configureNavigationTrailingItem() {
        Publishers.CombineLatest($orderDetails, $performingNetworkRequest)
            .map { orderDetails, performingNetworkRequest -> NavigationItem in
                guard !performingNetworkRequest else {
                    return .loading
                }

                guard orderDetails.emptyOrder != orderDetails.toOrder() else {
                    return .none
                }

                return .create
            }
            .assign(to: &$navigationTrailingItem)
    }

    /// Updates status badge viewmodel based on status order property.
    ///
    func configureStatusBadgeViewModel() {
        $orderDetails
            .map { [weak self] orderDetails in
                guard let siteOrderStatus = self?.currentSiteStatuses.first(where: { $0.status == orderDetails.status }) else {
                    return StatusBadgeViewModel(orderStatusEnum: orderDetails.status)
                }
                return StatusBadgeViewModel(orderStatus: siteOrderStatus)
            }
            .assign(to: &$statusBadgeViewModel)
    }

    /// Adds a selected product (from the product list) to the order
    ///
    func addProductToOrder(_ product: Product) {
        // Add product to the visible product list
        let productRowViewModel = ProductRowViewModel(product: product, canChangeQuantity: true)
        productRows.append(productRowViewModel)

        // Add product to the order details
        let orderItem = convertToOrderItem(product: product, quantity: 1)
        orderDetails.items.append(orderItem)
    }

    /// Converts product to order item, so it can be added to the order
    ///
    func convertToOrderItem(product: Product, quantity: Decimal) -> OrderItem {
        let price = NSDecimalNumber(string: product.price)
        let total = quantity * price.decimalValue

        return OrderItem(itemID: 0,
                         name: product.name,
                         productID: product.productID,
                         variationID: 0,
                         quantity: quantity,
                         price: price,
                         sku: nil,
                         subtotal: "\(total)",
                         subtotalTax: "",
                         taxClass: "",
                         taxes: [],
                         total: "\(total)",
                         totalTax: "0",
                         attributes: []
        )
    }
}
