import Foundation
import UIKit
import WordPressUI
import Yosemite

import class AutomatticTracks.CrashLogging

protocol ReviewsViewModelOutput {
    var isEmpty: Bool { get }

    var dataSource: UITableViewDataSource { get }

    var delegate: ReviewsInteractionDelegate { get }

    var hasUnreadNotifications: Bool { get }

    var shouldPromptForAppReview: Bool { get }

    var hasErrorLoadingData: Bool { get set }

    func containsMorePages(_ highestVisibleReview: Int) -> Bool
}

protocol ReviewsViewModelActionsHandler {
    func displayPlaceholderReviews(tableView: UITableView)

    func removePlaceholderReviews(tableView: UITableView)

    func configureResultsController(tableView: UITableView)

    func refreshResults()

    func configureTableViewCells(tableView: UITableView)

    func markAllAsRead(onCompletion: @escaping (Error?) -> Void)

    func synchronizeReviews(pageNumber: Int,
                            pageSize: Int,
                            onCompletion: (() -> Void)?)
}

final class ReviewsViewModel: ReviewsViewModelOutput, ReviewsViewModelActionsHandler {
    private let siteID: Int64

    private let data: ReviewsDataSource

    var isEmpty: Bool {
        data.isEmpty
    }

    var dataSource: UITableViewDataSource {
        data
    }

    var delegate: ReviewsInteractionDelegate {
        data
    }

    var hasUnreadNotifications: Bool {
        unreadNotifications.count != 0
    }

    private var unreadNotifications: [Note] {
        data.notifications.filter { $0.read == false }
    }

    var shouldPromptForAppReview: Bool {
        AppRatingManager.shared.shouldPromptForAppReview(section: Constants.section)
    }

    /// Set when sync fails, and used to display an error loading data banner
    ///
    var hasErrorLoadingData: Bool = false

    init(siteID: Int64, data: ReviewsDataSource) {
        self.siteID = siteID
        self.data = data
    }

    func displayPlaceholderReviews(tableView: UITableView) {
        let options = GhostOptions(reuseIdentifier: ProductReviewTableViewCell.reuseIdentifier, rowsPerSection: Settings.placeholderRowsPerSection)
        tableView.displayGhostContent(options: options,
                                      style: .wooDefaultGhostStyle)

        data.stopForwardingEvents()
    }

    /// Removes Placeholder Notes (and restores the ResultsController <> UITableView link).
    ///
    func removePlaceholderReviews(tableView: UITableView) {
        tableView.removeGhostContent()
        data.startForwardingEvents(to: tableView)
        tableView.reloadData()
    }

    func configureResultsController(tableView: UITableView) {
        data.startForwardingEvents(to: tableView)

        do {
            try data.observeReviews()
        } catch {
            ServiceLocator.crashLogging.logError(error)
        }

        // Reload table because observeReviews() executes performFetch()
        tableView.reloadData()
    }

    func refreshResults() {
        data.refreshDataObservers()
    }

    /// Setup: TableViewCells
    ///
    func configureTableViewCells(tableView: UITableView) {
        tableView.registerNib(for: ProductReviewTableViewCell.self)
    }

    func markAllAsRead(onCompletion: @escaping (Error?) -> Void) {
        markAsRead(notes: unreadNotifications, onCompletion: onCompletion)
    }

    func containsMorePages(_ highestVisibleReview: Int) -> Bool {
        highestVisibleReview > data.reviewCount
    }
}


// MARK: - Fetching data
extension ReviewsViewModel {
    /// Prepares data necessary to render the reviews tab.
    ///
    func synchronizeReviews(pageNumber: Int,
                            pageSize: Int,
                            onCompletion: (() -> Void)?) {
        hasErrorLoadingData = false

        let group = DispatchGroup()

        group.enter()
        synchronizeAllReviews(pageNumber: pageNumber, pageSize: pageSize) {
            group.leave()
        }

        group.enter()
        synchronizeProductsReviewed {
            group.leave()
        }

        group.enter()
        synchronizeNotifications {
            group.leave()
        }

        group.notify(queue: .main) {
            if let completionBlock = onCompletion {
                completionBlock()
            }
        }
    }

    /// Synchronizes the Reviews associated to the current store.
    ///
    private func synchronizeAllReviews(pageNumber: Int,
                                       pageSize: Int,
                                       onCompletion: (() -> Void)? = nil) {
        let action = ProductReviewAction.synchronizeProductReviews(siteID: siteID, pageNumber: pageNumber, pageSize: pageSize) { [weak self] error in
            if let error = error {
                DDLogError("⛔️ Error synchronizing reviews: \(error)")
                ServiceLocator.analytics.track(.reviewsListLoadFailed,
                                               withError: error)
                self?.hasErrorLoadingData = true
            } else {
                let loadingMore = pageNumber != Settings.firstPage
                ServiceLocator.analytics.track(.reviewsListLoaded,
                                               withProperties: ["is_loading_more": loadingMore])
            }

            onCompletion?()
        }

        ServiceLocator.stores.dispatch(action)
    }

    private func synchronizeProductsReviewed(onCompletion: @escaping () -> Void) {
        let reviewsProductIDs = data.reviewsProductsIDs

        let action = ProductAction.retrieveProducts(siteID: siteID, productIDs: reviewsProductIDs) { [weak self] result in
            switch result {
            case .failure(let error):
                DDLogError("⛔️ Error synchronizing products: \(error)")
                ServiceLocator.analytics.track(.reviewsProductsLoadFailed,
                                               withError: error)
                self?.hasErrorLoadingData = true
            case .success:
                ServiceLocator.analytics.track(.reviewsProductsLoaded)
            }

            onCompletion()
        }

        ServiceLocator.stores.dispatch(action)
    }

    /// Synchronizes the Notifications associated to the active WordPress.com account.
    ///
    private func synchronizeNotifications(onCompletion: (() -> Void)? = nil) {
        let action = NotificationAction.synchronizeNotifications { [weak self] error in
            if let error = error {
                DDLogError("⛔️ Error synchronizing notifications: \(error)")
                ServiceLocator.analytics.track(.notificationsLoadFailed,
                                               withError: error)
                self?.hasErrorLoadingData = true
            } else {
                ServiceLocator.analytics.track(.notificationListLoaded)
            }

            onCompletion?()
        }

        ServiceLocator.stores.dispatch(action)
    }
}

private extension ReviewsViewModel {
    /// Marks the specified collection of Notifications as Read.
    ///
    func markAsRead(notes: [Note], onCompletion: @escaping (Error?) -> Void) {
        let identifiers = notes.map { $0.noteID }
        let action = NotificationAction.updateMultipleReadStatus(noteIDs: identifiers, read: true, onCompletion: onCompletion)

        ServiceLocator.stores.dispatch(action)
    }
}

private extension ReviewsViewModel {
    enum Settings {
        static let placeholderRowsPerSection = [3]
        static let firstPage = 1
        static let pageSize = 25
    }

    struct Constants {
        static let section = "notifications"
    }
}
