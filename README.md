# expo-file-system background session completion repro

On iOS, an Expo SDK 58 app never calls the system completion handler of
`application(_:handleEventsForBackgroundURLSession:completionHandler:)`. Two `expo-file-system`
app delegate subscribers keep the handler (`EXSessionHandler` through
`EXLegacyAppDelegateWrapper`, and `FileSystemBackgroundSessionHandler`), and Expo waits for every
subscriber. See [ISSUE.md](ISSUE.md) for the analysis and [PR.md](PR.md) for the fix.

## What is in the app

- `modules/background-session-probe`: a local Expo module with its own background `URLSession`
  (`repro.probe.background-session`). Its `ExpoAppDelegateSubscriber` keeps the handler for its own
  session and calls it in `urlSessionDidFinishEvents`. It answers at once for other sessions.
  Launch argument `-BGReproAutoStart YES` starts an upload at launch.
- `plugins/withSystemCompletionLog.js`: overrides `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`
  only to log when iOS delivers the event and when Expo calls the system handler, plus a log
  28 s later (the `expo-file-system` fallback timer is 25 s).
- `App.tsx`: a button for the probe upload, and a button for an `expo-file-system` background
  download (`File.createDownloadTask(..., { sessionType: 'background' })`).
- `server/slow-server.mjs`: answers every request after 20 s, on port 8099.
- `package.json` sets `expo.autolinking.ios.buildFromSource: ["expo-file-system"]`, so the stock
  and the patched runs both compile `expo-file-system` from `node_modules`.

All log lines start with `[BGREPRO]`.

## Run it

```bash
npm install
npx expo prebuild -p ios
node server/slow-server.mjs            # keep it running
scripts/build-install.sh <simulator udid>
scripts/run-scenario.sh <simulator udid> terminate logs/stock.log
```

`run-scenario.sh` launches the app (the upload starts), terminates it with `xcrun simctl terminate`,
waits 75 s, and prints the `[BGREPRO]` lines. iOS relaunches the app in the background when the
upload finishes. Pass `background` instead of `terminate` to open Settings instead (the app is
suspended, not terminated).

For `expo-file-system`'s own session: launch the app, tap **Start expo-file-system background
download**, open another app, wait about 50 s, and read the log with
`xcrun simctl spawn <udid> log stream --predicate 'eventMessage CONTAINS "[BGREPRO]"'`.

With the fix:

```bash
scripts/patch-expo-file-system.sh apply     # `revert` to go back
scripts/build-install.sh <simulator udid>
scripts/run-scenario.sh <simulator udid> terminate logs/patched.log
```

## Results (iOS 27.0 simulator, Xcode 27.1, expo 58.0.25, expo-file-system 58.0.13)

| Log file | Session | expo-file-system | System handler called |
| --- | --- | --- | --- |
| `logs/1-stock-terminate.log` | probe module | stock (precompiled) | no, app still awake 28 s later |
| `logs/2-patched-terminate.log` | probe module | only the `FileSystemBackgroundSessionHandler` change | no (`EXSessionHandler` still keeps it) |
| `logs/3-patched-full-terminate.log` | probe module | full patch | yes, 22 ms after the probe answers |
| `logs/4-patched-fs-download-background.log` | expo-file-system download | full patch | yes, 40 ms after the event |
| `logs/5-stock-fs-download-background.log` | expo-file-system download | stock (from source) | no, app still awake 28 s later |

Unit tests (`tests/`, copied into `node_modules/expo-file-system/ios/Tests` and run as the
`ExpoFileSystem-Unit-Tests` scheme): `logs/unit-tests-stock.txt` (2 new tests fail) and
`logs/unit-tests-patched.txt` (13 of 13 pass). To run them, the test spec needs its
`ExpoModulesTestCore` dependency removed (58.0.7 does not compile against the precompiled
`ExpoModulesCore` 58.1.0), and the Podfile needs
`use_expo_modules!(exclude: ['expo-file-system'])` plus
`pod 'ExpoFileSystem', :path => '../node_modules/expo-file-system/ios', :testspecs => ['Tests']`.

## Patch

- `patches/0001-expo-file-system-fix.patch`: the commit on the local expo/expo branch
  `fix/file-system-foreign-background-sessions` (worktree `~/Developer/expo-fs-background-completion-fix`), for `git am`.
- `patches/expo-file-system-foreign-background-sessions.diff`: the same source change, relative to
  the package, for `node_modules/expo-file-system` (no test, no changeset).
