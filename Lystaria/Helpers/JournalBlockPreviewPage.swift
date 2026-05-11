//
//  JournalBlockPreviewPage.swift
//  Lystaria
//

import SwiftUI
import SwiftData
import UIKit

struct JournalBlockPreviewPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let entry: JournalEntry

    @State private var showDeleteConfirmation = false
    @State private var showEditorPage = false
    @State private var isCompletingAction = false
    @State private var hasPreparedPreview = false
    @State private var showBackgroundSettingsSheet = false
    @State private var showTextColorSheet = false
    @State private var textColorPickerSelection: Color = .white
    @State private var mentionedBook: JournalBook? = nil
    @State private var navigateToMentionedBook = false

    var body: some View {
        ZStack {
            JournalEntryBackground(entry: entry)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !entry.title.isEmpty {
                        GradientTitle(text: entry.title, font: .title.bold())
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, entry.tags.isEmpty ? 16 : 10)
                    }

                    if !entry.tags.isEmpty {
                        TagFlowLayout(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Image("tagsparkle")
                                        .resizable().renderingMode(.template)
                                        .scaledToFit().frame(width: 16, height: 16)
                                        .foregroundStyle(.white)
                                    Text(tag).font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }

                    JournalBlockDisplayView(entry: entry, onMentionTapped: { idString in
                        let descriptor = FetchDescriptor<JournalBook>(predicate: #Predicate { $0.deletedAt == nil })
                        let books = (try? modelContext.fetch(descriptor)) ?? []
                        if let match = books.first(where: { $0.uuid.uuidString == idString }) {
                            mentionedBook = match
                            navigateToMentionedBook = true
                        }
                    })
                }
            }
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Journal Entry")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(LColors.textSecondary)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showBackgroundSettingsSheet = true
                    } label: {
                        Label("Background", systemImage: "photo")
                    }
                    Button {
                        let hex = entry.textColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !hex.isEmpty,
                           let r = UInt8(hex.prefix(2), radix: 16),
                           let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
                           let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) {
                            textColorPickerSelection = Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
                        } else {
                            textColorPickerSelection = .white
                        }
                        showTextColorSheet = true
                    } label: {
                        Label("Text Color", systemImage: "textformat")
                    }
                } label: {
                    Image(systemName: "paintbrush.fill").foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil || entry.book == nil)
                .opacity((isCompletingAction || entry.deletedAt != nil || entry.book == nil) ? 0.5 : 1)

                Button {
                    guard !isCompletingAction, entry.deletedAt == nil, entry.book != nil else { return }
                    showEditorPage = true
                } label: {
                    Text("Edit").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil || entry.book == nil)
                .opacity((isCompletingAction || entry.deletedAt != nil || entry.book == nil) ? 0.5 : 1)

                Button(role: .destructive) {
                    guard !isCompletingAction, entry.deletedAt == nil else { return }
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash").foregroundStyle(.white)
                }
                .disabled(isCompletingAction || entry.deletedAt != nil)
                .opacity((isCompletingAction || entry.deletedAt != nil) ? 0.5 : 1)
            }
        }
        .navigationDestination(isPresented: $showEditorPage) {
            Group {
                if let book = entry.book, entry.deletedAt == nil {
                    JournalBlockEditorPage(book: book, existingEntry: entry)
                } else {
                    Color.clear.navigationBarBackButtonHidden(true)
                }
            }
        }
        .background {
            NavigationLink(
                destination: Group {
                    if let book = mentionedBook {
                        JournalBookDetailView(book: book).environmentObject(appState)
                    }
                },
                isActive: $navigateToMentionedBook
            ) { EmptyView() }
        }
        .sheet(isPresented: $showBackgroundSettingsSheet) {
            JournalBackgroundSettingsSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTextColorSheet) {
            NavigationStack {
                ZStack {
                    LystariaBackground().ignoresSafeArea()
                    VStack(spacing: 24) {
                        ColorPicker("Text Color", selection: $textColorPickerSelection, supportsOpacity: false)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, LSpacing.pageHorizontal)
                        if !entry.textColorHex.isEmpty {
                            Button {
                                entry.textColorHex = ""
                                entry.touch()
                                showTextColorSheet = false
                            } label: {
                                Text("Reset to Default")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.top, 24)
                }
                .navigationTitle("Text Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") {
                            let uiColor = UIColor(textColorPickerSelection)
                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                            entry.textColorHex = String(format: "%02X%02X%02X",
                                Int(r * 255), Int(g * 255), Int(b * 255))
                            entry.touch()
                            showTextColorSheet = false
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Entry", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the entry from your journal.")
        }
        .task {
            guard !hasPreparedPreview else { return }
            hasPreparedPreview = true

            if entry.book == nil || entry.deletedAt != nil {
                isCompletingAction = true
                dismiss()
                return
            }

            JournalEntryBlockMigration.migrateIfNeeded(entry: entry)
            entry.ensureStarterBlock()
            entry.normalizeBlockSortOrders()
            try? modelContext.save()
        }
        .onDisappear { isCompletingAction = false }
    }

    private func deleteEntry() {
        guard !isCompletingAction, entry.deletedAt == nil else { return }
        isCompletingAction = true
        showDeleteConfirmation = false
        showEditorPage = false
        entry.deletedAt = Date()
        entry.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
