import Combine
import protocol Storage.StorageManagerType
import Yosemite
import Foundation

/// Provides data and observables for UI in `StoreStatsV4PeriodViewController`.
final class StoreStatsPeriodViewModel {
    // MARK: - Public data & observables

    /// Used for chart updates.
    var orderStatsIntervals: [OrderStatsV4Interval] {
        orderStatsData.intervals
    }

    /// Updated externally from user interactions with the chart.
    @Published var selectedIntervalIndex: Int? = nil

    /// Emits order stats text values based on order stats and selected time interval.
    private(set) lazy var orderStatsText: AnyPublisher<String, Never> =
    Publishers.CombineLatest($orderStatsData.eraseToAnyPublisher(), $selectedIntervalIndex.eraseToAnyPublisher())
        .compactMap { [weak self] orderStatsData, selectedIntervalIndex in
            return self?.createOrderStatsText(orderStatsData: orderStatsData, selectedIntervalIndex: selectedIntervalIndex)
        }
        .removeDuplicates()
        .eraseToAnyPublisher()

    /// Emits revenue stats text values based on order stats and selected time interval.
    private(set) lazy var revenueStatsText: AnyPublisher<String, Never> =
    Publishers.CombineLatest($orderStatsData.eraseToAnyPublisher(), $selectedIntervalIndex.eraseToAnyPublisher())
        .compactMap { [weak self] orderStatsData, selectedIntervalIndex in
            self?.createRevenueStats(orderStatsData: orderStatsData, selectedIntervalIndex: selectedIntervalIndex)
        }
        .removeDuplicates()
        .eraseToAnyPublisher()

    /// Emits visitor stats text values based on site visit stats and selected time interval.
    private(set) lazy var visitorStatsText: AnyPublisher<String, Never> =
    Publishers.CombineLatest($siteStats.eraseToAnyPublisher(), $selectedIntervalIndex.eraseToAnyPublisher())
        .compactMap { [weak self] siteStats, selectedIntervalIndex in
            self?.createVisitorStatsText(siteStats: siteStats, selectedIntervalIndex: selectedIntervalIndex)
        }
        .removeDuplicates()
        .eraseToAnyPublisher()

    /// Emits conversion stats text values based on order stats, site visit stats, and selected time interval.
    private(set) lazy var conversionStatsText: AnyPublisher<String, Never> =
    Publishers.CombineLatest3($orderStatsData.eraseToAnyPublisher(), $siteStats.eraseToAnyPublisher(), $selectedIntervalIndex.eraseToAnyPublisher())
        .compactMap { [weak self] orderStatsData, siteStats, selectedIntervalIndex in
            self?.createConversionStats(orderStatsData: orderStatsData, siteStats: siteStats, selectedIntervalIndex: selectedIntervalIndex)
        }
        .removeDuplicates()
        .eraseToAnyPublisher()

    /// Emits view models for time range bar that shows the time range for the selected time interval.
    private(set) lazy var timeRangeBarViewModel: AnyPublisher<StatsTimeRangeBarViewModel, Never> =
    Publishers.CombineLatest($orderStatsData.eraseToAnyPublisher(), $selectedIntervalIndex.eraseToAnyPublisher())
        .compactMap { [weak self] orderStatsData, selectedIntervalIndex in
            return self?.createTimeRangeBarViewModel(orderStatsData: orderStatsData, selectedIntervalIndex: selectedIntervalIndex)
        }
        .eraseToAnyPublisher()

    /// Emits a boolean to reload chart, and the boolean indicates whether the reload should be animated.
    var reloadChartAnimated: AnyPublisher<Bool, Never> {
        shouldReloadChartAnimated.eraseToAnyPublisher()
    }

    // MARK: - Private data

    @Published private var siteStats: SiteVisitStats?

    typealias OrderStatsData = (stats: OrderStatsV4?, intervals: [OrderStatsV4Interval])
    @Published private var orderStatsData: OrderStatsData = (nil, [])

    private let shouldReloadChartAnimated: PassthroughSubject<Bool, Never> = .init()

    // MARK: - Results controllers

