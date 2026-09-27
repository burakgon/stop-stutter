import Darwin
import Foundation

/// Notices when an app update replaces this executable, so the helper can exit and let launchd start the new
/// build. Without this, the old helper keeps running until the Mac restarts or the helper is re-registered.
final class UpdateDetector {
    private struct Identity: Equatable {
        let device: dev_t, inode: ino_t, size: off_t, seconds: Int, nanoseconds: Int

        init?(path: String) {
            var info = stat()
            guard stat(path, &info) == 0 else { return nil }
            device = info.st_dev
            inode = info.st_ino
            size = info.st_size
            seconds = info.st_mtimespec.tv_sec
            nanoseconds = info.st_mtimespec.tv_nsec
        }
    }

    private let path: String
    private let running: Identity
    private var candidate: Identity?

    init?() {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(getpid(), &buffer, UInt32(buffer.count)) > 0 else { return nil }
        path = String(cString: buffer)
        guard let running = Identity(path: path) else { return nil }
        self.running = running
    }

    /// True once a different executable has stayed unchanged across two checks, so a copy still in progress is
    /// never launched. A missing file (for example, the app moved to the Trash) is not an update.
    func updateInstalled() -> Bool {
        guard let current = Identity(path: path), current != running else {
            candidate = nil
            return false
        }
        defer { candidate = current }
        return candidate == current
    }
}
