import XCTest
@testable import Networking

/// SiteSettingsRemote Unit Tests
///
class SiteSettingsRemoteTests: XCTestCase {

    /// Dummy Network Wrapper
    ///
    let network = MockNetwork()

    /// Dummy Site ID
    ///
    let sampleSiteID: Int64 = 1234

    /// Repeat always!
    ///
    override func setUp() {
        network.removeAllSimulatedResponses()
    }

    // MARK: - Load general settings tests

    /// Verifies that loadGeneralSettings properly parses the sample response.
    ///
    func testLoadGeneralSettingsProperlyReturnsParsedSettings() {
        let remote = SiteSettingsRemote(network: network)
        let expectation = self.expectation(description: "Load site settings")

        network.simulateResponse(requestUrlSuffix: "settings/general", filename: "settings-general")
        remote.loadGeneralSettings(for: sampleSiteID) { (siteSettings, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(siteSettings)
            XCTAssertEqual(siteSettings?.count, 20)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that loadGeneralSettings properly relays Networking Layer errors.
    ///
    func testLoadGeneralSettingsProperlyRelaysNetwokingErrors() {
        let remote = SiteSettingsRemote(network: network)
        let expectation = self.expectation(description: "Load site settings contains errors")

        remote.loadGeneralSettings(for: sampleSiteID) { (siteSettings, error) in
            XCTAssertNil(siteSettings)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    // MARK: - Load product settings tests

    /// Verifies that `loadProductSettings` properly parses the sample response.
    ///
    func testLoadProductSettingsProperlyReturnsParsedSettings() {
        let remote = SiteSettingsRemote(network: network)
        let expectation = self.expectation(description: "Load product settings")

        network.simulateResponse(requestUrlSuffix: "settings/products", filename: "settings-product")
        remote.loadProductSettings(for: sampleSiteID) { (siteSettings, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(siteSettings)
            XCTAssertEqual(siteSettings?.count, 23)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `loadProductSettings` properly relays Networking Layer errors.
    ///
    func testLoadProductSettingsProperlyRelaysNetwokingErrors() {
        let remote = SiteSettingsRemote(network: network)
        let expectation = self.expectation(description: "Load product settings contains errors")

        remote.loadProductSettings(for: sampleSiteID) { (siteSettings, error) in
            XCTAssertNil(siteSettings)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    // MARK: - Load advanced settings tests

    func test_load_advanced_settings_properly_returns_parsed_settings() throws {
        // Given
        network.simulateResponse(requestUrlSuffix: "settings/advanced", filename: "settings-advanced")
        let remote = SiteSettingsRemote(network: network)

        // When
        let result: Result<[Networking.SiteSetting], Error> = waitFor { promise in
            remote.loadAdvancedSettings(for: self.sampleSiteID) { result in
                promise(result)
            }
        }

        // Then
        let settings = try result.get()
        XCTAssertEqual(settings.count, 2)
    }
}
