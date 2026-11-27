# Design system

The source is the "Ride or Nah" page of the design canvas: https://claude.ai/artifact/ErZgTar5mNffaSuyjv57q2 (boards Today — Nah, Today — Ride, Next 7 days, Day detail, Notification settings, Daily notifications). The canvas's "Vespa or No Thank You" page is a separate design and never feeds this app. Share and Messages boards are marked "not in spec yet" and aren't built.

Tokens live in `RideOrNah/DesignSystem/Theme.swift`. Screens use them and never hard-code colors or fonts.

## Look

The app is dark only. The design is built on a near-black ground, so the app sets `preferredColorScheme(.dark)`. `app-platform`'s appearance requirement says so, and a change to the system light/dark setting leaves the app as it is.

| Token | Value | Use |
|---|---|---|
| `ground` | `#0A0B0D` | Screen background |
| `ink` | `#F2F1EE` | Primary text |
| `inkSecondary` | `#C9CCD2` | Secondary text, section labels |
| `inkTertiary` | `#9A9EA6` | Captions, timestamps |
| `inkQuiet` | `#8A8E96` | Inactive tabs, chevrons |
| `accent` | `#FF6B1A` | Ride, actions, active tab, emphasis |
| `nah` | `#BFD8EE` | Nah, hard breaches |
| `nahInk` | `#E8EEF5` | The big NAH word |
| `reasonWarm` | `#FFE2C7` | The italic reason line on Maybe and Ride |
| `card` | white at 5% with a 9% white hairline | Cards (26 pt radius) |
| `rule` | white at 8–10% | Dividers |

Verdicts are never color alone. Every verdict appears as its word, and every pill has a text label.

- **Ride:** filled accent pill, black text.
- **Maybe:** accent outline pill, ink text.
- **Nah:** filled `nah` pill, black text.
- **Unknown:** dashed white outline, "CAN'T TELL" in quiet text.

## Type

The canvas uses Barlow Condensed (display), Barlow (body) and Cormorant Garamond italic (the reason line), all Google Fonts. The app uses the system's closest equivalents, so no font files are downloaded or bundled:

| Role | Canvas | App |
|---|---|---|
| Verdict word | Barlow Condensed 800, 120–180 pt, tight | SF Pro, `.width(.compressed)`, black, uppercase, scaled to fit |
| Headings, pills, labels | Barlow Condensed 600–800, uppercase, tracked | SF Pro `.width(.condensed)`, bold, uppercase, tracking 1–3 |
| Body | Barlow 400–600 | SF Pro (system) |
| Reason line | Cormorant Garamond italic 600 | New York (`.serif`) italic, semibold |

Everything uses Dynamic Type text styles scaled from these sizes, so the largest accessibility size still fits by scrolling.

## Components

- **Wordmark:** "RIDE *or* NAH", condensed caps with an italic serif "or" in accent.
- **App icon:** option E on the canvas's "App icon — wordmark with gauge" board: the stacked wordmark inside tachometer ticks, orange on the Ride side, blue on the Nah side, with a white needle on Ride. `make app-icon` redraws it from `scripts/render-app-icon.swift` into both apps' asset catalogs.
- **Chips:** profile, location and radius, as 36 pt capsules on dark glass with a chevron. Glass is Liquid Glass through `adaptiveSurface`.
- **Verdict pill:** see above, 26 pt tall.
- **Severity tag:** "HARD" is filled `nah`, "SOFT" is a white outline.
- **Card:** a 26 pt radius `card`, holding a section label (condensed caps, tracked).
- **Primary button:** an accent capsule, 44 pt or taller, black text. Secondary is an outline capsule.
- **Tab bar:** Today, Week, Alerts, with stroke icons.
- **Attribution footer:** the Apple Weather mark plus "Weather data sources", on every weather screen.

Screens the canvas doesn't draw (first-run setup, settings, profiles, locations, paywall, widgets, watch) use the same tokens and components.
