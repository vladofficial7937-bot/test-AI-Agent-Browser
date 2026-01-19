# API Documentation

## Proxy Server API

Base URL: `http://localhost:3131` (configurable via `PORT` env var)

All endpoints use JSON format.

---

## Health Check

### `GET /health`

Check if server is running and configured correctly.

**Response:**
```json
{
  "status": "ok",
  "model": "anthropic/claude-3.5-sonnet",
  "baseUrl": "https://openrouter.ai/api/v1",
  "timestamp": "2026-01-19T12:00:00.000Z"
}
```

---

## Run Management

### `POST /agent/run/start`

Start a new agent run.

**Request Body:**
```json
{
  "task": "Find contact information on this page",
  "mode": "autonomous"  // or "careful"
}
```

**Response:**
```json
{
  "success": true,
  "runId": "550e8400-e29b-41d4-a716-446655440000",
  "state": {
    "status": "created",
    "currentStep": 0,
    "maxSteps": 150
  }
}
```

**Status Codes:**
- `200`: Success
- `400`: Bad request (missing task or invalid mode)
- `500`: Server error

---

### `POST /agent/run/:runId/step`

Execute next step in the run.

**Request Body:**
```json
{
  "snapshot": {
    "url": "https://example.com",
    "title": "Example Domain",
    "visibleText": "Example Domain This domain is for use in...",
    "elements": [
      {
        "id": "agent-1",
        "tag": "a",
        "text": "More information...",
        "href": "https://www.iana.org/domains/example"
      }
    ],
    "timestamp": 1737292800000
  },
  "lastActionResult": {
    "success": true,
    "message": "Clicked successfully"
  }
}
```

**Response (execute_tool):**
```json
{
  "action": "execute_tool",
  "tool": {
    "name": "click",
    "parameters": {
      "id": "agent-1"
    }
  },
  "state": {
    "status": "running",
    "currentStep": 1,
    "maxSteps": 150
  }
}
```

**Response (ask_user):**
```json
{
  "action": "ask_user",
  "question": "⚠️ Security check: Attempting to click 'Pay Now'. Proceed?",
  "state": {
    "status": "waiting_user",
    "currentStep": 5,
    "maxSteps": 150
  }
}
```

**Response (finish):**
```json
{
  "action": "finish",
  "result": "Contact info: email@example.com, phone: +1-234-567-8900",
  "state": {
    "status": "completed",
    "currentStep": 12,
    "maxSteps": 150
  }
}
```

**Response (error):**
```json
{
  "action": "error",
  "error": "Maximum steps reached",
  "state": {
    "status": "error",
    "currentStep": 150,
    "maxSteps": 150
  }
}
```

**Notes:**
- `snapshot` can be `null` on first call
- `lastActionResult` can be `null` if no previous action
- Server maintains state between calls

---

### `POST /agent/run/:runId/answer`

Respond to user question (when `action` is `ask_user`).

**Request Body:**
```json
{
  "approved": true,
  "answer": "optional text answer"
}
```

**Response:**
```json
{
  "action": "execute_tool",
  "tool": {
    "name": "observe",
    "parameters": {}
  },
  "state": {
    "status": "running",
    "currentStep": 6,
    "maxSteps": 150
  }
}
```

**Notes:**
- If `approved` is `false`, run will be cancelled
- Call `/step` again to continue execution

---

### `POST /agent/run/:runId/cancel`

Cancel a running task.

**Request Body:** (empty)

**Response:**
```json
{
  "success": true
}
```

**Status Codes:**
- `200`: Success
- `404`: Run not found
- `500`: Server error

---

### `GET /agent/run/:runId`

Get full state of a run.

**Response:**
```json
{
  "success": true,
  "state": {
    "runId": "550e8400-e29b-41d4-a716-446655440000",
    "task": "Find contact information",
    "mode": "autonomous",
    "status": "running",
    "currentStep": 5,
    "maxSteps": 150,
    "history": [
      {
        "stepNumber": 1,
        "action": "observe",
        "observation": "Success",
        "timestamp": 1737292800000
      },
      {
        "stepNumber": 2,
        "action": "click",
        "observation": "Clicked successfully",
        "timestamp": 1737292801000
      }
    ],
    "reflections": [
      {
        "stepNumber": 5,
        "stepsAnalyzed": 5,
        "efficiency": "high",
        "issues": [],
        "suggestions": [],
        "shouldAdjust": false,
        "timestamp": 1737292805000
      }
    ],
    "currentSnapshot": { ... },
    "createdAt": 1737292800000,
    "updatedAt": 1737292805000
  }
}
```

