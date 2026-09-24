import ImageIO
import UIKit

/// Reads where a photograph was taken from the file itself.
///
/// A picture chosen from the library was not necessarily taken here, or today.
/// Tagging it with the phone's current position would put a stranger's car on
/// the map outside your house, so the only acceptable source is the image's own
/// GPS metadata. No metadata, no pin.
enum Exif {

    static func coordinate(in data: Data) -> (lat: Double, lng: Double)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let lng = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }

        // Stored unsigned, with the hemisphere in a separate field.
        let north = (gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N") == "N"
        let east = (gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E") == "E"

        return (north ? lat : -lat, east ? lng : -lng)
    }
}
