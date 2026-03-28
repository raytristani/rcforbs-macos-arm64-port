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
                .background(
                    LinearGradient(colors: [Color.chassisGradientFrom, Color.chassisGradientTo], startPoint: .top, endPoint: .bottom)
                )
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.btnBorder), alignment: .bottom)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(cm.chatMessages) { msg in
                            if msg.isSystem {
                                Text(msg.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#888666"))
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
                                .foregroundColor(Color(hex: "#666666"))
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
                    .background(
                        LinearGradient(colors: [Color(hex: "#555444"), Color(hex: "#444333")], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.btnBorder, lineWidth: 1))
                    .cornerRadius(4)

                Button("Send") { handleSend() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Color.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(colors: [Color.chassisGradientFrom, Color.chassisGradientTo], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.btnBorder, lineWidth: 1))
                    .cornerRadius(4)
            }
            .padding(8)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#555444")), alignment: .top)
        }
    }

    private func handleSend() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        cm.sendCommand(CommandParser.chatMessage(text))
        input = ""
    }
}
