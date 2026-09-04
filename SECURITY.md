# Security policy

The current 0.1 release line receives security fixes.

Please report vulnerabilities privately through [GitHub's private vulnerability reporting](https://github.com/burakgon/stop-stutter/security/advisories/new). Include the affected version, macOS version, impact, and a minimal reproduction. Avoid disclosing active signing credentials or personal data.

The privileged helper is the primary security boundary. Its API is intentionally limited to a boolean AWDL suppression lease. See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for the trust model and recovery behavior.
