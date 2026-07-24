import SwiftUI

struct WatchEmptyStateView: View {
  let systemImage: String
  let title: String
  let message: String

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 28, weight: .semibold))
        .foregroundColor(Color(red: 111 / 255, green: 167 / 255, blue: 114 / 255))

      Text(title)
        .font(.headline)
        .multilineTextAlignment(.center)

      Text(message)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
