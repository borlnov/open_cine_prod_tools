<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# CI: build and release

This directory holds the GitHub Actions pipeline that builds Open Cine Prod Tools for Linux
(a Debian package), Windows (an Inno Setup installer) and macOS (a disk image), and publishes
all three to a GitHub Release on version tags.

## Workflows

### build.yml (main build)

Runs on push to `main`, on pull requests to `main`, on `v*` tags, and on manual dispatch.

- **get-version** - runs `git describe` once, shared by every other job.
- **build-linux** - installs the native build dependencies, generates the l10n/drift code,
  builds the Flutter app for Linux, packages it as a `.deb`, uploads it as an artifact.
- **build-windows** - same generation and build steps for Windows, packages an Inno Setup
  installer. Only runs on `main`, on `v*` tags, or on manual dispatch (not on every PR).
- **build-macos** - same generation and build steps for macOS, then packages the `.app` bundle
  as a drag-to-`Applications` disk image. Gated exactly like build-windows. It splits the
  version in two before building (`--build-name` gets the dotted numeric prefix,
  `--build-number` the commit distance) because a bundle's `CFBundleShortVersionString` only
  accepts dotted numbers, while the disk image's file name keeps the full `git describe`
  version. Signing and notarization steps sit around the packaging step but stay dormant until
  the Apple secrets exist (see
  [ADR 0011](../docs/adr/0011-macos-distribution-outside-the-app-store.md)); until then the app
  ships with the ad-hoc signature the Xcode project asks for. The job ends by checking the
  result structurally: `lipo -archs` on the executable, `codesign -dv` on the bundle,
  `plutil -lint` on the built `Info.plist`, and a mount of the image to confirm it holds the
  `.app` and the `Applications` symlink.
- **test-deb** - downloads the `.deb` built by build-linux, installs it on a fresh runner,
  checks the launcher and the bundled executable are present, then removes it.
- **create-release** - only on `v*` tags. Downloads the Linux, Windows and macOS artifacts,
  writes a `SHA256SUMS.txt`, and publishes a GitHub Release with all three files attached.

Nobody has run the macOS application yet - there is no Mac behind this project - so `build-macos`
is only ever verified as far as those structural checks go.

### flutter_lint.yml, markdown_lint.yml, reuse_compliance.yml

Pull-request and `main`-push checks: Dart checks, markdown linting, and REUSE compliance. All
three pin their third-party actions by commit SHA and run with `permissions: contents: read`.

- **flutter_lint.yml** (`Dart Checks`) runs a `checks` job over a `{app, fountain_kit}` matrix,
  `fail-fast: false`. Each entry gets its dependencies (`flutter pub get` plus the l10n/drift
  generation chain for `app`, `dart pub get` for `fountain_kit`), then `flutter analyze` /
  `dart analyze` and `flutter test` / `dart test`, all with `working-directory` set to the
  matrix entry's path.
- **markdown_lint.yml** lints `**/*.md` (excluding `actlibs/**`, `build/**`, `.dart_tool/**`,
  `**/node_modules` and `**/.git`), so it covers `docs/`, `.github/*.md` and
  `packages/fountain_kit/*.md`, not just the repository root.

## Structure

```text
.github/
|-- actions/
|   |-- flutter-setup/        # Flutter SDK + pub cache
|   |-- flutter-build/        # flutter build <platform> --release, with a build cache
|   |-- flutter-debian/       # packages a Flutter build directory as a .deb
|   |-- windows-installer/    # packages a Flutter build directory as an Inno Setup installer
|   `-- macos-dmg/            # packages a Flutter build directory as a .dmg (hdiutil)
|-- debian-templates/
|   |-- control.template      # Debian control file
|   |-- launcher.sh.template  # /usr/bin launcher script
|   |-- app.desktop.template  # desktop entry, named after the installed icon
|   |-- postinst              # ldconfig + icon/desktop caches after install
|   `-- postrm                # the same after removal
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
dart run build_runner build
flutter build linux --release
```

Then reproduce what the `flutter-debian` action does, from the repository root:

