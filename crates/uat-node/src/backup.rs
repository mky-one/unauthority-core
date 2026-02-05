use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use chrono::Local;
use serde::{Deserialize, Serialize};
use tokio::time::{interval, Duration};

/// Automated backup system for validator databases
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupConfig {
    /// Source directory to backup
    pub source_dir: PathBuf,
    /// Backup destination directory
    pub backup_dir: PathBuf,
    /// Backup interval in seconds
    pub interval_secs: u64,
    /// Maximum number of backups to keep
    pub max_backups: usize,
    /// Compress backups
    pub compress: bool,
}

impl Default for BackupConfig {
    fn default() -> Self {
        Self {
            source_dir: PathBuf::from("node_data"),
            backup_dir: PathBuf::from("backups"),
            interval_secs: 3600, // 1 hour
            max_backups: 24,     // Keep 24 backups (1 day of hourly backups)
            compress: true,
        }
    }
}

pub struct BackupManager {
    config: BackupConfig,
}

impl BackupManager {
    pub fn new(config: BackupConfig) -> Self {
        Self { config }
    }

    /// Start automated backup loop
    pub async fn start(&self) -> Result<(), Box<dyn std::error::Error>> {
        // Create backup directory if it doesn't exist
        fs::create_dir_all(&self.config.backup_dir)?;

        let mut interval = interval(Duration::from_secs(self.config.interval_secs));

        loop {
            interval.tick().await;

            if let Err(e) = self.create_backup().await {
                eprintln!("Backup failed: {}", e);
            } else {
                println!("✅ Backup completed successfully");
            }

            // Cleanup old backups
            if let Err(e) = self.cleanup_old_backups() {
                eprintln!("Backup cleanup failed: {}", e);
            }
        }
    }

    /// Create a backup
    async fn create_backup(&self) -> Result<(), Box<dyn std::error::Error>> {
        let timestamp = Local::now().format("%Y%m%d_%H%M%S");
        let backup_name = format!("backup_{}", timestamp);
        let backup_path = self.config.backup_dir.join(&backup_name);

        println!("🔄 Creating backup: {}", backup_name);

        // Copy source directory to backup
        self.copy_dir_recursive(&self.config.source_dir, &backup_path)?;

        // Compress if enabled
        if self.config.compress {
            self.compress_backup(&backup_path, &backup_name)?;
            // Remove uncompressed directory
            fs::remove_dir_all(&backup_path)?;
        }

        println!("✅ Backup created: {}", backup_name);

        Ok(())
    }

    /// Copy directory recursively
    fn copy_dir_recursive(&self, src: &Path, dst: &Path) -> Result<(), Box<dyn std::error::Error>> {
        if !src.exists() {
            return Err(format!("Source directory does not exist: {:?}", src).into());
        }

        fs::create_dir_all(dst)?;

        for entry in fs::read_dir(src)? {
            let entry = entry?;
            let path = entry.path();
            let file_name = entry.file_name();
            let dst_path = dst.join(&file_name);

            if path.is_dir() {
                self.copy_dir_recursive(&path, &dst_path)?;
            } else {
                fs::copy(&path, &dst_path)?;
            }
        }

        Ok(())
    }

    /// Compress backup directory to tar.gz
    fn compress_backup(&self, source: &Path, name: &str) -> Result<(), Box<dyn std::error::Error>> {
        use flate2::Compression;
        use flate2::write::GzEncoder;
        use tar::Builder;

        let tar_gz_path = self.config.backup_dir.join(format!("{}.tar.gz", name));
        let tar_gz = fs::File::create(&tar_gz_path)?;
        let enc = GzEncoder::new(tar_gz, Compression::default());
        let mut tar = Builder::new(enc);

        tar.append_dir_all(name, source)?;
        tar.finish()?;

        Ok(())
    }

