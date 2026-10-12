# Releasing Notes

The release workflow runs on an annotated version tag. It checks that the tag matches `CFBundleShortVersionString`, runs source checks and tests, builds a universal DMG, verifies the app and disk image, checks the SHA-256 checksum, then publishes a GitHub prerelease with both artifacts.

1. Update `packaging/Info.plist` and any versioned filenames or instructions in `README.md`.
2. Add `docs/releases/vX.Y.Z.md` with installation notes and the current signing status.
3. Run `node --check Sources/Notes/Web/app.js` and `python3 -m unittest discover -s tests -v`.
4. Commit and push the release changes to `main`.
5. Create and push an annotated tag: `git tag -a vX.Y.Z -m "Notes X.Y.Z" && git push origin vX.Y.Z`.
6. Follow the Release workflow in GitHub Actions. Check the release page and both attached assets when it finishes.

The workflow can also be rerun manually with an existing tag using **Actions → Release → Run workflow**. It will not overwrite an existing published release.

The automated build uses ad hoc signing because this repository has no Developer ID credentials. For a properly signed and notarized local build, configure a Developer ID Application signing identity and a `notarytool` keychain profile, then run:

```sh
NOTES_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTES_NOTARY_PROFILE="your-notarytool-keychain-profile" \
./scripts/build-dmg.sh
```

Do not present an ad hoc signed build as notarized. To automate notarized releases later, provision signing and notary credentials securely in GitHub Actions and verify the resulting DMG before publication.
