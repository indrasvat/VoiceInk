import SwiftUI

#if LOCAL_BUILD
private let appIconName = "AppIcon-Dev"
#else
private let appIconName = "AppIcon"
#endif

struct AppIconView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 160, height: 160)
                .blur(radius: 30)

            if let image = NSImage(named: appIconName) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .accentColor.opacity(0.3), radius: 20)
            }
        }
    }
}