    /// Remove old backups exceeding max_backups limit
    fn cleanup_old_backups(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut backups: Vec<_> = fs::read_dir(&self.config.backup_dir)?
            .filter_map(|e| e.ok())
            .filter(|e| {
                let name = e.file_name();
                let name_str = name.to_string_lossy();
                name_str.starts_with("backup_")
            })
            .collect();

        // Sort by modification time (newest first)
        backups.sort_by_key(|e| {
            e.metadata()
                .and_then(|m| m.modified())
                .unwrap_or(SystemTime::UNIX_EPOCH)
        });
        backups.reverse();

        // Remove old backups
        for backup in backups.iter().skip(self.config.max_backups) {
            let path = backup.path();
            if path.is_dir() {
                fs::remove_dir_all(&path)?;
            } else {
                fs::remove_file(&path)?;
            }
            println!("🗑️  Removed old backup: {:?}", path);
        }

        Ok(())
    }

    /// List all backups
    pub fn list_backups(&self) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        let mut backups: Vec<String> = fs::read_dir(&self.config.backup_dir)?
            .filter_map(|e| e.ok())
            .filter(|e| {
                let name = e.file_name();
                let name_str = name.to_string_lossy();
                name_str.starts_with("backup_")
            })
            .map(|e| e.file_name().to_string_lossy().to_string())
            .collect();

        backups.sort();
        backups.reverse();

        Ok(backups)
    }

    /// Restore from backup
    pub fn restore_backup(&self, backup_name: &str) -> Result<(), Box<dyn std::error::Error>> {
        let backup_path = self.config.backup_dir.join(backup_name);

        if !backup_path.exists() {
            return Err(format!("Backup not found: {}", backup_name).into());
        }

        println!("🔄 Restoring backup: {}", backup_name);

        // If compressed, extract first
        if backup_name.ends_with(".tar.gz") {
            self.extract_backup(&backup_path)?;
            let extracted_name = backup_name.trim_end_matches(".tar.gz");
            let extracted_path = self.config.backup_dir.join(extracted_name);
            
            // Remove existing source directory
            if self.config.source_dir.exists() {
                fs::remove_dir_all(&self.config.source_dir)?;
            }

            // Copy extracted backup to source
            self.copy_dir_recursive(&extracted_path, &self.config.source_dir)?;

            // Remove extracted directory
            fs::remove_dir_all(&extracted_path)?;
        } else {
            // Remove existing source directory
            if self.config.source_dir.exists() {
                fs::remove_dir_all(&self.config.source_dir)?;
            }

            // Copy backup to source
            self.copy_dir_recursive(&backup_path, &self.config.source_dir)?;
        }

        println!("✅ Backup restored successfully");

        Ok(())
    }

    /// Extract tar.gz backup
    fn extract_backup(&self, archive_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        use flate2::read::GzDecoder;
        use tar::Archive;

        let tar_gz = fs::File::open(archive_path)?;
        let tar = GzDecoder::new(tar_gz);
        let mut archive = Archive::new(tar);

        archive.unpack(&self.config.backup_dir)?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_backup_creation() {
        let temp_source = TempDir::new().unwrap();
        let temp_backup = TempDir::new().unwrap();

        // Create test file
        let test_file = temp_source.path().join("test.txt");
        fs::write(&test_file, "test data").unwrap();

        let config = BackupConfig {
            source_dir: temp_source.path().to_path_buf(),
            backup_dir: temp_backup.path().to_path_buf(),
            interval_secs: 3600,
            max_backups: 5,
            compress: false,
        };

        let manager = BackupManager::new(config);
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(manager.create_backup()).unwrap();

        let backups = manager.list_backups().unwrap();
        assert!(!backups.is_empty());
    }

    #[test]
    fn test_backup_cleanup() {
        let temp_source = TempDir::new().unwrap();
        let temp_backup = TempDir::new().unwrap();

        let config = BackupConfig {
            source_dir: temp_source.path().to_path_buf(),
            backup_dir: temp_backup.path().to_path_buf(),
            interval_secs: 3600,
            max_backups: 2,
            compress: false,
        };

        let manager = BackupManager::new(config);

        // Create multiple backups
        let rt = tokio::runtime::Runtime::new().unwrap();
        for _ in 0..5 {
            rt.block_on(manager.create_backup()).unwrap();
            std::thread::sleep(std::time::Duration::from_millis(100));
        }

        let backups = manager.list_backups().unwrap();
        assert_eq!(backups.len(), 2); // Should only keep 2 backups
    }
}
