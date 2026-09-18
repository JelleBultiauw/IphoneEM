# Share copy variants

Canonical caption: `share-copy.txt`. These are per-platform versions.

## X

```
Built iPhoneEM: it boots real jailbroken iPhones in a window on Apple Silicon. One or two device bays, a live screen you can tap and swipe, a file browser into the guest, and the firmware pipeline in a Setup tab. MIT.

github.com/JelleBultiauw/IphoneEM
```

## LinkedIn

```
For the last while I have been building iPhoneEM, a Mac app that runs jailbroken virtual iPhones on Apple Silicon.

It is a window around vphone-cli, the project that boots real iOS firmware in a Virtualization.framework VM and patches a jailbreak into it. I put a UI on it: a sidebar with shortcuts, one or two device bays that show the live screen (you can tap and swipe in it, and dragging an .ipa onto a bay installs it), a file browser for the guest, an app list, and a Setup tab that runs the whole pipeline from firmware download to first boot while streaming the engine's output.

Two things worth knowing up front: it needs SIP and AMFI relaxed on the host, and every machine is a real disk image, so an app you install or a file you drop in is still there after a reboot.

MIT, code and a 20 second demo: github.com/JelleBultiauw/IphoneEM
```

## Reddit (r/macOS, r/jailbreak, r/Virtualization)

```
I made a GUI for vphone-cli, the project that boots a virtual iPhone through Virtualization.framework with PV=3 guests.

It is a normal Mac app: a sidebar with shortcuts, one or two device bays that render the live screen with touch pass-through (mouse becomes a touch, right click is home), a file browser into the guest, an app list, and a Setup tab that runs the create pipeline with the console output visible in the app.

Notes from building it: the VM runs in-process, so two machines can be up at once, each with its own Disk.img. Guest-side features (files, apps, clipboard, HID keys) go over the vsock control channel to vphoned. Booting requires SIP disabled plus amfi_get_out_of_my_way=1, or the amfidont allowlist; the Setup tab checks both and says which one is missing.

The build script fetches the engine at a pinned commit and applies the UI as an overlay, so rebasing on upstream stays cheap. Feedback welcome, especially from people running it on their own hardware.

github.com/JelleBultiauw/IphoneEM
```
