import SwiftUI

struct FAQView: View {
    @State private var expandedID: String?

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(FAQContent.items) { item in
                        FAQRow(
                            item: item,
                            isExpanded: expandedID == item.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedID = expandedID == item.id ? nil : item.id
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
            }
        }
        .navigationTitle("よくある質問")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Text(item.question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .fill(Color.white.opacity(0.75))
        )
    }
}

#Preview {
    NavigationStack { FAQView() }
}
