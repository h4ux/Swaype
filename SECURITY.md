# Security Policy

## Supported versions

Only the most recent release on the `main` branch receives security fixes.
Older builds are unsupported — please update before reporting.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems. Instead:

1. Open a [private security advisory](../../security/advisories/new) on this
   repository, or
2. Email the maintainer directly (see the contact in the GitHub profile of the
   repo owner).

Include:

- A clear description of the issue
- Steps to reproduce
- The version of Swaype and macOS where you observed it
- Whether the issue can be triggered from the local user, another local user,
  or remotely

We aim to acknowledge reports within 72 hours and ship a fix or mitigation
within 30 days for high-severity issues.

## What Swaype does and does not do

Understanding the threat model helps decide whether something is a bug or a
vulnerability:

**Swaype does:**

- Read and write your system clipboard (`NSPasteboard.general`)
- Synthesize ⌘C and ⌘V keystrokes when you trigger the "Swap Selection" hotkey
  or menu item (Accessibility permission required)
- Read your installed keyboard layouts via Carbon's Text Input Sources API in
  order to build the conversion mapping
- Persist UI preferences (chosen layout pair, launch-at-login, hotkey
  binding) in `UserDefaults` under the `com.swaype.Swaype` domain
- Register itself as a Launch-at-Login service if you toggle that on
  (`SMAppService.mainApp`)

**Swaype does not:**

- Connect to the network. There is no telemetry, no update check, no remote
  call of any kind.
- Read text from any app other than via the clipboard / synthesized copy.
  We never call accessibility APIs that read window or text contents directly.
- Modify other applications' state, install kernel extensions, or escalate
  privileges.
- Collect, log, or persist the content of any text it converts. The clipboard
  pass-through happens in memory and is not written to disk.

If you find that any of the "does not" claims above is incorrect for a given
release, that's a security bug — please report it.

## Third-party code

Swaype depends on one third-party Swift package:

- [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) —
  used to register the global hotkey. Vulnerabilities in that package should
  be reported upstream first; if a fix lands there we'll bump our pinned
  version promptly.

## Distribution and code signing

Releases on GitHub are **ad-hoc signed**, not notarized with an Apple Developer
ID. On first launch, macOS Gatekeeper will quarantine the app and require an
explicit override (right-click → Open). This is expected behaviour for an
open-source project without a paid Apple Developer membership. If you want a
notarized build, you can produce one yourself with your own Developer ID after
cloning the repo.
