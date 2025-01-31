import Foundation
import Yosemite

/// View model for `ProductRow`.
///
final class ProductRowViewModel: ObservableObject, Identifiable {
    private let currencyFormatter: CurrencyFormatter

    /// Whether the product quantity can be changed.
    /// Controls whether the stepper is rendered.
    ///
    let canChangeQuantity: Bool

    /// Unique ID for the view model.
    ///
    let id: String

    // MARK: Product properties

    /// ID for the `Product` or `ProductVariation`
    ///
    let productOrVariationID: Int64

    /// The first available product image
    ///
    let imageURL: URL?

    /// Product name
    ///
    let name: String

    /// Product SKU
    ///
    private let sku: String?

    /// Product price
    ///
    private let price: String?

    /// Product stock status
    ///
    private let stockStatus: ProductStockStatus

    /// Product stock quantity
    ///
    private let stockQuantity: Decimal?

    /// Whether the product's stock quantity is managed
    ///
    private let manageStock: Bool

    /// Label showing product details: stock status, price, and variations (if any).
    ///
    lazy var productDetailsLabel: String = {
        let stockLabel = createStockText()
        let priceLabel = createPriceText()
        let variationsLabel = createVariationsText()

        return [stockLabel, priceLabel, variationsLabel]
            .compactMap({ $0 })
            .joined(separator: " • ")
    }()

    /// Label showing product SKU
    ///
    lazy var skuLabel: String = {
        guard let sku = sku, sku.isNotEmpty else {
            return ""
        }
        return String.localizedStringWithFormat(Localization.skuFormat, sku)
    }()

    /// Quantity of product in the order
    ///
    @Published private(set) var quantity: Decimal

    /// Minimum value of the product quantity
    ///
    private let minimumQuantity: Decimal = 1

    /// Whether the quantity can be decremented.
    ///
    var shouldDisableQuantityDecrementer: Bool {
        quantity <= minimumQuantity
    }

    /// Number of variations in a variable product
    ///
    let numberOfVariations: Int

    init(id: String? = nil,
         productOrVariationID: Int64,
         name: String,
         sku: String?,
         price: String?,
         stockStatusKey: String,
         stockQuantity: Decimal?,
         manageStock: Bool,
         quantity: Decimal = 1,
         canChangeQuantity: Bool,
         imageURL: URL?,
         numberOfVariations: Int = 0,
         currencyFormatter: CurrencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)) {
        self.id = id ?? productOrVariationID.description
        self.productOrVariationID = productOrVariationID
        self.name = name
        self.sku = sku
        self.price = price
        self.stockStatus = .init(rawValue: stockStatusKey)
        self.stockQuantity = stockQuantity
        self.manageStock = manageStock
        self.quantity = quantity
        self.canChangeQuantity = canChangeQuantity
        self.imageURL = imageURL
        self.currencyFormatter = currencyFormatter
        self.numberOfVariations = numberOfVariations
    }

    /// Initialize `ProductRowViewModel` with a `Product`
    ///
    convenience init(id: String? = nil,
                     product: Product,
                     quantity: Decimal = 1,
                     canChangeQuantity: Bool,
                     currencyFormatter: CurrencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)) {
        // Don't show any price for variable products; price will be shown for each product variation.
        let price: String?
        if product.productType == .variable {
            price = nil
        } else {
            price = product.price
        }

        self.init(id: id,
                  productOrVariationID: product.productID,
                  name: product.name,
                  sku: product.sku,
                  price: price,
                  stockStatusKey: product.stockStatusKey,
                  stockQuantity: product.stockQuantity,
                  manageStock: product.manageStock,
                  quantity: quantity,
                  canChangeQuantity: canChangeQuantity,
                  imageURL: product.imageURL,
                  numberOfVariations: product.variations.count,
                  currencyFormatter: currencyFormatter)
    }

    /// Initialize `ProductRowViewModel` with a `ProductVariation`
    ///
    convenience init(id: String? = nil,
                     productVariation: ProductVariation,
                     allAttributes: [ProductAttribute],
                     quantity: Decimal = 1,
                     canChangeQuantity: Bool,
                     currencyFormatter: CurrencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)) {
        let variationAttributes = allAttributes.map { attribute -> VariationAttributeViewModel in
            guard let variationAttribute = productVariation.attributes.first(where: { $0.id == attribute.attributeID && $0.name == attribute.name }) else {
                return VariationAttributeViewModel(name: attribute.name)
            }
            return VariationAttributeViewModel(productVariationAttribute: variationAttribute)
        }
        let name = variationAttributes.map { $0.nameOrValue }.joined(separator: " - ")

        let imageURL: URL?
        if let encodedImageURLString = productVariation.image?.src.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            imageURL = URL(string: encodedImageURLString)
        } else {
            imageURL = nil
        }

        self.init(id: id,
                  productOrVariationID: productVariation.productVariationID,
                  name: name,
                  sku: productVariation.sku,
                  price: productVariation.price,
                  stockStatusKey: productVariation.stockStatus.rawValue,
                  stockQuantity: productVariation.stockQuantity,
                  manageStock: productVariation.manageStock,
                  quantity: quantity,
                  canChangeQuantity: canChangeQuantity,
                  imageURL: imageURL,
                  currencyFormatter: currencyFormatter)
    }

    /// Create the stock text based on a product's stock status/quantity.
    ///
    private func createStockText() -> String {
        switch stockStatus {
        case .inStock:
            if let stockQuantity = stockQuantity, manageStock {
                let localizedStockQuantity = NumberFormatter.localizedString(from: stockQuantity as NSDecimalNumber, number: .decimal)
                return String.localizedStringWithFormat(Localization.stockFormat, localizedStockQuantity)
            } else {
                return stockStatus.description
            }
        default:
            return stockStatus.description
        }
    }

    /// Create the price text based on a product's price.
    ///
    private func createPriceText() -> String? {
        guard let price = price else {
            return nil
        }
        let unformattedPrice = price.isNotEmpty ? price : "0"
        return currencyFormatter.formatAmount(unformattedPrice)
    }

    /// Create the variations text for a variable product.
    ///
    private func createVariationsText() -> String? {
        guard numberOfVariations > 0 else {
            return nil
        }
        let format = String.pluralize(numberOfVariations, singular: Localization.singleVariation, plural: Localization.pluralVariations)
        return String.localizedStringWithFormat(format, numberOfVariations)
    }

    /// Increment the product quantity.
    ///
    func incrementQuantity() {
        quantity += 1
    }

    /// Decrement the product quantity.
    ///
    func decrementQuantity() {
        guard quantity > minimumQuantity else {
            return
        }
        quantity -= 1
    }
}

private extension ProductRowViewModel {
    enum Localization {
        static let stockFormat = NSLocalizedString("%1$@ in stock", comment: "Label about product's inventory stock status shown during order creation")
        static let skuFormat = NSLocalizedString("SKU: %1$@", comment: "SKU label in order details > product row. The variable shows the SKU of the product.")
        static let singleVariation = NSLocalizedString("%ld variation",
                                                       comment: "Label for one product variation when showing details about a variable product")
        static let pluralVariations = NSLocalizedString("%ld variations",
                                                        comment: "Label for multiple product variations when showing details about a variable product")
    }
}
