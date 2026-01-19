# Test Scenario - Smoke Test

## Purpose

Verify that the AI Web Agent system works end-to-end with the new thin client architecture.

---

## Prerequisites

1. ✅ Extension built: `npm run build`
2. ✅ Proxy server running: `cd agent-proxy && npm start`
3. ✅ Extension loaded in Chrome: `chrome://extensions` → Load unpacked → `dist/`
4. ✅ LLM API key configured in `agent-proxy/.env`

---

## Test 1: Health Check

### Steps

1. Open terminal
2. Run:
   ```bash
   curl http://localhost:3131/health
   ```

### Expected Result

```json
{
  "status": "ok",
  "model": "anthropic/claude-3.5-sonnet",
  "baseUrl": "https://openrouter.ai/api/v1",
  "timestamp": "2026-01-19T..."
}
```

### Pass Criteria
- ✅ HTTP 200 status
- ✅ `status: "ok"`
- ✅ Model name shown

---

## Test 2: Extension UI

### Steps

1. Open any website (e.g., https://example.com)
2. Click extension icon in Chrome toolbar
3. Side Panel opens

### Expected Result

- ✅ Panel opens on the right side
- ✅ "Agent Proxy" section shows `http://localhost:3131`
- ✅ Proxy Status shows "Configured ✓"
- ✅ Task input field is visible
- ✅ Start button is enabled

### Pass Criteria
- ✅ UI renders correctly
- ✅ No console errors

---

## Test 3: Proxy Connection Test

### Steps

1. In Side Panel, click **Test** button (next to proxy URL)

### Expected Result

- ✅ Message appears: "Testing connection..."
- ✅ After ~1 second: "✓ Connection successful!"

### Pass Criteria
- ✅ Green success message shown
- ✅ No errors in console

---

## Test 4: Simple Task Execution

### Steps

1. Navigate to: https://example.com
2. In Side Panel task input, enter:
   ```
   Find the link on this page and tell me what it says
   ```
3. Click **Start**

### Expected Result

**Logs should show:**
```
STARTED         - Task started on server
OBSERVE         - Executing observe...
CLICK or FINISH - (depends on LLM decision)
FINISH          - Found link: "More information..."
```

**Status should progress:**
- "Starting..." → "Running..." → "Completed"

**Step counter increments:**
- `0 / 150` → `1 / 150` → ... → `N / 150`

### Pass Criteria
- ✅ Task starts (Status: "Running...")
- ✅ Steps appear in logs
- ✅ Task completes (Status: "Completed")
- ✅ Final result makes sense
- ✅ Stop button is disabled after completion
- ✅ Start button re-enabled after completion

---

## Test 5: Multi-Step Task

### Steps

1. Navigate to: https://www.google.com
2. Enter task:
   ```
   Search for "AI autonomous agents" and tell me the first result title
   ```
3. Click **Start**

### Expected Result

**Logs should show sequence:**
```
STARTED         - Task started on server
OBSERVE         - Executing observe...
TYPE            - Executing type...
OBSERVE         - Executing observe...
FINISH          - First result: "..."
```

**Step count should reach 5-10 steps**

### Pass Criteria
- ✅ Agent types into search box
- ✅ Agent submits search
- ✅ Agent extracts result
- ✅ Agent returns final answer
- ✅ No loops detected
- ✅ Task completes successfully

---

## Test 6: Security Gate (Careful Mode)

### Steps

1. Navigate to: https://example.com
2. **Enable checkbox**: "Ask before acting (security confirmations)"
3. Enter task:
   ```
   Submit a form with test data
   ```
   (Note: example.com has no forms, so agent will likely fail, but this tests security flow)
4. Click **Start**

### Expected Result (if form found)

- ✅ Modal appears: "⚠️ Security check: ... Proceed?"
- ✅ Two buttons: "Approve" and "Deny"
- ✅ Status: "Waiting for you..."

**Click "Approve":**
- ✅ Task continues
- ✅ Log shows "USER_APPROVED"

**Click "Deny":**
- ✅ Task stops
- ✅ Status: "Stopped"

### Pass Criteria
- ✅ Security gate triggers on dangerous actions
- ✅ User can approve or deny
- ✅ Task continues/stops correctly

---

## Test 7: Stop Task

### Steps

1. Navigate to: https://www.google.com
2. Enter a long task:
   ```
   Search for "machine learning", then "deep learning", 
   then "neural networks", and summarize all results
   ```
3. Click **Start**
4. **Wait 2-3 steps**
5. Click **Stop** button

### Expected Result

- ✅ Task stops immediately
- ✅ Last log entry: "STOPPED - Task stopped by user"
- ✅ Status: "Stopped"
- ✅ Start button re-enabled

### Pass Criteria
- ✅ Stop button works
- ✅ Task doesn't continue after stop
- ✅ UI returns to idle state

---

## Test 8: Error Handling - Element Not Found

### Steps

1. Navigate to: https://example.com
2. Enter task:
   ```
   Click the button with text "Non-existent Button"
   ```
3. Click **Start**

### Expected Result

- ✅ Agent tries to find button
- ✅ Log shows error: "ELEMENT_NOT_FOUND" or similar
- ✅ Agent retries with observe
- ✅ Eventually finishes with: "Could not find button"

### Pass Criteria
- ✅ Errors handled gracefully
- ✅ Agent doesn't crash
- ✅ Task completes or errors out properly

---

## Test 9: Loop Detection

### Steps

1. Navigate to: https://example.com
2. Enter task:
   ```
   Keep clicking the same link over and over
   ```
3. Click **Start**

### Expected Result

- ✅ Agent clicks link a few times
- ✅ After 3-4 identical clicks, loop detected
- ✅ Task finishes with: "Detected action loop"
- ✅ Status: "Error" or "Completed"

### Pass Criteria
- ✅ Loop detection triggers
- ✅ Task stops automatically
- ✅ No infinite loop

---

## Test 10: Self-Reflection

### Steps

1. Navigate to: https://www.google.com
2. Enter task:
   ```
   Do a complex search and analysis (requires 10+ steps)
   ```
3. Click **Start**
4. **Watch logs carefully**

### Expected Result

- ✅ After every 5 steps, a REFLECTION log appears
- ✅ Shows efficiency: low/medium/high
- ✅ If efficiency is low 2x in row, task stops

### Pass Criteria
- ✅ Reflection logs appear every 5 steps
- ✅ Agent self-corrects when stuck
- ✅ Low efficiency triggers stop

---

## Test 11: Service Worker Restart

### Steps

1. Start a task (any simple task)
2. **While task is running**, go to `chrome://extensions`
3. Find "AI Web Agent"
4. Click **"service worker"** link to open console
5. Click **"Terminate"** (or close the console to terminate)
6. **Quickly** return to the Side Panel

### Expected Result

- ⚠️ Task may pause briefly
- ✅ Service worker restarts automatically
- ✅ Task continues OR shows error
- ✅ Server maintains run state
- ✅ Panel shows current status

### Pass Criteria
- ✅ System recovers from service worker termination
- ✅ Run state not lost (server has it)
- ✅ User sees clear status

---

## Test 12: Concurrent Runs (Multi-Tab)

### Steps

1. Open **Tab 1**: https://example.com
2. Open Side Panel, start task: "Find contact info"
3. Open **Tab 2**: https://www.google.com
4. Open Side Panel, start task: "Search for Python"
5. Observe both tabs

### Expected Result

- ✅ Each tab has separate run
- ✅ Each task executes independently
- ✅ Server handles both runs
- ✅ Logs don't mix between tabs

### Pass Criteria
- ✅ Multiple concurrent runs work
- ✅ No cross-contamination

---

## Test 13: Clear Logs

### Steps

1. Run any task (generate some logs)
2. Click **Clear Logs** button

### Expected Result

- ✅ All log entries disappear
- ✅ Empty state message: "Logs cleared. Start a task..."
- ✅ Step counter resets to `0 / 0`

### Pass Criteria
- ✅ Logs cleared
- ✅ UI resets properly

---

## Test 14: Autonomous Mode (No Security Gate)

### Steps

1. Navigate to any site with forms
2. **Uncheck**: "Ask before acting"
3. Enter task that would trigger security gate:
   ```
   Fill out the form and submit it
   ```
4. Click **Start**

### Expected Result

- ✅ No security modal appears
- ✅ Agent executes actions directly
- ✅ Warnings logged in server console (not shown to user)
- ✅ Task completes faster

### Pass Criteria
- ✅ Autonomous mode works
- ✅ No blocking confirmations
- ✅ Server logs warnings

---

## Test 15: Chrome:// Page Handling

### Steps

1. Navigate to: `chrome://extensions`
2. Open Side Panel
3. Enter any task: "Click something"
4. Click **Start**

### Expected Result

- ✅ Error message: "Cannot execute actions on chrome:// pages"
- ✅ Task stops immediately
- ✅ User instructed to navigate to regular website

### Pass Criteria
- ✅ Clear error message
- ✅ Agent doesn't attempt impossible actions

---

## Summary Checklist

Before considering the system "working":

- [ ] Test 1: Health Check ✓
- [ ] Test 2: Extension UI ✓
- [ ] Test 3: Proxy Connection ✓
- [ ] Test 4: Simple Task ✓
- [ ] Test 5: Multi-Step Task ✓
- [ ] Test 6: Security Gate ✓
- [ ] Test 7: Stop Task ✓
- [ ] Test 8: Error Handling ✓
- [ ] Test 9: Loop Detection ✓
- [ ] Test 10: Self-Reflection ✓
- [ ] Test 11: Service Worker Restart ✓
- [ ] Test 12: Concurrent Runs ✓
- [ ] Test 13: Clear Logs ✓
- [ ] Test 14: Autonomous Mode ✓
- [ ] Test 15: Chrome:// Pages ✓

---

## Common Issues

### Task Doesn't Start
- Check proxy server is running
- Check browser console for errors
- Verify API key in `.env`

### Agent Does Nothing
- Wait 3-5 seconds (LLM call takes time)
- Check server logs for LLM errors
- Verify page is fully loaded

### Elements Not Found
- Some sites have dynamic content
- Agent will retry automatically
- May need to increase wait times

### Loop Detection Too Sensitive
- Adjust thresholds in `agent-proxy/src/agentLogic.ts`
- Increase MAX_LOOP_DETECTION or pattern limits

---

## Performance Benchmarks

### Expected Timings

- **Health check**: < 100ms
- **UI load**: < 500ms
- **Simple task** (3 steps): 10-15 seconds
- **Multi-step task** (10 steps): 30-60 seconds
- **Complex task** (20+ steps): 1-3 minutes

### Resource Usage

- **Extension**: < 50 MB RAM
- **Proxy Server**: 100-200 MB RAM
- **Per Run**: ~5-10 MB additional

---

## Debugging

### Extension Logs
```
chrome://extensions → service worker → Console
```

### Server Logs
```
Terminal where `npm start` is running
```

### Content Script Logs
```
Open page → F12 → Console
```

### Network Requests
```
F12 → Network tab → Filter: localhost:3131
```

---

## Success Criteria

✅ **System is working if:**
1. All 15 tests pass
2. Simple tasks complete in < 20 seconds
3. Multi-step tasks complete without loops
4. Security gate works in careful mode
5. Service worker restart doesn't break tasks
6. Concurrent runs work
7. Errors handled gracefully

---

**Run these tests after any major changes to verify system integrity.** 🧪
