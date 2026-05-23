//
//  AutoResizingTextView.swift
//  Kagi Assistant
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PastedImageData {
    let data: Data
    let mimeType: String
    let contentType: UTType?
}

// MARK: - iOS: Auto-resizing UITextView wrapper

private class InputTextView: UITextView {
    var onSend: (() -> Void)?
    var onPasteImages: (([PastedImageData]) -> Void)?

    override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        let imageTypes = pasteboard.itemProviders.filter { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
        if let onPasteImages, !imageTypes.isEmpty {
            var pastedImages: [PastedImageData] = []
            for provider in imageTypes {
                // Try common image types
                for imageType in [UTType.png, UTType.jpeg, UTType.tiff, UTType.webP] {
                    if let data = pasteboard.data(forPasteboardType: imageType.identifier) {
                        pastedImages.append(PastedImageData(
                            data: data,
                            mimeType: imageType.preferredMIMEType ?? "application/octet-stream",
                            contentType: imageType
                        ))
                        break
                    }
                }
            }
            if !pastedImages.isEmpty {
                onPasteImages(pastedImages)
                return
            }
        }
        super.paste(sender)
    }
}

struct AutoResizingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var desiredHeight: CGFloat
    var maxLines: Int
    var placeholder: String
    var requestFocus: Bool = false
    var onSend: (() -> Void)?
    var onPasteImages: (([PastedImageData]) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> InputTextView {
        let textView = InputTextView()
        textView.onSend = onSend
        textView.onPasteImages = onPasteImages
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineFragmentPadding = 4
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .default

        context.coordinator.textView = textView
        context.coordinator.setupPlaceholder(in: textView)

        // Set initial single-line height
        let lineHeight = textView.font!.lineHeight
        let inset = textView.textContainerInset
        DispatchQueue.main.async {
            self.desiredHeight = lineHeight + inset.top + inset.bottom
        }

        return textView
    }

    func updateUIView(_ textView: InputTextView, context: Context) {
        if textView.text != text {
            textView.text = text
            context.coordinator.recalcHeight()
        }

        if requestFocus != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = requestFocus
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }

        textView.onSend = onSend
        textView.onPasteImages = onPasteImages
        context.coordinator.parent = self
        context.coordinator.updatePlaceholder()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoResizingTextView
        weak var textView: UITextView?
        var lastFocusTrigger = false
        private var placeholderLabel: UILabel?

        init(_ parent: AutoResizingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            recalcHeight()
            updatePlaceholder()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSend?()
                return false
            }
            return true
        }

        func recalcHeight() {
            guard let textView else { return }

            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
            let lineHeight = font.lineHeight
            let inset = textView.textContainerInset
            let singleLineHeight = lineHeight + inset.top + inset.bottom
            let maxHeight = lineHeight * CGFloat(parent.maxLines) + inset.top + inset.bottom

            let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
            let naturalHeight = size.height

            let targetHeight = max(singleLineHeight, min(naturalHeight, maxHeight))
            textView.isScrollEnabled = naturalHeight > maxHeight

            DispatchQueue.main.async {
                self.parent.desiredHeight = targetHeight
            }
        }

        func setupPlaceholder(in textView: UITextView) {
            let label = UILabel()
            label.text = parent.placeholder
            label.textColor = .tertiaryLabel
            label.font = textView.font
            label.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(label)

            let inset = textView.textContainerInset
            let padding = textView.textContainer.lineFragmentPadding
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: inset.left + padding),
                label.topAnchor.constraint(equalTo: textView.topAnchor, constant: inset.top)
            ])
            placeholderLabel = label
        }

        func updatePlaceholder() {
            placeholderLabel?.text = parent.placeholder
            placeholderLabel?.isHidden = !(textView?.text.isEmpty ?? true)
        }
    }
}
