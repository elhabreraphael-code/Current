# Releasing Current

## Local release

Run from the repository root:

```sh
bash scripts/test.sh --ui
bash build.sh --universal
bash scripts/create-dmg.sh --skip-build
```

The results are `dist/Current.app` and `dist/Current-1.1.0.dmg`.
The DMG contains the app, an Applications shortcut, and installation notes.
Both architectures are built; test on Intel hardware before claiming Intel runtime validation.

## Developer ID distribution

The default build is ad-hoc signed for local use. To distribute with the normal
Apple-trusted first-launch experience, use your own Apple Developer account and
a Developer ID Application certificate installed in Keychain:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' bash build.sh --universal
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' bash scripts/create-dmg.sh --skip-build
xcrun notarytool submit dist/Current-1.1.0.dmg --keychain-profile CurrentNotary --wait
xcrun stapler staple dist/Current-1.1.0.dmg
xcrun stapler validate dist/Current-1.1.0.dmg
```

Create the `CurrentNotary` Keychain profile yourself using `xcrun notarytool
store-credentials`; do not commit secrets. A notarization submission must report
Accepted before stapling. Update `docs/Install.txt` to describe your actual signed
release before packaging. This project does not include a certificate or claim
that its local release is notarized.

## Uploading this repository to GitHub

Create an empty repository in your account. Upload this folder's contents, including
`.github` and `.gitignore`, as the repository root. Alternatively, after replacing
the example URL with your own empty repository:

```sh
git init
git add .
git commit -m "Release Current 1.1.0"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/Current.git
git push -u origin main
```

Attach the DMG to a GitHub release tagged `v1.1.0`. Build products are intentionally
excluded from source control. The CI workflow builds and packages an artifact; it
does not publish a release or use signing credentials.
