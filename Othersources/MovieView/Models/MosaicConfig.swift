import Foundation
import CoreGraphics
import AppKit

/// Configuration for mosaic generation
struct MosaicConfig: Codable, Hashable {
    /// Width of the generated mosaic in pixels
    var width: CGFloat = 3840
    
    /// Density of thumbnails in the mosaic
    var density: DensityConfig = .default
    
    /// Whether to use auto-layout based on screen size
    var useAutoLayout: Bool = true
    
    /// Whether to add borders around thumbnails
    var addBorder: Bool = true
    
    /// Color of the thumbnail borders
    var borderColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.5)
    
    /// Width of the thumbnail borders
    var borderWidth: CGFloat = 2
    
    /// Whether to add shadow effects to thumbnails
    var addShadow: Bool = true
    
    /// String representation of the configuration for file naming
    var configString: String {
        let components = [
            "\(Int(width))w",
            "\(density.rawValue)d",
            useAutoLayout ? "auto" : "fixed",
            addBorder ? "border" : "noborder",
            addShadow ? "shadow" : "noshadow"
        ]
        return components.joined(separator: "_")
    }
    
    init(density: DensityConfig = .default) {
        self.density = density
    }
    
    static let `default` = MosaicConfig(density: .m)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case width, density, useAutoLayout, addBorder, borderColor, borderWidth, addShadow
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(density, forKey: .density)
        try container.encode(useAutoLayout, forKey: .useAutoLayout)
        try container.encode(addBorder, forKey: .addBorder)
        try container.encode(borderWidth, forKey: .borderWidth)
        try container.encode(addShadow, forKey: .addShadow)
        
        // Encode CGColor components
        let components = borderColor.components ?? [1, 1, 1, 0.5]
        try container.encode(components, forKey: .borderColor)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(CGFloat.self, forKey: .width)
        density = try container.decode(DensityConfig.self, forKey: .density)
        useAutoLayout = try container.decode(Bool.self, forKey: .useAutoLayout)
        addBorder = try container.decode(Bool.self, forKey: .addBorder)
        borderWidth = try container.decode(CGFloat.self, forKey: .borderWidth)
        addShadow = try container.decode(Bool.self, forKey: .addShadow)
        
        // Decode CGColor components
        let components = try container.decode([CGFloat].self, forKey: .borderColor)
        borderColor = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, 
                            components: components) ?? CGColor(red: 1, green: 1, blue: 1, alpha: 0.5)
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(density)
        hasher.combine(useAutoLayout)
        hasher.combine(addBorder)
        hasher.combine(borderWidth)
        hasher.combine(addShadow)
    }
    
    static func == (lhs: MosaicConfig, rhs: MosaicConfig) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}

// Add this extension to provide description
extension MosaicConfig: CustomStringConvertible {
    var description: String {
        return """
        MosaicConfig(
            width: \(width),
            density: \(density),
            useAutoLayout: \(useAutoLayout),
            addBorder: \(addBorder),
            borderWidth: \(borderWidth),
            addShadow: \(addShadow)
        )
        """
    }
} 