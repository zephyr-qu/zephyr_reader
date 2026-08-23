import Flutter
import Foundation
import ReadiumShared
import UIKit

private final class ReaderUnavailableView: NSObject, FlutterPlatformView {
    private let rootView: UIView

    init(frame: CGRect) {
        let label = UILabel(frame: frame)
        label.text = "Reader is not ready"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        self.rootView = label
        super.init()
        emitReaderStatusChanged(status: ReadiumReaderStatusError)
    }

    func view() -> UIView {
        return rootView
    }

    func dispose() {}
}

class ReadiumReaderViewFactory: NSObject, @preconcurrency FlutterPlatformViewFactory {
    private weak var registrar: FlutterPluginRegistrar?

  init(registrar: FlutterPluginRegistrar?) {
    self.registrar = registrar
    super.init()
  }

  @MainActor func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        // Dispatch on the current publication's format. The Dart side passes
        // identical creationParams regardless of content type; the native
        // factory picks the right reader.
        guard FlutterReadiumPlugin.instance?.getCurrentPublication() != nil,
              let registrar else {
            return ReaderUnavailableView(frame: frame)
        }
        let publication = FlutterReadiumPlugin.instance?.getCurrentPublication()
        if Self.isPDFPublication(publication) {
            return PDFReaderView(
                frame: frame,
                viewIdentifier: viewId,
                arguments: args,
                registrar: registrar) ?? ReaderUnavailableView(frame: frame)
        }
        return EPUBReaderView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            registrar: registrar) ?? ReaderUnavailableView(frame: frame)
    }

  /// True if the publication should be rendered with the PDF navigator.
  /// Checks both the Readium PDF profile and the first reading-order entry's
  /// media type so we cover publications that don't declare the profile but
  /// have a single `application/pdf` resource.
  private static func isPDFPublication(_ publication: Publication?) -> Bool {
    guard let publication else { return false }
    if publication.conforms(to: Publication.Profile.pdf) {
      return true
    }
    return publication.readingOrder.first?.mediaType == .pdf
  }

  // Undocumented, but boilerplate function required for creationParams to not silently become nil!
  // https://github.com/flutter/flutter/issues/28124
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}
