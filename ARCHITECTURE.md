# Architecture Documentation

## Overview

AI Web Agent uses a **thin client architecture** optimized for Chrome Extension Manifest V3 limitations.

### Key Design Decision

**Problem**: Chrome MV3 service workers can be terminated at any time, making long-running agent loops impossible.

**Solution**: Move the agent brain (state machine, decision loop, LLM integration) to a persistent Node.js server. The extension becomes a thin client that executes actions.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Chrome Extension                         │
│                         (Thin Client)                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐  │
│  │  Side Panel  │  │   Service    │  │  Content Script     │  │
│  │     (UI)     │◄─┤   Worker     │◄─┤  (DOM Automation)   │  │
│  └──────────────┘  └──────────────┘  └─────────────────────┘  │
│         │                 │                      │               │
│         └─────────────────┼──────────────────────┘               │
│                           │                                       │
└───────────────────────────┼───────────────────────────────────────┘
                            │ HTTP/JSON
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Proxy Server (Brain)                        │
│                      Node.js + Express                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐  │
│  │  Run Manager │◄─┤ Agent Logic  │◄─┤   LLM Client        │  │
│  │   (State)    │  │ (Decision)   │  │  (OpenRouter/etc)   │  │
│  └──────────────┘  └──────────────┘  └─────────────────────┘  │
│         │                 │                      │               │
│         │                 ├─ Security Gate       │               │
│         │                 ├─ Loop Detection      │               │
│         │                 └─ Self-Reflection     │               │
│         │                                        │               │
└─────────┼────────────────────────────────────────┼───────────────┘
          │                                        │
          └─ In-Memory State (runs Map)           └─ LLM API
```

---

## Component Details

### 1. Side Panel (UI)

**Location**: `src/panel/`

**Responsibilities:**
- Display task input and controls
- Show real-time logs
- Handle user questions/confirmations
- Proxy URL configuration

**Key Features:**
- Real-time status updates
- Step-by-step log display
- User interaction modal
- Proxy connection testing

**Communication:**
- Sends messages to Service Worker
- Receives broadcast messages about run state

---

### 2. Service Worker (Thin Executor)

**Location**: `src/background/serviceWorker.ts`

**Responsibilities:**
- Start/stop tasks via server API
- Execute one tool action at a time
- Send results back to server
- Broadcast updates to UI
- Manage minimal local state (current runId only)

**Key Features:**
- No long-running loops (MV3 safe)
- Automatic content script injection
- Navigation handling
- Message routing

**API Calls:**
```typescript
POST /agent/run/start           // Start task
POST /agent/run/:runId/step     // Get next action
POST /agent/run/:runId/answer   // User response
POST /agent/run/:runId/cancel   // Stop task
```

**State:**
```typescript
{
  currentRunId: string | null,
  proxyUrl: string,
  isExecuting: boolean
}
```

**Important**: Service worker can be terminated by Chrome at any time. All persistent state lives on server.

---

### 3. Content Script (DOM Automation)

**Location**: `src/content/contentScript.ts`

**Responsibilities:**
- Observe page (snapshot generation)
- Execute DOM actions (click, type, scroll)
- Assign `data-agent-id` to elements
- Return structured results

**Tools Implemented:**
```typescript
observe()                          // Get page snapshot
click(id)                         // Click element
type(id, text, submit?)           // Type into input
scroll(deltaY)                    // Scroll page
press(key)                        // Press keyboard key
```

**Snapshot Strategy:**
- Visible text: ~6000 chars max
- Interactive elements: 100 max
- Element info: id, tag, role, text, aria-label, bbox, etc.
- No hardcoded selectors - agent chooses by description

**Element Selection:**
```typescript
// Assign unique IDs to interactive elements
getOrAssignId(element) → "agent-1", "agent-2", etc.

