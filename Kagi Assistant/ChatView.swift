//
//  ChatView.swift
//  Kagi Assistant
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var showModelPicker: Bool
    @Binding var showingLogin: Bool
    @State private var messageText = ""
    @State private var shouldAutoScroll = true
    @State private var focusTrigger = false
    @State private var showingFilePicker = false
    @State private var inputHeight: CGFloat = 36
    @State private var editContext: MessageEditContext?
    @State private var preEditMessageText = ""
    @State private var preEditComposerAttachments: [ChatAttachment] = []
    private let composerControlHeight: CGFloat = 44
    private var singleLineInputHeight: CGFloat { composerControlHeight }
    private var textFieldCornerRadius: CGFloat { singleLineInputHeight / 2 }

    var body: some View {
        if let thread = viewModel.selectedThread {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(thread.messages) { message in
                                MessageBubble(message: message, onEdit: editAction(for: message))
                                    .id(message.id)
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                    .onScrollGeometryChange(for: Bool.self) { geo in
                        geo.contentOffset.y + geo.containerSize.height >= geo.contentSize.height - 20
                    } action: { _, isAtBottom in
                        shouldAutoScroll = isAtBottom
                    }
                    .onChange(of: thread.messages.count) {
                        if shouldAutoScroll {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: thread.messages.last?.content) {
                        if shouldAutoScroll {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .navigationTitle(thread.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .safeAreaInset(edge: .bottom) {
                        inputArea
                    }
                    .fileImporter(
                        isPresented: $showingFilePicker,
                        allowedContentTypes: [.item],
                        allowsMultipleSelection: true
                    ) { result in
                        if case .success(let urls) = result {
                            viewModel.addAttachments(from: urls)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ModelPicker(viewModel: viewModel, showPopover: $showModelPicker)
                        }
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                viewModel.createThread()
                            } label: {
                                Label("New Chat", systemImage: "square.and.pencil")
                            }
                            .help("New Chat")
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No Chat Selected",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Select a chat from the sidebar or create a new one.")
            )
        }
    }

    private var inputArea: some View {
        VStack(spacing: 8) {
            if editContext != nil {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                    Text("Editing message")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", action: cancelEditing)
                        .font(.footnote.weight(.medium))
                }
                .padding(.horizontal, 16)
            }

            if !viewModel.composerAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.composerAttachments) { attachment in
                            AttachmentChip(attachment: attachment, style: .composer) {
                                viewModel.removeComposerAttachment(attachment)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Button {
                    showingFilePicker = true
                } label: {
                    composerButtonLabel("Attach files", systemImage: "plus")
                }
                .disabled(viewModel.isStreaming || editContext != nil)
                .help("Attach files")

                Button {
                    viewModel.internetAccess.toggle()
                } label: {
                    composerButtonLabel(
                        viewModel.internetAccess ? "Internet access enabled" : "Internet access disabled",
                        systemImage: viewModel.internetAccess ? "network" : "network.slash"
                    )
                }
                .help(viewModel.internetAccess ? "Internet access enabled" : "Internet access disabled")

                if viewModel.selectedModelHasThinkingVariant {
                    Button {
                        viewModel.thinkingEnabled.toggle()
                    } label: {
                        composerButtonLabel(
                            viewModel.thinkingEnabled ? "Thinking enabled" : "Enable thinking",
                            systemImage: viewModel.thinkingEnabled ? "lightbulb.fill" : "lightbulb"
                        )
                    }
                    .help(viewModel.thinkingEnabled ? "Thinking enabled" : "Enable thinking")
                }

                AutoResizingTextView(
                    text: $messageText,
                    desiredHeight: $inputHeight,
                    maxLines: 6,
                    placeholder: "Message",
                    requestFocus: focusTrigger,
                    onSend: send,
                    onPasteImages: { images in
                        viewModel.addPastedImages(images)
                    }
                )
                .frame(height: inputHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: composerControlHeight, alignment: .leading)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: textFieldCornerRadius, style: .continuous))
                .accessibilityLabel("Message input")
                .layoutPriority(1)

                if viewModel.isStreaming {
                    Button(role: .destructive) {
                        viewModel.stopGeneration()
                    } label: {
                        composerButtonLabel("Stop generation", systemImage: "stop.fill")
                    }
                    .help("Stop generation")
                } else {
                    Button {
                        send()
                    } label: {
                        composerButtonLabel("Send message", systemImage: "arrow.up")
                    }
                    .disabled(!canSend)
                    .help("Send message")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.regular)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func composerButtonLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .imageScale(.medium)
            .frame(width: composerControlHeight, height: composerControlHeight)
    }

    private var canSend: Bool {
        if editContext != nil {
            return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.composerAttachments.isEmpty
    }

    private func send() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = viewModel.composerAttachments
        if let editContext {
            guard !viewModel.isStreaming, !trimmedText.isEmpty else { return }
            let text = messageText
            messageText = ""
            viewModel.clearComposerAttachments()
            self.editContext = nil
            preEditMessageText = ""
            preEditComposerAttachments = []
            viewModel.resendEditedMessage(text, context: editContext)
            return
        }

        guard !viewModel.isStreaming,
              !trimmedText.isEmpty || !attachments.isEmpty else { return }
        let text = messageText
        messageText = ""
        viewModel.clearComposerAttachments()
        viewModel.sendMessage(text, attachments: attachments)
    }

    private func editAction(for message: ChatMessage) -> (() -> Void)? {
        guard message.role == .user, !viewModel.isStreaming, editContext == nil else { return nil }
        return {
            beginEditing(message)
        }
    }

    private func beginEditing(_ message: ChatMessage) {
        guard let context = viewModel.beginEditingUserMessage(message) else { return }
        preEditMessageText = messageText
        preEditComposerAttachments = viewModel.composerAttachments
        editContext = context
        messageText = context.content
        viewModel.clearComposerAttachments()
        focusTrigger.toggle()
    }

    private func cancelEditing() {
        guard let context = editContext else { return }
        viewModel.cancelEditingUserMessage(context: context)
        editContext = nil
        messageText = preEditMessageText
        viewModel.composerAttachments = preEditComposerAttachments
        preEditMessageText = ""
        preEditComposerAttachments = []
    }
}
