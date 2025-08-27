import SwiftUI

enum UI {
  static let cardRadius: CGFloat = 16
  static let cardShadow: CGFloat = 0.08   // shadow opacity
  static let hPad: CGFloat = 16
  static let vPad: CGFloat = 12
}

extension View {
  func cardBackground() -> some View {
    self
      .background(RoundedRectangle(cornerRadius: UI.cardRadius).fill(Color(.secondarySystemBackground)))
      .overlay(RoundedRectangle(cornerRadius: UI.cardRadius).stroke(Color.black.opacity(0.06)))
      .shadow(color: .black.opacity(UI.cardShadow), radius: 8, x: 0, y: 2)
  }
}

extension Color {
  static let primaryBlue = Color.blue
  static let secondaryPurple = Color.purple
  static let accentGreen = Color.green
  static let backgroundGray = Color(.systemGray6)
  static let textGray = Color(.systemGray)
}