// Extract element metadata
{
  id: "agent-1",
  tag: "button",
  text: "Sign In",
  ariaLabel: "Sign in to your account",
  bbox: { x: 100, y: 200, width: 80, height: 40 }
}
```

---

### 4. Proxy Server

**Location**: `agent-proxy/`

**Responsibilities:**
- Maintain run state (in-memory Map)
- Execute agent decision loop
- Integrate with LLM
- Security gate enforcement
- Loop detection
- Self-reflection analysis

#### 4.1 Run Manager

**File**: `src/runManager.ts`

**Functions:**
```typescript
startRun(task, mode)              // Create new run
executeStep(runId, snapshot, result) // Execute one step
handleUserAnswer(runId, approved) // Process user response
cancelRun(runId)                  // Cancel run
getRunState(runId)                // Get full state
```

**Run State:**
```typescript
{
  runId: string,
  task: string,
  mode: 'autonomous' | 'careful',
  status: RunStatus,
  currentStep: number,
  maxSteps: number,
  history: AgentStep[],
  reflections: Reflection[],
  currentSnapshot: PageSnapshot | null,
  pendingQuestion?: string,
  createdAt: number,
  updatedAt: number
}
```

#### 4.2 Agent Logic

**File**: `src/agentLogic.ts`

**Functions:**
```typescript
getNextAction(run, llmClient)     // Decide next action
analyzeProgress(run)              // Self-reflection
checkSecurityGate(tool, snapshot) // Security check
isLooping(runId, action)          // Loop detection
```

**Decision Flow:**
```
1. Check if max steps reached → finish
2. Ask LLM for next action
3. Check for action loops → finish if detected
4. Check security gate (careful mode only)
   - Blocked → ask_user
   - Allowed → execute_tool
5. Perform self-reflection every 5 steps
   - Low efficiency 2x in row → finish
6. Return action to execute
```

**Security Gate Logic:**
```typescript
// Check URL patterns
if (url.includes('checkout') || url.includes('payment')) {
  block();
}

// Check button text
if (buttonText.includes('pay') || buttonText.includes('buy')) {
  block();
}

// Check form submit
if (tool === 'type' && submit === true) {
  block();
}
```

**Loop Detection:**
```typescript
// Pattern 1: Same action 3x in row
['observe', 'observe', 'observe'] → STOP

// Pattern 2: Same action 4x in 4 steps
['click', 'click', 'click', 'click'] → STOP

// Pattern 3: Same action 5x in 7 steps
['click', 'type', 'click', 'type', 'click', 'type', 'click'] → STOP
```

**Self-Reflection:**
```typescript
Every 5 steps:
1. Count: observes, errors, successes
2. Check action diversity
3. Calculate efficiency: low/medium/high
4. Identify issues
5. Generate suggestions
6. Pass to LLM in next prompt

If low efficiency 2 times in row → STOP
```

#### 4.3 LLM Client

**File**: `src/llmClient.ts`

**Responsibilities:**
- Format prompts (task + history + snapshot)
- Call LLM API
- Parse responses (tool calls)
- Retry on failure (2 attempts)

**Providers Supported:**
- OpenRouter (recommended)
- OpenAI
- GigaChat (Sber, with OAuth2)
- Groq

**Prompt Structure:**
```
SYSTEM_PROMPT: You are an autonomous web agent...

USER_PROMPT:
TASK: {task}

RECENT HISTORY:
Step 1: observe → Success
Step 2: click → Clicked button
...

CURRENT PAGE:
URL: https://example.com
Title: Example Domain
Visible Text: This domain is for use...
Interactive Elements (10):
[agent-1] button text="Sign In"
[agent-2] input type="text" placeholder="Search"
...

Respond with ONLY valid JSON.
```

**Response Parsing:**
```typescript
// Tool call format
{
  "type": "tool_call",
  "tool": {
    "name": "click",
    "arguments": { "id": "agent-1" }
  }
}

// Finish format
{
  "type": "final",
  "answer": "Task completed. Found 3 items."
}

