import Foundation
import os

/// Handles migration of Whisper models from Documents folder to Application Support folder
class WhisperModelMigration {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "WhisperModelMigration")
    
    /// Source directory in Documents folder
    private let sourceDirectory: URL
    
    /// Destination directory in Application Support folder
    private let destinationDirectory: URL
    
    /// Flag to track if migration has been completed
    private let migrationCompletedKey = "WhisperModelMigrationCompleted"
    
    /// Initializes a new migration handler
    init() {
        // Define source directory (old location in Documents)
        self.sourceDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperModels")
        
        // Define destination directory (new location in Application Support)
        self.destinationDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.VoiceInk")
            .appendingPathComponent("WhisperModels")
    }
    
    /// Checks if migration is needed
    var isMigrationNeeded: Bool {
        // If migration was already completed, no need to check further
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            return false
        }
        
        // Check if source directory exists and has content
        if FileManager.default.fileExists(atPath: sourceDirectory.path) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
                // Only migrate if there are .bin files in the source directory
                return contents.contains { $0.pathExtension == "bin" }
            } catch {
                logger.error("Error checking source directory: \(error.localizedDescription)")
            }
        }
        
        return false
    }
    
    /// Creates the destination directory if needed
    private func createDestinationDirectoryIfNeeded() -> Bool {
        do {
            if !FileManager.default.fileExists(atPath: destinationDirectory.path) {
                try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                logger.info("Created destination directory at \(self.destinationDirectory.path)")
            }
            return true
        } catch {
            logger.error("Failed to create destination directory: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Performs the migration of models from Documents to Application Support
    /// - Returns: A tuple containing success status and an array of migrated model URLs
    func migrateModels() async -> (success: Bool, migratedModels: [URL]) {
        guard isMigrationNeeded else {
            logger.info("Migration not needed or already completed")
            return (true, [])
        }
        
        guard createDestinationDirectoryIfNeeded() else {
            return (false, [])
        }
        
        var migratedModels: [URL] = []
        
        do {
            // Get all .bin files from source directory
            let modelFiles = try FileManager.default.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "bin" }
            
            if modelFiles.isEmpty {
                logger.info("No model files found to migrate")
                markMigrationAsCompleted()
                return (true, [])
            }
            
            logger.info("Found \(modelFiles.count) model files to migrate")
            
            // Copy each model file to the new location
            for sourceURL in modelFiles {
                let fileName = sourceURL.lastPathComponent
                let destinationURL = destinationDirectory.appendingPathComponent(fileName)
                
                // Skip if file already exists at destination
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    logger.info("Model already exists at destination: \(fileName)")
                    migratedModels.append(destinationURL)
                    continue
                }
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    logger.info("Successfully migrated model: \(fileName)")
                    migratedModels.append(destinationURL)
                } catch {
                    logger.error("Failed to copy model \(fileName): \(error.localizedDescription)")
                }
            }
            
            // Mark migration as completed if at least some models were migrated
            if !migratedModels.isEmpty {
                markMigrationAsCompleted()
                return (true, migratedModels)
            } else {
                return (false, [])
            }
            
        } catch {
            logger.error("Error during migration: \(error.localizedDescription)")
            return (false, [])
        }
    }
    
    /// Marks the migration as completed in UserDefaults
    private func markMigrationAsCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        logger.info("Migration marked as completed")
    }
} 