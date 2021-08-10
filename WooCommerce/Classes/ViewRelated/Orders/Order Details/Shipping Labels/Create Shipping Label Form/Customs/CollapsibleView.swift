import SwiftUI

struct CollapsibleView<Label: View, Content: View>: View {
    private let label: Label
    private let content: Content
    private let safeAreaInsets: EdgeInsets
    private let isCollapsible: Bool

    @State private var isCollapsed = false

    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 8

    init(isCollapsible: Bool = true, safeAreaInsets: EdgeInsets = .zero, @ViewBuilder label: () -> Label, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
        self.safeAreaInsets = safeAreaInsets
        self.isCollapsible = isCollapsible
    }

    var body: some View {
        VStack(spacing: verticalPadding) {
            Button(action: {
                guard isCollapsible else { return }
                withAnimation {
                    isCollapsed.toggle()
                }
            }, label: {
                HStack {
                    label
                    Spacer()
                    if isCollapsible {
                        Image(uiImage: isCollapsed ? .chevronDownImage : .chevronUpImage)
                    }
                }
            })
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, horizontalPadding)
            .padding(.horizontal, insets: safeAreaInsets)

            Divider()

            if !isCollapsed {
                content
            }
        }
        .padding(.top, verticalPadding)
        .background(Color(.listForeground))
    }
}

struct CollapsibleView_Previews: PreviewProvider {
    static var previews: some View {
        CollapsibleView(label: {
            Text("Test")
                .font(.headline)
        }, content: {
            VStack {
                Text("Roses are red")
                Divider()
                Text("Violets are blue")
            }
        })
    }
}
