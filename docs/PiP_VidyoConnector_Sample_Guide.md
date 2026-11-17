# Enabling iOS Picture-in-Picture (PiP) in the VidyoConnector Sample

**Audience:** iOS developers who use the public **VidyoConnector** sample (or build their own conferencing app from it) on the **Vidyo SDK (VidyoClientIOS)**.
**Reference implementation:** `Samples/VidyoConnector/ios-Swift` (System PiP on `VCConnector`).

**How to use this document:** follow sections **1–8** in order to wire PiP into an app. Copy the PiP source files listed in **section 4** into your project. Sections **9–14** explain the API and internals for debugging.

---

## 0. Fast path (copy from the sample)

If you are starting from this VidyoConnector sample, PiP is already implemented. To port it into another `VCConnector` app:

1. Copy the three PiP source files into your app target (see **section 4**), either from the sample tree or from `docs/PiP_Source.zip`.
2. Apply the small host-app edits in sections **6–8** (managers snapshots, connector background guard, scene delay, conference VC wiring).
3. Add `picture-in-picture` to `UIBackgroundModes` (section **5**).
4. Build on a **real device** and run the checklist in section **12**.

If your app is not based on this sample, still copy those three files, implement `PiPCallDataSource` for your own services (section **6**), then follow sections **7–8**.

---

## 1. Background

The Vidyo SDK has no Picture-in-Picture support. Its renderer draws the conference into a `UIView` (the view you pass to `VCConnector.assignView(toCompositeRenderer:)`). iOS cannot put that view into a PiP window, and the SDK’s default behaviour on backgrounding (`VCConnector.setMode(.background)`) stops rendering and pauses the local camera.

The VidyoConnector sample solves this entirely in app code, using Apple’s **video-call PiP API** (iOS 15+):

1. Pull raw remote video frames from the SDK (`VCRemoteCamera` / `VCRemoteWindowShare` → `registerFrameEventListener`).
2. Convert each `VCVideoFrame` (I420) to an NV12 `CVPixelBuffer` → `CMSampleBuffer`.
3. Push those buffers into an `AVSampleBufferDisplayLayer` hosted in an `AVPictureInPictureVideoCallViewController`.
4. Drive an `AVPictureInPictureController` whose content source is the SDK render view (`activeVideoCallSourceView`).
5. Keep the SDK connector in **foreground mode** while PiP is visible, so video and the local camera keep running.

The engine lives in **`PiPManager.swift`**. Call state is supplied through **`PiPCallDataSource`** / `ConferencePiPDataSource`, which maps the sample’s `VCConnector` managers into PiP.

In this sample, PiP **auto-starts when the user backgrounds the app during a connected call**. There is no PiP toolbar button.

## 2. Features

- The remote video is shown in a floating system PiP window while the user is on the home screen or in another app.
- The PiP window automatically follows the most relevant stream, in this priority order:
  1. remote screen share
  2. pinned participant
  3. loudest speaker
  4. first remote camera
- When the focused participant’s camera is off, the window shows a placeholder: their initials on a black 16:9 frame, plus a speaking ring.
- When you are the only participant, the window shows an “only person in the call” message.
- The local camera keeps sending video while PiP is active (iOS 16+).
- An “expand” button in the PiP window brings the user back to the call.
- Frame rate adapts to app state and device temperature (12 fps live, 10 fps placeholder, 8 fps when throttled).
- The window recovers by itself when frames stall, a share switches, or the display layer fails.

## 3. Requirements

| Item | Requirement |
|---|---|
| iOS | **15.0+** for PiP. **16.0+** for keeping the local camera running in the background. |
| Device | Real device. PiP is unavailable in the iOS Simulator and on devices where `AVPictureInPictureController.isPictureInPictureSupported()` is `false`. |
| Vidyo SDK | A build that exposes `VCRemoteCamera.registerFrameEventListener`, `VCRemoteWindowShare.registerFrameEventListener` and `VCVideoFrame` plane accessors (`getDataY/Cb/Cr`, `getPitch*`, `getWidth*`, `getHeight*`, `getOffset*`). |
| Connector API | This sample uses **`VCConnector`** (`import VidyoClientIOS`), not `VCEndpoint`. |
| Audio | `AVAudioSession` category `.playAndRecord`, mode `.voiceChat`, active for the whole call (the SDK normally sets this). Without an active audio session iOS suspends the app and PiP goes black. |
| Language | Swift 5. Xcode project must compile the `.m` multitasking file in the app target. |