**Status Codes:**
- `200`: Success
- `404`: Run not found
- `500`: Server error

---

## Data Types

### RunStatus
```typescript
type RunStatus = 
  | 'created'      // Just created
  | 'running'      // Actively executing
  | 'waiting_user' // Waiting for user answer
  | 'completed'    // Successfully finished
  | 'error'        // Error occurred
  | 'cancelled';   // User cancelled
```

### RunMode
```typescript
type RunMode = 
  | 'autonomous'  // No security gate blocking
  | 'careful';    // Security gate enabled
```

### ToolName
```typescript
type ToolName = 
  | 'observe'    // Get page snapshot
  | 'navigate'   // Go to URL
  | 'click'      // Click element
  | 'type'       // Type into input
  | 'scroll'     // Scroll page
  | 'press'      // Press key
  | 'ask_user'   // Ask user question
  | 'finish';    // Complete task
```

### PageSnapshot
```typescript
interface PageSnapshot {
  url: string;
  title: string;
  visibleText: string;  // Limited to ~6000 chars
  elements: ElementInfo[];  // Max 100 elements
  timestamp: number;
}
```

### ElementInfo
```typescript
interface ElementInfo {
  id: string;          // data-agent-id
  tag: string;         // HTML tag name
  role?: string;       // ARIA role
  text?: string;       // Visible text (max 200 chars)
  ariaLabel?: string;  // aria-label attribute
  placeholder?: string;
  type?: string;       // input type
  value?: string;      // input value (max 100 chars)
  href?: string;       // link href
  disabled?: boolean;
  name?: string;       // input name
  bbox?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
}
```

### ToolResult
```typescript
interface ToolResult {
  success: boolean;
  data?: any;
  error?: string;
  message?: string;
}
```

---

## Error Handling

All endpoints return consistent error format:

```json
{
  "error": "Error category",
  "message": "Detailed error message"
}
```

**Common Errors:**
- `400 Bad Request`: Invalid input (missing required fields, wrong types)
- `404 Not Found`: Run ID doesn't exist or expired
- `500 Internal Server Error`: Server-side error (LLM API failure, etc.)

---

## Rate Limiting

Currently no rate limiting is implemented. For production use, consider adding rate limiting middleware.

---

## Authentication

Currently no authentication is required. The server trusts all requests from `localhost`.

For production deployment:
- Add API key authentication
- Restrict CORS to specific extension IDs
- Implement request signing

---

## WebSocket (Future)

Real-time streaming of logs could be implemented via WebSocket:

```typescript
// Future feature
const ws = new WebSocket('ws://localhost:3131/agent/run/:runId/stream');
ws.onmessage = (event) => {
  const log = JSON.parse(event.data);
  // Real-time log streaming
};
```

---

## Example Flow

```javascript
// 1. Start run
const startRes = await fetch('http://localhost:3131/agent/run/start', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    task: 'Find pricing information',
    mode: 'autonomous'
  })
});
const { runId } = await startRes.json();

// 2. Execute steps in loop
while (true) {
  const snapshot = await getPageSnapshot();
  
  const stepRes = await fetch(`http://localhost:3131/agent/run/${runId}/step`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ snapshot, lastActionResult })
  });
  
  const step = await stepRes.json();
  
  if (step.action === 'execute_tool') {
    // Execute tool in browser
    lastActionResult = await executeTool(step.tool);
    continue;
  }
  
  if (step.action === 'ask_user') {
    // Show question to user
    const approved = await askUser(step.question);
    await fetch(`http://localhost:3131/agent/run/${runId}/answer`, {
      method: 'POST',
      body: JSON.stringify({ approved })
    });
    continue;
  }
  
  if (step.action === 'finish') {
    console.log('Task completed:', step.result);
    break;
  }
  
  if (step.action === 'error') {
    console.error('Task failed:', step.error);
    break;
  }
}
```
