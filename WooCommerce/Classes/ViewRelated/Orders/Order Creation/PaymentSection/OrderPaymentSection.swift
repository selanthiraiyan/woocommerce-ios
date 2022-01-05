import SwiftUI

/// Represents the Payment section in an order
///
struct OrderPaymentSection: View {
    /// View model to drive the view content
    let viewModel: NewOrderViewModel.PaymentDataViewModel

    ///   Environment safe areas
    ///
    @Environment(\.safeAreaInsets) var safeAreaInsets: EdgeInsets

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: .zero) {
            Text(Localization.payment)
                .headlineStyle()
                .padding()

            TitleAndValueRow(title: Localization.productsTotal, value: .content(viewModel.itemsTotal), selectable: false) {}

            TitleAndValueRow(title: Localization.orderTotal, value: .content(viewModel.orderTotal), bold: true, selectable: false) {}

            Text(Localization.taxesInfo)
                .footnoteStyle()
                .padding([.horizontal, .bottom])
        }
        .padding(.horizontal, insets: safeAreaInsets)
        .background(Color(.listForeground))

        Divider()
    }
}

// MARK: Constants
private extension OrderPaymentSection {
    enum Localization {
        static let payment = NSLocalizedString("Payment", comment: "Title text of the section that shows Payment details when creating a new order")
        static let productsTotal = NSLocalizedString("Products Total", comment: "Label for the row showing the total cost of products in the order")
        static let orderTotal = NSLocalizedString("Order Total", comment: "Label for the the row showing the total cost of the order")
        static let taxesInfo = NSLocalizedString("Total excluding taxes. Taxes will be automatically calculated based on your store settings.",
                                                 comment: "Information about taxes and the order total when creating a new order")
    }
}

struct OrderPaymentSection_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = NewOrderViewModel.PaymentDataViewModel(itemsTotal: "20.00", orderTotal: "20.00")

        OrderPaymentSection(viewModel: viewModel)
            .previewLayout(.sizeThatFits)
    }
}