## 4. Files

Do **not** paste the PiP engine into this document. Copy the source from the sample (or from the zip beside this guide). That keeps the guide short and the code easy to update.

### 4.1 PiP source to copy

| File in sample | Required | Purpose |
|---|---|---|
| `VidyoConnector/PiP/PiPManager.swift` | Yes | PiP engine (AVKit, frame bridge, focus, placeholder) |
| `VidyoConnector/PiP/PiPCallDataSource.swift` | Yes | `PiPCallDataSource` protocol + `ConferencePiPDataSource` adapter |
| `VidyoConnector/Categories/AVCaptureSession+Multitasking.m` | Recommended | Keep local camera alive in background on iOS 16+ |

**Zip package:** `docs/PiP_Source.zip` contains the same three files for customers who should not browse the full sample tree. Prefer copying from git when you already have the sample checked out.

Add all three to your app target (Compile Sources). The `.m` file needs no bridging-header entry (`+load` runs automatically).

### 4.2 Host files you must edit (already done in this sample)

| File | What to add |
|---|---|
| `RemoteCameraManager.swift` | Camera snapshot list + change observers |
| `RemoteShareManager.swift` | Share snapshot list + change observers |
| `RemoteMicrophoneManager.swift` | Mic on/off map + change observers |
| `ParticipantsManager.swift` | Loudest id; do **not** unregister remote cameras for the whole call |
| `ConnectorManager.swift` | `isSystemPiPActive` + skip background mode while PiP is active |
| `SceneDelegate.swift` | Delay `handleBackground()` by ~0.35 s |
| `ConferenceViewController.swift` | Configure / auto-start / tearDown / delegate |
| `Info.plist` | `picture-in-picture` background mode |

## 5. Project configuration

1. Add the three PiP source files (section 4) to the **app target** (Compile Sources).
2. **Background Modes:** enable **Audio, AirPlay, and Picture in Picture**. In `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
    <string>picture-in-picture</string>
</array>
```

3. **Camera while in PiP (iOS 16+):** if `isMultitaskingCameraAccessSupported` is `false` for your bundle, request `com.apple.developer.avfoundation.multitasking-camera-access` from Apple.
4. Keep existing camera/mic usage description strings.
5. Deployment target **iOS 15.0+**.

## 6. Supplying call state (`PiPCallDataSource`) — most important step

`PiPManager` never talks to NeoIOS types. It only needs a `PiPCallDataSource`.

### 6.1 Protocol (full file: `PiPCallDataSource.swift`)

```swift
protocol PiPCallDataSource: AnyObject {
    var localUserId: String { get }
    var pinnedParticipantId: String? { get }
    var loudestParticipantId: String? { get }
    func remoteCameraSnapshot() -> [PiPRemoteCameraRow]
    func remoteShareSnapshot() -> [PiPRemoteShareRow]
    func participant(for userId: String) -> VCParticipant?
    func hasActiveRemoteParticipant() -> Bool
    func isRemoteMicOn(userId: String) -> Bool
    func addFocusObserver(_ handler: @escaping () -> Void) -> AnyObject
    func removeFocusObserver(_ token: AnyObject)
}
```

| Information | Sample source | SDK listener |
|---|---|---|
| Remote cameras | `RemoteCameraManager.synchronizedSnapshot()` | `registerRemoteCameraEventListener` |
| Remote shares | `RemoteShareManager.synchronizedSnapshot()` | `registerRemoteWindowShareEventListener` |
| Loudest | `ParticipantsManager.loudestParticipantId` | `onLoudestParticipantChanged` |
| Pin | `ConferenceViewController.pinnedParticipantID` | Your UI / `pinParticipant` |
| Names | `VCParticipant.name` / `getId()` | `onParticipantJoined / Left` |
| Mic for speaking ring | `RemoteMicrophoneManager.isMicOn(for:)` | `registerRemoteMicrophoneEventListener` |
| Local user id | Local participant `isLocal()` | Same |
| PiP flag | `ConnectorManager.setSystemPiPActive` | Background guard |

### 6.2 Manager snapshots you must expose

**Critical:** `VCConnector` allows only **one** remote-camera event listener. PiP must share your existing `RemoteCameraManager` registration. Keep that listener registered for the whole conference.

Add a full camera list (not only controllable cameras), update it in `onRemoteCameraAdded/Removed/StateUpdated`, and expose:

