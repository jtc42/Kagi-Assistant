//
//  ContentView.swift
//  Kagi Assistant
//
//  Created by James on 2026-03-22.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ChatViewModel()
    @State private var showingLogin = false
    @State private var searchFocusTrigger = false
    @State private var showModelPicker = false

    var body: some View {
        // New .task added here outside NavigationSplitView to check token immediately on launch
        NavigationSplitView {
            SidebarView(viewModel: viewModel, focusSearch: $searchFocusTrigger, showingLogin: $showingLogin)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            ChatView(viewModel: viewModel, showModelPicker: $showModelPicker, showingLogin: $showingLogin)
        }
        .sheet(isPresented: $showingLogin) {
            LoginSheet(viewModel: viewModel, isPresented: $showingLogin)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .background {
            Group {
                Button(action: { viewModel.createThread() }) { EmptyView() }
                    .keyboardShortcut("k", modifiers: .command)
                Button(action: { viewModel.createThread() }) { EmptyView() }
                    .keyboardShortcut("n", modifiers: .command)
                Button(action: { searchFocusTrigger.toggle() }) { EmptyView() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Button(action: { viewModel.internetAccess.toggle() }) { EmptyView() }
                    .keyboardShortcut("i", modifiers: .command)
                Button(action: { showModelPicker.toggle() }) { EmptyView() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button(action: {
                    if viewModel.selectedModelHasThinkingVariant {
                        viewModel.thinkingEnabled.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("t", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .task {
            if UserDefaults.standard.string(forKey: "kagi_session") == nil {
                showingLogin = true
            }
        }
        .onChange(of: viewModel.isAuthenticated) {
            if viewModel.isAuthenticated {
                showingLogin = false
            } else {
                showingLogin = true
            }
        }
    }
}

// MARK: - Login Sheet

struct LoginSheet: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var tokenInput = ""
    @State private var isLoggingIn = false
    @State private var showWebLogin = false

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text("Sign in to Kagi")
                    .font(.headline)

                Text("Enter your Kagi session token. You can find this in your browser cookies for kagi.com (cookie name: `kagi_session`). Or sign in with the in-app browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                SecureField("Session Token", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Sign In") {
                        isLoggingIn = true
                        Task {
                            await viewModel.login(token: tokenInput)
                            isLoggingIn = false
                            if viewModel.isAuthenticated {
                                isPresented = false
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tokenInput.isEmpty || isLoggingIn)
                }
                Button("Sign In with Browser") {
                    showWebLogin = true
                }
                .disabled(isLoggingIn)

                if isLoggingIn {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(24)
            .frame(maxWidth: 400)

            if showWebLogin {
                Color.black.opacity(0.3).ignoresSafeArea()
                LoginWebView { token in
                    showWebLogin = false
                    if let token, !token.isEmpty {
                        tokenInput = token
                        isLoggingIn = true
                        Task {
                            await viewModel.login(token: token)
                            isLoggingIn = false
                            if viewModel.isAuthenticated {
                                isPresented = false
                            }
                        }
                    }
                }
                .frame(width: 420, height: 640)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 16)
                .padding(24)
            }
        }
    }
}

#Preview {
    ContentView()
}
