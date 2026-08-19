# Third-Party Notices

The following open-source projects were used as references when implementing the
persistent Touch Bar feature (`Sources/Shim/DFRShim.h`, `Sources/Shim/DFRShim.m`).

## ddddxxx/TouchBarHelper

- URL: https://github.com/ddddxxx/TouchBarHelper
- License: Mozilla Public License 2.0 — https://mozilla.org/MPL/2.0/

The system-modal Touch Bar wrapper design (dynamic loading of the DFRFoundation
private framework, the `NSTouchBarItem`/`NSTouchBar` category methods, and the
Control Strip presence handling) follows TouchBarHelper's approach. The two files
under `Sources/Shim/` are therefore distributed under MPL-2.0, consistent with
the upstream license.

## ddddxxx/LyricsX

- URL: https://github.com/ddddxxx/LyricsX
- License: Mozilla Public License 2.0 — https://mozilla.org/MPL/2.0/

LyricsX demonstrates the same technique in production and was used to verify the
presentation workflow (present on resign-active, Control Strip tray toggle, etc.).

## Apple private APIs

`Sources/Shim/` calls private AppKit / DFRFoundation APIs by name. These symbols
belong to Apple. All calls are guarded (`respondsToSelector` / `dlsym`) and are
no-ops when unavailable; the app remains fully functional without them.
