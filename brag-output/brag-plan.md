# Brag Plan: iPhoneEM

## What is this app?
A Mac app that boots real jailbroken iPhones in a window on Apple Silicon. It is a UI around
vphone-cli, which does the actual firmware work, and it can run two phones side by side.

## The angle
The claim people do not expect: the iPhone in the window is not a mockup, a screenshot, or a
simulator. It is iOS firmware running in a virtual machine, jailbroken, on a laptop. The video makes
that claim in the first three seconds and then shows the app doing it.

## Hook (first 2-3 seconds)
"Your Mac can run an iPhone." The app window lands under it. Then the second line, which is the part
that earns the next seventeen seconds: "A jailbroken one."

## Key moments (the middle)
- The bay: a real iPhone screen inside a Mac window, with a tap landing on it.
- The proof shot: iOS home screen plus a root shell in the same frame, from the engine's own docs.
- Two bays side by side, each phone with its own disk, and the sidebar switch that turns it on.

## Outro / punchline
Icon, name, and the line that says what it is: "Jailbroken iPhones, in a window." Then the repo URL
and music out.

## User flow worth showing
Entry: the app is open with a machine in the first bay. Key action: tap the screen, and (from the
repo's own docs) what is actually running underneath. Result: a second bay, so two machines are up at
once. The create pipeline is not in the video; it is a long download and the README covers it.

## Tone
- Preset: polished
- Creative direction: quiet product film for a tool that should not exist
- Interpretation: few scenes, long holds, no bouncy motion, no jokes spelled out. Confidence comes
  from showing the thing and stopping.

## Format: landscape — 1920x1080
## Duration: 20s

## Visual identity (from the project)
- Background: #0e0e10, with a #2b6cf6 radial glow behind the subject
- Accent: #0a84ff
- Text: rgba(255,255,255,0.94), secondary rgba(255,255,255,0.58)
- Cards: #19191c with a 1px rgba(255,255,255,0.09) border and a deep shadow
- Display font: system UI (the app uses SF, the video stays on the platform default)
- Strongest visual element: the device bay, a phone inside a card

## Share copy (draft)
iPhoneEM boots real jailbroken iPhones in a window on your Mac. One or two device bays with a live
screen you can tap and swipe, a file browser into the guest, and the whole firmware pipeline behind a
Setup tab. MIT, on GitHub: github.com/JelleBultiauw/IphoneEM

## Audio direction
- Role: warm bed, sparse accents
- Music: happy-beats-business-moves-vol-1 (120 BPM, cue preset available)
- Music treatment: fades in over the first second, sits at 0.5, fades out over the last 1.8s
- Music cue guidance: preset cues; scene cuts placed near the strong beats at 4.02, 8.02, 12.02,
  16.02, 20.02
- Audio-reactive treatment: none. The edit is already quiet and dark.
- SFX posture: sparse, motion matched, one per moment
- Audio-coupled moments: the window landing (drop), the tap on the screen (click), the engine card
  reveal (soft impact), the two-bay reveal (switch), the logo (single bell)
- Restraint rule: no whooshes on every transition, no riser before the outro

## Storyboard

### Scene 1 — hook — 4s
Black stage with a soft glow. The app window fades in and settles. Two headline lines arrive and hold.
Sequential/interaction: the second line arrives 1.5s in; that arrival is the beat.
Audio intent: settle the viewer, no build up yet.
Audio-coupled idea: soft drop as the window lands.
Music: bed comes up under it.
Transition mood: soft → Scene 2

### Scene 2 — the live screen — 4s
Slow push into the bay from the same screenshot. A tap ring lands on the phone screen and fades.
Text bottom left: "A live screen you can tap and swipe." / "Right click is the home button."
Sequential/interaction: simulated tap at 5.3s.
Audio intent: quiet, the click is the only sharp sound.
Audio-coupled idea: mouse click on the tap.
Music: steady bed.
Transition mood: soft → Scene 3

### Scene 3 — what runs inside — 4s
The engine's own demo frame: iOS home screen next to a root shell. Headline: "It boots real iOS
firmware." Caption credits the engine.
Sequential/interaction: none. The card rises and holds.
Audio intent: this is the credibility beat, give it a low accent.
Audio-coupled idea: soft impact on the card landing.
Music: bed continues.
Transition mood: soft → Scene 4

### Scene 4 — two phones — 4s
Two device bays side by side, both phones visible, switch on. Headline: "Two phones, two disks."
Sub: "Clone a machine in Setup, then put it in the second bay."
Sequential/interaction: card lands, headline, then sub line.
Audio intent: the payoff beat, one clean accent.
Audio-coupled idea: switch sound under the card landing.
Music: bed continues.
Transition mood: soft → Scene 5

### Scene 5 — outro — 4s
Icon, name, tagline, repo URL. Music fades out under the URL.
Sequential/interaction: four elements arrive in order, then hold.
Audio intent: land it, then silence.
Audio-coupled idea: single soft bell on the icon.
Music: fades to zero by 20s.
Transition mood: end.

**Music mood for this video:** steady, warm, business-calm at low volume
**Audio summary:** a quiet bed that carries a four beat structure, five motion matched accents, and
gets out of the way at the end.
