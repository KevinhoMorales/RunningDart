import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var sessionStore: WatchSessionStore

  var body: some View {
    Group {
      switch sessionStore.state {
      case .loading:
        VStack(spacing: 8) {
          ProgressView()
          Text("Cargando...")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      case .loginRequired:
        WatchEmptyStateView(
          systemImage: "iphone.and.arrow.forward",
          title: "Inicia sesión",
          message: "Inicia sesión en SAINTS desde tu iPhone para ver tu QR."
        )
      case .membershipRequired:
        WatchEmptyStateView(
          systemImage: "person.crop.circle.badge.plus",
          title: "Membresía requerida",
          message: "Suscríbete a una membresía en la app de iPhone para acceder a tu QR."
        )
      case .qrReady:
        MembershipQRView(
          imageBase64: sessionStore.qrImageBase64 ?? "",
          displayName: sessionStore.displayName
        )
      }
    }
    .padding(.horizontal, 4)
    .onAppear {
      sessionStore.requestRefresh()
    }
  }
}
