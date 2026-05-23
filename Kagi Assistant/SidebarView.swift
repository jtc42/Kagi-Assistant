//
//  SidebarView.swift
//  Kagi Assistant
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SidebarView: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var focusSearch: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search threads...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .focused($isSearchFocused)
                .onSubmit {
                    guard !searchText.isEmpty else { return }
                    Task {
                        await viewModel.searchAndSelectThread(query: searchText)
                    }
                }
                .onChange(of: searchText) {
                    if searchText.isEmpty {
                        Task { await viewModel.fetchThreads() }
                    }
                }

            Divider()

            List(viewModel.threads, selection: $viewModel.selectedThreadID) { thread in
                Text(thread.name)
                    .tag(thread.id)
                    .lineLimit(1)
                    .contextMenu {
                        if let kagiId = thread.kagiThreadId {
                            Button("Copy Link") {
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("https://kagi.com/assistant/\(kagiId)", forType: .string)
                                #else
                                UIPasteboard.general.string = "https://kagi.com/assistant/\(kagiId)"
                                #endif
                            }
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.deleteThread(thread)
                        }
                    }
            }
            .onChange(of: viewModel.selectedThreadID) { _, newValue in
                guard let newValue,
                      let thread = viewModel.threads.first(where: { $0.id == newValue }) else { return }
                Task { await viewModel.selectThread(thread) }
            }
        }
        .onChange(of: focusSearch) {
            isSearchFocused = true
        }
    }
}
