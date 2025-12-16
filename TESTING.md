# Testing the Breakout EA

Use these steps to validate breakout entries and session behaviour in MetaTrader 5. All checks use demo data and the MT5 Strategy Tester unless otherwise noted.

## Prerequisites
- Install the EA on a chart with tick-mode backtesting enabled.
- Set `DebugOn=true` to view diagnostic `Print` statements.
- Confirm broker symbol suffix/prefix matches the EA input symbol.
- Ensure the news calendar is available if `UseNewsFilter` is true; otherwise disable it for tests.

## Test matrix
Run the following scenarios for each session (Daily, London, Asia) and both BUY/SELL directions:
1. **Baseline breakout near level**
   - Configure `EntryTolerancePoints` to a small value (e.g., 10).
   - Place the range high/low so that price crosses within the tolerance.
   - **Expect:** A single market order opens when price is within tolerance; `buyFired`/`sellFired` for that session set to true; level deactivates after entry.

2. **Reject far breakout**
   - Set `EntryTolerancePoints` small (e.g., 5) and move price to cross more than the tolerance away.
   - **Expect:** No order opens; debug logs show tolerance rejection.

3. **Duplicate-entry guard across sessions**
   - Open a manual BUY (or SELL) on the same symbol before the test run.
   - Allow another session to trigger the same direction signal.
   - **Expect:** No additional order opens in that direction; logs note existing symbol exposure.

4. **Session window expiry without trade**
   - Let a session’s close time arrive without triggering an entry.
   - **Expect:** Session levels deactivate; subsequent crosses after close do not trade.

5. **Session deactivation after fill**
   - Trigger a valid entry and keep price hovering around the level.
   - **Expect:** Only the first trade fires; no repeat orders from the same or other sessions in the same direction.

6. **Spread/news gating (regression)**
   - Increase spread or schedule blocked news events.
   - **Expect:** Entries are skipped while filters block trading; once filters clear and price re-tests within tolerance, a single valid entry occurs.

## Reporting
Capture Strategy Tester logs/screenshots showing whether each expectation was met. Include symbol, timeframe, inputs, and the exact `EntryTolerancePoints` used.
