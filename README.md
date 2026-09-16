# SMS SIM Selector

KernelSU / Magisk / APatch module that keeps the **default SIM for SMS** on your choice.

No app, no UI, no reboot dance — one Action button and the choice sticks.

## What it does

* Applies the saved SIM as the default for outgoing SMS once the SIMs are up after boot.
* Re-applies it whenever the system overwrites it — see [Why the watcher exists](#why-the-watcher-exists).
* Lets you switch SIMs with the **Action** button in the module list, using the hardware keys.
* Stores the choice in `/data/adb/sms_sim_selector/config`, so it survives module updates.

## Usage

Open your root manager, find **SMS SIM Selector** in the module list and tap **Action**:

| Key             | Effect                                  |
|-----------------|-----------------------------------------|
| Volume **Up**   | SIM 1 (physical) — applied instantly    |
| Volume **Down** | SIM 2 (eSIM) — applied instantly        |

One press is all it takes: the SIM is applied right away, the screen says
`APPLIED` and you can close the window. No confirmation step.

Default after install: **SIM 1**. The choice is kept applied from then on.
If no key is pressed within 60 seconds the current selection is kept and applied.

## Why the watcher exists

Applying the choice once at boot is not enough. The framework re-picks the
default SMS subscription every time the SIMs are re-initialised — a modem
restart, an eSIM refresh, a carrier config reload, a restart of
`com.android.phone`. The physical slot wins that race because it reaches
`LOADED` a few milliseconds before the eSIM:

```
07:57:09.948 - updateSimState: slot 0 LOADED          <- physical SIM, sub 2
07:57:10.022 - Default SMS subId changed from 1 to 2  <- our choice is gone
07:57:10.031 - updateSimState: slot 1 LOADED          <- eSIM, sub 1
```

It happens once more on every boot, about a minute in, when you unlock the
device: the credential encrypted storage becomes available, `SIM_STATE_CHANGED`
is delivered again and the framework repeats the same choice — right when you
pick the phone up, which is why it looks like the module "forgot" your setting
during boot.

Nothing is wrong with the saved config when this happens — only the applied
system value is overwritten. So the module stays resident: it reacts to SIM
state changes and to the first unlock, verifies the system value every
`WATCH_INTERVAL` seconds for the first `BOOT_GUARD` seconds after boot and every
`VERIFY_INTERVAL` seconds afterwards, and puts the choice back when something
else has changed it.

The flip side: while the watcher runs, changing the default SMS SIM in the system
settings will be reverted within a minute. Use Action to change it, or set
`WATCH=0` to go back to the apply-once-at-boot behaviour.

## How it works

Under the hood the module calls the telephony service directly:

```sh
# SIM 2 (eSIM)
service call isub 37 i32 1

# SIM 1 (physical)
service call isub 37 i32 2
```

`37` is the transaction id of `setDefaultSmsSubId` on the tested ROM, and `i32 <n>` is the
subscription id. Both are configurable — see below.

`service call` reports success even when it changed nothing, so every apply is
verified against `settings get global multi_sim_sms` and retried if it did not stick.

## Configuration

`/data/adb/sms_sim_selector/config`:

```sh
SMS_SIM=1            # currently selected SIM: 1 or 2
SUB_SIM1=2           # sub id passed to `service call isub` for SIM 1
SUB_SIM2=1           # sub id passed to `service call isub` for SIM 2
ISUB_CODE=37         # transaction id of setDefaultSmsSubId
WATCH=1              # 1 = keep re-applying, 0 = apply once at boot only
WATCH_INTERVAL=10    # seconds between two cheap SIM state checks
VERIFY_INTERVAL=60   # seconds between two full checks of the system value
SETTLE_DELAY=15      # seconds to wait after the SIMs load, so we get the last word
BOOT_GUARD=600       # seconds after boot with WATCH_INTERVAL verification
```

The transaction id differs between Android versions and vendors. If nothing changes after
applying, check the log and try a neighbouring number, or look it up in your ROM's
`ISub.aidl` ordering. You can verify the result with:

```sh
adb shell settings get global multi_sim_sms
```

`VERIFY_INTERVAL` is how long the wrong SIM can stay selected after the system
overwrote the choice, once the `BOOT_GUARD` window has passed. Lower it if that
matters, at the cost of more wakeups.

## Log

```
/data/adb/sms_sim_selector/log.txt
```

Only real changes and failures are logged — a quiet log means nothing has been
overwriting your choice.

If applying keeps failing, the watcher stops after 10 consecutive attempts and
says so in the log — that usually means `ISUB_CODE` is wrong for your ROM.

## Install

Download the zip from [Releases](../../releases) and flash it in KernelSU / Magisk / APatch,
or install from the module manager. Updates are delivered automatically through
`updateJson`.

## Requirements

* Android with root (KernelSU, Magisk or APatch)
* A dual-SIM (or SIM + eSIM) device

## License

MIT
