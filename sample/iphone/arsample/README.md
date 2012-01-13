# ARSample for iPhone

> **Pre-requisite** you must [index your images](https://github.com/Moodstocks/moodstocks-api/wiki/api-v2-tuto-indexing) on Moodstocks API and [flag them offline](https://github.com/Moodstocks/moodstocks-api/wiki/api-v2-tuto-indexing#wiki-flag-offline).

1.   Open `ARSample.xcodeproj` in Xcode,
2.   Grab the latest build of the SDK from the [Downloads section](https://github.com/Moodstocks/moodstocks-sdk/downloads) (`v3_0-iOS5_0.tar.gz` at the time of writing),
3.   Drag & drop `moodstocks_sdk.h` and `libmoodstocks-sdk.a` into the `Moodstocks SDK/C` folder,
4.   Open `Moodstocks SDK/Obj-C/MSScanner.m` then replace `"ApIkEy"` and `"ApIsEcReT"` with your key/secret pair,
5.   Build & run on your device.

## Copyright

Copyright (c) 2012 Moodstocks SAS
