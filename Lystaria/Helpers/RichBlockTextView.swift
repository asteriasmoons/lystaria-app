//
//  RichBlockTextView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import SwiftUI
import UIKit

struct RichBlockTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    var isSelectable: Bool = true
    var linkTintColor: UIColor? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = isSelectable
        textView.isUserInteractionEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.adjustsFontForContentSizeCategory = true
        textView.dataDetectorTypes = []
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)

        return textView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let targetWidth = max(0, width)
        let fittingSize = uiView.sizeThatFits(
            CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: targetWidth, height: fittingSize.height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.invalidateIntrinsicContentSize()
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()

        if let linkTintColor {
            uiView.linkTextAttributes = [
                .foregroundColor: linkTintColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        } else {
            uiView.linkTextAttributes = [
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @available(iOS, introduced: 10.0, deprecated: 17.0)
        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            true
        }

        @available(iOS 17.0, *)
        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            defaultAction
        }
    }
}
