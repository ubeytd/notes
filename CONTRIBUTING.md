# Contributing

Thanks for helping improve Notes. Please open an issue before starting a large change so the scope is clear.

## Build locally

You need macOS 13 or newer, Xcode command line tools, Node.js for the JavaScript syntax check, and Python 3 for the MCP tests.

```sh
./scripts/build-app.sh
open dist/Notes.app
```

## Check a change

```sh
node --check Sources/Notes/Web/app.js
python3 -m unittest discover -s tests -v
./scripts/build-app.sh
```

Use an isolated data file when testing note migration or destructive actions:

```sh
NOTES_DATA_FILE=/tmp/notes-dev.json dist/Notes.app/Contents/MacOS/Notes
```

Keep interface changes consistent across Noir, Graphite, and Evergreen. Include a screenshot when changing a visible flow. Avoid committing personal notes, credentials, or generated build artifacts.

## Pull requests

Explain the user-facing change, how you checked it, and any platform or permission limits. Third-party frontend libraries and icons keep their original licenses in `Sources/Notes/Web/vendor/` and `Sources/Notes/Web/icons/`.
