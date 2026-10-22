# serve-avd: mobile preview customization

Research date: 2026-10-08. Scope: identify the upstream project and the seams for a mobile browser preview fork. These are implementation findings, not an approved UI specification.

## Identity and architecture

The upstream project is [hsandhu/serve-avd](https://github.com/hsandhu/serve-avd), a Node.js tool for streaming and controlling Android emulators or connected devices through a browser. It captures H.264 with `adb screenrecord`, converts the stream for WebCodecs decoding, and falls back to MJPEG screenshots. Input travels over a WebSocket to a persistent adb shell. CLI, MCP and SDK interfaces share the device controls. The upstream README describes same-origin proxying, including automatic `wss:` selection when HTTPS terminates at a reverse proxy. It also explicitly requires an authenticated proxy for remote exposure because actions include shell commands and APK installation. [Upstream README](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/README.md)

The requested hosted page returned HTTP 403 to a direct read during this investigation. Local installation notes identify the runtime as npm `serve-avd` version `0.1.3`, and the installed source revision matches the upstream revision below. The authenticated public origin was not independently verified.

The examined upstream revision is `19b4a096da0239dc7fe42583d57b136ecb1ad922`; its package version is `0.1.3`. The package declares Node `>=18.17`, `commander` and `ws` dependencies. [Package manifest](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/package.json)

## Mobile UI entry points

| Source | Relevant responsibilities |
| --- | --- |
| [`src/client/client.css`](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/src/client/client.css) | Page, stage, phone frame, controls and sidebar sizing |
| [`src/client/client.ts`](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/src/client/client.ts) | Vanilla DOM UI; `DeviceView.applyAspect`, `buildControls`, `bindInput`; `Panes.open`/`toggle` |
| [`src/middleware.ts`](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/src/middleware.ts) | `previewHtml` injects bundled CSS/JS and viewport metadata; browser assets are cached in-process |

The stylesheet has no responsive media queries. It uses `100vh` for the app, 24px stage padding, a fixed 360px sidebar, 40×34px icon buttons, and a portrait screen height of `calc(100vh - 210px)`. The landscape screen width uses `min(calc(100vw - 420px), 1200px)`. These rules imply squeezed sidebar layouts, excess chrome and unsuitable landscape sizing on narrow phones; the landscape defect is supported by the qualified local observation below. [Stylesheet](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/src/client/client.css)

A read-only local browser check using installed source matching this upstream revision found both landscape `.screen-wrap` elements measuring 0×0 at a 390×844 viewport. Streams were blocked and WebSockets stubbed, so this establishes a layout defect without validating video playback or real touch interaction. No emulator input or service change was performed.

Pointer Events already forward touch drags, with normalized coordinates and cancellation handling. Pinch uses Alt+drag with a mirrored second contact, rather than tracking two fingers. Keyboard forwarding listens to key events on the focusable screen div; it does not provide a text input to summon a phone keyboard. The emulator software-keyboard button is explicitly hidden. Layout adjustments can therefore start in CSS; mobile typing or true multitouch changes also require `client.ts`. [Browser client](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/src/client/client.ts)

## Fork and validation considerations

The project is Apache-2.0 licensed. Preserve the license and relevant attribution; distributed modified files require notices of modification. Section 4 also specifies handling of upstream NOTICE files if present. [Upstream license](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/LICENSE)

The build bundles `client.ts` into `dist/client.js` and copies `client.css` into `dist/client.css`; edit source assets, rebuild, then restart the preview process to avoid its cached HTML retaining old assets. [Build script](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/build.mjs), [HTML cache](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/src/middleware.ts)

Recommended first patch: fit the stream to available phone width and height, reduce frame/header chrome, keep navigation reachable, and present Devices/Tools/Logs without consuming fixed sidebar width. Confirm the owner's desired mobile behavior before treating these suggestions as requirements.

Run `npm run build`, `npm run typecheck` and `npm test`. These commands exist upstream; browser viewport and touch behavior still need separate validation. [Package scripts](https://github.com/hsandhu/serve-avd/blob/19b4a096da0239dc7fe42583d57b136ecb1ad922/package.json)

Validate portrait and landscape phone sizes, panel open/close, touch drag/cancel, H.264 and MJPEG geometry, and desktop layout. Use mocked endpoints for layout work where possible; coordinate live interaction with the owner because the existing emulator is shared. Preserve the current remote authentication and proxy configuration when eventually switching to the fork.
