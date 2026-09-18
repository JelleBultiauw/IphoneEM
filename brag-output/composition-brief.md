# Hyperframes Composition Brief: iPhoneEM

## Objective
A 20 second launch video for iPhoneEM, a Mac app that boots jailbroken virtual iPhones.

## Output
- Composition: `brag-output/composition/index.html`
- Render: `brag-output/brag.mp4`, poster `brag-output/brag.jpg` (baked as frame 0)
- Format: landscape, 1920x1080, 30fps, 20.0s

## Source Material
- Project root: `~/Downloads/IphoneEM` (app sources in `overlay/sources/vphone-cli/`)
- Product name: iPhoneEM
- Tagline: Jailbroken iPhones, in a window.
- Real UI used: `assets/bay.png` (device bay, single phone), `assets/dual.png` (two bays),
  `assets/icon.png` (rendered from `tools/em_icon.swift`)
- Engine material: `assets/engine-demo.jpg`, the iOS home screen and root shell from the vphone-cli
  docs, credited in the caption
- Palette and type come from the app itself: #0e0e10 background, #0a84ff accent, cards #19191c with a
  1px white 9% border, system UI font

## Creative Direction
- Tone preset: polished
- Creative direction: quiet product film for a tool that should not exist
- Interpretation: four scenes plus an outro, long holds, no bounce, no jokes spelled out. The claim
  carries the video; the UI is the evidence.
- Avoid: generic SaaS language, stock motion graphics, em dashes, any line that could belong to
  another product

## Storyboard
Use `brag-plan.md` as the contract.

1. Hook, 4s: "Your Mac can run an iPhone." / "A jailbroken one." over the app window.
2. Live screen, 4s: push into the bay, simulated tap, "A live screen you can tap and swipe."
3. What runs inside, 4s: engine demo frame, "It boots real iOS firmware."
4. Two phones, 4s: dual bay screenshot, "Two phones, two disks."
5. Outro, 4s: icon, name, tagline, repo URL.

## Audio
- Role: warm bed with sparse motion matched accents
- Music: `assets/music.mp3` (brag bundled track, 120 BPM), 0.5 volume, fade in over 1.4s, fade out
  from 18.2s to 20s via `data-automation`
- SFX: drop on the window landing, mouse click on the tap, soft impact on the engine card, switch on
  the two bay reveal, single bell on the icon. Chosen after the animation existed.
- Audio-reactive treatment: none

## Implementation notes
- One standalone composition, one paused GSAP timeline on `window.__timelines["main"]`, all animation
  via `fromTo` so no CSS transform fights a tween
- Scene wrappers are `class="clip"` with `data-start`/`data-duration`; fades are on the scene element,
  never `autoAlpha` on a clip's children that the runtime owns
- Scene cuts sit on the track's beat grid (4.02, 8.02, 12.02, 16.02)
- `npx hyperframes check` passes with 0 findings across lint, runtime, layout, motion and contrast
