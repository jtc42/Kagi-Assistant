//
//  SidebarView.swift
//  Kagi Assistant
//

import SwiftUI
import UIKit

struct SidebarView: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var focusSearch: Bool
    @Binding var showingLogin: Bool
    @State private var searchText = ""
    @State private var showAccountPopover = false

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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                accountControl
            }
        }
        .onChange(of: focusSearch) {
            if focusSearch {
                // No explicit focus management needed for .searchable on iOS currently
            }
        }
    }

    @ViewBuilder
    private var accountControl: some View {
        if viewModel.isAuthenticated {
            Button {
                showAccountPopover.toggle()
            } label: {
                Label("Account", systemImage: "person.circle.fill")
            }
            .popover(isPresented: $showAccountPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    if let email = viewModel.userEmail {
                        Text(email)
                            .font(.callout)
                    }
                    Button("Sign Out", role: .destructive) {
                        showAccountPopover = false
                        Task { await viewModel.logout() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(minWidth: 220, alignment: .leading)
            }
        } else {
            Button {
                showingLogin = true
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
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
