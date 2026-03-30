import SwiftUI

struct ChatView: View {
    @EnvironmentObject var cm: ConnectionManager
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Chat")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.chassisGradientTo)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.btnBorder), alignment: .bottom)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(cm.chatMessages) { msg in
                            if msg.isSystem {
                                Text(msg.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(.mutedForeground)
                                    .italic()
                            } else {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("\(msg.user):")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.cream)
                                    Text(msg.text)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.creamDark)
                                }
                            }
                        }

                        if cm.chatMessages.isEmpty {
                            Text("No messages yet")
                                .font(.system(size: 12))
                                .foregroundColor(.mutedForeground.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 20)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: cm.chatMessages.count) {
                    if let last = cm.chatMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Input
            HStack(spacing: 4) {
                StyledTextField(placeholder: "Type a message...", text: $input, onSubmit: handleSend)
                    .frame(height: 24)
                    .padding(.horizontal, 8)
                    .background(Color.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.btnBorder, lineWidth: 1))
                    .cornerRadius(8)

                Button("Send") { handleSend() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Color.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.chassisGradientTo)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.btnBorder, lineWidth: 1))
                    .cornerRadius(8)
            }
            .padding(8)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.border), alignment: .top)
        }
    }

    private func handleSend() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        cm.sendCommand(CommandParser.chatMessage(text))
        input = ""
    }
}
