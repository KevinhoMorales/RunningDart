import SwiftUI

struct MembershipQRView: View {
  let imageBase64: String
  let displayName: String?

  var body: some View {
    VStack(spacing: 8) {
      if let displayName, !displayName.isEmpty {
        Text(displayName)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      if let image = QRImageDecoder.makeImage(fromBase64: imageBase64) {
        Image(uiImage: image)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .padding(8)
          .background(Color.white)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      } else {
        Text("No se pudo generar el QR.")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Text("Membresía SAINTS")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

enum QRImageDecoder {
  static func makeImage(fromBase64 value: String) -> UIImage? {
    guard let data = Data(base64Encoded: value) else {
      return nil
    }
    return UIImage(data: data)
  }
}
