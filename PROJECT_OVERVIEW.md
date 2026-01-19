# AI Web Agent - Project Overview

## What Is This?

An **autonomous AI agent** that automates web browsing tasks in Chrome. The agent can navigate websites, click buttons, fill forms, extract data, and complete multi-step tasks based on natural language instructions.

## Key Features

- 🤖 **Autonomous Operation**: Agent makes decisions and executes actions without constant supervision
- 🛡️ **Security Gate**: Prevents destructive actions (payments, deletions) with user confirmation
- 🔄 **Self-Reflection**: Analyzes its own performance every 5 steps and adjusts strategy
- 🚫 **Loop Detection**: Automatically stops when repeating failed actions
- 📊 **Real-time Logs**: See every step the agent takes in the Side Panel UI
- 🌐 **Universal**: Works on any website without hardcoded selectors

## Architecture

### Two-Part Design

The project follows a **thin client** architecture optimized for Chrome Extension Manifest V3:

1. **Extension (Thin Client)**
   - Side Panel UI for user interaction
   - Service Worker as thin executor (no long-running loops)
   - Content Script for DOM automation
   - Sends tasks to server, executes actions, returns results

2. **Proxy Server (Brain)**
   - Agent loop and state machine
   - LLM integration (decision making)
   - Security gate logic
   - Loop detection and self-reflection
   - Run management (create, step, cancel)

### Why This Architecture?

**Manifest V3 Limitation**: Service workers can be terminated at any time by Chrome. Running a long agent loop in the extension would fail.

**Solution**: Move the agent brain to a persistent Node.js server. Extension becomes a thin client that:
- Receives "next action" from server
- Executes it in the browser
- Sends result back
- Repeats until task completes

## Technology Stack

### Extension
- **Language**: TypeScript
- **Platform**: Chrome Extension Manifest V3
- **APIs**: chrome.tabs, chrome.scripting, chrome.sidePanel, chrome.storage
- **Build**: Webpack

### Proxy Server
- **Runtime**: Node.js
- **Framework**: Express
- **Language**: TypeScript
- **LLM Providers**: OpenRouter, OpenAI, GigaChat, Groq

## How It Works

### 1. User Starts Task
```
User enters task in Side Panel
  ↓
Extension calls POST /agent/run/start
  ↓
Server creates run with unique runId
  ↓
Extension receives runId and begins execution
```

### 2. Execution Loop
```
Extension gets page snapshot (observe)
  ↓
Extension calls POST /agent/run/:runId/step with snapshot
  ↓
Server:
  - Analyzes snapshot
  - Asks LLM for next action
  - Checks security gate
  - Detects loops
  - Performs self-reflection
  ↓
Server returns next action (tool call, ask_user, or finish)
  ↓
Extension executes action in browser
  ↓
Extension sends result back to server
  ↓
Repeat until finish or error
```

### 3. Task Completion
```
Server returns finish action
  ↓
Extension shows final result
  ↓
Run is marked as completed
```

## Agent Tools

The agent has access to these tools to interact with web pages:

| Tool | Description | Example |
|------|-------------|---------|
| `observe()` | Get page snapshot (URL, title, text, elements) | Agent sees current page state |
| `navigate(url)` | Go to a URL | `navigate("https://example.com")` |
| `click(id)` | Click an element | `click("button-login")` |
| `type(id, text, submit?)` | Type into input field | `type("search-input", "AI agent", true)` |
| `scroll(deltaY)` | Scroll page | `scroll(500)` - scroll down 500px |
| `press(key)` | Press keyboard key | `press("Enter")` |
| `ask_user(question)` | Ask user for input | `ask_user("Which option to choose?")` |
| `finish(result)` | Complete task with result | `finish("Found 3 items")` |

## Security Features

### Security Gate (Careful Mode)

Blocks potentially dangerous actions and asks for user confirmation:

- **URL patterns**: `checkout`, `payment`, `bank`, `cart`
- **Button text**: `Pay`, `Buy`, `Delete`, `Submit`, `Remove`
- **Form submission**: Any form submit action

### Autonomous Mode

Security gate only logs warnings but doesn't block actions. Useful for trusted websites.

## Self-Reflection

Every 5 steps, the agent analyzes its own performance:

```typescript
Reflection {
  efficiency: 'low' | 'medium' | 'high',
  issues: [
    "Too many observe() calls without action",
    "High error rate"
  ],
  suggestions: [
    "Stop observing and take action immediately",
    "Try different approach"
  ]
}
```

If efficiency is low 2 times in a row, agent stops to prevent wasting resources.

## Loop Detection

Prevents infinite loops by tracking recent actions:

- **3 identical actions in a row**: Stop
- **3+ observe() without other actions**: Stop  
- **5 same actions in last 7 steps**: Stop

## Limitations

- **Max steps**: 150 per task (configurable)
- **Visible text**: Limited to ~6000 characters per snapshot
- **Interactive elements**: Max 100 per snapshot
- **Chrome:// pages**: Cannot interact with browser internal pages
- **Service worker lifecycle**: Extension can be unloaded by Chrome (server maintains state)

## Use Cases

### ✅ Good Use Cases
- Extract data from websites (prices, contact info, job listings)
- Fill forms with test data
- Navigate multi-step flows (search → filter → extract results)
- Monitor website changes
- Automated testing of web apps

### ❌ Not Recommended
- Financial transactions (payments, trading)
- Deleting important data
- Tasks requiring CAPTCHA solving
- Actions on pages with complex JavaScript frameworks (may work but unreliable)

## Example Tasks

### Simple
```
"Find contact information on this page"
"Click the pricing button and show me the plans"
```

### Multi-step
```
"Go to hh.ru, search for Python developer jobs in Moscow, show me top 3 results"
"Find iPhone 14 on Avito, filter by price under 50000, show first 5 listings"
```

### Complex
```
"Navigate to hh.ru, search for 'AI engineer' with salary > 200000, 
apply location filter to Moscow, extract first 5 job titles, 
companies, and salary ranges"
```

## Project Status

**Current Version**: 2.0  
**Status**: ✅ Production Ready

### Implemented
- ✅ Thin client architecture (MV3 compatible)
- ✅ Run/Step protocol
- ✅ Agent loop on server
- ✅ Security gate (careful/autonomous modes)
- ✅ Self-reflection pattern
- ✅ Loop detection (3 strategies)
- ✅ 8 agent tools
- ✅ Real-time logs
- ✅ User confirmation flow
- ✅ Automatic content script injection

### Future Enhancements
- [ ] Persistent storage (database for runs)
- [ ] Multi-tab support
- [ ] Screenshot analysis (vision)
- [ ] Browser action recording/playback
- [ ] Collaborative runs (multiple users)
- [ ] Run analytics and metrics

## Getting Started

See [README.md](README.md) for installation and usage instructions.

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical architecture details.

See [API.md](API.md) for API documentation.
