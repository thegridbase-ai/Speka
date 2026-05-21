# GridBaseUIKit Fonts

Drop the GridBase typeface files here to enable native rendering:

- `JetBrainsMono-Regular.ttf` (or `.otf`) — code / numerics
- `GeneralSans-Regular.ttf` (or `.otf`) — UI text

`GridFont.registerFonts()` registers any present file with CoreText on first
use. If the files are absent, `GridFont.mono(...)` falls back to the system
monospaced font and `GridFont.ui(...)` to the system default — no crash.

This file also guarantees the target ships a resource bundle, so
`Bundle.module` is available for font lookup.
