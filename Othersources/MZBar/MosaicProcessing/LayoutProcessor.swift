import Foundation
import CoreGraphics
import os.log
import AppKit

/// Handles mosaic layout calculations and optimization
public final class LayoutProcessor {
    private let logger = Logger(subsystem: "com.mosaic.processing", category: "LayoutProcessor")
    public var mosaicAspectRatio: CGFloat
    private var layoutCache: [String: MosaicLayout] = [:]
    
    /// Get the screen with the largest resolution
    private func getLargestScreen() -> NSScreen? {
        let screens = NSScreen.screens
        return screens.max(by: { screen1, screen2 in
            let size1 = screen1.frame.size
            let size2 = screen2.frame.size
            return (size1.width * size1.height) < (size2.width * size2.height)
        })
    }
    
    /// Initialize a new layout processor
    public init(aspectRatio: CGFloat = 16.0 / 9.0) {
        self.mosaicAspectRatio = aspectRatio
    }
    
    /// Update the mosaic aspect ratio
    /// - Parameter ratio: New aspect ratio to use
    public func updateAspectRatio(_ ratio: CGFloat) {
        self.mosaicAspectRatio = ratio
        layoutCache.removeAll()
    }
    
    /// Calculate optimal mosaic layout
    /// - Parameters:
    ///   - originalAspectRatio: Aspect ratio of the original video
    ///   - thumbnailCount: Number of thumbnails to include
    ///   - mosaicWidth: Desired width of the mosaic
    ///   - density: Density configuration for layout
    ///   - useCustomLayout: Whether to use custom layout algorithm
    /// - Returns: Optimal layout for the mosaic
    public func calculateLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int,
        density: DensityConfig,
        useCustomLayout: Bool,
        useAutoLayout: Bool = false
    ) -> MosaicLayout {
        logger.info("Calculating layout: aspectRatio=\(originalAspectRatio), count=\(thumbnailCount)")
        
        if useAutoLayout {
            return calculateAutoLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount
            )
        }
        
        return useCustomLayout
        ? calculateCustomLayout(
            originalAspectRatio: originalAspectRatio,
            thumbnailCount: thumbnailCount,
            mosaicWidth: mosaicWidth,
            density: density.rawValue
        )
        : calculateClassicLayout(
            originalAspectRatio: originalAspectRatio,
            thumbnailCount: thumbnailCount,
            mosaicWidth: mosaicWidth
        )
    }

    /// Calculate auto layout based on screen size
    /// - Parameters:
    ///   - originalAspectRatio: Original video aspect ratio
    ///   - thumbnailCount: Number of thumbnails to include
    /// - Returns: Optimal layout for the screen
    private func calculateAutoLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int
    ) -> MosaicLayout {
        // Get largest screen dimensions
        guard let screen = getLargestScreen() else {
            return calculateClassicLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount,
                mosaicWidth: 1920
            )
        }
        
        let screenSize = screen.visibleFrame.size
        let scaleFactor = screen.backingScaleFactor
        
        // Calculate minimum readable thumbnail size (scaled for DPI)
        let minThumbWidth: CGFloat = 160 * scaleFactor
        let minThumbHeight = minThumbWidth / originalAspectRatio
        
        // Calculate maximum possible thumbnails
        let maxHorizontal = Int(floor(screenSize.width / minThumbWidth))
        let maxVertical = Int(floor(screenSize.height / minThumbHeight))
        
        var bestLayout: MosaicLayout?
        var bestScore: CGFloat = 0
        
        // Try different grid configurations
        for rows in 1...maxVertical {
            for cols in 1...maxHorizontal {
                let totalThumbs = rows * cols
                if totalThumbs < thumbnailCount {
                    continue
                }
                
                let thumbWidth = screenSize.width / CGFloat(cols)
                let thumbHeight = screenSize.height / CGFloat(rows)
                
                // Calculate scores
                let coverage = (thumbWidth * CGFloat(cols) * thumbHeight * CGFloat(rows)) / (screenSize.width * screenSize.height)
                let readabilityScore = (thumbWidth * thumbHeight) / (minThumbWidth * minThumbHeight)
                let score = coverage * 0.6 + readabilityScore * 0.4
                
                if score > bestScore {
                    bestScore = score
                    
                    // Generate positions and sizes
                    var positions: [(x: Int, y: Int)] = []
                    var thumbnailSizes: [CGSize] = []
                    
                    for row in 0..<rows {
                        for col in 0..<cols {
                            if positions.count < thumbnailCount {
                                positions.append((
                                    x: Int(CGFloat(col) * thumbWidth),
                                    y: Int(CGFloat(row) * thumbHeight)
                                ))
                                thumbnailSizes.append(CGSize(
                                    width: thumbWidth,
                                    height: thumbHeight
                                ))
                            }
                        }
                    }
                    
                    bestLayout = MosaicLayout(
                        rows: rows,
                        cols: cols,
                        thumbnailSize: CGSize(width: thumbWidth, height: thumbHeight),
                        positions: positions,
                        thumbCount: thumbnailCount,
                        thumbnailSizes: thumbnailSizes,
                        mosaicSize: screenSize
                    )
                }
            }
        }
        
        return bestLayout ?? calculateClassicLayout(
            originalAspectRatio: originalAspectRatio,
            thumbnailCount: thumbnailCount,
            mosaicWidth: Int(screenSize.width)
        )
    }
    
    private func calculateCustomLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int,
        density: String
    ) -> MosaicLayout {
        let mosaicHeight = Int(CGFloat(mosaicWidth) / mosaicAspectRatio)
        
        // Initialize layout parameters based on density
        var (largeCols, largeRows, smallCols, smallRows) = getInitialLayoutParams(density)
        
        // Adjust for portrait videos
        if originalAspectRatio < 1.0 {
            if smallRows > 2 {
                smallRows = smallRows / 2
            }
            smallCols *= 2
            largeCols *= 2
        }
        
        let totalCols = smallCols
        let smallThumbWidth = CGFloat(Int(mosaicWidth/totalCols))
        let smallThumbHeight =  CGFloat(Int(smallThumbWidth / originalAspectRatio))
        
        // Adjust layout for aspect ratio
        if originalAspectRatio < 1.0 {
            (smallCols, largeCols) = adjustPortraitLayout(
                smallCols: smallCols,
                largeCols: largeCols,
                smallRows: smallRows,
                largeRows: largeRows,
                smallThumbWidth: smallThumbWidth,
                smallThumbHeight: smallThumbHeight,
                mosaicAspectRatio: mosaicAspectRatio
            )
        } else {
            (smallRows, largeRows) = adjustLandscapeLayout(
                smallRows: smallRows,
                largeRows: largeRows,
                mosaicHeight: mosaicHeight,
                smallThumbHeight: smallThumbHeight
            )
        }
        
        // Generate row configurations
        let rowConfigs = generateRowConfigs(
            largeCols: largeCols,
            largeRows: largeRows,
            smallCols: smallCols,
            smallRows: smallRows
        )
        
        // Calculate final dimensions
        let totalSmallThumbs = smallCols * smallRows
        let totalLargeThumbs = largeCols * largeRows
        let totalRows = smallRows + 2 * largeRows
        let largeThumbWidth = smallThumbWidth * 2
        let largeThumbHeight = largeThumbWidth / originalAspectRatio
        
        // Generate positions and sizes
        var positions: [(x: Int, y: Int)] = []
        var thumbnailSizes: [CGSize] = []
        var y: CGFloat = 0
        
        for (smallCount, largeCount) in rowConfigs {
            var x: CGFloat = 0
            if smallCount > 0 {
                for _ in 0..<smallCount {
                    positions.append((x: Int(x), y: Int(y)))
                    thumbnailSizes.append(CGSize(width: smallThumbWidth, height: smallThumbHeight))
                    x += smallThumbWidth
                }
                y += smallThumbHeight
            } else {
                for _ in 0..<largeCount {
                    positions.append((x: Int(x), y: Int(y)))
                    thumbnailSizes.append(CGSize(width: largeThumbWidth, height: largeThumbHeight))
                    x += largeThumbWidth
                }
                y += largeThumbHeight
            }
        }
        
        return MosaicLayout(
            rows: totalRows,
            cols: smallCols,
            thumbnailSize: CGSize(width: smallThumbWidth, height: smallThumbHeight),
            positions: positions,
            thumbCount: totalSmallThumbs + totalLargeThumbs,
            thumbnailSizes: thumbnailSizes,
            mosaicSize: CGSize(width: mosaicWidth, height: Int(y))
        )
    }
    
    private func calculateClassicLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int
    ) -> MosaicLayout {
        let mosaicHeight = Int(CGFloat(mosaicWidth) / mosaicAspectRatio)
        var thumbnailSizes: [CGSize] = []
        let count = thumbnailCount
        
        func calculateLayout(rows: Int) -> MosaicLayout {
            let cols = Int(ceil(Double(count) / Double(rows)))
            let thumbnailWidth = CGFloat(mosaicWidth) / CGFloat(cols)
            let thumbnailHeight = thumbnailWidth / originalAspectRatio
            let adjustedRows = min(rows, Int(ceil(CGFloat(mosaicHeight) / thumbnailHeight)))
            
            var positions: [(x: Int, y: Int)] = []
            var y: CGFloat = 0
            
            for row in 0..<adjustedRows {
                var x: CGFloat = 0
                for col in 0..<cols {
                    if positions.count < count {
                        positions.append((x: Int(x), y: Int(y)))
                        thumbnailSizes.append(CGSize(width: thumbnailWidth, height: thumbnailHeight))
                        x += thumbnailWidth
                    }
                }
                y += thumbnailHeight
            }
            
            return MosaicLayout(
                rows: adjustedRows,
                cols: cols,
                thumbnailSize: CGSize(width: thumbnailWidth, height: thumbnailHeight),
                positions: positions,
                thumbCount: count,
                thumbnailSizes: thumbnailSizes,
                mosaicSize: CGSize(
                    width: CGFloat(cols) * thumbnailWidth,
                    height: CGFloat(adjustedRows) * thumbnailHeight
                )
            )
        }
        
        // Find optimal layout
        var bestLayout = calculateLayout(rows: Int(sqrt(Double(thumbnailCount))))
        var bestScore = Double.infinity
        
        for rows in 1...thumbnailCount {
            let layout = calculateLayout(rows: rows)
            let fillRatio = (CGFloat(layout.rows) * layout.thumbnailSize.height) / CGFloat(mosaicHeight)
            let thumbnailCount = layout.positions.count
            let countDifference = abs(thumbnailCount - count)
            let score = (1 - fillRatio) + Double(countDifference) / Double(count)
            
            if score < bestScore {
                bestScore = score
                bestLayout = layout
            }
            
            if CGFloat(layout.rows) * layout.thumbnailSize.height > CGFloat(mosaicHeight) {
                break
            }
        }
        
        return bestLayout
    }
    
    // MARK: - Helper Methods
    
    private func getInitialLayoutParams(_ density: String) -> (largeCols: Int, largeRows: Int, smallCols: Int, smallRows: Int) {
        switch density.uppercased() {
        case "XXL":
            return (2, 1, 4, 2)
        case "XL":
            return (3, 1, 6, 2)
        case "L":
            return (3, 2, 6, 4)
        case "M":
            return (4, 2, 8, 4)
        case "S":
            return (6, 2, 12, 4)
        case "XS":
            return (8, 2, 16, 4)
        case "XXS":
            return (9, 4, 18, 8)
        default:
            return (4, 2, 8, 4)
        }
    }
    
    private func generateRowConfigs(
        largeCols: Int,
        largeRows: Int,
        smallCols: Int,
        smallRows: Int
    ) -> [(smallCount: Int, largeCount: Int)] {
        var configs: [(Int, Int)] = []
        let halfSmallRows = smallRows / 2
        
        // Add top small rows
        for _ in 0..<halfSmallRows {
            configs.append((smallCols, 0))
        }
        
        // Add large rows
        for _ in 0..<largeRows {
            configs.append((0, largeCols))
        }
        
        // Add bottom small rows
        for _ in 0..<halfSmallRows {
            configs.append((smallCols, 0))
        }
        
        return configs
    }
    
    private func adjustPortraitLayout(
        smallCols: Int,
        largeCols: Int,
        smallRows: Int,
        largeRows: Int,
        smallThumbWidth: CGFloat,
        smallThumbHeight: CGFloat,
        mosaicAspectRatio: CGFloat
    ) -> (smallCols: Int, largeCols: Int) {
        var adjustedSmallCols = smallCols
        var adjustedLargeCols = largeCols
        
        var mozW = smallThumbWidth * CGFloat(adjustedSmallCols)
        var mozH = smallThumbHeight * CGFloat(smallRows + largeRows * 2)
        var mozAR = mozW / mozH
        
        while mozAR < mosaicAspectRatio {
            adjustedSmallCols += 2
            adjustedLargeCols += 1
            mozW = smallThumbWidth * CGFloat(adjustedSmallCols)
            mozH = smallThumbHeight * CGFloat(smallRows + largeRows * 2)
            mozAR = mozW / mozH
        }
        
        return (adjustedSmallCols, adjustedLargeCols)
    }
    
    private func adjustLandscapeLayout(
        smallRows: Int,
        largeRows: Int,
        mosaicHeight: Int,
        smallThumbHeight: CGFloat
    ) -> (smallRows: Int, largeRows: Int) {
        var adjustedSmallRows = smallRows
        var adjustedLargeRows = largeRows
        
        let tmpTotalRows = Int(CGFloat(mosaicHeight) / smallThumbHeight)
        var diff = tmpTotalRows - (adjustedSmallRows + 2 * adjustedLargeRows)
        
        while diff > 0 {
            if diff >= 2 {
                adjustedLargeRows += 1
                diff -= 2
            } else if diff >= 1 {
                adjustedSmallRows += 1
                diff -= 1
            }
        }
        
        return (adjustedSmallRows, adjustedLargeRows)
    }
    
    /// Calculate thumbnail count based on video duration and width
    /// - Parameters:
    ///   - duration: Video duration in seconds
    ///   - width: Mosaic width
    ///   - density: Density configuration
    /// - Returns: Optimal number of thumbnails
    public func calculateThumbnailCount(
        duration: Double,
        width: Int,
        density: DensityConfig,
        useAutoLayout: Bool = false
    ) -> Int {
        if duration < 5 { return 4 }
        
        if useAutoLayout {
            // For auto layout, calculate based on largest screen size
            guard let screen = getLargestScreen() else { return 4 }
            let scaleFactor = screen.backingScaleFactor
            let minThumbWidth: CGFloat = 160 * scaleFactor
            
            // Calculate maximum thumbnails that can fit on screen
            let maxHorizontal = Int(floor(screen.visibleFrame.width / minThumbWidth))
            let maxVertical = Int(floor(screen.visibleFrame.height / (minThumbWidth / mosaicAspectRatio)))
            
            return min(maxHorizontal * maxVertical, 800)
        }
        
        // Original calculation for non-auto layout
        let base = Double(width) / 200.0
        let k = 10.0
        let decayFactor = 0.2
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, 800)
    }
}
