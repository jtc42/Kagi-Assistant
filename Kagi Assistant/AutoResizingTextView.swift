//
//  AutoResizingTextView.swift
//  Kagi Assistant
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers

struct PastedImageData {
    let data: Data
    let mimeType: String
    let contentType: UTType?
}

// MARK: - Platform-specific implementations

#if os(macOS)

// MARK: - macOS: Auto-resizing NSTextView wrapper

private class InputTextView: NSTextView {
    var onSend: (() -> Void)?
    var onPasteImages: (([PastedImageData]) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Return
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onSend?()
            }
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a",
           window?.firstResponder == self {
            selectAll(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)),
           onPasteImages != nil,
           pasteboardHasImages(NSPasteboard.general) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func paste(_ sender: Any?) {
        let pastedImages = imageData(from: NSPasteboard.general)
        if let onPasteImages, !pastedImages.isEmpty {
            onPasteImages(pastedImages)
            return
        }

        super.paste(sender)
    }

    private func pasteboardHasImages(_ pasteboard: NSPasteboard) -> Bool {
        guard let items = pasteboard.pasteboardItems else { return false }
        return items.contains { item in
            item.types.contains { UTType($0.rawValue)?.conforms(to: .image) == true }
        }
    }

    private func imageData(from pasteboard: NSPasteboard) -> [PastedImageData] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        return items.compactMap { item in
            for type in item.types {
                guard let contentType = UTType(type.rawValue), contentType.conforms(to: .image),
                      let data = item.data(forType: type) else {
                    continue
                }

                return PastedImageData(
                    data: data,
                    mimeType: contentType.preferredMIMEType ?? "application/octet-stream",
                    contentType: contentType
                )
            }

            return nil
        }
    }
}

struct AutoResizingTextView: NSViewRepresentable {
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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = InputTextView()
        textView.onSend = onSend
        textView.onPasteImages = onPasteImages
        textView.delegate = context.coordinator
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Set initial single-line height
        let lineHeight = textView.font!.boundingRectForFont.height
        let inset = textView.textContainerInset
        DispatchQueue.main.async {
            self.desiredHeight = lineHeight + inset.height * 2
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InputTextView else { return }

        if textView.string != text {
            textView.string = text
            context.coordinator.recalcHeight()
        }

        if requestFocus != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = requestFocus
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        textView.onSend = onSend
        textView.onPasteImages = onPasteImages
        context.coordinator.parent = self
        context.coordinator.updatePlaceholder()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoResizingTextView
        weak var textView: NSTextView?
        var lastFocusTrigger = false
        private var placeholderView: NSTextField?

        init(_ parent: AutoResizingTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            recalcHeight()
            updatePlaceholder()
        }

        func recalcHeight() {
            guard let textView else { return }

            let font = textView.font ?? NSFont.preferredFont(forTextStyle: .body)
            let lineHeight = font.boundingRectForFont.height
            let inset = textView.textContainerInset
            let singleLineHeight = lineHeight + inset.height * 2
            let maxHeight = lineHeight * CGFloat(parent.maxLines) + inset.height * 2

            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let usedHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? lineHeight
            let naturalHeight = usedHeight + inset.height * 2

            let targetHeight = max(singleLineHeight, min(naturalHeight, maxHeight))

            DispatchQueue.main.async {
                self.parent.desiredHeight = targetHeight
            }
        }

        func updatePlaceholder() {
            guard let textView else { return }

            if placeholderView == nil {
                let field = NSTextField(labelWithString: parent.placeholder)
                field.textColor = .tertiaryLabelColor
                field.font = textView.font
                field.translatesAutoresizingMaskIntoConstraints = false
                textView.addSubview(field)

                let inset = textView.textContainerInset
                let padding = textView.textContainer?.lineFragmentPadding ?? 0
                NSLayoutConstraint.activate([
                    field.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: inset.width + padding),
                    field.topAnchor.constraint(equalTo: textView.topAnchor, constant: inset.height)
                ])
                placeholderView = field
            }

            placeholderView?.stringValue = parent.placeholder
            placeholderView?.isHidden = !textView.string.isEmpty
        }
    }
}

#else

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

#endif
