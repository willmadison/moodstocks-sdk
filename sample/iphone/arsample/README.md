# ARSample for iPhone

This is an iPhone demo application that illustrates [how to create an Augmented Reality overlay](https://github.com/Moodstocks/moodstocks-sdk/wiki/How-to-create-an-Augmented-Reality-Overlay) with the Moodstocks SDK:

*   it can be deployed on an iPhone 3GS or higher, with iOS 4.0 or higher,
*   it cannot be used within the Simulator since there is no support for the camera,
*   it has been created with Xcode 4.2 and successfully built with iOS 5.0 (9A334),
*   it has **not** been designed for iPad (even though most logic would be easily re-usable / adaptable).

Feel free to use this project as a starter to design your own app.

In most cases you will have at least to re-use:

*   the Objective C wrapper around Moodstocks SDK C library (see `Moodstocks SDK/Obj-C`),
*   the logic retained to process frames (see `captureOutput:didOutputSampleBuffer:fromConnection:`).

## Usage

### Step 1: index your images

1.   [Register for an account](http://extranet.moodstocks.com/signup) on Moodstocks API,
2.   [Create an API key](http://extranet.moodstocks.com/access_keys/new),
3.   [Index your own reference images](https://github.com/Moodstocks/moodstocks-api/wiki/api-v2-doc#wiki-add-object),
4.   [Make your reference images available offline](https://github.com/Moodstocks/moodstocks-api/wiki/api-v2-doc#wiki-make-offline).

Please note that we also provide a [step-by-step indexing tutorial](https://github.com/Moodstocks/moodstocks-api/wiki/api-v2-tuto-indexing) that you might find helpful.

### Step 2: build & run ARSample

1.   Open `ARSample.xcodeproj` in Xcode,
2.   Grab the latest build of the SDK from the [Downloads section](https://github.com/Moodstocks/moodstocks-sdk/downloads) (`v3_0-iOS5_0.tar.gz` at the time of writing),
3.   Drag `moodstocks_sdk.h` and `libmoodstocks-sdk.a` into the `Moodstocks SDK/C` folder,
4.   Open `Moodstocks SDK/Obj-C/MSScanner.m` then replace `"ApIkEy"` and `"ApIsEcReT"` with your key/secret pair,
5.   Build & run on your device.

> **WARNING** the app will crash at runtime if you do not build it with the
same iOS SDK version than the one used for the Moodstocks SDK build.

## Help

Ping us on our [support chat](https://moodstocks.campfirenow.com/2416e). We're here to help!

## Copyright

Copyright (c) 2011 Moodstocks SAS
