//
//  ShareBookmarkView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI

struct ShareBookmarkView: View {
    @ObservedObject var viewModel: ShareBookmarkViewModel
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.12, green: 0.04, blue: 0.22),
                        Color(red: 0.02, green: 0.18, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        card {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Save to Lystaria")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)

                                Text("Add this to your bookmark manager with the right details before it lands in your library.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))

                                if !viewModel.url.isEmpty {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.06))
                                                .frame(width: 46, height: 46)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                )

                                            if let image = previewUIImage {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 46, height: 46)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                            } else {
                                                Image(systemName: "link")
                                                    .foregroundStyle(.white.opacity(0.85))
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(viewModel.title.isEmpty ? "Untitled Bookmark" : viewModel.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)

                                            Text(viewModel.url)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        card {
                            VStack(alignment: .leading, spacing: 12) {
                                fieldLabel("Title")
                                textField("Enter title", text: $viewModel.title)

                                fieldLabel("Description")
                                textField("Add description", text: $viewModel.bookmarkDescription)

                                fieldLabel("Link")
                                textField("Paste or confirm link", text: $viewModel.url)

                                fieldLabel("Tags")
                                textField("Comma-separated tags", text: $viewModel.tagsRaw)

                                fieldLabel("Folder")
                                Menu {
                                    ForEach(viewModel.availableFolders) { folder in
                                        Button(folder.name) {
                                            viewModel.selectedFolder = folder
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: viewModel.selectedFolder.iconName)
                                            .foregroundStyle(.white)

                                        Text(viewModel.selectedFolder.name)
                                            .foregroundStyle(.white)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !viewModel.errorMessage.isEmpty {
                            Text(viewModel.errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.45)))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
private var previewUIImage: UIImage? {
    if let data = viewModel.previewThumbnailData,
       let image = UIImage(data: data) {
        return image
    }

    if let data = viewModel.previewIconData,
       let image = UIImage(data: data) {
        return image
    }

    return nil
}
}
