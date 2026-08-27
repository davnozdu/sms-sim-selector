# SMS SIM Selector

KernelSU / Magisk / APatch module that sets the **default SIM for SMS** on every boot.

No app, no UI, no reboot dance — one Action button and the choice sticks.

## What it does

* Applies the saved SIM as the default for outgoing SMS after every boot.
* Lets you switch SIMs with the **Action** button in the module list, using the hardware keys.
* Stores the choice in `/data/adb/sms_sim_selector/config`, so it survives module updates.

## Usage

Open your root manager, find **SMS SIM Selector** in the module list and tap **Action**:

| Key             | Effect                                  |
|-----------------|-----------------------------------------|
| Volume **Up**   | SIM 1 (physical) — applied instantly    |
| Volume **Down** | SIM 2 (eSIM) — applied instantly        |
| **Power**       | keep the current SIM and re-apply it    |

One press is all it takes: the SIM is applied right away, the screen says
`APPLIED` and you can close the window. No confirmation step.

Default after install: **SIM 1**. The choice is re-applied on every boot.
If no key is pressed within 60 seconds the current selection is kept and applied.

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

## Configuration

`/data/adb/sms_sim_selector/config`:

```sh
SMS_SIM=1      # currently selected SIM: 1 or 2
SUB_SIM1=2     # sub id passed to `service call isub` for SIM 1
SUB_SIM2=1     # sub id passed to `service call isub` for SIM 2
ISUB_CODE=37   # transaction id of setDefaultSmsSubId
```

The transaction id differs between Android versions and vendors. If nothing changes after
applying, check the log and try a neighbouring number, or look it up in your ROM's
`ISub.aidl` ordering. You can verify the result with:

```sh
adb shell settings get global multi_sim_sms
```

## Log

```
/data/adb/sms_sim_selector/log.txt
```

Every apply is logged with the exact command, its return code and the resulting
`multi_sim_sms` value.

## Install

Download the zip from [Releases](../../releases) and flash it in KernelSU / Magisk / APatch,
or install from the module manager. Updates are delivered automatically through
`updateJson`.

## Requirements

* Android with root (KernelSU, Magisk or APatch)
* A dual-SIM (or SIM + eSIM) device

## License

MIT