    /// SiteVisitStats ResultsController: Loads site visit stats from the Storage Layer
    private lazy var siteStatsResultsController: ResultsController<StorageSiteVisitStats> = {
        let predicate = NSPredicate(format: "siteID = %ld AND granularity ==[c] %@ AND timeRange == %@",
                                    siteID,
                                    timeRange.siteVisitStatsGranularity.rawValue,
                                    timeRange.rawValue)
        let descriptor = NSSortDescriptor(keyPath: \StorageSiteVisitStats.date, ascending: false)
        return ResultsController(storageManager: storageManager, matching: predicate, sortedBy: [descriptor])
    }()

    /// OrderStats ResultsController: Loads order stats from the Storage Layer
    private lazy var orderStatsResultsController: ResultsController<StorageOrderStatsV4> = {
        let predicate = NSPredicate(format: "siteID = %ld AND timeRange ==[c] %@", siteID, timeRange.rawValue)
        return ResultsController(storageManager: storageManager, matching: predicate, sortedBy: [])
    }()

    // MARK: - Configurations

    /// Updated externally when reloading data.
    var siteTimezone: TimeZone

    private let siteID: Int64
    private let timeRange: StatsTimeRangeV4
    private let currencyFormatter: CurrencyFormatter
    private let currencyCode: String
    private let storageManager: StorageManagerType

    private var cancellables: Set<AnyCancellable> = []

    init(siteID: Int64,
         timeRange: StatsTimeRangeV4,
         siteTimezone: TimeZone,
         currencyFormatter: CurrencyFormatter,
         currencyCode: String,
         storageManager: StorageManagerType = ServiceLocator.storageManager) {
        self.siteID = siteID
        self.timeRange = timeRange
        self.siteTimezone = siteTimezone
        self.currencyFormatter = currencyFormatter
        self.currencyCode = currencyCode
        self.storageManager = storageManager

        // Make sure the ResultsControllers are ready to observe changes to the data even before the view loads
        configureResultsControllers()
    }
}

// MARK: Private helpers for public data calculation
//
private extension StoreStatsPeriodViewModel {
    func createTimeRangeBarViewModel(orderStatsData: OrderStatsData, selectedIntervalIndex: Int?) -> StatsTimeRangeBarViewModel? {
        let orderStatsIntervals = orderStatsData.intervals
        guard let startDate = orderStatsIntervals.first?.dateStart(timeZone: self.siteTimezone),
              let endDate = orderStatsIntervals.last?.dateStart(timeZone: self.siteTimezone) else {
                  return nil
              }
        guard let selectedIndex = selectedIntervalIndex else {
            return StatsTimeRangeBarViewModel(startDate: startDate,
                                              endDate: endDate,
                                              timeRange: timeRange,
                                              timezone: siteTimezone)
        }
        let date = orderStatsIntervals[selectedIndex].dateStart(timeZone: siteTimezone)
        return StatsTimeRangeBarViewModel(startDate: startDate,
                                          endDate: endDate,
                                          selectedDate: date,
                                          timeRange: timeRange,
                                          timezone: siteTimezone)
    }

    func createOrderStatsText(orderStatsData: OrderStatsData, selectedIntervalIndex: Int?) -> String {
        if let count = orderCount(at: selectedIntervalIndex, orderStats: orderStatsData.stats, orderStatsIntervals: orderStatsData.intervals) {
            return Double(count).humanReadableString()
        } else {
            return Constants.placeholderText
        }
    }

    func createRevenueStats(orderStatsData: OrderStatsData, selectedIntervalIndex: Int?) -> String {
        if let revenue = revenue(at: selectedIntervalIndex, orderStats: orderStatsData.stats, orderStatsIntervals: orderStatsData.intervals) {
            return currencyFormatter.formatAmount(revenue, with: currencyCode) ?? String()
        } else {
            return Constants.placeholderText
        }
    }

    func createVisitorStatsText(siteStats: SiteVisitStats?, selectedIntervalIndex: Int?) -> String {
        if let visitorCount = visitorCount(at: selectedIntervalIndex, siteStats: siteStats) {
            return Double(visitorCount).humanReadableString()
        } else {
            return Constants.placeholderText
        }
    }

