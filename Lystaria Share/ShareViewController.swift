//
//  ShareViewController.swift
//  Lystaria Share
//
//  Created by Asteria Moon on 3/19/26.
//

import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    private let viewModel = ShareBookmarkViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        viewModel.loadFolders()

        let providers = extractItemProviders()
        viewModel.populateFromSharedItems(providers) { }

        let host = UIHostingController(
            rootView: ShareBookmarkView(
                viewModel: viewModel,
                onCancel: { [weak self] in
                    self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareCancelled", code: 0))
                },
                onSave: { [weak self] in
                    guard let self else { return }
                    do {
                        try self.viewModel.save()
                        self.extensionContext?.completeRequest(returningItems: nil)
                    } catch {
                        self.viewModel.errorMessage = error.localizedDescription
                    }
                }
            )
        )

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func extractItemProviders() -> [NSItemProvider] {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return []
        }

        return extensionItems.flatMap { $0.attachments ?? [] }
    }
}
