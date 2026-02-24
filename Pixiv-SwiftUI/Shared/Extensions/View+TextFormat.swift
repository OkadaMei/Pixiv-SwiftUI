import SwiftUI

extension View {
    @ViewBuilder
    func autocapitalizationDisabled() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func urlKeyboardType() -> some View {
        #if os(iOS)
        self.keyboardType(.URL)
        #else
        self
        #endif
    }
}
