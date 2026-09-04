# Contributing to Stop Stutter

Thanks for helping Mac streams feel better. Small, focused pull requests are welcome.

1. Describe the problem and reproduction before proposing a fix.
2. Keep privileged operations narrowly scoped to AWDL. Never introduce a shell, arbitrary commands, password storage, or passwordless sudo rules.
3. Run `swift test` and `./scripts/build.sh`. Add behavior tests for policy, recovery, and security-sensitive changes.
4. Check any UI change in the actual app, including small windows and both appearances.
5. Document behavior changes and testing limits. Do not promise performance gains without measurements.

Use English for code, documentation, issues, and pull requests. Keep commit messages concise and describe the actual change. Contributions are licensed under the repository's MIT license.

For a vulnerability, follow [SECURITY.md](SECURITY.md) rather than posting exploit details in a public issue.