// Ask user format
{
  "type": "ask_user",
  "question": "Which option should I choose?"
}
```

---

## Data Flow

### Starting a Task

```
┌─────────┐        ┌──────────┐        ┌────────┐
│  User   │───1───▶│  Panel   │───2───▶│Service │
└─────────┘        └──────────┘        │ Worker │
                                        └────┬───┘
                                             │3
                   ┌──────────┐              │
                   │  Server  │◀─────────────┘
                   └────┬─────┘
                        │4
                   ┌────▼────┐
                   │Run State│
                   └─────────┘
```

1. User enters task and clicks Start
2. Panel sends START_TASK to Service Worker
3. Service Worker calls POST /agent/run/start
4. Server creates run with unique runId

### Execution Loop

```
┌────────┐     ┌───────┐     ┌────────┐     ┌──────┐
│Service │────▶│Content│────▶│Service │────▶│Server│
│ Worker │  1  │Script │  2  │ Worker │  3  │      │
└────────┘     └───────┘     └────────┘     └──┬───┘
    ▲                                           │4
    │                                           ▼
    │                                      ┌─────────┐
    │6                                     │   LLM   │
    │                                      └─────────┘
    │                                           │5
    │         ┌───────┐                         │
    └─────────┤Content│◀────────────────────────┘
          7   │Script │  Execute Tool
              └───────┘
```

1. Service Worker requests snapshot from Content Script
2. Content Script sends snapshot back
3. Service Worker sends snapshot to Server (/step)
4. Server asks LLM for next action
5. LLM returns tool call
6. Server sends tool call to Service Worker
7. Service Worker executes tool via Content Script
8. Loop continues until finish/error

### User Confirmation Flow

```
┌──────┐     ┌──────┐     ┌────────┐     ┌──────┐
│Server│────▶│Service│────▶│ Panel  │────▶│ User │
│      │  1  │Worker │  2  │        │  3  │      │
└──────┘     └───────┘     └────────┘     └───┬──┘
   ▲                                           │4
   │                                           ▼
   │         ┌────────┐      ┌───────┐    ┌──────┐
   └─────────┤Service │◀─────┤ Panel │◀───┤Approve│
         6   │ Worker │   5  │       │    └──────┘
             └────────┘      └───────┘
```

1. Server detects security issue → ask_user
2. Service Worker receives question
3. Panel shows modal to user
4. User clicks Approve/Deny
5. Panel sends response to Service Worker
6. Service Worker sends to Server (/answer)
7. Continue execution or cancel

---

## State Management

### Extension State (Minimal)

Stored in Service Worker memory (can be lost):
```typescript
{
  currentRunId: string | null,  // Active run ID
  proxyUrl: string,              // Server URL
  isExecuting: boolean           // Execution lock
}
```

Stored in chrome.storage.local (persistent):
```typescript
{
  proxyUrl: string  // User configuration
}
```

### Server State (Authoritative)

Stored in-memory Map (production needs database):
```typescript
runs: Map<runId, RunState>

