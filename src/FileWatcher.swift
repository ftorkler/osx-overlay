import Foundation

/// Monitors a file for changes using GCD's DispatchSource.
/// Mirrors the C++ `Inotify` class from x11-overlay, adapted for macOS
/// (which doesn't have inotify, so we use kqueue-based dispatch sources).
public final class FileWatcher {

    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var fileChanged: Bool = false
    private let filePath: String

    init(_ filename: String) {
        self.filePath = filename
        setupDispatchSource(for: filename)
    }

    deinit {
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    /// Returns true if the file has been rewritten since the last call.
    /// Resets the flag after reading (edge-triggered).
    func hasFileBeenRewritten() -> Bool {
        if fileChanged {
            fileChanged = false

            // If the file was deleted/renamed, re-watch it
            if fileDescriptor >= 0 {
                // Re-open to handle file replacement (common with atomic writes)
                source?.cancel()
                close(fileDescriptor)
                fileDescriptor = -1
                setupDispatchSource(for: filePath)
            }

            return true
        }
        return false
    }

    /// Opens the file and creates a dispatch source to monitor it for changes.
    /// Replaces any existing file descriptor and source.
    private func setupDispatchSource(for path: String) {
        let fd = open(path, O_EVTONLY)
        if fd < 0 {
            print("File cannot be monitored: error opening '\(path)'")
            return
        }

        fileDescriptor = fd

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )

        newSource.setEventHandler { [weak self] in
            self?.fileChanged = true
        }

        newSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        newSource.resume()
        self.source = newSource
    }
}
