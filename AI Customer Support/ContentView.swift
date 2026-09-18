import SwiftUI
import Combine

// MARK: - Chat View Model Linked with APIService

@MainActor
final class ChatViewModel: ObservableObject {
    
    @Published var messages: [Message] = [] {
        didSet {
            ChatStorage.saveMessages(messages)
        }
    }
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var showClearAlert: Bool = false
    
    private(set) var sessionID: String = ""

    static let welcomeMessage = Message(
        text: """
        Hello! 👋

        I'm your AI Customer Support Agent. I can help you with orders, delivery, returns, refunds, cancellations and more.
        """,
        isUser: false
    )

    init() {
        self.sessionID = ChatStorage.getSessionID()
        let saved = ChatStorage.loadMessages()
        if !saved.isEmpty {
            self.messages = saved
        } else {
            self.messages = [Self.welcomeMessage]
        }
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func sendQuickMessage(_ text: String) {
        guard !isLoading else { return }
        inputText = text
        sendMessage()
    }

    func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let userMessage = Message(text: trimmedText, isUser: true)
        messages.append(userMessage)

        inputText = ""
        isLoading = true

        Task {
            do {
                // Backend API Call
                let response = try await APIService.shared.sendMessage(
                    message: trimmedText,
                    sessionID: sessionID
                )
                
                let aiMessage = Message(
                    text: response.response,
                    isUser: false,
                    order: response.order
                )
                self.messages.append(aiMessage)
            } catch {
                let errorMessage = Message(
                    text: "⚠️ Backend Error: \(error.localizedDescription)",
                    isUser: false
                )
                self.messages.append(errorMessage)
            }
            self.isLoading = false
        }
    }

    func clearChat() {
        let currentSession = sessionID
        
        // Front-end state reset
        inputText = ""
        ChatStorage.clearMessages()
        sessionID = ChatStorage.resetSession()
        messages = [Self.welcomeMessage]
        
        // Backend clear call
        Task {
            try? await APIService.shared.clearChatSession(sessionID: currentSession)
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @FocusState private var isInputFocused: Bool
    @State private var showChangePassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                #if os(iOS)
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                #else
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()
                #endif

                VStack(spacing: 0) {
                    header
                    Divider()
                    chatArea
                    Divider()
                    inputArea
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .alert("Clear Conversation?", isPresented: $viewModel.showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearChat()
                }
            } message: {
                Text("This will remove the current conversation from both local storage and server.")
            }
        }
    }
}

// MARK: - Header (Connected with AuthManager)

private extension ContentView {
    var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Customer Support")
                    .font(.system(size: 18, weight: .bold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)

                    Text("AI Assistant • Online")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Top Menu dropdown with Clear Chat & Logout
            Menu {
                Button(role: .destructive) {
                    viewModel.showClearAlert = true
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }

                Divider()

                Button {
                    showChangePassword = true
                } label: {
                    Label("Change Password", systemImage: "key.fill")
                }

                Button(role: .destructive) {
                    withAnimation {
                        authManager.logout()
                    }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
    }
}

// MARK: - Chat Area

private extension ContentView {
    var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    welcomeSection

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        TypingIndicator()
                            .id("typingIndicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("typingIndicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

// MARK: - Welcome & Quick Actions

private extension ContentView {
    var welcomeSection: some View {
        Group {
            if viewModel.messages.count <= 1 {
                VStack(spacing: 18) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)

                    VStack(spacing: 7) {
                        Text("How can I help you?")
                            .font(.system(size: 24, weight: .bold))

                        Text("Ask me anything about your order or support request.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    quickActions
                }
                .padding(.top, 28)
                .padding(.bottom, 8)
            }
        }
    }

    var quickActions: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            QuickAction(title: "Track Order", icon: "shippingbox.fill") {
                viewModel.sendQuickMessage("I want to track my order")
            }
            QuickAction(title: "Delivery", icon: "truck.box.fill") {
                viewModel.sendQuickMessage("What are the delivery options?")
            }
            QuickAction(title: "Refund", icon: "arrow.uturn.backward.circle.fill") {
                viewModel.sendQuickMessage("How can I request a refund?")
            }
            QuickAction(title: "Return", icon: "arrow.left.arrow.right") {
                viewModel.sendQuickMessage("How can I return my product?")
            }
        }
    }
}

// MARK: - Input Area

private extension ContentView {
    var inputArea: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask anything...", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .disabled(viewModel.isLoading)
                    .submitLabel(.send)
                    .onSubmit {
                        guard viewModel.canSend else { return }
                        isInputFocused = false
                        viewModel.sendMessage()
                    }

                if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }

            Button {
                isInputFocused = false
                viewModel.sendMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.canSend ? Color.blue : Color.gray.opacity(0.25))

                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(viewModel.canSend ? .white : .secondary)
                }
                .frame(width: 46, height: 46)
            }
            .disabled(!viewModel.canSend)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Subviews (Message Bubble, Typing, Order Cards, Quick Action)

struct MessageBubble: View {
    let message: Message

    var body: some View {
        VStack(
            alignment: message.isUser ? .trailing : .leading,
            spacing: 8
        ) {
            HStack(alignment: .bottom, spacing: 8) {
                if !message.isUser { avatar }

                VStack(
                    alignment: message.isUser ? .trailing : .leading,
                    spacing: 7
                ) {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if let order = message.order {
                        OrderCard(order: order)
                    }
                }

                if message.isUser { userAvatar }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private var avatar: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(
                    colors: [.blue, .indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }

    private var userAvatar: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color.blue)
            .clipShape(Circle())
    }

    private var bubbleBackground: some View {
        Group {
            if message.isUser {
                LinearGradient(
                    colors: [.blue, .indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.gray.opacity(0.15)
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 7, height: 7)
                        .offset(y: animate ? -4 : 3)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.12),
                            value: animate
                        )
                }

                Text("AI is thinking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
        .onAppear { animate = true }
    }
}

struct QuickAction: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(13)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.blue.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            orderHeader

            Divider()
                .padding(.vertical, 16)

            VStack(spacing: 15) {
                InfoRow(
                    title: "Product",
                    value: order.product.isEmpty ? "N/A" : order.product,
                    icon: "cube.box.fill"
                )

                // The current backend doesn't fill in customer_name (it's
                // always ""), so this row would otherwise show a
                // meaningless "N/A" on every order card. Hide it until
                // the backend actually returns a name.
                if !order.customerName.isEmpty {
                    InfoRow(
                        title: "Customer Name",
                        value: order.customerName,
                        icon: "person.fill"
                    )
                }

                InfoRow(
                    title: "Delivery",
                    value: formattedDate(order.deliveryDate),
                    icon: "calendar"
                )

                InfoRow(
                    title: "Total",
                    value: order.price.formatted(.currency(code: "INR")),
                    icon: "indianrupeesign.circle.fill"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color.gray.opacity(0.08))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
    }

    private var orderHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.blue.opacity(0.10))

                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.blue)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text("Order #\(order.orderId.isEmpty ? "N/A" : order.orderId)")
                    .font(.system(size: 16, weight: .bold))

                Text("Order Details")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(order.status.isEmpty ? "Processing" : order.status.capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func formattedDate(_ value: String) -> String {
        guard !value.isEmpty else { return "Not available" }
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.10))

                Image(systemName: icon)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.blue)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
}
