import Foundation
import ReadiumNavigator
import ReadiumShared

private let jsonEncoder = JSONEncoder()

/// Applying reader preferences (custom CSS variables, DiViNa iframe propagation)
/// and the media-overlay column-break-prevention CSS that's gated by them.
extension EPUBReaderView {

  func setUserPreferences(preferences: FlutterEPUBPreferences) async throws {
    self.preferences = preferences
    self.readiumViewController.submitPreferences(preferences.readium)
    try await self.updateCustomPreferences(preferences)
    try await applyColumnBreakPrevention()

    // Re-anchor after Readium has accepted the preference submission. This is
    // the completion point for the native reflow; no timing delay is needed.
    if let locator = getCurrentLocation() {
      _ = await readiumViewController.go(
        to: locator,
        options: NavigatorGoOptions(animated: false)
      )
    }
  }

  /// Resolves preferences against the publication's layout. The first-element top
  /// margin is a reflowable-text affordance, so it's dropped for every non-reflowable
  /// publication — FXL EPUBs and paginated DiViNa report `.fixed`, scrolled DiViNa
  /// reports `.scrolled`, and image publications (CBZ via ImageParser) report no
  /// layout at all — where it would otherwise shift the full-page content down.
  func effectivePreferences(_ preferences: FlutterEPUBPreferences) -> FlutterEPUBPreferences {
    guard publication.metadata.layout != .reflowable else { return preferences }
    var resolved = preferences
    resolved.firstElementTopMargin = nil
    return resolved
  }

  func updateCustomPreferences(_ preferences: FlutterEPUBPreferences) async throws {
    let cssVariables = effectivePreferences(preferences).toCustomCssVariables()

    if cssVariables.isEmpty == false,
       let jsonData = try? jsonEncoder.encode(cssVariables),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      let result = await self.readiumViewController.evaluateJavaScript("readium.setCSSProperties(\(jsonString));")
      try result.get()
      Log.reader.info("updated custom preferences")

      if let textAlignData = try? jsonEncoder.encode(cssVariables[textAlignCssVariable]),
         let textAlignJson = String(data: textAlignData, encoding: .utf8) {
        let script = """
        (function(value) {
          var root = document.documentElement;
          if (!root) return;
          var style = document.getElementById('flutter-readium-text-align');
          var supported = ['left', 'right', 'justify'];
          if (supported.indexOf(value) === -1) {
            if (style) style.remove();
            return;
          }
          if (!style) {
            style = document.createElement('style');
            style.id = 'flutter-readium-text-align';
            (document.head || root).appendChild(style);
          }
          style.textContent = 'body, body p, body li { text-align: ' + value + ' !important; }';
        })(\(textAlignJson));
        """
        let result = await self.readiumViewController.evaluateJavaScript(script)
        try result.get()
      }
    }

    let fontFaceStyle = makeFontFaceStyle(for: preferences.readium.fontFamily)
    if let styleData = try? jsonEncoder.encode(fontFaceStyle),
       let styleJson = String(data: styleData, encoding: .utf8) {
      let script = """
      (function() {
        var style = document.getElementById('flutter-readium-font-face');
        if (!style) {
          style = document.createElement('style');
          style.id = 'flutter-readium-font-face';
          document.head.appendChild(style);
        }
        style.textContent = \(styleJson);
      })();
      """
      let result = await self.readiumViewController.evaluateJavaScript(script)
      try result.get()
    }

    // For CBZ/DiViNa FXL publications, also propagate CSS vars to the inner
    // iframe. The FXL wrapper (fxl-spread-one.html) exposes window.spread.eval("", code)
    // which runs JS in the iframe's context. This ensures dynamic preference
    // updates (e.g. toggling B&W mode mid-read) reach the image iframe.
    if publication.conforms(to: Publication.Profile.divina) {
      let innerScript = cssVariables.map { k, v in
        if let v { "document.documentElement.style.setProperty('\(k)','\(v)','important');" }
        else { "document.documentElement.style.removeProperty('\(k)');" }
      }.joined()
      if let scriptData = try? jsonEncoder.encode(innerScript),
         let scriptJson = String(data: scriptData, encoding: .utf8) {
        let result = await self.readiumViewController.evaluateJavaScript("window.spread?.eval?.('',\(scriptJson));")
        try result.get()
      }
    }
  }

  private func makeFontFaceStyle(for fontFamily: String?) -> String {
    guard fontFamily == "Noto Serif SC" else { return "" }

    let paths = [
      Bundle.main.path(forResource: "flutter_assets/assets/fonts/NotoSerifSC-Regular.ttf", ofType: nil),
      Bundle.main.path(forResource: "assets/fonts/NotoSerifSC-Regular.ttf", ofType: nil),
    ].compactMap { $0 }
    guard let path = paths.first,
          let data = FileManager.default.contents(atPath: path) else {
      Log.reader.error("Noto Serif SC font asset is missing; falling back to the system font")
      return ""
    }

    let base64 = data.base64EncodedString()
    return """
    @font-face {
      font-family: 'Noto Serif SC';
      src: url(data:font/ttf;base64,\(base64)) format('truetype');
      font-weight: 400;
      font-style: normal;
    }
    """
  }

  /// MO-only: prevents CSS columns from splitting a paragraph during sync playback.
  /// Not related to `PageBreakSkippingContentIteratorFactory` (TTS-only, content-iteration).
  public func setMOActive(_ active: Bool) {
    isMOActive = active
    Task { @MainActor [weak self] in
      do {
        try await self?.applyColumnBreakPrevention()
      } catch {
        Log.reader.error("Failed to apply media-overlay CSS: \(error)")
      }
    }
  }

  private func applyColumnBreakPrevention() async throws {
    if shouldPreventColumnBreaks {
      try await injectColumnBreakCSS()
    } else {
      try await removeColumnBreakCSS()
    }
  }

  func injectColumnBreakCSS() async throws {
    // Delegates to the helper bundle (window.flutterReadium), matching Android.
    // Optional-chained: no-op if called before the helper finishes initializing.
    let result = await self.readiumViewController.evaluateJavaScript("window.flutterReadium?.injectMOBreakCSS();")
    try result.get()
  }

  private func removeColumnBreakCSS() async throws {
    let result = await self.readiumViewController.evaluateJavaScript("window.flutterReadium?.removeMOBreakCSS();")
    try result.get()
  }
}
