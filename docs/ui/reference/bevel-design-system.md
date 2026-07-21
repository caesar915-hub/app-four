<!-- Created: 2026-07-02 18:36 (WEST) · Updated: 2026-07-03 14:28 (WEST) -->
# Bevel — design-system teardown (measured)

Reverse-engineered from 6 iPhone screenshots (IMG_4804–4809, 1170×2532 @3x → 390×844pt), PIL pixel-sampled (median patches, mask medians, circle fits, cap-height→pt ÷0.714). Reproduced in Figma: **Squil-Design → page "Bevel"**. All values measured unless marked ~.

## 1. Screens covered
| Source | Screen |
|---|---|
| IMG_4804 | Home — "Today, 7 June", Active pill, rings card, Stress & Energy |
| IMG_4805 | Health Monitor — Today, 6 No-data metric cards, Timeline empty |
| IMG_4806 | Journal — week strip w/ gold checks, habit rows |
| IMG_4807 | Fitness (30 days) — heatmap calendar, Activity Summary chart |
| IMG_4808 | Fitness (Strength) — empty progression, template skeletons, dark CTA |
| IMG_4809 | Biological Age — warm gradient hero, 39,6 gauge, banners |

## 2. Palette
**Neutrals**
- App background `#F7F7FB` (light lavender-grey; reads `#F4F4F9`–`#F6F6FA` under shadow falloff)
- Card `#FFFFFF` (interior `#FEFEFE`; subtle darker vignette toward edges — not reproduced)
- Primary text / dark fills `#222325` (dark CTA pill, tab icons, titles)
- Secondary text `#8B8C8E` (subtitles darker `#616264`) · disabled/"No data" `#CACBCE` · skeleton bars `#E0E0E3`
- Hairline/segmented-control bg `#F5F5F6` · selected-tab chip `#F3F3F7` · chip bg `#ECECED` (biomarkers chip)
- Empty ring track `#EFEFF1` · bio gauge ticks `#DEDCDE` · heat grey cell `#CACBCE`

**Accents**
- Mint (Active pill, stress dot) `#64CEA9`
- Gold (journal checks): radial disc `#F0C850` core → `#F0D890` rim + soft gold glow (flat median `#F6C956` overstates it) · sun `#F8D748` · strain arc gold `#F2CD90` (striped)
- Orange (energy bolt) `#E86A41` · bio orange (text/band/▲) `#F2A842`
- Chart pink `#EE80A1` · chart orange `#F5BF71` (softer than first-pass medians `#EF919A`/`#F0B256`)
- Heat green light `#AFDC6C` · heat green mid `#7AC290` (heatmap contains zero `#65C466` px — that is the battery green only) · heat blue `#4CA8C1` · empty cell `#ECECF0`
- Avatar disc `#C8DDED` (pale blue, "JS" dark text)
- Mascot (Ask Bevel): periwinkle gradient `#94A5E2` → `#CACBF3`, ~28×24pt blob w/ two eyes

**Gradients**
- Biological-Age hero: peach `#F2D5C7` (top-left) → cream `#F4DFBD` (top) → `#EDE6C0` (top-right), vertical fade to `#FBFAF8` → app bg by ~y440pt
- Stress dial tick ramp (pastel, heavily desaturated): green `#D9EDD0` → `#E8EFCC` → yellow `#F8F1CD` → pink `#F1D7D0`/`#EDD6D0`; right side fades to near-invisible
- Confidence banner fill: warm near-white `#FFFDF9` → `#FEFBF5` (subtle cream card, not saturated gold)

## 3. Typography (SF Pro on device; Inter stand-in in Figma — SF renders 0-width in MCP)
| Role | Size (cap-height measured) | Weight |
|---|---|---|
| Large title ("Today, 7 June", "Journal", "Fitness") | ~30pt | Bold |
| Screen title ("Biological Age") | ~25pt | Semibold |
| Giant numeral ("39,6") | ~42pt | Bold, decimal comma |
| Ring numeral ("2%", "−%") | ~24pt | Semibold |
| Section header ("Stress & Energy", "Yesterday's Entries") | ~17pt | Bold |
| Status-bar time / nav title ("Today") | ~17pt | Semibold |
| Body / row label ("Alcohol") | ~14pt | Semibold |
| Card title ("Today's stress") | ~14.5pt | Semibold |
| Subtitle grey ("May 2026", "Last 30 days") | ~15pt | Regular `#88898B` |
| Orange delta ("4,4 years older") | ~19pt | Semibold `#F2A842` |
| Ask placeholder | ~16pt | Regular `#88898B` |
| Tab label | ~10pt | Medium |