RunState {
  runId, task, mode, status,
  currentStep, maxSteps,
  history: AgentStep[],
  reflections: Reflection[],
  currentSnapshot,
  pendingQuestion,
  createdAt, updatedAt
}
```

**Cleanup**: Old runs (>1 hour) are automatically deleted.

---

## Error Handling

### Extension Errors

```typescript
try {
  await executeTool(tool);
} catch (error) {
  // Try to inject content script
  await injectContentScript();
  await executeTool(tool);  // Retry once
}
```

### Server Errors

```typescript
try {
  const action = await getNextAction();
} catch (error) {
  // Log error
  // Mark run as error
  // Return error action to extension
  return { action: 'error', error: error.message };
}
```

### LLM Errors

```typescript
// Retry logic (2 attempts)
async function chat(request, retries = 2) {
  try {
    return await fetchLLM(request);
  } catch (error) {
    if (retries > 0) {
      return await chat(request, retries - 1);
    }
    throw error;
  }
}
```

---

## Security Considerations

### Extension Security

- ✅ No remote code execution
- ✅ Content Security Policy enforced
- ✅ Only communicates with configured proxy URL
- ✅ Cannot act on chrome:// pages
- ✅ Requires user permission for each site

### Server Security

- ⚠️ Currently no authentication (local only)
- ⚠️ No rate limiting
- ⚠️ In-memory state (no persistence)

**For Production:**
- Add API key authentication
- Restrict CORS to specific extension IDs
- Add rate limiting
- Use database for runs
- Add request signing
- Deploy with HTTPS

### Security Gate

- Checks URL patterns and button text
- Blocks in "careful" mode
- Logs warnings in "autonomous" mode
- User confirmation required for blocked actions

---

## Performance

### Extension Performance

- Thin client: minimal CPU usage
- No long-running loops
- Fast DOM actions (< 500ms per action)
- Automatic script injection (no manual refresh)

### Server Performance

- In-memory state: fast access
- LLM calls: 1-5 seconds per step
- Concurrent runs supported (multiple tabs)
- Auto-cleanup of old runs

### Optimization Strategies

1. **Snapshot Size**: Limited to 6K text + 100 elements
2. **History Compression**: Only last 20 steps sent to LLM
3. **Loop Detection**: Stops wasteful retries early
4. **Self-Reflection**: Prevents low-efficiency runs

---

## Scalability

### Current Limitations

- In-memory state (single server instance)
- No distributed locking
- No persistent storage
- Limited to ~100 concurrent runs

### Scaling Strategies

1. **Add Database**: PostgreSQL/MongoDB for run state
2. **Add Redis**: For distributed locking and caching
3. **Add Queue**: Bull/RabbitMQ for async processing
4. **Horizontal Scaling**: Multiple server instances
5. **Load Balancer**: Distribute requests

---

## Testing Strategy

### Unit Tests
- Agent logic (loop detection, security gate)
- LLM client (response parsing)
- Run manager (state transitions)

### Integration Tests
- Server API endpoints
- Extension↔Server communication

### E2E Tests
- Full task execution
- User confirmation flow
- Error handling

See `test-scenario.md` for smoke test procedure.

---

## Monitoring & Logging

### Extension Logs
```javascript
// Service Worker Console
console.log('[ServiceWorker] Started run', runId);

// Content Script Console
console.log('[ContentScript] Clicked element', id);

// Panel Console
console.log('[Panel] Received step result', action);
```

### Server Logs
```javascript
console.log('[Run Start] Created runId:', task);
console.log('[Run Step] runId - Action:', action);
console.log('[Agent Logic] Reflection:', reflection);
```

### Production Monitoring

Recommended tools:
- **Logs**: Winston + Elasticsearch
- **Metrics**: Prometheus + Grafana
- **Tracing**: Jaeger
- **Errors**: Sentry

---

## Deployment

### Development

```bash
# Extension
npm run build

# Server
cd agent-proxy
npm start
```

### Production

**Extension:**
- Build: `npm run build`
- Upload to Chrome Web Store
- Review process (~1-2 days)

**Server:**
- Deploy to VPS/cloud (DigitalOcean, AWS, etc.)
- Use PM2 for process management
- Configure HTTPS (Let's Encrypt)
- Set up monitoring
- Configure firewall
- Add authentication

---

## Future Architecture

### Potential Improvements

1. **WebSocket Stream**: Real-time log streaming
2. **Multi-Tab Support**: Coordinate multiple tabs
3. **Run Persistence**: Save/resume runs
4. **Run Sharing**: Share run results
5. **Vision API**: Screenshot analysis
6. **Action Recording**: Record user actions for playback
7. **Distributed State**: Redis/PostgreSQL backend
8. **Horizontal Scaling**: Multiple server instances

---

## Conclusion

This architecture provides a robust foundation for an autonomous web agent that:
- ✅ Works within MV3 limitations
- ✅ Maintains state reliably on server
- ✅ Scales to handle concurrent tasks
- ✅ Provides real-time feedback to users
- ✅ Prevents destructive actions
- ✅ Self-corrects when stuck

The thin client approach ensures the extension remains responsive and compliant with Chrome's strict service worker lifecycle.
