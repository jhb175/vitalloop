# Body Coach UI Demos

This folder contains three homepage demo directions for the Apple Watch + iPhone body coach app.

## Files

- `body-coach-ui-demos.html`
  - Best preview file.
  - Open it in a browser to compare all three iPhone screens side by side.
- `body-coach-ui-demos.svg`
  - Importable static board.
  - Drag it into Figma or use Figma import to bring the three screens in as vector artwork.
- `body-coach-ui-v2.html`
  - Revised preview based on the darker, data-rich reference images.
  - Replaces the earlier white-card direction with stronger status summaries and richer charts.
- `body-coach-ui-v2.svg`
  - Importable static board for the revised V2 direction.
- `body-coach-ui-v3.html`
  - Reworked homepage information architecture.
  - Separates the homepage dashboard from metric detail pages.
- `body-coach-ui-v4.html`
  - Current review version.
  - Contains the same homepage in dark mode and light mode with optimized color palettes.
- `body-coach-ui-v4.svg`
  - Importable static board for the current dark/light homepage direction.
- `body-coach-ui-v5-liquid-glass.html`
  - Current texture exploration version.
  - Keeps the V4 layout and typography, then upgrades background/card/navigation texture toward Liquid Glass.
- `body-coach-ui-v5-liquid-glass.svg`
  - Importable static board for the V5 Liquid Glass direction.
- `body-coach-ui-v6-liquid-glass-refined.html`
  - Current review version after annotation fixes.
  - Refines Liquid Glass texture, hero proportions, card curvature, and bottom navigation alignment.
- `body-coach-ui-v6-liquid-glass-refined.svg`
  - Importable static board for the V6 refined Liquid Glass direction.
- `body-coach-ui-v7-contrast.html`
  - Current review version.
  - Keeps the V6 structure and material direction, then fixes text readability over glass/pattern backgrounds.
- `ui-contrast-audit.md`
  - Notes the contrast issues found in V6 and the design rules used for the V7 fix.
- `body-coach-watch-ui-v1.html`
  - Apple Watch UI preview with four 46mm watch screens.
- `body-coach-watch-ui-v1.svg`
  - Importable static board for the Apple Watch V1 design.

## Demo Directions

### Demo A - Dashboard

Professional body data dashboard. Highest information density.

Best if the product should feel like a serious body monitoring console.

### Demo B - Coach

Coach-first daily action view. The user sees what to do today before seeing the data.

Best if long-term adherence matters more than showing every metric up front.

### Demo C - Apple Native

Apple Health / Fitness inspired native style. Lowest design and implementation risk.

Best if the app should feel close to the Apple ecosystem and be straightforward to build in SwiftUI.

## Recommendation

The original v1 demos were rejected because the black hero block felt crude, the charts were too plain, and the summary content was weak.

Use `body-coach-ui-v7-contrast.html` as the current direction for review.

V2 moves toward a darker health-monitoring product language: glassy black panels, stronger daily status copy, richer line charts, time-axis mini charts, and Apple Watch-style glanceable modules.

V3 corrected the homepage structure: the first screen is now a body overview dashboard, while dense single-metric charts belong to a secondary detail page.

V4 keeps that homepage architecture and provides two visual themes: a dark Apple Watch-like mode and a lighter daytime mode. The sample charts and numbers are placeholders, not real HealthKit output.

V5 preserves the V4 table layout, colors, and type hierarchy, then improves the material quality with Liquid Glass-style treatment: translucent cards, edge highlights, background refraction, glowing data marks, and a floating glass tab bar. In SwiftUI, this should map to `GlassEffectContainer`, `.glassEffect(...)`, and glass button styles on iOS 26+, with material fallbacks for older systems.

V6 addresses the annotated issues: the bottom navigation now follows the phone's lower curve instead of reading as a square block; the hero score/text proportions are tighter; card radii are unified; glass highlights are subtler; and the layout uses vertical space more efficiently.

V7 addresses text legibility over glass and patterned backgrounds. Decorative glow, reflection, and card shine layers now sit behind text; secondary text colors are stronger in both dark and light modes; and the main hero copy has a subtle readability backing so the background texture does not reduce contrast.

The Watch V1 design is not a smaller iPhone dashboard. Watch A now uses a data-first layout with multiple compact metric cards instead of a large central score ring; the other screens focus on ranked daily tasks, quick subjective logging, and a complication / Smart Stack entry point.
