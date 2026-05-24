//
//  SidebarView.swift
//  Kagi Assistant
//

import SwiftUI
import UIKit

struct SidebarView: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var focusSearch: Bool
    @State private var searchText = ""

    var body: some View {
        List(viewModel.threads, selection: $viewModel.selectedThreadID) { thread in
            SidebarThreadRow(thread: thread)
                .tag(thread.id)
                .contextMenu {
                    if let kagiId = thread.kagiThreadId {
                        Button("Copy Link") {
                            UIPasteboard.general.string = "https://kagi.com/assistant/\(kagiId)"
                        }
                    }
                    Button("Delete", role: .destructive) {
                        viewModel.deleteThread(thread)
                    }
                }
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) {
            if searchText.isEmpty {
                Task { await viewModel.fetchThreads() }
            } else {
                Task { await viewModel.searchAndSelectThread(query: searchText) }
            }
        }
        .onChange(of: viewModel.selectedThreadID) {
            guard let selectedID = viewModel.selectedThreadID,
                  let thread = viewModel.threads.first(where: { $0.id == selectedID }) else { return }
            Task { await viewModel.selectThread(thread) }
        }
        .listStyle(.insetGrouped)
        .onChange(of: focusSearch) {
            if focusSearch {
                // No explicit focus management needed for .searchable on iOS currently
            }
        }
    }
}

private struct SidebarThreadRow: View {
    let thread: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(thread.name)
                .lineLimit(1)
            if let lastMessage = thread.lastMessage {
                Text(lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }
}
