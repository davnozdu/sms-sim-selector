# Changelog

## v1.1.0

* **Fixed: the choice was silently lost after boot.** The framework re-picks the
  default SMS subscription every time the SIMs are re-initialised (modem
  restart, eSIM refresh, carrier config reload, a restart of
  `com.android.phone`). The physical slot wins that race because it reaches
  `LOADED` a few milliseconds before the eSIM, so the one-shot apply at boot was
  quietly undone hours later. The module now keeps watching and re-applies.
* The boot apply waits for `gsm.sim.state` to report `LOADED` instead of a fixed
  20 second sleep, then settles for `SETTLE_DELAY` so the framework picks its
  defaults first and we get the last word.
* `apply_sim` now verifies the result: `service call` returns success even when
  it changed nothing, which made the retry loop dead code.
* New config keys: `WATCH`, `WATCH_INTERVAL`, `VERIFY_INTERVAL`, `SETTLE_DELAY`.
* The log only records real changes and failures instead of one block per apply.

## v1.0.3

* Power key removed — only the volume keys are used.

## v1.0.2

* Installer text matches the new one-press behaviour.

## v1.0.1

* Volume Up / Volume Down now apply the SIM immediately — no Power confirmation.
* The result screen says `APPLIED` and that the window can be closed.
* Power keeps the current selection and re-applies it.

## v1.0.0

* First release.
* Applies the saved default SMS SIM on every boot.
* Action button with hardware-key selection: Vol Up = SIM 1, Vol Down = SIM 2, Power = confirm.
* Configurable sub ids and `isub` transaction code.
* Automatic updates via `updateJson`, zip built and released by GitHub Actions.
