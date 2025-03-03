import Foundation
import CoreGraphics
import AppKit
import OSLog
import os.signpost

/// Logger for mosaic layout operations
fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movieview", category: "MosaicLayout")
private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "com.movieview", category: "MosaicLayout")

/// Cache for storing frequently used layouts
private struct LayoutCacheKey: Hashable {
    let aspectRatio: CGFloat
    let thumbnailCount: Int
    let width: Int
    let useAutoLayout: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(aspectRatio)
        hasher.combine(thumbnailCount)
        hasher.combine(width)
        hasher.combine(useAutoLayout)
    }

    static func == (lhs: LayoutCacheKey, rhs: LayoutCacheKey) -> Bool {
        return lhs.aspectRatio == rhs.aspectRatio &&
               lhs.thumbnailCount == rhs.thumbnailCount &&
               lhs.width == rhs.width &&
               lhs.useAutoLayout == rhs.useAutoLayout
    }
    
    func description() -> String {
        return "LayoutCacheKey(aspectRatio: \(aspectRatio.description), thumbnailCount: \(thumbnailCount.description), width: \(width.description), useAutoLayout: \(useAutoLayout.description))"
    }
}

/// Represents a section in the mosaic layout
struct MosaicSection {
    let startIndex: Int
    let count: Int
    let startTime: Double
    let endTime: Double
    let thumbsPerRow: Int
    let thumbSize: CGSize
}

/// Represents the layout information for a mosaic
struct MosaicLayout {
    /// Number of rows in the mosaic
    let rows: Int
    
    /// Number of columns in the mosaic
    let cols: Int
    
    /// Base size for thumbnails
    let thumbnailSize: CGSize
    
    /// Positions of thumbnails in the mosaic
    let positions: [(x: Int, y: Int)]
    
    /// Total number of thumbnails
    let thumbCount: Int
    
    /// Individual sizes for each thumbnail (may vary for emphasis)
    let thumbnailSizes: [CGSize]
    
    /// Overall size of the mosaic
    let mosaicSize: CGSize
    
    /// Information about each section (first, middle, last)
    let sections: [MosaicSection]
    
    /// Cache for storing calculated layouts
    private static var layoutCache: [LayoutCacheKey: (layout: MosaicLayout, timestamp: Date)] = [:]
    
    /// Maximum number of cached layouts
    private static let maxCacheSize = 50
    
    /// Cache TTL
    private static let cacheTTL: TimeInterval = 3600 // 1 hour
    
    /// Get the screen with the largest resolution
    private static func getLargestScreen() -> NSScreen? {
        NSScreen.screens.max(by: { screen1, screen2 in
            let size1 = screen1.frame.size
            let size2 = screen2.frame.size
            return (size1.width * size1.height) < (size2.width * size2.height)
        })
    }
    
    /// Clear the layout cache
    static func clearCache() {
        layoutCache.removeAll()
    }
    
