import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var needsScroll = false
    
    var body: some View {
        VStack {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if chatViewModel.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Scroll setup
                }
                .onChange(of: chatViewModel.messages.count) { _ in
                    withAnimation {
                        if let lastMessage = chatViewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chatViewModel.isLoading) { isLoading in
                    if isLoading {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Error message
            if let errorMessage = chatViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Input area
            HStack {
                TextField("Ask about rooms...", text: $chatViewModel.currentInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        chatViewModel.sendMessage()
                    }
                
                Button(action: {
                    chatViewModel.sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(chatViewModel.currentInput.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(chatViewModel.currentInput.isEmpty || chatViewModel.isLoading)
            }
            .padding()
        }
        .navigationTitle("AI Assistant")
        .navigationBarItems(trailing: Button("Clear") {
            chatViewModel.clearChat()
        })
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .cornerRadius(4, corners: .bottomRight)
                    
                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain")
                            .foregroundColor(.green)
                            .padding(6)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(message.content)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                            .cornerRadius(4, corners: .bottomLeft)
                    }
                    
                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                }
                
                Spacer()
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animateOpacity = false
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain")
                    .foregroundColor(.green)
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Circle())
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .opacity(animateOpacity ? 0.3 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(0.2 * Double(index)),
                                value: animateOpacity
                            )
                    }
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(16)
                .cornerRadius(4, corners: .bottomLeft)
            }
            
            Spacer()
        }
        .onAppear {
            animateOpacity = true
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationView {
        ChatView()
            .environmentObject(ChatViewModel())
    }
}