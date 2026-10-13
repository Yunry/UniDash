//
//  PDFKitRepresentedView.swift
//  UniDash
//
//  Cross-platform SwiftUI wrapper for PDFKit's PDFView (iOS & macOS).
//

import SwiftUI
import PDFKit

#if canImport(UIKit)
import UIKit

struct PDFKitRepresentedView: UIViewRepresentable {
    let document: PDFDocument?
    var autoScales: Bool = true

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = autoScales
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFDocument?
    var autoScales: Bool = true

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = autoScales
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
    }
}
#endif
