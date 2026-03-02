# PropMarshal — Drawdown Protection EA for MetaTrader 4/5

**The only drawdown guardian that stops your other EAs from digging you deeper.**

PropMarshal monitors your account equity in real time and instantly closes all positions the moment a drawdown or profit target threshold is breached. But it doesn't stop there — it closes every chart on your platform too, cutting off any other Expert Advisors before they can open new trades and compound the damage.

---

## The Problem PropMarshal Solves

Most prop firm traders run multiple EAs across multiple charts. When a drawdown limit is hit, the typical approach is to close all open positions — but that leaves the other EAs still running. They don't know the limit was hit. They just keep doing their job: scanning for setups and opening new trades. Each new trade is another loss you're absorbing while already over the line.

**PropMarshal closes the charts, not just the trades.**

When protection triggers:

1. All open positions are closed immediately with market orders
2. All pending orders are cancelled
3. Every chart on the platform is closed — taking every running EA with it
4. Each closed chart is saved as a template so your setup isn't lost
5. A **Restore Charts** button appears on the PropMarshal panel so you can bring everything back with one click when you're ready

For daily drawdown breaches, PropMarshal automatically reopens your charts at the start of the next trading day — no manual action needed.

> ⚠️ **Why this matters:** If charts stay open, other EAs will keep opening positions. PropMarshal will catch and close those too, but each cycle creates a small additional loss. With enough EAs running, those micro-losses can push you further over the limit. Closing the charts eliminates the problem entirely.

---

## Features

- **Daily Drawdown Protection** — tracks loss from the start of each trading day, resets automatically at your configured GMT offset
- **Static (Max) Drawdown Protection** — monitors total drawdown from initial balance; mirrors the absolute max loss rule common in most prop firm challenges
- **Trailing Drawdown Protection** — tracks the highest equity watermark achieved and protects a configurable percentage from the peak; directly replicates how many prop firms calculate trailing drawdown
- **Profit Target Close-Out** — optionally closes all trades when a profit goal is reached, locking in a passing result and preventing overtrading
- **Recovery Buffer** — applies a configurable safety margin before the hard limit, giving you an early-warning zone and reducing the chance of cutting too close
- **Real-Time Dashboard** — an on-chart panel shows live drawdown progress per module with colour-coded status (green → yellow → orange → red) so you always know where you stand
- **Multi-Channel Alerts** — configurable per module: pop-up alert, push notification, email, or all three at once
- **State Persistence** — daily baseline, peak equity, and last reset time are saved via global variables and survive platform restarts

---

## How Protection Triggers

PropMarshal checks your account equity on every tick and every second via a timer. When any active threshold is breached, it fires in this priority order:

1. Daily Drawdown
2. Trailing Drawdown
3. Static Drawdown
4. Profit Target

Once triggered: positions closed → pending orders cancelled → alerts sent → charts closed (if enabled).

---

## Compatibility

- MetaTrader 5 only (MQL5)
- Works with any broker, any account type
- Works alongside any other EA — PropMarshal never places trades of its own
- No DLL dependencies

---

## Settings Reference

### Shared Settings

Three settings appear in every protection module (Daily Drawdown, Static Drawdown, Trailing Drawdown, and Profit Target) and work the same way across all of them.

**Mode** — Default: `Percentage (%)`

Controls how the threshold is measured. `Percentage (%)` expresses the limit as a percentage of the relevant baseline (opening day balance, initial balance, or peak equity). `Currency Amount` uses a fixed monetary value in your account currency — useful when your prop firm states a hard dollar or euro figure rather than a percentage. Setting mode to `Disabled`, or setting the limit to `0`, turns that module off entirely.

**Limit** — Default: `0` (disabled)

The threshold value for that module, interpreted according to the mode above. For example, `5` in percentage mode means 5%. Set to `0` to disable the module.

**Alert type** — Default: `Everything`

What notifications are sent when the threshold is breached. `Nothing` sends no notification but protection still triggers. `Alert` shows a MetaTrader pop-up on screen. `Alert & Notification` adds a mobile push notification (requires the MetaTrader mobile app to be configured). `Alert & Email` adds an email (requires email to be configured in MetaTrader settings). `Everything` fires all three simultaneously.

---

### Initial Balance

**Initial balance** — Default: `0`

The starting balance used as the baseline for static drawdown and profit target calculations. Set this to your challenge starting balance (e.g. `100000`). When left at `0`, the EA uses the current account balance at startup — **not recommended**, as restarting the EA mid-challenge will reset the baseline to the current balance rather than the original starting value, making all subsequent calculations incorrect.

---

### Recovery Buffer

The recovery buffer shrinks your effective drawdown limit by a configurable margin, so protection triggers slightly before the hard prop firm rule would be hit. For example, with a 5% daily drawdown limit and a 15% recovery buffer, PropMarshal triggers at 4.25% — giving you a cushion.

**Recovery buffer mode** — Default: `Percentage (%)`

Whether the buffer is expressed as a percentage of the configured limit or as a fixed currency amount. Set to `Disabled` to turn the buffer off entirely.

**Recovery buffer** — Default: `15`

The size of the buffer. At the default of `15`, each limit is reduced by 15% of its configured value. Set to `0` to disable.

---

### Daily Drawdown

Measures loss from the start of the current trading day. The baseline — the balance or equity recorded at the open of the day — resets automatically at midnight in your configured timezone.

Uses the shared **Mode**, **Limit**, and **Alert type** settings described above.

**Daily reset GMT offset** — Default: `2`

The hour offset from GMT used to determine when a new trading day begins. Set this to match your broker's server time offset so the daily baseline resets at the correct time.

---

### Static Drawdown

Measures total loss from the initial balance. This is the "maximum drawdown" rule that most prop firms enforce — if your account ever falls more than X% below the starting balance, the challenge is failed.

Uses the shared **Mode**, **Limit**, and **Alert type** settings described above.

---

### Trailing Drawdown

Tracks the highest equity value your account has ever reached and measures drawdown from that peak. The watermark moves up as your account grows but never comes back down. This mirrors the trailing drawdown rules used by many prop firms where your maximum loss floor rises as your profits increase.

Uses the shared **Mode**, **Limit**, and **Alert type** settings described above.

---

### Profit Target

Automatically closes all trades when a profit goal is reached. Useful for locking in a challenge pass without risking a pullback that could invalidate the account.

Uses the shared **Mode**, **Limit**, and **Alert type** settings described above. In this module, the limit represents a profit goal rather than a loss threshold — for example, `10` in percentage mode means close everything when the account is up 10% from the initial balance.

---

### Close Charts

This is PropMarshal's most important protection layer. Closing charts ensures no other EA can open a new position after the drawdown limit has been hit.

**Close all charts when drawdown is triggered** — Default: `true`

**Strongly recommended to leave enabled.** When `true`, every chart except PropMarshal's own is closed the moment protection triggers. Each chart's layout is saved as a named template beforehand. A **Restore Charts** button appears on the dashboard so you can reopen everything when you're ready to trade again. If the closure was triggered by a daily drawdown, charts reopen automatically at the next daily reset.

When set to `false`, only trades are closed — all other EAs remain running on their charts and will continue to look for entries. PropMarshal will catch and close each new position they open, but every cycle adds a small loss. With multiple EAs running, these micro-losses accumulate and can push the account further over the limit than the initial breach alone.
