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
    @State private var showAccountPopover = false
    @State private var focusTrigger = false
    @State private var showingFilePicker = false
    @State private var inputHeight: CGFloat = 36
    @State private var editContext: MessageEditContext?
    @State private var preEditMessageText = ""
    @State private var preEditComposerAttachments: [ChatAttachment] = []

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
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            accountControl
                            ModelPicker(viewModel: viewModel, showPopover: $showModelPicker)
                            Button {
                                viewModel.createThread()
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .imageScale(.large)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .padding(4)
                            }
                            .buttonStyle(.automatic)
                            .help("New Chat")
                            .accessibilityLabel("New Chat")
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

    @ViewBuilder
    private var accountControl: some View {
        if viewModel.isAuthenticated {
            Button {
                showAccountPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .imageScale(.large)
                        .frame(width: 44, height: 44)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
                .padding(4)
            }
            .buttonStyle(.automatic)
            .help("Account")
            .popover(isPresented: $showAccountPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    if let email = viewModel.userEmail {
                        Text(email)
                            .font(.callout)
                    }

                    Button("Sign Out") {
                        showAccountPopover = false
                        Task { await viewModel.logout() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                .frame(minWidth: 220, alignment: .leading)
            }
            .accessibilityLabel("Account")
        } else {
            Button {
                showingLogin = true
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .imageScale(.large)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .padding(4)
            }
            .buttonStyle(.automatic)
            .help("Sign In")
            .accessibilityLabel("Sign In")
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

            HStack(alignment: .bottom, spacing: 8) {
                composerIconButton(
                    systemName: "plus.circle.fill",
                    label: "Attach files",
                    foregroundStyle: .primary
                ) {
                    showingFilePicker = true
                }
                .disabled(viewModel.isStreaming || editContext != nil)

                composerIconButton(
                    systemName: viewModel.internetAccess ? "network" : "network.slash",
                    label: viewModel.internetAccess ? "Internet access enabled" : "Internet access disabled",
                    foregroundStyle: viewModel.internetAccess ? .primary : .secondary
                ) {
                    viewModel.internetAccess.toggle()
                }

                if viewModel.selectedModelHasThinkingVariant {
                    composerIconButton(
                        systemName: viewModel.thinkingEnabled ? "lightbulb.fill" : "lightbulb",
                        label: viewModel.thinkingEnabled ? "Thinking enabled" : "Enable thinking",
                        foregroundStyle: viewModel.thinkingEnabled ? .yellow : .secondary
                    ) {
                        viewModel.thinkingEnabled.toggle()
                    }
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
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
                )
                .accessibilityLabel("Message input")

                if viewModel.isStreaming {
                    stopButton
                } else {
                    sendButton
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.bar)
    }

    private func composerIconButton(
        systemName: String,
        label: String,
        foregroundStyle: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(foregroundStyle)
                .frame(width: 34, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var canSend: Bool {
        if editContext != nil {
            return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.composerAttachments.isEmpty
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(canSend ? Color.accentColor : Color.secondary.opacity(0.35)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .help("Send message")
        .accessibilityLabel("Send message")
    }

    private var stopButton: some View {
        Button {
            viewModel.stopGeneration()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.red))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Stop generation")
        .accessibilityLabel("Stop generation")
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
        self.editContext = nil
        messageText = preEditMessageText
        viewModel.composerAttachments = preEditComposerAttachments
        preEditMessageText = ""
        preEditComposerAttachments = []
    }
}