```swift
func synchronizedSnapshot() -> [PiPRemoteCameraRow] { remoteCameras.map { $0 } }

@discardableResult
func addChangeObserver(_ handler: @escaping () -> Void) -> UUID { ... }
func removeChangeObserver(_ id: UUID) { ... }
```

Treat `.paused` / `.stopped` / `.suspended` / `.removed` as `isPaused = true`.

Do the same for shares (`PiPRemoteShareRow`), mic on/off per `userId`, and store `loudestParticipantId` in `onLoudestParticipantChanged`.

When pin changes:

```swift
var pinnedParticipantID: String? {
    didSet { pipDataSource?.notePinnedChanged() }
}
```

### 6.3 Minimal adaptation

- Return `nil` for pin if you have no pinning.
- Return `false` from `isRemoteMicOn` to disable the speaking ring.
- Keep camera + share + loudest sources so PiP can follow the call.

## 7. Connector layer changes (mandatory)

While PiP is showing, UIKit considers the app backgrounded. You must **not** call `connector.setMode(.background)` or mute/unpair the camera then.

```swift
private(set) var isSystemPiPActive = false

func setSystemPiPActive(_ active: Bool) {
    guard isSystemPiPActive != active else { return }
    isSystemPiPActive = active
}

func handleBackground() {
    if isSystemPiPActive {
        connectionManager.connector.setMode(.foreground)
        return // do NOT mute camera / setMode(.background)
    }
    // existing background path...
}
```

`PiPManager` sets the flag `true` slightly before PiP fully starts (background can arrive first), and clears it on stop / fail / tearDown.

**SceneDelegate delay** (so PiP can set the flag first):

```swift
func sceneWillResignActive(_ scene: UIScene) {
    pendingBackgroundWorkItem?.cancel()
    let work = DispatchWorkItem {
        ConnectorManager.shared.handleBackground()
    }
    pendingBackgroundWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
}

func sceneDidBecomeActive(_ scene: UIScene) {
    pendingBackgroundWorkItem?.cancel()
    pendingBackgroundWorkItem = nil
    ConnectorManager.shared.handleForeground()
}
```

## 8. Call-screen integration (`ConferenceViewController`)

Own the PiP manager on the VC that owns the composite render view (`videoView`).

### 8.1 Properties

```swift
private var pipManager: PiPManager?
private var pipDataSource: ConferencePiPDataSource?
var blockSystemPiPBackgroundStart = false
```

### 8.2 Configure after connect / when the view is in a window

```swift
private func configureSystemPiPIfNeeded() {
    guard #available(iOS 15.0, *) else { return }
    guard connectionManager.connectionState == .connected, !isLobbyMode else { return }
    guard videoView.window != nil else { return }

    if pipDataSource == nil {
        pipDataSource = ConferencePiPDataSource(conference: self)
    }
    let manager = pipManager ?? PiPManager()
    manager.delegate = self
    pipManager = manager
    manager.configure(sourceView: videoView, dataSource: pipDataSource)
}
```

Call this from:

- `viewDidAppear` (after `registerRemoteDevices()` so camera + mic listeners exist)
- connection-success handler
- after `refreshVideoView()` (also call `pipManager?.updateSourceView(videoView)`)

`sourceView` **must** be the SDK composite render view and must be in a window.

### 8.3 Auto-start (this sample’s start path)

```swift
// in addObservers():
observe(UIScene.willDeactivateNotification, #selector(sceneWillDeactivateForPiP(_:)))
observe(UIApplication.willEnterForegroundNotification, #selector(applicationWillEnterForegroundForPiP(_:)))
observe(UIApplication.didBecomeActiveNotification, #selector(applicationDidBecomeActiveForPiP(_:)))

@objc private func sceneWillDeactivateForPiP(_ notification: Notification) {
    guard #available(iOS 15.0, *) else { return }
    pipManager?.noteSceneWillDeactivate()
    let isCallActive = !blockSystemPiPBackgroundStart
        && connectionManager.connectionState == .connected
        && !isLobbyMode
    pipManager?.requestBackgroundStart(
        reason: "UISceneWillDeactivate",
        sceneState: view.window?.windowScene?.activationState,
        isCallActive: isCallActive
    )
}
```

Rules:

