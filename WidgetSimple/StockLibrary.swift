import UIKit

/// The photos the Photo widget can show: the CC0 stock set bundled in `Stock/`
/// (credits in Stock/CREDITS.md) plus photos the person imports. The app copies them
/// into the App Group, where the widget extension reads them; nothing is downloaded.
enum StockLibrary {
    /// Copies any missing stock photo into the App Group and rewrites the index:
    /// stock entries from the bundle's manifest, then the person's own, in order.
    static func seed(into store: SharedStore) -> [PhotoAsset] {
        let stock = bundledManifest()
        let fm = FileManager.default
        for photo in stock {
            let destination = store.photoURL(photo)
            guard !fm.fileExists(atPath: destination.path), let source = resource(photo.file) else { continue }
            try? fm.copyItem(at: source, to: destination)
        }
        let own = store.loadPhotos().filter { !$0.isStock }
        let all = stock.filter { fm.fileExists(atPath: store.photoURL($0).path) } + own
        store.savePhotos(all)
        return all
    }

    /// A photo the person picked, downscaled to 1600 px and stored as JPEG.
    static func importPhoto(_ data: Data, into store: SharedStore) -> PhotoAsset? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = downscale(image, maxSide: 1600)
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let id = UUID().uuidString
        let count = store.loadPhotos().filter { !$0.isStock }.count + 1
        let photo = PhotoAsset(id: "user-\(id)", title: String(localized: "My photo \(count)"),
                               file: "user-\(id).jpg", isStock: false)
        do {
            try jpeg.write(to: store.photoURL(photo), options: .atomic)
        } catch {
            return nil
        }
        return photo
    }

    /// The licence page shown in Settings › Photo credits.
    static func credits() -> String {
        guard let url = resource("CREDITS.md"), let text = try? String(contentsOf: url, encoding: .utf8) else {
            return String(localized: "Credits are missing from this build.")
        }
        return text
    }

    // MARK: Helpers

    private static func bundledManifest() -> [PhotoAsset] {
        guard let url = resource("stock-manifest.json"), let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([PhotoAsset].self, from: data) else { return [] }
        return entries.map { entry in
            var stock = entry
            stock.isStock = true
            return stock
        }
    }

    /// A bundled file, whether Xcode kept the Stock folder or flattened it.
    private static func resource(_ file: String) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Stock")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
