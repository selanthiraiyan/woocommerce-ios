import Yosemite

final class MockOrders {
    let siteID: Int64 = 1234
    let orderID: Int64 = 5678

    /// Returns an `Order` with empty values. Use `copy()` to modify them.
    func empty() -> Order {
        Order(
            siteID: 0,
            orderID: 0,
            parentID: 0,
            customerID: 0,
            orderKey: "",
            number: "",
            status: .pending,
            currency: "",
            customerNote: nil,
            dateCreated: Date(),
            dateModified: Date(),
            datePaid: nil,
            discountTotal: "",
            discountTax: "",
            shippingTotal: "",
            shippingTax: "",
            total: "",
            totalTax: "",
            paymentMethodID: "",
            paymentMethodTitle: "",
            items: [],
            billingAddress: nil,
            shippingAddress: nil,
            shippingLines: [],
            coupons: [],
            refunds: [],
            fees: [],
            taxes: []
        )
    }

    func makeOrder(status: OrderStatusEnum = .processing,
                   items: [OrderItem] = [],
                   shippingLines: [ShippingLine] = sampleShippingLines(),
                   refunds: [OrderRefundCondensed] = [],
                   fees: [OrderFeeLine] = [],
                   taxes: [OrderTaxLine] = []) -> Order {
        return Order(siteID: siteID,
                     orderID: orderID,
                     parentID: 0,
                     customerID: 11,
                     orderKey: "abc123",
                     number: "963",
                     status: status,
                     currency: "USD",
                     customerNote: "",
                     dateCreated: date(with: "2018-04-03T23:05:12"),
                     dateModified: date(with: "2018-04-03T23:05:14"),
                     datePaid: date(with: "2018-04-03T23:05:14"),
                     discountTotal: "30.00",
                     discountTax: "1.20",
                     shippingTotal: "0.00",
                     shippingTax: "0.00",
                     total: "31.20",
                     totalTax: "1.20",
                     paymentMethodID: "stripe",
                     paymentMethodTitle: "Credit Card (Stripe)",
                     items: items,
                     billingAddress: sampleAddress(),
                     shippingAddress: sampleAddress(),
                     shippingLines: shippingLines,
                     coupons: [],
                     refunds: refunds,
                     fees: fees,
                     taxes: taxes)
    }

    func sampleOrder() -> Order {
        makeOrder()
    }

    func orderWithFees() -> Order {
        makeOrder(fees: sampleFeeLines())
    }

    func orderWithAPIRefunds() -> Order {
        makeOrder(refunds: refundsWithNegativeValue())
    }

    func orderWithTransientRefunds() -> Order {
        makeOrder(refunds: refundsWithPositiveValue())
    }

    func sampleOrderCreatedInCurrentYear() -> Order {
        return Order(siteID: siteID,
                     orderID: orderID,
                     parentID: 0,
                     customerID: 11,
                     orderKey: "abc123",
                     number: "963",
                     status: .processing,
                     currency: "USD",
                     customerNote: "",
                     dateCreated: Date(),
                     dateModified: Date(),
                     datePaid: Date(),
                     discountTotal: "30.00",
                     discountTax: "1.20",
                     shippingTotal: "0.00",
                     shippingTax: "0.00",
                     total: "31.20",
                     totalTax: "1.20",
                     paymentMethodID: "stripe",
                     paymentMethodTitle: "Credit Card (Stripe)",
                     items: [],
                     billingAddress: sampleAddress(),
                     shippingAddress: sampleAddress(),
                     shippingLines: Self.sampleShippingLines(),
                     coupons: [],
                     refunds: [],
                     fees: [],
                     taxes: [])
    }

    static func sampleShippingLines(cost: String = "133.00", tax: String = "0.00") -> [ShippingLine] {
        return [ShippingLine(shippingID: 123,
        methodTitle: "International Priority Mail Express Flat Rate",
        methodID: "usps",
        total: cost,
        totalTax: tax,
        taxes: [])]
    }

    func sampleFeeLines() -> [OrderFeeLine] {
        return [
            sampleFeeLine()
        ]
    }