- Start only while scene is still `.foregroundActive` — `willDeactivate` is the last reliable moment. `didEnterBackground` is too late.
- Built-in guards: call active, one attempt per background cycle, 0.25 s debounce.
- Control Center / Notification Center also deactivate the scene — test for unexpected starts.
- `canStartPictureInPictureAutomaticallyFromInline = false` (app decides).

There is **no** PiP toolbar button in this sample. `PiPManager.toggle()` is available if you add one later.

### 8.4 Returning to the app

```swift
@objc private func applicationWillEnterForegroundForPiP(_ notification: Notification) {
    guard #available(iOS 15.0, *) else { return }
    pipManager?.stop(force: true)
    pipManager?.resetBackgroundCycle()
}

@objc private func applicationDidBecomeActiveForPiP(_ notification: Notification) {
    guard #available(iOS 15.0, *) else { return }
    pipManager?.stop(force: true)
    // Recreate AVKit controller while foreground (NeoIOS pattern).
    // Dropping the old controller releases a stuck system PiP bubble after tap-to-restore;
    // the new controller is ready for the next Home → PiP auto-start.
    // Do not detach ContentSource and do not recreate during willDeactivate.
    pipManager?.updateSourceView(videoView)
}
```

### 8.5 Ending the call (mandatory)

On end-call, disconnect, and leaving the conference screen:

```swift
blockSystemPiPBackgroundStart = true
tearDownSystemPiP()

func tearDownSystemPiP() {
    let work = { [weak self] in
        guard let self = self else { return }
        if #available(iOS 15.0, *) {
            self.pipManager?.tearDown(invalidate: true)
            self.pipManager = nil
            self.pipDataSource = nil
        }
        ConnectorManager.shared.setSystemPiPActive(false)
    }
    Thread.isMainThread ? work() : DispatchQueue.main.async(execute: work)
}
```

`tearDown(invalidate: true)` blocks late starts, stops PiP, releases the AVKit controller, and clears the connector flag.

### 8.6 Delegate

```swift
@available(iOS 15.0, *)
extension ConferenceViewController: PiPManagerDelegate {
    func pipManager(_ manager: PiPManager, didChangeActive isActive: Bool, canStart: Bool) {
        // Optional: update a PiP button if you add one
    }
    func pipManager(_ manager: PiPManager, didFailWith error: Error) {
        // Log / analytics
    }
}
```

### 8.7 Implementation checklist (in order)

1. [ ] Copy the three PiP source files (section 4) into the target  
2. [ ] Add camera / share / mic / loudest snapshots + observers  
3. [ ] Keep remote-camera listener registered for the whole call  
4. [ ] Add `setSystemPiPActive` + `handleBackground` guard  
5. [ ] Delay background in `SceneDelegate` by 0.35 s  
6. [ ] Wire `ConferenceViewController` configure / observers / tearDown  
7. [ ] Add `picture-in-picture` to `UIBackgroundModes`  
8. [ ] Test on a real device (section 12)

## 9. Public API reference

| Member | Use |
|---|---|
| `static var isSupported: Bool` | Device supports PiP |
| `weak var delegate: PiPManagerDelegate?` | Active/canStart / failures (main thread) |
| `var isActive: Bool` / `var canStart: Bool` | Current state |
| `configure(sourceView:dataSource:)` | Create or refresh |
| `updateSourceView(_:)` | Render view replaced |
| `toggle()` | Manual start/stop (optional button) |
| `stop(force:)` | Foreground return |
| `resetBackgroundCycle()` | Re-arm auto-start |
| `noteSceneWillDeactivate()` | Before auto-start |
| `requestBackgroundStart(reason:sceneState:isCallActive:)` | Auto-start |
| `tearDown(invalidate:)` | Call end; use `true` |

## 10. How it works (internals)

```
 Vidyo SDK (VCConnector)           PiPManager.swift                                   iOS
 ───────────────────────           ────────────────                                   ───
 RemoteCamera / Share / Loudest ─► PiPFocusTracker ── target ──┐
 Participant / Mic events          via PiPCallDataSource       │
                                                               ▼
 VCRemoteCamera  ─ registerFrameEventListener ─► RemoteCameraSampleBufferBridge
 VCRemoteWindowShare                              I420 ─► NV12 CVPixelBuffer ─► CMSampleBuffer
                                                               │
                                     OpenGLFrameCaptureService ┤ (placeholder / fallback)
                                                               ▼
                                     SystemPiPCoordinator ─► AVSampleBufferDisplayLayer
                                                             in AVPictureInPictureVideoCallViewController
                                                             ─► AVPictureInPictureController
                                                                (activeVideoCallSourceView = videoView)
```