    /// Calculate optimal layout for given parameters
    /// - Parameters:
    ///   - originalAspectRatio: Aspect ratio of the original video
    ///   - thumbnailCount: Number of thumbnails to include
    ///   - mosaicWidth: Desired width of the mosaic
    ///   - useAutoLayout: Whether to optimize for screen size
    ///   - density: Density configuration
    /// - Returns: Optimal layout configuration
    static func calculateOptimalLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int,
        useAutoLayout: Bool = false,
        density: DensityConfig
    ) -> MosaicLayout {
        let interval = signposter.beginInterval("Calculate Optimal Layout", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Calculate Optimal Layout", interval) }
        
        logger.debug("Starting optimal layout calculation: aspectRatio=\(originalAspectRatio), count=\(thumbnailCount), width=\(mosaicWidth), auto=\(useAutoLayout)")
        
        // Calculate new layout
        let layout: MosaicLayout = if useAutoLayout {
            calculateAutoLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount,
                density: density
            )
        } else {
            calculateEmphasisLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount,
                mosaicWidth: mosaicWidth,
                density: density
            )
        }
        
        signposter.emitEvent("Layout Calculation Complete", "thumbnails: \(thumbnailCount)")
        return layout
    }
    
    /// Calculate layout optimized for screen size
    private static func calculateAutoLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        density: DensityConfig
    ) -> MosaicLayout {
        let startTime = CFAbsoluteTimeGetCurrent()
        let interval = signposter.beginInterval("Auto Layout Calculation", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Auto Layout Calculation", interval) }
        
        logger.debug("Starting auto layout calculation: aspectRatio=\(originalAspectRatio), count=\(thumbnailCount)")
        
        guard let screen = getLargestScreen() else {
            logger.warning("No screen found, falling back to classic layout")
            signposter.emitEvent("Fallback to Classic Layout", "No screen found")
            return calculateClassicLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount,
                mosaicWidth: 1920,
                density: density
            )
        }
        
        let screenSize = screen.visibleFrame.size
        let scaleFactor = screen.backingScaleFactor
        
        // Adjust base thumbnail size based on orientation
        let isPortrait = originalAspectRatio < 1.0
        let baseThumbWidth: CGFloat = isPortrait ? 120 : 160
        let minThumbWidth = baseThumbWidth * scaleFactor
        let minThumbHeight = minThumbWidth / originalAspectRatio
        
        // Calculate maximum possible thumbnails with adjusted sizes
        let maxHorizontal = Int(floor(screenSize.width / minThumbWidth))
        let maxVertical = Int(floor(screenSize.height / minThumbHeight))
        
        // Adjust grid dimensions based on orientation
        let (minRows, maxRows) = isPortrait 
            ? (2, min(maxVertical, Int(Double(thumbnailCount) * 0.8)))
            : (1, maxVertical)
        
        let (minCols, maxCols) = isPortrait
            ? (max(3, Int(Double(maxHorizontal) * 0.6)), maxHorizontal)
            : (3, maxHorizontal)
        
        var bestLayout: MosaicLayout?
        var bestScore: CGFloat = 0
        
        logger.debug("""
        Auto layout calculation:
        - Portrait: \(isPortrait)
        - Screen size: \(screenSize.width)×\(screenSize.height)
        - Min thumb size: \(minThumbWidth)×\(minThumbHeight)
        - Grid limits: \(minRows)-\(maxRows) rows, \(minCols)-\(maxCols) cols
        """)
        
        // Try different grid configurations
        let gridInterval = signposter.beginInterval("Grid Configuration Search", id: signposter.makeSignpostID())
       
        for rows in minRows...maxRows {
            for cols in minCols...maxCols {
                let totalThumbs = rows * cols
                if totalThumbs < thumbnailCount { continue }
                
                let thumbWidth = screenSize.width / CGFloat(cols)
                let thumbHeight = screenSize.height / CGFloat(rows)
                
                // Calculate scores with orientation-specific weights
                let coverage = (thumbWidth * CGFloat(cols) * thumbHeight * CGFloat(rows)) / (screenSize.width * screenSize.height)
                let readabilityScore = (thumbWidth * thumbHeight) / (minThumbWidth * minThumbHeight)
                let aspectScore = isPortrait 
                    ? min(thumbHeight / thumbWidth, 1.5) / 1.5 // Prefer taller thumbnails for portrait
                    : min(thumbWidth / thumbHeight, 2.0) / 2.0 // Prefer wider thumbnails for landscape
                
                let score = coverage * 0.4 + readabilityScore * 0.4 + aspectScore * 0.2
                
                if score > bestScore {
                    bestScore = score
                    signposter.emitEvent("New Best Layout Found", "score: \(score), grid: \(rows)×\(cols)")
                    bestLayout = createLayout(
                        rows: rows,
                        cols: cols,
                        thumbnailCount: thumbnailCount,
                        thumbWidth: thumbWidth,
                        thumbHeight: thumbHeight,
                        sections: [MosaicSection(
                            startIndex: 0,
                            count: thumbnailCount,
                            startTime: 0,
                            endTime: 1.0,
                            thumbsPerRow: cols,
                            thumbSize: CGSize(width: thumbWidth, height: thumbHeight)
                        )]
                    )
                }
            }
        }
        signposter.endInterval("Grid Configuration Search", gridInterval)
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.debug("Auto layout calculation completed in \(String(format: "%.2f", duration))ms with score \(bestScore)")
        return bestLayout ?? calculateClassicLayout(
            originalAspectRatio: originalAspectRatio,
            thumbnailCount: thumbnailCount,
            mosaicWidth: Int(screenSize.width),
            density: density
        )
    }
    
    /// Calculate classic grid layout
    private static func calculateClassicLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int,
        density: DensityConfig
    ) -> MosaicLayout {
        let startTime = CFAbsoluteTimeGetCurrent()
        let interval = signposter.beginInterval("Classic Layout Calculation", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Classic Layout Calculation", interval) }
        
        logger.debug("Starting classic layout calculation: aspectRatio=\(originalAspectRatio), count=\(thumbnailCount), width=\(mosaicWidth)")
        
        let count = thumbnailCount
        let baseCount = Int(Double(count) / density.factor)
        let rows = Int(sqrt(Double(baseCount)))
        let cols = Int(ceil(Double(baseCount) / Double(rows)))
        
        let thumbWidth = CGFloat(mosaicWidth) / CGFloat(cols)
        let thumbHeight = thumbWidth / originalAspectRatio
        
        let layout = createLayout(
            rows: rows,
            cols: cols,
            thumbnailCount: count,
            thumbWidth: thumbWidth,
            thumbHeight: thumbHeight,
            sections: [MosaicSection(
                startIndex: 0,
                count: count,
                startTime: 0,
                endTime: 1.0,
                thumbsPerRow: cols,
                thumbSize: CGSize(width: thumbWidth, height: thumbHeight)
            )]
        )
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.debug("Classic layout calculation completed in \(String(format: "%.2f", duration))ms")
        return layout
    }
    
    /// Calculate layout with emphasized middle section
    private static func calculateEmphasisLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int, 
        density: DensityConfig
    ) -> MosaicLayout {
        let startTime = CFAbsoluteTimeGetCurrent()
        let interval = signposter.beginInterval("Emphasis Layout Calculation", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Emphasis Layout Calculation", interval) }
        
        logger.debug("Starting emphasis layout calculation: aspectRatio=\(originalAspectRatio), count=\(thumbnailCount), width=\(mosaicWidth)")
        
        // Target 16:9 aspect ratio
        let targetAspectRatio: CGFloat = 16.0 / 9.0
        let targetHeight = CGFloat(mosaicWidth) / targetAspectRatio
     //   print("Target dimensions - width: \(mosaicWidth), height: \(targetHeight), aspect ratio: \(targetAspectRatio)")
        
        // Adjust scale based on orientation
        let isPortrait = originalAspectRatio < 1.0
        let middleScale: CGFloat = isPortrait ? 1.8 : 1.5 // Larger scale for portrait videos
        print("Orientation: \(isPortrait ? "Portrait" : "Landscape"), Middle scale: \(middleScale)")
        
        // Calculate optimal base thumbnails per row
        let minThumbsPerRow: CGFloat = isPortrait ? 5 : 6
        let maxThumbsPerRow: CGFloat = isPortrait ? 12 : 15
      //  print("Thumbnails per row - min: \(minThumbsPerRow), max: \(maxThumbsPerRow)")
        
        // Calculate base thumbnail width based on mosaic width and density
        let baseThumbWidth = CGFloat(mosaicWidth) / (maxThumbsPerRow * density.factor)
        let minThumbWidth = CGFloat(mosaicWidth) / (maxThumbsPerRow * 1.5) // Minimum acceptable width
        let maxThumbWidth = CGFloat(mosaicWidth) / minThumbsPerRow // Maximum acceptable width
      //  print("Thumbnail widths - base: \(baseThumbWidth), min: \(minThumbWidth), max: \(maxThumbWidth)")
        
        // Calculate optimal base thumbs per row considering thumbnail count
        let targetBaseCount = Double(thumbnailCount) * (isPortrait ? 0.3 : 0.35) // Target count for base sections
        let idealRowCount = isPortrait ? 4 : 3 // Ideal number of rows for base sections
        let suggestedThumbsPerRow = ceil(targetBaseCount / Double(idealRowCount))
      //  print("Base section calculations - target count: \(targetBaseCount), ideal rows: \(idealRowCount), suggested per row: \(suggestedThumbsPerRow)")
        
        // Adjust based on density and width constraints
        let densityAdjustedThumbsPerRow = suggestedThumbsPerRow * density.factor
        let widthPerThumb = CGFloat(mosaicWidth) / CGFloat(densityAdjustedThumbsPerRow)
      //  print("Density adjustments - thumbs per row: \(densityAdjustedThumbsPerRow), width per thumb: \(widthPerThumb)")
        
        // Clamp the width to acceptable range and recalculate final thumbs per row
        let clampedWidth = min(maxThumbWidth, max(minThumbWidth, widthPerThumb))
        let baseThumbsPerRow = max(
            minThumbsPerRow,
            min(
                maxThumbsPerRow * density.factor,
                CGFloat(mosaicWidth) / clampedWidth
            )
        )
      //  print("Final base calculations - clamped width: \(clampedWidth), thumbs per row: \(baseThumbsPerRow)")
        
        // Calculate base dimensions
        let baseWidth = CGFloat(mosaicWidth) / baseThumbsPerRow
        let baseHeight = baseWidth / originalAspectRatio
        let middleWidth = baseWidth * middleScale
        let middleHeight = baseHeight * middleScale
      //  print("Thumbnail dimensions - base: \(baseWidth)×\(baseHeight), middle: \(middleWidth)×\(middleHeight)")
        
        // Calculate thumbnails per row with density consideration
        let baseThumbsPerRowFinal = max(1, Int(floor(baseThumbsPerRow)))
        let middleThumbsPerRow = max(1, Int(floor(CGFloat(mosaicWidth) / middleWidth)))
      //  print("Final thumbnails per row - base: \(baseThumbsPerRowFinal), middle: \(middleThumbsPerRow)")
        
        // Adjust middle section ratio based on orientation and target aspect ratio
        let middleSectionRatio = isPortrait ? 0.5 : 0.4
      //                  print("Middle section ratio: \(middleSectionRatio)")
        
        // Calculate optimal distribution
        let targetMiddleCount = Int(Double(thumbnailCount) * middleSectionRatio)
        let middleRows = Int(ceil(Double(targetMiddleCount) / Double(middleThumbsPerRow)))
        let adjustedMiddleCount = middleRows * middleThumbsPerRow
      //  print("Middle section distribution - target: \(targetMiddleCount), rows: \(middleRows), adjusted: \(adjustedMiddleCount)")
        
        // Calculate side sections with balanced distribution
        let remainingCount = thumbnailCount - adjustedMiddleCount
        let sideRowsTotal = Int(ceil(Double(remainingCount) / Double(baseThumbsPerRowFinal)))
        let sideRowsEach = max(1, sideRowsTotal / 2)
        let adjustedSideCount = sideRowsEach * baseThumbsPerRowFinal
      //  print("Side sections distribution - remaining: \(remainingCount), rows each: \(sideRowsEach), count each: \(adjustedSideCount)")
        
        // Calculate total height without spacing
        let rawHeight = (CGFloat(sideRowsEach * 2) * baseHeight) + (CGFloat(middleRows) * middleHeight)
      //  print("Raw height before spacing: \(rawHeight)")
        
        // Calculate spacing to achieve target aspect ratio
        let totalSpacingNeeded = max(0, targetHeight - rawHeight)
        let totalSections = CGFloat(sideRowsEach * 2 + middleRows + 2) // +2 for extra spaces around middle section
        let verticalSpacing = min(totalSpacingNeeded / totalSections, baseHeight * 0.15) // Cap at 15% of base height
        print("Spacing calculations - total needed: \(totalSpacingNeeded), per section: \(verticalSpacing)")
        
        var positions: [(x: Int, y: Int)] = []
        var thumbnailSizes: [CGSize] = []
        var currentY: CGFloat = verticalSpacing // Start with spacing
        
        // Create sections array
        var sections: [MosaicSection] = []
        
        // Function to add a row of thumbnails with proper spacing
        func addRow(thumbWidth: CGFloat, thumbHeight: CGFloat, count: Int) {
            let xSpacing = (CGFloat(mosaicWidth) - (CGFloat(count) * thumbWidth)) / CGFloat(count + 1)
            print("Adding row - width: \(thumbWidth), height: \(thumbHeight), count: \(count), x-spacing: \(xSpacing)")
            
            for i in 0..<count {
                let x = xSpacing + CGFloat(i) * (thumbWidth + xSpacing)
                positions.append((x: Int(x), y: Int(currentY)))
                thumbnailSizes.append(CGSize(width: thumbWidth, height: thumbHeight))
            }
            currentY += thumbHeight + verticalSpacing
        }
        
        // First section
        let firstSectionInterval = signposter.beginInterval("First Section Generation", id: signposter.makeSignpostID())
      //  print("\nGenerating first section...")
        let firstSectionStartIndex = 0
        for _ in 0..<sideRowsEach {
            addRow(thumbWidth: baseWidth, thumbHeight: baseHeight, count: baseThumbsPerRowFinal)
        }
        sections.append(MosaicSection(
            startIndex: firstSectionStartIndex,
            count: adjustedSideCount,
            startTime: 0,
            endTime: 1.0/3.0,
            thumbsPerRow: baseThumbsPerRowFinal,
            thumbSize: CGSize(width: baseWidth, height: baseHeight)
        ))
        signposter.endInterval("First Section Generation", firstSectionInterval)
        
        // Add extra spacing before middle section
        currentY += verticalSpacing
      //  print("\nGenerating middle section...")

        // Middle section
        let middleSectionInterval = signposter.beginInterval("Middle Section Generation", id: signposter.makeSignpostID())
        let middleSectionStartIndex = positions.count
        for _ in 0..<middleRows {
            addRow(thumbWidth: middleWidth, thumbHeight: middleHeight, count: middleThumbsPerRow)
        }
        sections.append(MosaicSection(
            startIndex: middleSectionStartIndex,
            count: adjustedMiddleCount,
            startTime: 1.0/3.0,
            endTime: 2.0/3.0,
            thumbsPerRow: middleThumbsPerRow,
            thumbSize: CGSize(width: middleWidth, height: middleHeight)
        ))
        signposter.endInterval("Middle Section Generation", middleSectionInterval)
        
        // Add extra spacing after middle section
        currentY += verticalSpacing
      //  print("\nGenerating last section...")
        
        // Last section
        let lastSectionInterval = signposter.beginInterval("Last Section Generation", id: signposter.makeSignpostID())
        let lastSectionStartIndex = positions.count
        for _ in 0..<sideRowsEach {
            addRow(thumbWidth: baseWidth, thumbHeight: baseHeight, count: baseThumbsPerRowFinal)
        }
        sections.append(MosaicSection(
            startIndex: lastSectionStartIndex,
            count: adjustedSideCount,
            startTime: 2.0/3.0,
            endTime: 1.0,
            thumbsPerRow: baseThumbsPerRowFinal,
            thumbSize: CGSize(width: baseWidth, height: baseHeight)
        ))
        signposter.endInterval("Last Section Generation", lastSectionInterval)
        
        let finalHeight = currentY
      //  print("\nFinal mosaic dimensions: \(mosaicWidth)×\(finalHeight)")
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
      //  logger.debug("Emphasis layout calculation completed in \(String(format: "%.2f", duration))ms")
        return MosaicLayout(
            rows: sideRowsEach * 2 + middleRows,
            cols: max(baseThumbsPerRowFinal, middleThumbsPerRow),
            thumbnailSize: CGSize(width: baseWidth, height: baseHeight),
            positions: positions,
            thumbCount: positions.count,
            thumbnailSizes: thumbnailSizes,
            mosaicSize: CGSize(width: CGFloat(mosaicWidth), height: finalHeight),
            sections: sections
        )
    }
    
    /// Create layout with calculated dimensions
    private static func createLayout(
        rows: Int,
        cols: Int,
        thumbnailCount: Int,
        thumbWidth: CGFloat,
        thumbHeight: CGFloat,
        sections: [MosaicSection]
    ) -> MosaicLayout {
        let startTime = CFAbsoluteTimeGetCurrent()
        let interval = signposter.beginInterval("Create Layout", id: signposter.makeSignpostID(), "rows: \(rows), cols: \(cols)")
        defer { signposter.endInterval("Create Layout", interval) }
        
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
        
        let layout = MosaicLayout(
            rows: rows,
            cols: cols,
            thumbnailSize: CGSize(width: thumbWidth, height: thumbHeight),
            positions: positions,
            thumbCount: thumbnailCount,
            thumbnailSizes: thumbnailSizes,
            mosaicSize: CGSize(
                width: CGFloat(cols) * thumbWidth,
                height: CGFloat(rows) * thumbHeight
            ),
            sections: sections
        )
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    //    logger.debug("Layout creation completed in \(String(format: "%.2f", duration))ms")
        return layout
    }
} 