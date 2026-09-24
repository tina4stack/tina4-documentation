# Dependency licence review

ADR-0073 control 6 requires review of inbound dependencies on every pull request. The Doc Truth job checks the exact `package.json` and `pnpm-lock.yaml` SHA-256 values against `scripts/dependency-licenses.json`; any change requires a reviewed inventory update in the same pull request. The two resolved build dependencies record their published npm licence declarations and version-specific registry evidence. Both declared MIT when checked on 2026-09-24.

Review the complete resolved lockfile, version-specific upstream licence text and attribution obligations before updating the hashes and inventory. Do not update hashes merely to make CI pass. This is a review gate, not an automated legal-compatibility opinion or an assertion that build dependencies are shipped with every page. Existing dependency releases retain their original licensing.
