# iPhoneEM

A native macOS app that runs **jailbroken virtual iPhones** on Apple Silicon — built as a GUI on top of
[`vphone-cli`](https://github.com/Lakr233/vphone-cli).

![iPhoneEM](docs/screenshot.png)

The engine boots real iOS firmware (PV=3 virtual machines via `Virtualization.framework`); iPhoneEM
gives it a proper window: a sidebar of shortcuts on the left, live device bays on the right — one
phone by default, **two side by side** with the *Two phones* switch. Everything the VM writes stays
on disk, so whatever you do on the phone is still there after a reboot.

## Features

| Sidebar | What it does |
| --- | --- |
| **Phones** | 1–2 device bays with a live, touchable screen. Boot / Stop, Home, Lock, volume, Snapshot. Drag an `.ipa` onto a bay to install it, right-click the screen for Home. |
| **Files** | The iPhone's own file system — browse, upload, download, new folder, delete. |
| **Apps** | Installed apps with launch/terminate, `.ipa`/`.tipa` install, and "open URL on the phone". |
| **Screenshots** | Device captures saved to `~/Pictures/iPhoneEM`. |
| **Setup** | Host checks (SIP / AMFI), the machine library (create / clone / delete / assign to a bay) and a live console of the engine's output. |
| **Info** | Paths, per-phone UDID / IP / SSH command and a clipboard bridge to the guest. |

## Requirements

- Apple Silicon, macOS 15 (Sequoia) or newer, Xcode command line tools
- Homebrew packages for the firmware pipeline:
  `brew install aria2 gnu-tar openssl@3 ldid-procursus sshpass zstd cmake keystone python@3.13 wget libusb ipsw`
- **SIP / AMFI relaxation** (Apple requires this for PV=3 guests — no app can do it for you):
  1. Reboot into Recovery (hold the power button), open Terminal:
     ```
     csrutil disable
     csrutil allow-research-guests enable
     ```
  2. Back in macOS, then reboot again:
     ```
     sudo nvram boot-args="amfi_get_out_of_my_way=1"
     ```

  The Setup page shows the live status of both. Without them the app runs, but no VM can boot.

## Build

```sh
./build.sh                 # fetches the pinned engine, applies the GUI, installs to /Applications
./build.sh --no-install    # only produces dist/iPhoneEM.app
VPHONE_ENGINE=~/vphone-cli ./build.sh   # use your own vphone-cli checkout instead
```

The engine is pinned to a known-good commit and lives in `.build/engine`. Its firmware pipeline needs
extra host tools once:

```sh
cd .build/engine && ./scripts/setup_tools.sh
```

## Run a jailbroken phone

1. Setup → name it (e.g. `myphone`), variant **jb** → **Create Phone**. The console shows the whole
   pipeline: IPSW download (cached in `~/.vphone/ipsws`), boot-chain patch, DFU restore, CFW install
   (macOS asks for your password once — the app uses the native admin dialog) and the first boot.
2. Phones → **Select VM** → your machine → **Boot**. During iOS setup pick a region outside Japan/EU
   (system apps fail to install there). Sileo + TrollStore arrive automatically with the `jb` variant.
3. Optional second phone: Setup → **Clone** (fast APFS copy, fresh identity) → assign it to bay 2 and
   turn on *Two phones*.
4. SSH into the guest: `ssh -p 22222 mobile@<ip>` (password `alpine`; the IP is on the Info page).

### Where your data lives

`~/.vphone/VMs/<name>/` — `Disk.img` (sparse, 64 GB by default), `nvram.bin`, `SEPStorage` and
`config.plist`. The guest writes straight to that disk, so installed apps, files and settings survive
stopping the phone or quitting the app. Stopping is a hard power-off (iOS recovers through its journal
on the next boot); the engine has no suspend, so a boot is always a cold boot from disk.

## Repository layout

```
build.sh                     fetch engine → apply GUI → build → sign → bundle → install
overlay/sources/vphone-cli/  the GUI sources (EM*.swift) that are copied into the engine
patches/                     the two small edits the engine needs (entry point + guest-stop guard)
app/EMInfo.plist             app bundle metadata
tools/em_icon.swift          renders the app icon (tools/EMAppIcon.icns)
scripts/sync-from-engine.sh  dev helper: regenerate overlay + patches from a working engine tree
```

## How it works

`vphone-cli` is a CLI that creates and boots virtual iPhones. iPhoneEM compiles that engine into an
app bundle and adds a GUI on top of it:

- Each bay boots its own `VPhoneVirtualMachine` **inside the app process** (two VMs coexist) and shows
  it through a `VZVirtualMachineView` subclass that injects touches into the guest.
- Guest-side features (file browser, app list, clipboard, HID keys) go through the engine's vsock
  control channel (`VPhoneControl` + the `vphoned` daemon that ships inside the guest).
- Pipeline commands (`vm create/clone/delete`, host checks) run the same binary as a child process with
  their output streamed into the Setup console.

## Credits & license

- Engine: [`Lakr233/vphone-cli`](https://github.com/Lakr233/vphone-cli) (MIT) and its contributors.
- Background research: [wh1te4ever/super-tart-vphone-writeup](https://github.com/wh1te4ever/super-tart-vphone-writeup).
- iPhoneEM's own code (the GUI, build script, icon): MIT — see [LICENSE](LICENSE).

Not affiliated with Apple. The virtual iPhones are research VMs: use them for development and testing
on hardware you own, and respect the software licences of anything you install into a guest.
