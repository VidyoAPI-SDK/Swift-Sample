# VidyoPlatform Reference App for IOS
VidyoPlatform reference application highlighting how to integrate Vidyo capabilities in the native IOS app.

Developer documentation: https://vidyo.github.io/vidyoplatform.github.io

## Pre-Requisites
git, pod, Xcode installed on MAC

## Clone Repository
```
git clone https://github.com/VidyoAPI-SDK/Swift-Sample.git
```

## Prepare VidyoPlatform IOS SDK

1. Download the latest VidyoPlatform IOS SDK package [here](https://enghouse-vidyo.gitbook.io/vidyoplatform/resources) and unzip it.
2. Copy the SDK package (VidyoClient-iOSSDK) inside Swift-Sample folder.

## Building Application

1. Install pod
```
pod install
```

2. Open project with Xcode
```
open VidyoConnector.xcworkspace
```

3. In Xcode, select build target as VidyoConnector-IOS. Please note that arm64 simulator is not supported.

4. Build the code 