## 4. Geometry & spacing
- Screen margins **20pt** (cards x=20…370). Full-width card = 350pt
- Card radius **24pt** (rings card fit 23.4, metric card 22.5, journal row 22.5 — one token)
- Journal habit row: 350×**50pt**, radius 24 (near-capsule)
- Metric mini-card (Health Monitor): **168×112pt**, 14.3pt gaps (h+v), 2-col grid, rows pitch ~126.3pt; labels secondary `#8B8C8E` (whole card reads disabled)
- Tab bar pill: span x21–299 (**278pt**), height **62pt**, bottom inset **21pt**; detached FAB **62pt** Ø, right margin 20pt; selected tab = `#F3F3F7` chip
- Ask Bevel bar: 350×**48pt** capsule, floats above tab bar (overlays content)
- Ring gauge (rings card): embossed white "tube" outer Ø **~108pt** (nearly fills the 116pt column; the visible recessed grey band r33–41 sits inside it); value arc gold `#F2CD90` **striped**, anatomy = solid cap at 12 o'clock + hatched sweep 3→7 o'clock; center numeral 24pt
- Rings card: 350pt wide, top y204pt, 3 equal columns w/ 2 hairline dividers
- Stress dial: tick ring r ~33–40pt, ~60 radial ticks, pastel ramp (see §2), "−" center
- Gold check disc (journal) **23pt** Ø, white ✓, pitch **54.2pt** (centers 33→357, bleeds past 20pt margins); day digits ~12pt; today = white rounded card 55×**70pt** behind date+disc
- Heatmap cell **15×7pt horizontal pill** (radius 3.5), pitch **22.3pt × 17pt**; legend dots 6pt
- Dark CTA pill (`+ Add workout template`): height **42pt**, capsule, `#222325`, white 15pt Semibold label
- Light button ("Edit Fitness"): 350×**46pt**, white capsule, dark 15pt label
- Confidence banner: full-width card, top y448pt, radius 24, cream gradient fill, orange badge + 17pt orange Bold text + →
- Status bar: standard iOS, time 17pt Semibold + moon glyph, battery pill w/ green `#65C466` fill + ⚡
- Nav circular buttons 50pt Ø white; share+avatar pill ~98×42pt white capsule, avatar 33pt disc `#C8DDED`

## 5. Elevation
- Card shadow: large, diffuse, **lavender-tinted** — at card bottom edge bg dips from `#F7F7FB` to `#DDDAE7` (Δ~10% dark, blue-shifted), decaying over 40+px (>13pt). Figma approx: `DROP_SHADOW rgba(93,91,133,0.18), y=10, blur=40` + touch `rgba(93,91,133,0.10), y=2, blur=8`
- Floating elements (tab pill, FAB, Ask bar, nav pills) carry the same shadow, stronger presence on bg
- Recessed elements (ring tracks, skeleton pills in metric cards) read as inner-shadowed; approximated flat `#EFEFF1`/`#E8E8E9`

## 6. Component inventory (as built in Figma)
Status Bar · Nav Circle Button (share/…/+/calendar/home) · Avatar Pill · Tab Bar (5 tabs + selected chip) + FAB · Mini footer (home disc + Ask bar + FAB) · Ask Bevel Bar · Card · Ring Gauge (value/empty) · Rings Card 3-up · Stress Dial + stat triple (Highest/Lowest/Average) · Energy bolt row (dashed progress ticks + 1%) · Metric Mini-card (icon+label, No data, skeleton pill) · Journal Habit Row (segmented ✕/−/✓ · value+chevron) · Week-strip Day Cell (checked/today) · Heatmap Cell (grey/green1/green2/blue) + legend · Dark CTA Pill · Light Button · Add Pill · Dismiss ✕ · Confidence Banner · Delta Chip (▲ +0,4 from last week ›) · Biomarkers Chip · Section Header (title+→) · Skeleton Bar · Line Chart kit (pink/orange/grey, hollow dots, area fade) · Bio Arc Gauge (ticks, orange band, markers 25,2/35,2/45,2) · Month heatmap grid

## 7. Open questions / not measured
- Exact SF Pro optical sizes (Text vs Display cutoffs) — sizes inferred from cap heights ±1pt
- Card edge vignette (interior `#FEFEFE`→`#F9F9F9` near edges) — likely inner shadow; not reproduced
- Strain arc stripe pattern angle/pitch (visual approximation)
- Dark-mode theme, pressed/disabled states, motion — no source material
