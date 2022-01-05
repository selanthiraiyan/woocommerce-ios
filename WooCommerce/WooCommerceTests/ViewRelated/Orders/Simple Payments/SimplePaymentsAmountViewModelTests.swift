import Foundation
import XCTest
import Combine

@testable import WooCommerce
@testable import Yosemite

final class SimplePaymentsAmountViewModelTests: XCTestCase {

    private let sampleSiteID: Int64 = 123

    private let usLocale = Locale(identifier: "en_US")
    private let usStoreSettings = CurrencySettings() // Default is US settings

    private var subscriptions = Set<AnyCancellable>()

    func test_view_model_prepends_currency_symbol() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "12"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "$12")
    }

    func test_view_model_formats_amount_with_custom_currency_settings() {
        // Given
        let customSettings = CurrencySettings(currencyCode: .GBP,
                                              currencyPosition: .rightSpace,
                                              thousandSeparator: ",",
                                              decimalSeparator: ".",
                                              numberOfDecimals: 3)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: customSettings)

        // When
        viewModel.amount = "12.203"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "12.203 £")
    }

    func test_view_model_removes_non_digit_characters() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "hi:11.30-"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "$11.30")
    }

    func test_view_model_trims_more_than_two_decimal_numbers() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "$67.321432432"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "$67.32")
    }

    func test_view_model_removes_duplicated_decimal_separators() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "$6.7.3"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "$6.7")
    }

    func test_view_model_removes_consecutive_decimal_separators() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "$6..."

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "$6.")
    }

    func test_view_model_disables_next_button_when_there_is_no_amount() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID)

        // When
        viewModel.amount = ""

        // Then
        XCTAssertTrue(viewModel.shouldDisableDoneButton)
    }

    func test_view_model_disables_next_button_when_amount_only_has_currency_symbol() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "$"

        // Then
        XCTAssertTrue(viewModel.shouldDisableDoneButton)
    }

    func test_view_model_disables_next_button_when_amount_is_not_greater_than_zero() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "$0"

        // Then
        XCTAssertTrue(viewModel.shouldDisableDoneButton)
    }

    func test_view_model_enables_next_button_when_amount_has_more_than_one_character() {
        // Given
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "$2"

        // Then
        XCTAssertFalse(viewModel.shouldDisableDoneButton)
    }

    func test_view_model_changes_coma_separator_for_dot_separator_when_the_store_requires_it() {
        // Given
        let comaSeparatorLocale = Locale(identifier: "es_AR")
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: comaSeparatorLocale, storeCurrencySettings: usStoreSettings)

        // When
        viewModel.amount = "10,25"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "$10.25")
    }

    func test_view_model_uses_the_store_currency_symbol() {
        // Given
        let storeSettings = CurrencySettings(currencyCode: .EUR, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: storeSettings)

        // When
        viewModel.amount = "10.25"

        // Then
        XCTAssertEqual(viewModel.formattedAmount, "€10.25")
    }

    func test_amount_placeholder_is_formatted_with_store_currency_settings() {
        // Given
        let storeSettings = CurrencySettings(currencyCode: .EUR, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ",", numberOfDecimals: 2)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, locale: usLocale, storeCurrencySettings: storeSettings)

        // When & Then
        XCTAssertEqual(viewModel.formattedAmount, "€0,00")
    }

    func test_view_model_enables_loading_state_while_performing_network_operations() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore)
        viewModel.amount = "$12.30"
        XCTAssertFalse(viewModel.loading)

        // When
        let isLoading: Bool = waitFor { promise in
            testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .createSimplePaymentsOrder:
                    promise(viewModel.loading)
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            viewModel.createSimplePaymentsOrder()
        }

        // Then
        XCTAssertTrue(isLoading)
    }

    func test_order_is_created_with_taxes() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore)
        viewModel.amount = "$12.30"

        // When
        let taxable: Bool = waitFor { promise in
            testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .createSimplePaymentsOrder(_, _, taxable, _):
                    promise(taxable)
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            viewModel.createSimplePaymentsOrder()
        }

        // Then
        XCTAssertTrue(taxable)
    }

    func test_summaryViewModel_is_created_after_an_order_is_created() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore)

        // When
        waitForExpectation { exp in
            testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .createSimplePaymentsOrder(_, _, _, onCompletion):
                    onCompletion(.success(.fake()))
                    exp.fulfill()
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }

            viewModel.createSimplePaymentsOrder()
        }

        // Then
        XCTAssertNotNil(viewModel.summaryViewModel)
        XCTAssertTrue(viewModel.navigateToSummary)
    }

    func test_summaryViewModel_is_nilled_after_navigation_is_set_to_false() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore)
        waitForExpectation { exp in
            testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .createSimplePaymentsOrder(_, _, _, onCompletion):
                    onCompletion(.success(.fake()))
                    exp.fulfill()
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }

            viewModel.createSimplePaymentsOrder()
        }

        // When
        viewModel.navigateToSummary = false

        // Then
        XCTAssertNil(viewModel.summaryViewModel)
    }

    func test_view_model_attempts_error_notice_presentation_when_failing_to_create_order() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        let noticeSubject = PassthroughSubject<SimplePaymentsNotice, Never>()
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore, presentNoticeSubject: noticeSubject)
        testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .createSimplePaymentsOrder(_, _, _, onCompletion):
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
            viewModel.createSimplePaymentsOrder()
        }

        // Then
        XCTAssertTrue(receivedError)
    }

    func test_failure_is_tracked_when_failing_to_create_order() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .createSimplePaymentsOrder(_, _, _, onCompletion):
                onCompletion(.failure(NSError(domain: "Error", code: 0)))
            default:
                XCTFail("Received unsupported action: \(action)")
            }
        }

        let analytics = MockAnalyticsProvider()
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.createSimplePaymentsOrder()

        // Then
        assertEqual(analytics.receivedEvents, [WooAnalyticsStat.simplePaymentsFlowFailed.rawValue])
        assertEqual(analytics.receivedProperties.first?["source"] as? String, "amount")
    }

    func test_view_model_disable_cancel_button_while_creating_payment_order() {
        // Given
        let testingStore = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = SimplePaymentsAmountViewModel(siteID: sampleSiteID, stores: testingStore)
        viewModel.amount = "$10.30"
        XCTAssertFalse(viewModel.loading)

        // Before creating simple payment order
        XCTAssertFalse(viewModel.disableViewActions)

        // When
        let _: Bool = waitFor { promise in
            testingStore.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .createSimplePaymentsOrder:
                    promise(viewModel.loading)
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            viewModel.createSimplePaymentsOrder()
        }

        // Then
        XCTAssertTrue(viewModel.disableViewActions)
    }

}
