# HyperMovie Documentation

## Project Structure

### App Components

#### Views
- **ContentView**: Main app structure with three-column navigation
  - Left: LibrarySidebar for library navigation
  - Middle: VideoList for displaying videos in grid layout
  - Right: VideoDetail for video preview and details

#### Package Modules
1. **HyperMovieModels**
   - Data structures and models
   - SwiftData integration for persistence
   - Key models: Video, VideoMetadata, LibraryItem, SmartFolderCriteria

2. **HyperMovieCore**
   - Core protocols and interfaces
   - Logging integration
   - Base functionality definitions

3. **HyperMovieServices**
   - Concrete implementations
   - Video processing and management
   - Async operations handling
   - VideoFinderService for discovering videos

### Workflow

1. **Folder Selection**
   - User selects folder in LibrarySidebar
   - Videos are loaded using VideoFinderService
   - Videos are displayed in VideoList
   - Each video card shows thumbnail, filename, and size

2. **Video Selection**
   - User selects video in VideoList
   - VideoDetail shows:
     - Video player
     - Mosaic generation controls
     - Thumbnail grid
     - Metadata (resolution, codec, duration)

3. **Video Processing**
   - Automatic thumbnail generation
   - Optional mosaic generation
   - Optional preview generation
   - Metadata extraction (codec, bitrate, etc.)

4. **Smart Folders**
   - Filter videos by various criteria:
     - Date ranges (today, last week, last month)
     - File size
   - Name patterns
     - Keywords in metadata
   - Automatic updates when new videos match criteria

## Dependencies

- **swift-collections**: Advanced collection types
- **swift-log**: Logging functionality
- **swift-async-algorithms**: Advanced async operations

## Recent Changes

### Version 1.0.1
- Added VideoFinderService for discovering videos in folders
  - Support for folder scanning
  - Smart folder functionality with customizable criteria
  - Date-based video filtering
  - File size and metadata-based filtering
- Added SmartFolderCriteria model for flexible video filtering
  - Predefined criteria for common use cases (today, last week, etc.)
  - Custom criteria support for advanced filtering

### Version 1.0.0
- Initial implementation of three-column navigation
- SwiftData integration for persistence
- Video processing and thumbnail generation
- Mosaic and preview generation features

## [Unreleased]

### Added
- Comprehensive test plan implementation
  - Created detailed TestPlan.xctestplan with Debug and Release configurations
  - Added test coverage goals and monitoring
  - Implemented thread sanitizer and timeout checks
  - Set up random test execution ordering for better reliability
- Detailed test strategy documentation
  - Module-specific test plans for Models, Core, and Services
  - Test categories and implementation guidelines
  - Best practices and maintenance procedures
  - Continuous integration recommendations
- Adaptive Concurrent Batch Processing in VideoProcessor
  - Dynamic concurrency adjustment based on system metrics
  - CPU, memory, and disk I/O monitoring
  - Batch-based video processing with size of 5
  - Configurable minimum (2) and maximum (8) concurrent tasks
  - Enhanced logging and progress tracking
  - System resource optimization
- ProcessingMetrics model for system resource monitoring
  - CPU usage tracking
  - Memory availability monitoring
  - Disk I/O pressure measurement
  - Formatted string representations for metrics
  - Adaptive concurrency recommendations
- Preview Generation Feature
  - Added a new "Generate Preview" button in the video detail view with two modes:
    - Quick Preview (30s, XS density) - Shows in the player
    - Custom Preview (30-240s, configurable density) - Opens in IINA
  - Preview generation using video extracts with speed adjustment
  - Configurable preview settings:
    - Duration: 30-240 seconds
    - Density: Uses DensityConfig (XS to XL)
    - Save location: Temp directory or next to original
  - Automatic speed adjustment up to 1.5x to fit target duration
  - Visual feedback during preview generation
  - Error handling and user notifications
  - Preview player with close button to return to original video
- Created comprehensive `.gitignore` file to exclude unnecessary files from version control
  - Added macOS system files
  - Added Xcode-specific files
  - Added dependency management files
  - Added IDE-specific files
  - Added project-specific exclusions (@Othersources/)
- Created comprehensive README.md with:
  - Detailed feature overview
  - Installation and getting started guides
  - System requirements
  - Advanced features documentation
  - Contributing and support information

### Changed
- Updated test configurations to include environment variables
- Enhanced test target organization
- Improved test coverage tracking
- Updated `AppStateManaging` protocol to match concrete implementation:
  - Added required service properties (`videoProcessor`, `libraryScanner`, `mosaicGenerator`, `previewGenerator`, `modelContext`)
  - Updated `loadLibrary()` method to be throwing
  - Improved documentation with detailed property descriptions
  - Changed `libraryScanner` to be get-only to prevent external modification
- Fixed `loadLibrary()` implementation by removing unnecessary optional check for non-optional `modelContext`
- Fixed initialization order in AppState by using local variable for ModelContext initialization
- Fixed `LibraryItem` implementation:
  - Removed circular reference in parent parameter type
  - Updated SmartFolderCriteria to macOS 14 compatibility
  - Improved criteria matching with case-insensitive name filtering
  - Removed videos relationship field for better data management
  - Videos are now stored directly in SwiftData schema
- Improved library loading by moving it to ContentView's task modifier for window appearance timing
- Updated video processing pipeline to use batched processing
- Improved resource utilization during video processing
- Enhanced error handling and progress reporting
- Moved ProcessingMetrics from VideoProcessor to Models layer
  - Improved architecture separation
  - Better reusability across services
  - Enhanced public API surface
  - Added formatted string representations for metrics
- Enhanced the video detail controls layout to accommodate both preview and mosaic generation buttons
- Improved error handling and user feedback during video processing operations
- Updated PreviewSettingsSheet to use DensityConfig for consistent UX
- Standardized density controls across thumbnail and preview generation

### Fixed
- Proper cleanup of resources after preview generation
- Correct handling of video preview URLs
- Consistent density configuration across the application

### Technical Details
- Test Configurations:
  - Debug: Enhanced logging and comprehensive error reporting
  - Release: Production logging and performance metrics
- Coverage Goals:
  - Line coverage: ≥ 85%
  - Branch coverage: ≥ 80%
  - Function coverage: ≥ 90%
- Test Categories:
  - Unit Tests
  - Integration Tests
  - Performance Tests
  - Concurrency Tests
- Added ProcessingMetrics struct for system resource monitoring
- Implemented Darwin-based system metrics collection
- Enhanced concurrent processing with adaptive task management
- Added batch-based processing to prevent system overload
- Added PreviewGenerating protocol for preview generation operations
- Implemented PreviewConfiguration for flexible preview settings
- Added PreviewError enum for structured error handling
- Enhanced preview generation with:
  - Intelligent extract selection
  - Dynamic speed adjustment
  - Proper resource management
  - Performance monitoring with signposts
