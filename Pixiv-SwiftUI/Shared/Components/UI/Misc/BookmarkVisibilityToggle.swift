import SwiftUI

struct BookmarkVisibilityToggle: View {
    @Binding var selectedRestrict: TypeFilterButton.RestrictType?
    var isAvailable: Bool

    var body: some View {
        Button {
            withAnimation {
                selectedRestrict = selectedRestrict == .publicAccess
                    ? .privateAccess
                    : .publicAccess
            }
        } label: {
            Image(systemName: selectedRestrict == .publicAccess
                ? "heart.fill"
                : "heart.slash.fill")
        }
        .help(selectedRestrict == .publicAccess
            ? String(localized: "当前：公开收藏，点击切换为非公开")
            : String(localized: "当前：非公开收藏，点击切换为公开"))
        .opacity(isAvailable ? 1 : 0)
        .disabled(!isAvailable)
    }
}

#Preview {
    BookmarkVisibilityToggle(
        selectedRestrict: .constant(.publicAccess),
        isAvailable: true
    )
}