    func createConversionStats(orderStatsData: OrderStatsData, siteStats: SiteVisitStats?, selectedIntervalIndex: Int?) -> String {
        let visitors = visitorCount(at: selectedIntervalIndex, siteStats: siteStats)
        let orders = orderCount(at: selectedIntervalIndex, orderStats: orderStatsData.stats, orderStatsIntervals: orderStatsData.intervals)
        if let visitors = visitors, let orders = orders, visitors > 0 {
            // Maximum conversion rate is 100%.
            let conversionRate = min(orders/visitors, 1)
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .percent
            numberFormatter.minimumFractionDigits = 1
            return numberFormatter.string(from: conversionRate as NSNumber) ?? Constants.placeholderText
        } else {
            return Constants.placeholderText
        }
    }
}

// MARK: - Private data helpers
//
private extension StoreStatsPeriodViewModel {
    func visitorCount(at selectedIndex: Int?, siteStats: SiteVisitStats?) -> Double? {
        let siteStatsItems = siteStats?.items?.sorted(by: { (lhs, rhs) -> Bool in
            return lhs.period < rhs.period
        }) ?? []
        if let selectedIndex = selectedIndex, selectedIndex < siteStatsItems.count {
            return Double(siteStatsItems[selectedIndex].visitors)
        } else if let siteStats = siteStats {
            return Double(siteStats.totalVisitors)
        } else {
            return nil
        }
    }

    func orderCount(at selectedIndex: Int?, orderStats: OrderStatsV4?, orderStatsIntervals: [OrderStatsV4Interval]) -> Double? {
        if let selectedIndex = selectedIndex, selectedIndex < orderStatsIntervals.count {
            let orderStats = orderStatsIntervals[selectedIndex]
            return Double(orderStats.subtotals.totalOrders)
        } else if let orderStats = orderStats {
            return Double(orderStats.totals.totalOrders)
        } else {
            return nil
        }
    }

    func revenue(at selectedIndex: Int?, orderStats: OrderStatsV4?, orderStatsIntervals: [OrderStatsV4Interval]) -> Decimal? {
        if let selectedIndex = selectedIndex, selectedIndex < orderStatsIntervals.count {
            let orderStats = orderStatsIntervals[selectedIndex]
            return orderStats.subtotals.grossRevenue
        } else if let orderStats = orderStats {
            return orderStats.totals.grossRevenue
        } else {
            return nil
        }
    }

    func orderStatsIntervals(from orderStats: OrderStatsV4?) -> [OrderStatsV4Interval] {
        return orderStats?.intervals.sorted(by: { (lhs, rhs) -> Bool in
            return lhs.dateStart(timeZone: siteTimezone) < rhs.dateStart(timeZone: siteTimezone)
        }) ?? []
    }
}

// MARK: - Results controller
//
private extension StoreStatsPeriodViewModel {
    func configureResultsControllers() {
        configureSiteStatsResultsController()
        configureOrderStatsResultsController()
    }

    func configureOrderStatsResultsController() {
        orderStatsResultsController.onDidChangeContent = { [weak self] in
            self?.updateOrderDataIfNeeded()
        }
        orderStatsResultsController.onDidResetContent = { [weak self] in
            self?.updateOrderDataIfNeeded()
        }
        try? orderStatsResultsController.performFetch()
    }

    func configureSiteStatsResultsController() {
        siteStatsResultsController.onDidChangeContent = { [weak self] in
            self?.updateSiteVisitDataIfNeeded()
        }
        siteStatsResultsController.onDidResetContent = { [weak self] in
            self?.updateSiteVisitDataIfNeeded()
        }
        try? siteStatsResultsController.performFetch()
    }
}

// MARK: - Private Helpers
//
private extension StoreStatsPeriodViewModel {
    func updateSiteVisitDataIfNeeded() {
        siteStats = siteStatsResultsController.fetchedObjects.first
    }

    func updateOrderDataIfNeeded() {
        let orderStats = orderStatsResultsController.fetchedObjects.first
        let intervals = orderStatsIntervals(from: orderStats)
        orderStatsData = (stats: orderStats, intervals: intervals)

        // Don't animate the chart here - this helps avoid a "double animation" effect if a
        // small number of values change (the chart WILL be updated correctly however)
        shouldReloadChartAnimated.send(false)
    }
}

private extension StoreStatsPeriodViewModel {
    enum Constants {
        static let placeholderText = "-"
    }
}
