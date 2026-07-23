<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# CI: build and release

This directory holds the GitHub Actions pipeline that builds Open Cine Prod Tools for Linux
(a Debian package) and Windows (an Inno Setup installer), and publishes both to a GitHub
Release on version tags.

## Workflows

### build.yml (main build)

Runs on push to `main`, on pull requests to `main`, on `v*` tags, and on manual dispatch.

- **get-version** - runs `git describe` once, shared by every other job.
- **build-linux** - installs the native build dependencies, generates the l10n/drift code,
  builds the Flutter app for Linux, packages it as a `.deb`, uploads it as an artifact.
- **build-windows** - same generation and build steps for Windows, packages an Inno Setup
  installer. Only runs on `main`, on `v*` tags, or on manual dispatch (not on every PR).
- **test-deb** - downloads the `.deb` built by build-linux, installs it on a fresh runner,
  checks the launcher and the bundled executable are present, then removes it.
- **create-release** - only on `v*` tags. Downloads the Linux and Windows artifacts, writes a
  `SHA256SUMS.txt`, and publishes a GitHub Release with both files attached.

### flutter_lint.yml, markdown_lint.yml, reuse_compliance.yml

Pull-request checks: `flutter analyze`, markdown linting, and REUSE compliance. All three pin
their third-party actions by commit SHA and run with `permissions: contents: read`.

## Structure

```text
.github/
|-- actions/
|   |-- flutter-setup/        # Flutter SDK + pub cache
|   |-- flutter-build/        # flutter build <platform> --release, with a build cache
|   |-- flutter-debian/       # packages a Flutter build directory as a .deb
|   `-- windows-installer/    # packages a Flutter build directory as an Inno Setup installer
|-- debian-templates/
|   |-- control.template      # Debian control file
|   |-- launcher.sh.template  # /usr/bin launcher script
|   |-- postinst              # runs ldconfig after install
|   `-- postrm                # runs ldconfig after removal
|-- inno-setup/
|   `-- installer.iss.template
|-- workflows/
`-- dependabot.yml             # weekly bump of the pinned action SHAs
```

## Building a .deb locally

Inside the devcontainer:

```bash
flutter pub get
dart run intl_utils:generate
dart run build_runner build --delete-conflicting-outputs
flutter build linux --release
```

Then reproduce what the `flutter-debian` action does, from the repository root:

```bash
VERSION=$(git describe --tags --always --match 'v[0-9]*' | sed 's/^v//; /^[0-9]/! s/^/0.0.0-/')
PACKAGE_NAME=open-cine-prod-tools
DEB_DIR="debian-package/${PACKAGE_NAME}_${VERSION}_amd64"

mkdir -p "${DEB_DIR}/usr/bin" "${DEB_DIR}/usr/lib/${PACKAGE_NAME}" "${DEB_DIR}/DEBIAN"
cp -r build/linux/x64/release/bundle/* "${DEB_DIR}/usr/lib/${PACKAGE_NAME}/"

sed -e "s/{{APP_NAME}}/Open Cine Prod Tools/g" \
    -e "s/{{PACKAGE_NAME}}/${PACKAGE_NAME}/g" \
    -e "s/{{EXECUTABLE_NAME}}/open_cine_prod_tools/g" \
    .github/debian-templates/launcher.sh.template > "${DEB_DIR}/usr/bin/${PACKAGE_NAME}"
chmod +x "${DEB_DIR}/usr/bin/${PACKAGE_NAME}"

sed -e "s/{{PACKAGE_NAME}}/${PACKAGE_NAME}/g" -e "s/{{VERSION}}/${VERSION}/g" \
    -e "s/{{ARCHITECTURE}}/amd64/g" \
    -e "s/{{DEPENDENCIES}}/libgtk-3-0, libc6, libsecret-1-0/g" \
    -e "s/{{MAINTAINER}}/Benoit Rolandeau <borlnov.obsessio@gmail.com>/g" \
    -e "s/{{DESCRIPTION_SHORT}}/Open-source production tools for film making/g" \
    -e "s/{{DESCRIPTION_LONG}}/ A Fountain screenplay editor./g" \
    .github/debian-templates/control.template > "${DEB_DIR}/DEBIAN/control"

cp .github/debian-templates/postinst .github/debian-templates/postrm "${DEB_DIR}/DEBIAN/"
chmod +x "${DEB_DIR}/DEBIAN/postinst" "${DEB_DIR}/DEBIAN/postrm"

dpkg-deb --build --root-owner-group "${DEB_DIR}"
```

The `.deb` is written next to `${DEB_DIR}`. Install it with
`sudo apt install ./debian-package/open-cine-prod-tools_*.deb`, run `open-cine-prod-tools`, then
remove it with `sudo apt-get remove open-cine-prod-tools`.

## Building the Windows installer locally

Requires Windows with Flutter 3.41.9 and Inno Setup (`choco install innosetup`) installed.

```powershell
flutter pub get
dart run intl_utils:generate
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

Copy `.github/inno-setup/installer.iss.template` next to
`build/windows/x64/runner/Release`, replace `{{APP_NAME}}`, `{{APP_PUBLISHER}}`,
`{{APP_EXE_NAME}}`, `{{APP_ID}}` and `{{OUTPUT_BASE_FILENAME}}` (see build.yml for the current
values), rename it to `installer.iss`, then run
`iscc /DMyAppVersion="0.1.0" installer.iss` from that directory.

## Cutting a release

```bash
git tag v0.1.0
git push --tags
```

This triggers `build.yml` on the new tag: `create-release` publishes a GitHub Release with the
`.deb`, the Windows installer, and a `SHA256SUMS.txt`. The binaries are unsigned, so Windows
SmartScreen will warn on first run.
