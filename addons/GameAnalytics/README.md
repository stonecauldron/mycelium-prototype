# GameAnalytics Godot SDK

Vendored from the official [3.1.1 release](https://github.com/GameAnalytics/GA-SDK-GODOT/releases/tag/3.1.1).

- Archive: `GameAnalytics-Godot-3.1.1.zip`
- SHA-256: `5dc8a91d3be5c289d2cb42fee0771dcdb549e6c714df0ebc42c437ffc1732d9d`
- Existing Godot resource UIDs are preserved; SDK files otherwise match the release.

Version 3.1.1 adds Godot 4.7 support and fixes the HTTP-client hang on exit that
blocked desktop initialization. The game's wrapper is
`assets/autoload/analytics.gd`; editor runs continue to skip analytics.
