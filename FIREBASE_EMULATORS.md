# Firebase Emulator Suite

The local suite keeps development accounts and Firebase data separate from the
production project.

## Start

From the repository root:

```sh
firebase emulators:start --only auth,firestore,functions,eventarc,storage
```

Open the local dashboard at <http://127.0.0.1:4000/>. Stop all emulators with
Control-C. Emulator data is discarded when they stop unless an explicit
`--import`/`--export-on-exit` directory is used.

## Connect the iOS app

In Xcode, open **Product > Scheme > Edit Scheme > Run > Arguments** and add:

```text
--firebase-emulators
--in-memory-store
```

Use an iOS Simulator. `127.0.0.1` from the simulator resolves to the Mac where
the suite is running. The Xcode console must contain:

```text
Firebase Emulator Suite enabled at 127.0.0.1
```

Remove or uncheck `--firebase-emulators` to reconnect a Debug build to the
production Firebase project. Release and TestFlight builds always use
production, even if the argument is accidentally present.

For a physical iPhone, expose the emulator ports only on a trusted local
network and set the Xcode environment variable `FIREBASE_EMULATOR_HOST` to the
Mac's LAN IP address. The default emulator configuration intentionally listens
only on the Mac for safety.

Cloud Messaging/APNs delivery is not emulated. Verify locally that a function
creates the expected `notification_events` document; test the final push on a
non-production Firebase test account after deployment.