```bash
VERSION=$(git describe --tags --always --match 'v[0-9]*' | sed 's/^v//; /^[0-9]/! s/^/0.0.0-/')
# Debian sorts a hyphenated suffix after the plain version, semver sorts it before. Spell the
# pre-release with a tilde so apt sees 0.1.0~alpha.1 as older than 0.1.0, and keep git describe's
# trailing '<n>-g<sha>' sorting after it with a '+'.
VERSION="${VERSION/-/\~}"
VERSION="${VERSION//-/+}"
PACKAGE_NAME=open-cine-prod-tools
DEB_DIR="debian-package/${PACKAGE_NAME}_${VERSION}_amd64"

mkdir -p "${DEB_DIR}/usr/bin" "${DEB_DIR}/usr/lib/${PACKAGE_NAME}" "${DEB_DIR}/DEBIAN" \
         "${DEB_DIR}/usr/share/applications" \
         "${DEB_DIR}/usr/share/icons/hicolor/512x512/apps" \
         "${DEB_DIR}/usr/share/icons/hicolor/scalable/apps"
cp -r build/linux/x64/release/bundle/* "${DEB_DIR}/usr/lib/${PACKAGE_NAME}/"

cp assets/branding/icons/ocpt_icon_512.png \
   "${DEB_DIR}/usr/share/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png"
cp assets/branding/ocpt_logo_light.svg \
   "${DEB_DIR}/usr/share/icons/hicolor/scalable/apps/${PACKAGE_NAME}.svg"

sed -e "s/{{APP_NAME}}/Open Cine Prod Tools/g" \
    -e "s/{{PACKAGE_NAME}}/${PACKAGE_NAME}/g" \
    -e "s/{{EXECUTABLE_NAME}}/open_cine_prod_tools/g" \
    -e "s/{{DESCRIPTION_SHORT}}/Open-source production tools for film making/g" \
    .github/debian-templates/app.desktop.template \
    > "${DEB_DIR}/usr/share/applications/${PACKAGE_NAME}.desktop"

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

Requires Windows with Flutter 3.44.6 and Inno Setup (`choco install innosetup`) installed.

```powershell
flutter pub get
dart run intl_utils:generate
dart run build_runner build
flutter build windows --release
```

Copy `.github/inno-setup/installer.iss.template` next to
`build/windows/x64/runner/Release`, replace `{{APP_NAME}}`, `{{APP_PUBLISHER}}`,
`{{APP_EXE_NAME}}`, `{{APP_ID}}` and `{{OUTPUT_BASE_FILENAME}}` (see build.yml for the current
values), rename it to `installer.iss`, then run
`iscc /DMyAppVersion="0.1.0" installer.iss` from that directory.

## Building the DMG locally

Requires a Mac with Flutter 3.44.6 and Xcode's command line tools. Everything below is what the
`build-macos` job does, minus the dormant signing steps.

```bash
flutter pub get
dart run intl_utils:generate
dart run build_runner build
flutter build macos --release --build-name=0.1.0 --build-number=0
```

`--build-name` must be dotted numbers only: it becomes `CFBundleShortVersionString`, which
rejects anything else. The build writes its bundle to `build/macos/Build/Products/Release`, named
after `PRODUCT_NAME` and therefore holding spaces - so every path below quotes it.

Then reproduce what the `macos-dmg` action does, from the repository root:

```bash
APP_NAME="Open Cine Prod Tools"
VERSION=$(git describe --tags --always --match 'v[0-9]*' | sed 's/^v//; /^[0-9]/! s/^/0.0.0-/')
APP_BUNDLE="build/macos/Build/Products/Release/${APP_NAME}.app"

# Stage what the mounted volume shows: the application, and the shortcut to drag it onto. ditto,
# never cp: it is the only copy preserving the extended attributes a signature covers.
rm -rf dmg-staging && mkdir -p dmg-staging artifacts
ditto "${APP_BUNDLE}" "dmg-staging/${APP_NAME}.app"
ln -s /Applications dmg-staging/Applications

hdiutil create -volname "${APP_NAME}" -srcfolder dmg-staging -ov -format UDZO \
    "artifacts/OpenCineProdTools_${VERSION}_macos.dmg"
rm -rf dmg-staging
```

Two macOS specifics worth knowing before touching this:

- **`macos/Podfile.lock` is not in the repository.** `pod install` only runs on macOS, so the lock
  file cannot be produced here and is deliberately left untracked rather than gitignored - the
  first person to build on a Mac is expected to commit the one their build generates.
- **The application has never been run on a Mac.** The build is exercised by the CI only, and only
  through the structural checks listed above.

## Cutting a release

Bump `version:` in `pubspec.yaml` first, and merge that. It is what `package_info_plus` reports
inside the app - the About dialog and the settings page - and nothing derives it from the tag, so
a tag that disagrees with it ships binaries that misname themselves.

```bash
git tag v0.1.0
git push --tags
```

This triggers `build.yml` on the new tag: `create-release` publishes a GitHub Release with the
`.deb`, the Windows installer, the macOS disk image, and a `SHA256SUMS.txt`. The binaries are
unsigned, so Windows SmartScreen warns on first run and macOS Gatekeeper refuses the downloaded
application until the user opens it from its context menu or clears its quarantine flag - which
the README explains to them.

Pre-release tags follow semver: `v0.1.0-alpha.1`, `v0.1.0-beta.2`, `v1.0.0-rc.1`. The hyphenated
suffix is what `create-release` keys on to flag the release as a pre-release, so it never takes
over the "Latest release" slot.
