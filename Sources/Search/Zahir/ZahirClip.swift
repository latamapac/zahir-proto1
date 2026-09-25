import SwiftUI
import WebKit

// Point at anything on a page (a competitor's hero, an ad, a headline) and it
// comes into Zahir as a reference: "make ours". It rides on the browser's own
// pointing mode, the one ⇧⌘H uses to hide things, so the highlight and the
// click feel the same; only what happens after the click differs.

extension Browser {
    /// ⇧⌘E, or "Point at something" in Figaro.
    func toggleClipping() {
        guard let tab = active, !tab.isBlank, ZahirRoute(tab.address) == nil else {
            ZahirStore.shared.toast("Open a website first, then point at something on it", symbol: "hand.point.up.left")
            return
        }
        if clipping {
            clipping = false
            tab.stopPicking()
        } else {
            if veiling { toggleHiding() }
            clipping = true
            tab.startPicking()
        }
    }

    /// The element was clicked: picture just that part of the page, hand it to
    /// the image studio, and go there.
    func clip(_ tab: Tab, selector: String, label: String) {
        clipping = false
        tab.stopPicking()
        let host = tab.address?.host()?.replacingOccurrences(of: "www.", with: "") ?? "the page"
        tab.picture(of: selector) { image in
            ZahirStore.shared.reference = ZReference(image: image, source: host, note: label)
            ZahirStore.shared.toast("Brought in from \(host)", symbol: "hand.point.up.left")
            self.openZahir(.image)
        }
    }
}

extension Tab {
    /// A picture of one element, as it looks on screen now.
    func picture(of selector: String, done: @escaping (NSImage?) -> Void) {
        let quoted = selector
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let script = """
        (function () {
          var el = document.querySelector(`\(quoted)`);
          if (!el) return null;
          var r = el.getBoundingClientRect();
          return [r.left, r.top, r.width, r.height];
        })()
        """
        let view = web
        // A beat for the pointing frame to leave before the picture is taken.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            view.evaluateJavaScript(script) { result, _ in
                let config = WKSnapshotConfiguration()
                if let box = result as? [Double], box.count == 4, box[2] > 4, box[3] > 4 {
                    let visible = view.bounds
                    let rect = CGRect(x: box[0], y: box[1], width: box[2], height: box[3]).intersection(visible)
                    if !rect.isNull, rect.width > 4, rect.height > 4 { config.rect = rect }
                }
                view.takeSnapshot(with: config) { image, _ in done(image) }
            }
        }
    }
}
