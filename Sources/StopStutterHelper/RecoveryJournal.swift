import Darwin
import Foundation
import StopStutterCore

final class RecoveryJournal: RecoveryJournaling {
    private let directory = "/private/var/db/\(ServiceIdentity.app)"
    private var marker: String { directory + "/restore-awdl" }

    init() throws {
        if mkdir(directory, 0o700) != 0 && errno != EEXIST {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var info = stat()
        guard lstat(directory, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR, info.st_uid == 0,
              info.st_mode & 0o077 == 0 else { throw ControlError.invalidJournal }
    }

    var needsRestore: Bool {
        get throws {
            var info = stat()
            if lstat(marker, &info) != 0 {
                if errno == ENOENT { return false }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == 0,
                  info.st_mode & 0o077 == 0 else { throw ControlError.invalidJournal }
            return true
        }
    }

    func markForRestore() throws {
        if try needsRestore { return }
        let fd = open(marker, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw POSIXError(.EIO) }
        try syncDirectory()
    }

    func clear() throws {
        if unlink(marker) != 0 && errno != ENOENT {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try syncDirectory()
    }

    private func syncDirectory() throws {
        let fd = open(directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw POSIXError(.EIO) }
    }
}
