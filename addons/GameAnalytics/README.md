# GameAnalytics Godot SDK

Vendored from the official [3.1.1 release](https://github.com/GameAnalytics/GA-SDK-GODOT/releases/tag/3.1.1).

- Archive: `GameAnalytics-Godot-3.1.1.zip`
- SHA-256: `5dc8a91d3be5c289d2cb42fee0771dcdb549e6c714df0ebc42c437ffc1732d9d`
- Existing Godot resource UIDs are preserved. The binaries listed below replace
  the release versions; other SDK files match the release.

Version 3.1.1 adds Godot 4.7 support and fixes the HTTP-client hang on exit that
blocked desktop initialization. The game's wrapper is
`assets/autoload/analytics.gd`; editor runs continue to skip analytics.

## Resource configuration fix

Upstream [PR #39](https://github.com/GameAnalytics/GA-SDK-GODOT/pull/39) fixes
`configureAvailableResourceItemTypes` calling the currency setter. The fix is
already in the 3.1.1 source, but the release ZIP's Web and macOS binaries still
overwrite the currency list and reject Biomass Resource events.

We use binaries built from the same 3.1.1 commit,
`48fbc9ce71f50228bc7852bceb45c59305f14cea`:

- **macOS:** rebuilt locally as a signed universal library (arm64 + x86_64).
- **Web:** release artifact from the official
  [CI run](https://github.com/GameAnalytics/GA-SDK-GODOT/actions/runs/34941259026).
  The library comes from `godotgameanalytics-web-release`, not another platform's
  artifact (which also bundles older libraries).
- **Windows:** already identical to that CI run's Windows release library except
  for PE build timestamps; the existing binary is retained.
- **Linux:** already byte-identical to that CI run's Linux release library.

Exact hashes and build provenance are in `binary-provenance.json`. No changes to
upstream C++ source are needed. The game uses the same normal SDK configuration
calls on Web and desktop, with no JavaScript bypass or event-name changes.

### Rebuilding

Check out the commit above with submodules; its pinned `godot-cpp` commit is
`05057de73de4b99f114d36c40d84ca46926c0e25`. The source checkout includes the C++
SDK 5.4.1 static libraries. Use SCons (local macOS build: 4.11.0):

```sh
scons platform=macos target=template_release arch=universal -j8
# On a Windows build host:
scons platform=windows target=template_release
# With Emscripten 4.0.11 activated:
scons platform=web target=template_release threads=yes
```

Copy only the corresponding `bin/<platform>/release/libGodotGameAnalytics.*`
into this addon's `bin/<platform>/`. The upstream macOS build signs the result
ad hoc; preserve both architecture slices.

### Verification

From the game's root, run the offline desktop regression check:

```sh
python3 scripts/verify_gameanalytics_sdk.py
```

This loads the real native library in an isolated minimal project and checks
that currencies and item types reach different setters. It never initializes
an analytics session or sends events. `--godot` and `--sdk` allow another engine
or SDK directory. The original macOS release binary fails this check; the
rebuilt binary passes.

Both the macOS release export and threaded Web export were also exercised
through New Run, Scout reroll, a battle victory, Day 2, and Return to title.
All four Biomass Resource events were accepted by the server alongside
progression and intent events. macOS Quit also delivered the final events and
exited successfully. Windows export was checked, but Windows and Linux runtime
delivery were not tested on this Mac. Local sanitized delivery reports live
under the ignored `build/verification/` directory.