    func sampleFeeLine(amount: String = "100.00") -> OrderFeeLine {
        return OrderFeeLine(feeID: 1,
                            name: "Fee",
                            taxClass: "",
                            taxStatus: .none,
                            total: amount,
                            totalTax: "",
                            taxes: [],
                            attributes: [])
    }

    func sampleAddress() -> Address {
        return Address(firstName: "Johnny",
                       lastName: "Appleseed",
                       company: "",
                       address1: "234 70th Street",
                       address2: "",
                       city: "Niagara Falls",
                       state: "NY",
                       postcode: "14304",
                       country: "US",
                       phone: "333-333-3333",
                       email: "scrambled@scrambled.com")
    }

    /// An order with broken elements, inspired by `broken-order.json`
    ///
    func brokenOrder() -> Order {
        return Order(siteID: 545,
                     orderID: 85,
                     parentID: 0,
                     customerID: 0,
                     orderKey: "abc123",
                     number: "85",
                     status: .custom("draft"),
                     currency: "GBP",
                     customerNote: "",
                     dateCreated: Date(),
                     dateModified: Date(),
                     datePaid: nil, // there is no paid date
                     discountTotal: "0.00",
                     discountTax: "0.00",
                     shippingTotal: "0.00",
                     shippingTax: "0.00",
                     total: "0.00",
                     totalTax: "0.00",
                     paymentMethodID: "",
                     paymentMethodTitle: "", // broken in the sense that there should be a payment title
                     items: [],
                     billingAddress: brokenAddress(), // empty address
                     shippingAddress: brokenAddress(),
                     shippingLines: brokenShippingLines(), // empty shipping
                     coupons: [],
                     refunds: [],
                     fees: [],
                     taxes: [])
    }

    /// An order with broken elements that hasn't been paid, inspired by `broken-order.json`
    ///
    func unpaidOrder() -> Order {
        return Order(siteID: 545,
                     orderID: 85,
                     parentID: 0,
                     customerID: 0,
                     orderKey: "abc123",
                     number: "85",
                     status: .custom("draft"),
                     currency: "GBP",
                     customerNote: "",
                     dateCreated: Date(),
                     dateModified: Date(),
                     datePaid: nil, // there is no paid date
                     discountTotal: "0.00",
                     discountTax: "0.00",
                     shippingTotal: "0.00",
                     shippingTax: "0.00",
                     total: "0.00",
                     totalTax: "0.00",
                     paymentMethodID: "cod",
                     paymentMethodTitle: "Cash on Delivery",
                     items: [],
                     billingAddress: brokenAddress(), // empty address
                     shippingAddress: brokenAddress(),
                     shippingLines: brokenShippingLines(), // empty shipping
                     coupons: [],
                     refunds: [],
                     fees: [],
                     taxes: [])
    }

    /// An address that may or may not be broken, that came from `broken-order.json`
    ///
    func brokenAddress() -> Address {
        return Address(firstName: "",
                       lastName: "",
                       company: "",
                       address1: "",
                       address2: "",
                       city: "",
                       state: "",
                       postcode: "",
                       country: "",
                       phone: "",
                       email: "")
    }

    /// A shipping line that may or may not be broken, from `broken-order.json`
    ///
    func brokenShippingLines() -> [ShippingLine] {
        return [ShippingLine(shippingID: 1,
                            methodTitle: "Shipping",
                            methodID: "",
                            total: "0.00",
                            totalTax: "0.00",
                            taxes: [])]
    }

    /// Converts a date string to a date type
    ///
    func date(with dateString: String) -> Date {
        guard let date = DateFormatter.Defaults.dateTimeFormatter.date(from: dateString) else {
            return Date()
        }
        return date
    }

    func refundsWithNegativeValue() -> [OrderRefundCondensed] {
        return [
            OrderRefundCondensed(refundID: 0, reason: nil, total: "-1.2"),
        ]
    }

    func refundsWithPositiveValue() -> [OrderRefundCondensed] {
        return [
            OrderRefundCondensed(refundID: 0, reason: nil, total: "1.2"),
        ]
    }
}
