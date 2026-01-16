# ``SekaiKit``
Access and process data about BanG Dream GBP.

@Metadata {
    @Available(iOS, introduced: "17.0")
    @Available(iPadOS, introduced: "17.0")
    @Available("Mac Catalyst", introduced: "17.0")
    @Available(macOS, introduced: "14.0")
    @Available(visionOS, introduced: "1.0")
    @Available(watchOS, introduced: "10.0")
}

## Overview

SekaiKit provides functions to access information related to BanG Dream GBP and corresponding data structures to store it. The framework provides localized text, image resources and other assets for related part of GBP, and tools to process these data.

Raw data from Bestdori! API can be got using ``SekaiAPI``. Use ``SekaiFrontend`` to let SekaiKit process the raw data and give you ready-to-use data. Cache data from ``SekaiAPI`` or ``SekaiFrontend`` by ``SekaiCache`` to get information faster and reduce calling on internet. Store source assets from GBP by ``SekaiOfflineAsset`` and make them available when offline.

## Topics

### Essentials


### Fetch Data

- ``SekaiAPI``
- ``SekaiFrontend``
- ``SekaiCache``
- ``PagedContent``

### Rich Content

- ``RichContent``
- ``RichContentGroup``
- ``RichContentView``

### Offline Asset

- ``SekaiOfflineAsset``
- ``withOfflineAsset(_:_:)``
- ``withOfflineAsset(_:isolation:_:)``
- ``OfflineAssetBehavior``
- ``OfflineAssetURL(_:)``
