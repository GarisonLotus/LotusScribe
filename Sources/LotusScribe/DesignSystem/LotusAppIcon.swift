import AppKit
import SwiftUI

// MARK: - App icon (design spec §3)

/// The app icon: the two-tone `LotusMark` centered at ~55% width on a dark
/// macOS-squircle background — a radial bloom (#2B1332 from the upper-right →
/// #171019 at 60% radius) with a subtle 1px inner white hairline. Rendered at
/// every size in the `AppIcon` set (see `make appicon`) and set as
/// `applicationIconImage` at launch for dev builds (icons Task 3).
struct LotusAppIcon: View {
    let size: CGFloat

    init(size: CGFloat = 1024) { self.size = size }

    // Icon background hexes are icon code (allowed). Local helper — the theme's
    // `NSColor(rgb:)` is file-private, and these two colors are icon-only.
    private func hex(_ rgb: UInt32) -> Color {
        Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255)
    }
    private var bloom: Color { hex(0x2B1332) }
    private var base: Color { hex(0x171019) }
    // macOS icons are a continuous-corner ("squircle") rounded square.
    private var cornerRadius: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(RadialGradient(
                    colors: [bloom, base],
                    center: UnitPoint(x: 0.85, y: -0.1),
                    startRadius: 0,
                    endRadius: size * 0.6))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            LotusMark(size: size * 0.55)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Icon renderer (build tool + launch fallback)

/// Renders `LotusAppIcon` to NSImages / the `AppIcon` asset set. Used two ways:
/// at launch to set `applicationIconImage` (dev fallback), and from the hidden
/// `--render-app-icon <dir>` flag (the `make appicon` build tool) to regenerate
/// the asset catalog — a single source of truth (`LotusAppIcon`), never a
/// duplicated drawing.
@MainActor
enum AppIconRenderer {
    /// The distinct pixel sizes the macOS AppIcon set needs (16…1024).
    private static let pixelSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

    /// (size pt, scale) → filename, the standard macOS AppIcon idiom entries.
    private static let entries: [(size: Int, scale: Int)] = [
        (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
        (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
    ]

    /// Render `LotusAppIcon` to a `pixels`×`pixels` PNG-capable NSImage.
    static func image(pixels: Int) -> NSImage? {
        let renderer = ImageRenderer(content: LotusAppIcon(size: CGFloat(pixels)))
        renderer.scale = 1
        return renderer.nsImage
    }

    /// A ready-to-use Dock/app icon at a comfortable size (launch fallback).
    static func applicationIcon() -> NSImage? { image(pixels: 512) }

    /// If `--render-app-icon <dir>` is present, write the full AppIcon set
    /// (PNGs + Contents.json) into `<dir>` and return true (caller exits).
    static func handleCommandLineIfNeeded() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-app-icon"), i + 1 < args.count
        else { return false }
        render(to: args[i + 1])
        return true
    }

    /// Write every pixel size as `icon_<px>.png` plus a macOS `Contents.json`
    /// into the given `.appiconset` directory.
    static func render(to directory: String) {
        let dir = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)

        for px in pixelSizes {
            guard let image = image(pixels: px),
                let tiff = image.tiffRepresentation,
                let rep = NSBitmapImageRep(data: tiff),
                let png = rep.representation(using: .png, properties: [:])
            else {
                FileHandle.standardError.write(
                    Data("render failed at \(px)px\n".utf8))
                continue
            }
            try? png.write(to: dir.appendingPathComponent("icon_\(px).png"))
        }

        let images = entries.map { entry -> String in
            let px = entry.size * entry.scale
            return """
                    {
                      "idiom" : "mac",
                      "size" : "\(entry.size)x\(entry.size)",
                      "scale" : "\(entry.scale)x",
                      "filename" : "icon_\(px).png"
                    }
                """
        }.joined(separator: ",\n")
        let contents = """
            {
              "images" : [
            \(images)
              ],
              "info" : { "version" : 1, "author" : "xcode" }
            }

            """
        try? contents.write(
            to: dir.appendingPathComponent("Contents.json"),
            atomically: true, encoding: .utf8)
        FileHandle.standardOutput.write(
            Data("wrote AppIcon set to \(directory)\n".utf8))
    }
}
