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

        fileDescriptor = open(filename, O_EVTONLY)
        if fileDescriptor < 0 {
            print("File cannot be monitored: error opening '\(filename)'")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.fileChanged = true
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        self.source = source
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

                fileDescriptor = open(filePath, O_EVTONLY)
                if fileDescriptor >= 0 {
                    let newSource = DispatchSource.makeFileSystemObjectSource(
                        fileDescriptor: fileDescriptor,
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

            return true
        }
        return false
    }
}
