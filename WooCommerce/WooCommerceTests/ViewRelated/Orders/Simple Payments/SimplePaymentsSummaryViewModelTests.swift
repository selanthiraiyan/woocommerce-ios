import Foundation
import XCTest
import Combine

@testable import WooCommerce
@testable import Yosemite

final class SimplePaymentsSummaryViewModelTests: XCTestCase {

    var subscriptions = Set<AnyCancellable>()

    func test_updating_noteViewModel_updates_noteContent_property() {
        // Given
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "$100.00",
                                                       totalWithTaxes: "$104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [])
        // When
        viewModel.noteViewModel.newNote = "Updated note"

        // Then
        assertEqual(viewModel.noteContent, viewModel.noteViewModel.newNote)
    }

    func test_calling_reloadContent_triggers_viewModel_update() {
        // Given
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "$100.00",
                                                       totalWithTaxes: "$104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [])
        // When
        let triggeredUpdate: Bool = waitFor { promise in
            viewModel.objectWillChange.sink {
                promise(true)
            }
            .store(in: &self.subscriptions)

            viewModel.reloadContent()
        }

        // Then
        XCTAssertTrue(triggeredUpdate)
    }

    func test_provided_amount_gets_properly_formatted() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        mockStores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .getSimplePaymentsTaxesToggleState(_, onCompletion):
                onCompletion(.success(false)) // Keep the taxes toggle turned off
            case .setSimplePaymentsTaxesToggleState:
                break // No op
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let currencyFormatter = CurrencyFormatter(currencySettings: CurrencySettings()) // Default is US.
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       currencyFormatter: currencyFormatter,
                                                       stores: mockStores)

        // When & Then
        XCTAssertEqual(viewModel.providedAmount, "$100.00")
        XCTAssertEqual(viewModel.total, "$100.00")
    }

    func test_provided_amount_with_taxes_gets_properly_formatted() {
        // Given
        let currencyFormatter = CurrencyFormatter(currencySettings: CurrencySettings()) // Default is US.
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       currencyFormatter: currencyFormatter)
        // When
        viewModel.enableTaxes = true

        // Then
        XCTAssertEqual(viewModel.providedAmount, "$100.00")
        XCTAssertEqual(viewModel.total, "$104.30")
    }

    func test_tax_amount_is_properly_formatted() {
        // Given
        let currencyFormatter = CurrencyFormatter(currencySettings: CurrencySettings()) // Default is US.
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "4.3",
                                                       taxLines: [],
                                                       currencyFormatter: currencyFormatter)
        // When & Then
        XCTAssertEqual(viewModel.taxAmount, "$4.30")
    }

    func test_tax_rate_is_calculated_properly() {
        // Given
        let currencyFormatter = CurrencyFormatter(currencySettings: CurrencySettings()) // Default is US.
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       currencyFormatter: currencyFormatter)
        // When & Then
        XCTAssertEqual(viewModel.taxRate, "4.30")
    }

    func test_showTaxBreakup_is_false_if_taxLinesInSimplePayments_feature_flag_is_off() {
        // Given
        let featureFlagService = MockFeatureFlagService(isTaxLinesInSimplePaymentsOn: false)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       featureFlagService: featureFlagService)
        // Then
        XCTAssertFalse(viewModel.showTaxBreakup)
    }

    func test_showTaxBreakup_is_true_if_taxLinesInSimplePayments_feature_flag_is_on() {
        // Given
        let featureFlagService = MockFeatureFlagService(isTaxLinesInSimplePaymentsOn: true)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       featureFlagService: featureFlagService)
        // Then
        XCTAssertTrue(viewModel.showTaxBreakup)
    }

    func test_showChargeTaxesToggle_is_true_if_taxLinesInSimplePayments_feature_flag_is_off() {
        // Given
        let featureFlagService = MockFeatureFlagService(isTaxLinesInSimplePaymentsOn: false)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       featureFlagService: featureFlagService)
        // Then
        XCTAssertTrue(viewModel.showChargeTaxesToggle)
    }

    func test_showChargeTaxesToggle_is_true_when_taxLines_is_not_empty_and_taxLinesInSimplePayments_feature_flag_is_off() {
        // Given
        let featureFlagService = MockFeatureFlagService(isTaxLinesInSimplePaymentsOn: false)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [
                                                        SimplePaymentsSummaryViewModel.TaxLine(id: 1,
                                                                                               title: "State",
                                                                                               value: "4.23")
                                                       ],
                                                       featureFlagService: featureFlagService)
        // Then
        XCTAssertTrue(viewModel.showChargeTaxesToggle)
    }

    func test_showChargeTaxesToggle_is_false_when_taxLines_is_empty_and_taxLinesInSimplePayments_feature_flag_is_on() {
        // Given
        let featureFlagService = MockFeatureFlagService(isTaxLinesInSimplePaymentsOn: true)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [],
                                                       featureFlagService: featureFlagService)
        // Then
        XCTAssertFalse(viewModel.showChargeTaxesToggle)
    }

    func test_showChargeTaxesToggle_is_true_when_taxLines_is_not_empty_and_taxLinesInSimplePayments_feature_flag_is_on() {
        // Given
        let featureFlagService = MockFeatureFlagService(isTaxLinesInSimplePaymentsOn: true)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "100",
                                                       totalWithTaxes: "104.30",
                                                       taxAmount: "$4.3",
                                                       taxLines: [
                                                        SimplePaymentsSummaryViewModel.TaxLine(id: 1,
                                                                                               title: "State",
                                                                                               value: "4.23")
                                                       ],
                                                       featureFlagService: featureFlagService)
        // Then
        XCTAssertTrue(viewModel.showChargeTaxesToggle)
    }

    func test_taxLines_is_empty_when_Order_does_not_have_taxes() {
        // Given
        let order = Order.fake().copy(taxes: [])
        let viewModel = SimplePaymentsSummaryViewModel(order: order,
                                                       providedAmount: "100")

        // Then
        XCTAssertTrue(viewModel.taxLines.isEmpty)
    }

    func test_taxLines_is_not_empty_when_Order_has_taxes() {
        // Given
        let order = Order.fake().copy(taxes: [OrderTaxLine.fake()])
        let viewModel = SimplePaymentsSummaryViewModel(order: order,
                                                       providedAmount: "100")

        // Then
        XCTAssertFalse(viewModel.taxLines.isEmpty)
    }

    func test_taxLines_count_matches_taxes_count() {
        // Given
        let order = Order.fake().copy(taxes: [OrderTaxLine.fake(), OrderTaxLine.fake()])
        let viewModel = SimplePaymentsSummaryViewModel(order: order,
                                                       providedAmount: "100")

        // Then
        XCTAssertEqual(viewModel.taxLines.count, order.taxes.count)
    }

    /// Test that generated `taxLines` are in the same order as `Order`'s `taxes`
    ///
    func test_taxLines_order_matches_taxes_order() {
        // Given
        let order = Order.fake().copy(taxes: [OrderTaxLine.fake().copy(taxID: 1),
                                              OrderTaxLine.fake().copy(taxID: 2),
                                              OrderTaxLine.fake().copy(taxID: 3)])
        let viewModel = SimplePaymentsSummaryViewModel(order: order,
                                                       providedAmount: "100")

        // Then
        XCTAssertEqual(viewModel.taxLines[0].id, order.taxes[0].taxID)
        XCTAssertEqual(viewModel.taxLines[1].id, order.taxes[1].taxID)
        XCTAssertEqual(viewModel.taxLines[2].id, order.taxes[2].taxID)
    }

    func test_taxLine_title_matches_values_of_tax() {
        // Given
        let order = Order.fake().copy(taxes: [OrderTaxLine.fake().copy(taxID: 1,
                                                                       label: "State",
                                                                       ratePercent: 4.5)])
        let viewModel = SimplePaymentsSummaryViewModel(order: order,
                                                       providedAmount: "100")

        // Then
        let title = "\(order.taxes[0].label) (\(order.taxes[0].ratePercent)%)"
        XCTAssertEqual(viewModel.taxLines[0].title, title)
    }

    func test_taxLine_value_matches_totalTax_of_tax() {
        // Given
        let order = Order.fake().copy(taxes: [OrderTaxLine.fake().copy(totalTax: "4.30")])
        let currencyFormatter = CurrencyFormatter(currencySettings: CurrencySettings()) // Default is US.
        let viewModel = SimplePaymentsSummaryViewModel(order: order,
                                                       providedAmount: "100",
                                                       currencyFormatter: currencyFormatter)

        // Then
        XCTAssertEqual(viewModel.taxLines[0].value, "$4.30")
    }

    func test_when_order_is_updated_loading_indicator_is_toggled() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores)
        mockStores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateSimplePaymentsOrder(_, _, _, _, _, _, _, onCompletion):
                onCompletion(.success(Order.fake()))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        // When
        let loadingStates: [Bool] = waitFor { promise in
            viewModel.$showLoadingIndicator
                .dropFirst() // Initial value
                .collect(2)  // Collect toggle
                .first()
                .sink { loadingStates in
                    promise(loadingStates)
                }
                .store(in: &self.subscriptions)
            viewModel.updateOrder()
        }

        // Then
        XCTAssertEqual(loadingStates, [true, false]) // Loading, then not loading.
    }

    func test_view_model_attempts_error_notice_presentation_when_failing_to_update_order() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        let noticeSubject = PassthroughSubject<SimplePaymentsNotice, Never>()
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       presentNoticeSubject: noticeSubject,
                                                       stores: mockStores)
        mockStores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateSimplePaymentsOrder(_, _, _, _, _, _, _, onCompletion):
                onCompletion(.failure(NSError(domain: "Error", code: 0)))
            default:
                XCTFail("Received unsupported action: \(action)")
            }
        }

        // When
        let receivedError: Bool = waitFor { promise in
            noticeSubject.sink { intent in
                switch intent {
                case .error:
                    promise(true)
                case .completed, .created:
                    promise(false)
                }
            }
            .store(in: &self.subscriptions)
            viewModel.updateOrder()
        }

        // Then
        XCTAssertTrue(receivedError)
    }

    func test_when_order_is_updated_navigation_to_payments_method_is_triggered() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores)
        mockStores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateSimplePaymentsOrder(_, _, _, _, _, _, _, onCompletion):
                onCompletion(.success(Order.fake()))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }
        XCTAssertFalse(viewModel.navigateToPaymentMethods)

        // When
        viewModel.updateOrder()

        // Then
        XCTAssertTrue(viewModel.navigateToPaymentMethods)
    }

    func test_when_order_is_updated_email_is_trimmed() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores)
        viewModel.email = " some@email.com "

        // When
        let trimmedEmail: String? = waitFor { promise in
            mockStores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .updateSimplePaymentsOrder(_, _, _, _, _, _, email, _):
                    promise(email)
                default:
                    XCTFail("Unexpected action: \(action)")
                }
            }
            viewModel.updateOrder()
        }

        // Then
        XCTAssertEqual(trimmedEmail, "some@email.com")
        XCTAssertEqual(trimmedEmail, viewModel.email)
    }

    func test_empty_emails_are_send_as_nil_when_updating_orders() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores)
        viewModel.email = ""

        // When
        let emailSent: String? = waitFor { promise in
            mockStores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .updateSimplePaymentsOrder(_, _, _, _, _, _, email, _):
                    promise(email)
                default:
                    XCTFail("Unexpected action: \(action)")
                }
            }
            viewModel.updateOrder()
        }

        // Then
        XCTAssertNil(emailSent)
    }

    func test_noteAdded_event_is_tracked_after_editing_note() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        mockStores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .getSimplePaymentsTaxesToggleState(_, onCompletion):
                onCompletion(.success(true))
            case .setSimplePaymentsTaxesToggleState:
                break // No op
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let mockAnalytics = MockAnalyticsProvider()
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores,
                                                       analytics: WooAnalytics(analyticsProvider: mockAnalytics))

        // When
        viewModel.noteViewModel.newNote = "content"
        viewModel.noteViewModel.updateNote(onFinish: { _ in })

        // Then
        assertEqual(mockAnalytics.receivedEvents, [
            WooAnalyticsStat.simplePaymentsFlowTaxesToggled.rawValue, // Event triggered when view model loads the toggle state during initialization
            WooAnalyticsStat.simplePaymentsFlowNoteAdded.rawValue
        ])
    }

    func test_taxesToggled_event_is_tracked_after_switching_taxes_toggle() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        mockStores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .getSimplePaymentsTaxesToggleState(_, onCompletion):
                onCompletion(.success(false))
            case .setSimplePaymentsTaxesToggleState:
                break // No op
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let mockAnalytics = MockAnalyticsProvider()
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores,
                                                       analytics: WooAnalytics(analyticsProvider: mockAnalytics))

        // When
        viewModel.enableTaxes = true
        viewModel.enableTaxes = false

        // Then
        assertEqual(mockAnalytics.receivedEvents, [
            WooAnalyticsStat.simplePaymentsFlowTaxesToggled.rawValue,  // Event triggered when view model loads the toggle state during initialization
            WooAnalyticsStat.simplePaymentsFlowTaxesToggled.rawValue,  // Taxes enabled
            WooAnalyticsStat.simplePaymentsFlowTaxesToggled.rawValue   // Taxes disabled
        ])

        assertEqual(mockAnalytics.receivedProperties[0]["state"] as? String,
                    "off")  // Taxes disabled when view model loads the toggle state during initialization
        assertEqual(mockAnalytics.receivedProperties[1]["state"] as? String, "on")  // Taxes enabled due to setting `enableTaxes` as true
        assertEqual(mockAnalytics.receivedProperties[2]["state"] as? String, "off") // Taxes disabled due to setting `enableTaxes` as false
    }

    func test_failing_event_is_tracked_when_order_fails_to_update() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        mockStores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateSimplePaymentsOrder(_, _, _, _, _, _, _, onCompletion):
                onCompletion(.failure(NSError(domain: "", code: 0, userInfo: nil)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let mockAnalytics = MockAnalyticsProvider()
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores,
                                                       analytics: WooAnalytics(analyticsProvider: mockAnalytics))

        // When
        viewModel.updateOrder()

        // Then
        assertEqual(mockAnalytics.receivedEvents, [WooAnalyticsStat.simplePaymentsFlowFailed.rawValue])
        assertEqual(mockAnalytics.receivedProperties.first?["source"] as? String, "summary")
    }

    func test_taxes_toggle_state_is_properly_loaded() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        mockStores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .getSimplePaymentsTaxesToggleState(_, onCompletion):
                onCompletion(.success(true))
            case .setSimplePaymentsTaxesToggleState:
                break // No op
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        // When
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores)

        // Then
        XCTAssertTrue(viewModel.enableTaxes)
    }

    func test_taxes_toggle_state_is_stored_after_toggling_taxes() {
        // Given
        let mockStores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsSummaryViewModel(providedAmount: "1.0",
                                                       totalWithTaxes: "1.0",
                                                       taxAmount: "0.0",
                                                       taxLines: [],
                                                       stores: mockStores)
        // When
        let stateStored: Bool = waitFor { promise in
            mockStores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
                switch action {
                case .setSimplePaymentsTaxesToggleState:
                    promise(true)
                default:
                    XCTFail("Unexpected action: \(action)")
                }
            }

            viewModel.enableTaxes = true
        }

        // Then
        XCTAssertTrue(stateStored)
    }
}
