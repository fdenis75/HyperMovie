//
//  ProgressInfo.swift
//  MZBar
//
//  Created by Francois on 04/11/2024.
//


import Foundation

/// Information about processing progress
public struct ProgressInfo {
    public let progressType: ProgressType
    
    /// Current progress (0.0 - 1.0)
    public let progress: Double
    
    /// Currently processing file
    public let currentFile: String
    
    /// Number of processed files
    public let processedFiles: Int
    
    /// Total number of files to process
    public let totalFiles: Int
    
    /// Current processing stage
    public let currentStage: String
    
    /// Time elapsed since start
    public let elapsedTime: TimeInterval
    
    /// Estimated time remaining
    public let estimatedTimeRemaining: TimeInterval
    
    /// Number of skipped files
    public let skippedFiles: Int
    
    /// Number of files with errors
    public let errorFiles: Int
    
    /// Whether processing is currently running
    public let isRunning: Bool
    
    /// Progress of the current file
    public let fileProgress: Double?
    
    /// Frames per second
    public let fps: Double?
    
    /// Completed file information
    public let doneFile: ResultFiles
    
    /// Initialize progress information
    public init(
        progressType: ProgressType,
        progress: Double,
        currentFile: String,
        processedFiles: Int,
        totalFiles: Int,
        currentStage: String,
        elapsedTime: TimeInterval,
        estimatedTimeRemaining: TimeInterval,
        skippedFiles: Int,
        errorFiles: Int,
        isRunning: Bool,
        fileProgress: Double?,
        doneFile: ResultFiles? = nil
    ) {
        self.progressType = progressType
        self.progress = progress
        self.currentFile = currentFile
        self.processedFiles = processedFiles
        self.totalFiles = totalFiles
        self.currentStage = currentStage
        self.elapsedTime = elapsedTime
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.skippedFiles = skippedFiles
        self.errorFiles = errorFiles
        self.isRunning = isRunning
        self.fileProgress = fileProgress
        self.fps = Double(processedFiles) / elapsedTime
        self.doneFile = doneFile ?? ResultFiles(video: URL(fileURLWithPath: currentFile), output: URL(fileURLWithPath: currentFile))
    }
}