### 10.1 Focus selection (`PiPFocusTracker`)

- Re-evaluates on pin / share / loudest / camera changes (150 ms debounce).
- Priority: remote share → pinned camera → loudest camera → first remote camera → `.none`.
- No camera object → `.remoteVideoUnavailable` → initials placeholder.
- Sticky camera-off: stay on that user when their camera is removed; restore when it returns.
- Share comparison uses `getId()` (SDK may replace wrapper objects).

### 10.2 Frame conversion (`RemoteCameraSampleBufferBridge`)

- One frame listener at a time; unregister before switching.
- Dedicated serial queue; I420 → NV12 (`420YpCbCr8BiPlanarVideoRange`); even dimensions (crop odd sizes).
- Strictly increasing PTS (timescale 60 000, 2 000 ticks/frame); `DisplayImmediately`; `controlTimebase = nil`.
- Rate limit ≈ 12 / 10 / 8 fps (live / placeholder / thermal throttle).

### 10.3 Video-off detection

- Y-plane sampling detects black frames when SDK omits pause state.
- 10 black frames → placeholder; 3 non-black → live again.
- Listener stays attached during placeholder so real video can be detected.

### 10.4 Watchdog and recovery

- 1 s timer: camera stall → placeholder + recompute; share stall → keep last frame; no source → attach first camera.
- Flush display layer only on `.failed` / error (not on `requiresFlushToResumeDecoding` alone).
- Epoch counter drops stale enqueues after stop.

### 10.5 AVKit (`SystemPiPCoordinator`)

- 320×180 content size; always “playing”; start retries 6× / 120 ms.
- `willStart` marks active early so connector stays foreground.
- Expand control (`viewfinder`) stops PiP like foreground return.

### 10.6 Placeholder

- Initials from display name (no contact-avatar model in this sample).
- Speaking ring when mic on + loudest.
- “Only person” message when no remotes remain.

## 11. Local camera while in PiP

- iOS 16+: multitasking swizzle enables background camera capture.
- Requires connector foreground mode (section 7).
- iOS 15: local camera pauses; remote A/V continue.
- PiP does not change the user’s mute state.

## 12. Testing checklist

**Basics**
- [ ] Real device, connected conference, swipe home → PiP starts with remote video + audio.
- [ ] Far end still sees your camera in PiP (iOS 16+).

**Focus**
- [ ] Follows loudest; pin moves PiP; remote share wins; own share never shown.

**Video off**
- [ ] Camera off → initials; camera on → video; alone → “only person” message.

**Lifecycle**
- [ ] Expand / return → in-call video live; hang-up / disconnect clears PiP; no leftover bubble.
- [ ] Repeated background/foreground: no black / stuck state.
- [ ] Rotation / iPad Split View: in-app video not frozen.
- [ ] Lock/unlock during PiP: call continues.

**Auto-start**
- [ ] Home starts PiP once; Control Center / Notification Center does not leave sticky flicker.

## 13. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| PiP never starts on home | Not connected / lobby / scene inactive / `blockSystemPiPBackgroundStart`. Check `background trigger ignored` logs. |
| Black PiP | Connector went `.background` (section 7); wrong camera listener; PTS not increasing. |
| Frozen frame | Timeline not reset on source change; another listener stole the camera frame callback. |
| Far end loses your video | Missing multitasking `.m`; iOS &lt; 16; entitlement; camera muted/unpaired in background handler. |
| Flicker initials ↔ video | Black-frame heuristic too sensitive; flushing on `requiresFlushToResumeDecoding`. |
| PiP after hang-up | Missing `tearDown(invalidate: true)` or block flag order. |
| Wrong / stale participant | Camera listener unregistered; snapshots / loudest / pin not notifying. |
| Black flash on share | Compared share by object not `getId()`, or flushed on camera→share switch. |

## 14. Log keywords

All PiP logs start with **`System PiP`**:

- `will start` / `did start` / `will stop` / `did stop` / `failed`
- `remote frame bridge: focus camera|share|remoteVideoUnavailable`
- `first frame after attachment change`
- `watchdog: camera|share frame stall`
- `placeholder capture on userId=…`
- `remote bridge metrics: received=… converted=…`
- `background trigger ignored: <reason>`

---

