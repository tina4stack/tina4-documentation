# Docker release 3.13.138 packaging and integrity

Pre-publication inspection found that the Python, PHP and Node Docker recipes omitted root release licence documents. PHP also omitted `src/public`, although its DevAdmin resolves bundled assets there. Ruby already copies the complete application and its notices.

The three Docker recipes now copy LICENSE, NOTICE and COMMERCIAL-LICENSE.md into `/usr/share/licenses/tina4`; Python also includes them in its wheel build context. PHP copies the framework public assets and third-party notices after the example application. These are packaging-only changes; framework runtime code and version remain unchanged.

Native arm64 builds and real published-port `/health` requests pass for all three corrected images, each returning 3.13.138 and remaining alive. The legal documents and bundled notices were checked inside the resulting images. Python's installed dist-info also contains LICENSE. Full required CI and exact-head shared-lab evidence remain release prerequisites.

The manual publisher now requests SPDX SBOM and maximal BuildKit provenance, records the image digest and build metadata, retrieves both attestations per architecture, and promotes `v3`/`latest` only after the immutable published digest passes the arm64 version/health gate. Temporary container names are unique to the publisher process. The version manifest is pushed before the arm64 registry gate; a failure leaves that exact version visible but does not promote the moving aliases.

Host emulation provisioning and publication must wait for the lab to finish. Docker's documented `tonistiigi/binfmt` image was resolved read-only to `sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0`; install only arm64. No host services or running lab containers were changed during preparation. Retain registry manifests, digest records, SPDX documents, provenance and boot logs with the release evidence; verify the Docker Hub tags independently after publication.

Publisher validation: bash syntax and whitespace checks pass. A real Python OCI image built with `--sbom=true --provenance=mode=max` contains SPDX-2.3 (47 packages) and SLSA v1 attestations. The evidence validator accepts real registry SBOM/provenance output, and rejects both a removed arm64 inventory and an empty SPDX document. Exact version tags already present in the registry are refused; partial releases require deliberate recovery rather than overwriting a tag.
