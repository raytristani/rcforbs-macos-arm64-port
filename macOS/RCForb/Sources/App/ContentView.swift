import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Error banner
                if let error = connectionManager.errorMessage {
                    HStack {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(Color.errorText)
                        Spacer()
                        Button("Dismiss") {
                            connectionManager.errorMessage = nil
                        }
                        .font(.system(size: 13))
                        .foregroundColor(Color.errorDismiss)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.errorBg)
                }

                // Main content based on connection state
                switch connectionManager.connectionState {
                case .disconnected, .failed:
                    LoginView()
                case .authenticating:
                    loadingView("Authenticating...")
                case .authenticated:
                    LobbyView()
                case .connecting:
                    loadingView("Connecting to station...")
                case .connected:
                    RadioView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadingView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 18))
                .foregroundColor(Color.cream)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
