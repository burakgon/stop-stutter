import Foundation
import Security

public enum PeerTrust {
    /// Trust a fixed bundle identifier signed by the same Apple team as this executable.
    /// Ad-hoc builds can preview the UI, but never install or talk to the privileged service.
    public static func requirement(for identifier: String) throws -> String {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { throw ControlError.unsignedBuild }
        var information: CFDictionary?
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any],
              let team = values[kSecCodeInfoTeamIdentifier as String] as? String,
              team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil,
              [ServiceIdentity.app, ServiceIdentity.helper].contains(identifier)
        else { throw ControlError.unsignedBuild }
        return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }
}
