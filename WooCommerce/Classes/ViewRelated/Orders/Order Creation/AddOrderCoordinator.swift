import UIKit
import Yosemite

final class AddOrderCoordinator: Coordinator {
    var navigationController: UINavigationController

    private let siteID: Int64
    private let isOrderCreationEnabled: Bool
    private let shouldShowSimplePaymentsButton: Bool
    private let sourceBarButtonItem: UIBarButtonItem?
    private let sourceView: UIView?

    /// Assign this closure to be notified when a new order is created
    ///
    var onOrderCreated: (Order) -> Void = { _ in }

    init(siteID: Int64,
         isOrderCreationEnabled: Bool,
         shouldShowSimplePaymentsButton: Bool,
         sourceBarButtonItem: UIBarButtonItem,
         sourceNavigationController: UINavigationController) {
        self.siteID = siteID
        self.isOrderCreationEnabled = isOrderCreationEnabled
        self.shouldShowSimplePaymentsButton = shouldShowSimplePaymentsButton
        self.sourceBarButtonItem = sourceBarButtonItem
        self.sourceView = nil
        self.navigationController = sourceNavigationController
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        switch (isOrderCreationEnabled, shouldShowSimplePaymentsButton) {
        case (true, true):
            presentOrderTypeBottomSheet()
        case (false, true):
            presentOrderCreationFlow(bottomSheetOrderType: .simple)
        case (true, false):
            presentOrderCreationFlow(bottomSheetOrderType: .full)
        case (false, false):
            return
        }
    }
}

// MARK: Navigation
private extension AddOrderCoordinator {
    func presentOrderTypeBottomSheet() {
        let viewProperties = BottomSheetListSelectorViewProperties(title: nil)
        let command = OrderTypeBottomSheetListSelectorCommand(selected: nil) { selectedBottomSheetOrderType in
            self.navigationController.dismiss(animated: true)
            self.presentOrderCreationFlow(bottomSheetOrderType: selectedBottomSheetOrderType)
        }
        command.data = [.full, .quick]
        let productTypesListPresenter = BottomSheetListSelectorPresenter(viewProperties: viewProperties, command: command)
        productTypesListPresenter.show(from: navigationController, sourceView: sourceView, sourceBarButtonItem: sourceBarButtonItem, arrowDirections: .any)
    }

    func presentOrderCreationFlow(bottomSheetOrderType: BottomSheetOrderType) {
        switch bottomSheetOrderType {
        case .simple:
            presentSimplePaymentsAmountController()
        case .full:
            presentNewOrderController()
            return
        }
    }

    /// Presents `SimplePaymentsAmountHostingController`.
    ///
    func presentSimplePaymentsAmountController() {
        let viewModel = SimplePaymentsAmountViewModel(siteID: siteID)
        viewModel.onOrderCreated = onOrderCreated

        let viewController = SimplePaymentsAmountHostingController(viewModel: viewModel)
        let simplePaymentsNC = WooNavigationController(rootViewController: viewController)
        navigationController.present(simplePaymentsNC, animated: true)

        ServiceLocator.analytics.track(event: WooAnalyticsEvent.SimplePayments.simplePaymentsFlowStarted())
    }

    /// Presents `NewOrderHostingController`.
    ///
    func presentNewOrderController() {
        let viewController = NewOrderHostingController()
        let newOrderNC = WooNavigationController(rootViewController: viewController)
        navigationController.present(newOrderNC, animated: true)
    }
}
