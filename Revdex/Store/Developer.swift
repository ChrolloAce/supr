import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Develops a capture into a showroom render: the same car, shot side on and
/// facing left in a plain showroom, so a garage full of catches reads as one
/// collection rather than a camera roll.
///
/// The number plate is covered on device first, before anything leaves the
/// phone. Only the censored frame is ever sent for rendering.
enum Developer {

    private static let ctx = CIContext(options: [.useSoftwareRenderer: false])

    struct Output {
        let render: UIImage
        /// False when the render could not run and this is the censored photo.
        let isRendered: Bool
    }

    // MARK: Entry point

    static func develop(_ image: UIImage) async -> Output? {
        // 1 · plate first, so nothing readable ever leaves the device
        let plates = await detectPlates(in: image)
        let censored = mask(plates, on: image)

        // 2 · the render itself
        do {
            let rendered = try await ShowroomRender.render(censored)
            return Output(render: rendered, isRendered: true)
        } catch {
            // A failed render is not a failed capture. The censored photo is
            // still a perfectly good record of the catch, so it stands in and
            // the person can try the render again from the card.
            return Output(render: censored, isRendered: false)
        }
    }

    /// Vision wants the orientation as a CGImage property, not a UIImage one.
    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: 1 · Plates

    private struct Run {
        let box: CGRect
        let hasDigit: Bool
    }

    /// A plate is usually several lines of text stacked together: the state
    /// name, the number, sometimes a URL. Masking single runs leaves half the
    /// plate showing, so runs sitting on top of each other are clustered and the
    /// union of the cluster gets covered.
    static func detectPlates(in image: UIImage) async -> [CGRect] {
        guard let cg = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(
                    cgImage: cg,
                    orientation: cgOrientation(image.imageOrientation),
                    options: [:]
                )
                try? handler.perform([request])

                let width = CGFloat(cg.width), height = CGFloat(cg.height)
                var runs: [Run] = []

                for obs in (request.results ?? []) {
                    let b = obs.boundingBox
                    let ratio = (b.width * width) / max(1, b.height * height)
                    let raw = (obs.topCandidates(1).first?.string ?? "")
                        .trimmingCharacters(in: .whitespaces)
                    let compact = raw.replacingOccurrences(of: " ", with: "")

                    guard compact.count >= 2, compact.count <= 14 else { continue }
                    guard b.height > 0.018, b.width > 0.03, b.width < 0.62 else { continue }
                    guard ratio > 1.0, ratio < 9 else { continue }

                    let alnum = compact.filter { $0.isLetter || $0.isNumber }.count
                    guard Double(alnum) / Double(compact.count) > 0.6 else { continue }

                    runs.append(Run(box: b, hasDigit: compact.contains(where: \.isNumber)))
                }

                var clusters: [[Run]] = []
                for run in runs {
                    let index = clusters.firstIndex { cluster in
                        cluster.contains { other in
                            let overlap = min(other.box.maxX, run.box.maxX) - max(other.box.minX, run.box.minX)
                            let narrower = min(other.box.width, run.box.width)
                            let gap = abs(other.box.midY - run.box.midY)
                            let tallest = max(other.box.height, run.box.height)
                            return overlap > narrower * 0.25 && gap < tallest * 2.2
                        }
                    }
                    if let index { clusters[index].append(run) } else { clusters.append([run]) }
                }

                let boxes: [CGRect] = clusters.compactMap { cluster in
                    var union = cluster[0].box
                    for run in cluster.dropFirst() { union = union.union(run.box) }

                    guard union.width > 0.035, union.width < 0.7 else { return nil }
                    let ratio = (union.width * width) / max(1, union.height * height)
                    guard ratio > 0.8, ratio < 9 else { return nil }

                    // Either it carries a number, or the block is shaped and
                    // sized like a plate. OCR mangles plate glyphs often enough
                    // that demanding a digit on its own misses real plates.
                    let plateShaped = ratio > 1.2 && ratio < 6.5 && union.height > 0.024
                    guard cluster.contains(where: \.hasDigit) || plateShaped else { return nil }

                    return union
                }

                continuation.resume(returning: boxes)
            }
        }
    }

    /// Heavy pixelation rather than a flat bar: it survives a slightly loose box
    /// and reads as a deliberate censor instead of a sticker slapped on.
    static func mask(_ boxes: [CGRect], on image: UIImage) -> UIImage {
        guard !boxes.isEmpty, let cg = image.cgImage else { return image }

        let width = CGFloat(cg.width), height = CGFloat(cg.height)
        let base = CIImage(cgImage: cg)
        var work = base

        for box in boxes {
            var rect = CGRect(
                x: box.minX * width,
                y: box.minY * height,
                width: box.width * width,
                height: box.height * height
            )
            rect = rect.insetBy(dx: -rect.width * 0.12, dy: -rect.height * 0.36)

            let pixellate = CIFilter.pixellate()
            pixellate.inputImage = work
            pixellate.center = CGPoint(x: rect.midX, y: rect.midY)
            pixellate.scale = Float(max(10, min(rect.width, rect.height) * 0.55))
            guard let pixelated = pixellate.outputImage else { continue }

            let darken = CIFilter.exposureAdjust()
            darken.inputImage = pixelated
            darken.ev = -0.7

            guard let patch = darken.outputImage?.cropped(to: rect) else { continue }
            work = patch.composited(over: work)
        }

        guard let out = ctx.createCGImage(work, from: base.extent) else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }
}
