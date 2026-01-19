# AI Web Agent - Chrome Extension

Autonomous AI agent for automating web browsing tasks in Chrome. Navigate websites, extract data, fill forms, and complete multi-step tasks using natural language instructions.

**Architecture**: Thin client extension + persistent proxy server (MV3 compatible)

---

## ✨ Features

- 🤖 **Autonomous Operation**: Agent makes decisions and takes actions independently
- 🧠 **Self-Reflection**: Analyzes its own performance and adjusts strategy every 5 steps
- 🛡️ **Security Gate**: Prevents destructive actions (payments, deletions) with user confirmation
- 🔄 **Loop Detection**: Automatically stops when repeating failed actions
- 📊 **Real-time Logs**: See every step in the Side Panel UI
- 🌐 **Universal**: Works on any website without hardcoded selectors
- ⚡ **MV3 Compatible**: Thin client architecture optimized for service worker lifecycle

---

## 🏗️ Architecture

### Why Thin Client?

Chrome Manifest V3 service workers can be terminated at any time, making long-running agent loops impossible.

**Solution**: The agent brain (state machine, decision loop, LLM integration) runs on a persistent Node.js server. The extension is a thin client that executes actions.

```
Extension (Thin Client)          Proxy Server (Brain)
├─ Side Panel UI        ←────→   ├─ Agent Loop
├─ Service Worker                ├─ LLM Integration
└─ Content Script                ├─ Security Gate
   (DOM Automation)              ├─ Loop Detection
                                 └─ Self-Reflection
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

---

## 📦 Installation

### 1. Clone and Install Dependencies

```bash
# Install extension dependencies
npm install

# Install proxy server dependencies
cd agent-proxy
npm install
cd ..
```

### 2. Configure Proxy Server

Create `.env` file in `agent-proxy/`:

```bash
cd agent-proxy
cp env.example .env
```

Edit `.env` and add your LLM API key:

**Option A: OpenRouter** (Recommended - supports multiple models)
```env
LLM_API_KEY=sk-or-v1-your_key_here
LLM_MODEL=anthropic/claude-3.5-sonnet
LLM_BASE_URL=https://openrouter.ai/api/v1
PORT=3131
```

Get API key: https://openrouter.ai

**Option B: OpenAI** (Direct)
```env
LLM_API_KEY=sk-your_key_here
LLM_MODEL=gpt-4o
LLM_BASE_URL=https://api.openai.com/v1
PORT=3131
```

**Option C: Groq** (Fast)
```env
LLM_API_KEY=gsk_your_key_here
LLM_MODEL=llama-3.3-70b-versatile
LLM_BASE_URL=https://api.groq.com/openai/v1
PORT=3131
```

See [agent-proxy/README.md](agent-proxy/README.md) for more providers.

### 3. Build Extension

```bash
# Production build
npm run build

# Development build with watch
npm run dev
```

### 4. Build and Start Proxy Server

```bash
cd agent-proxy
npm run build
npm start
```

You should see:
```
============================================================
AI Web Agent Proxy Server
============================================================
Server running on: http://localhost:3131
Model: anthropic/claude-3.5-sonnet
...
```

### 5. Load Extension in Chrome

1. Open Chrome and go to `chrome://extensions`
2. Enable **Developer mode** (toggle in top-right)
3. Click **Load unpacked**
4. Select the `dist/` folder from this project
5. Extension is now installed!

### 6. Configure Proxy URL

1. Click the extension icon in Chrome toolbar
2. Side Panel opens
3. In "Agent Proxy" section, verify URL is `http://localhost:3131`
4. Click **Test** to verify connection
5. Should show "✓ Connection successful!"

---

## 🚀 Usage

### Quick Start

1. **Open any website** (e.g., Google, hh.ru, GitHub)
2. **Click extension icon** to open Side Panel
3. **Enter task** in the text field:
   ```
   Find contact information on this page
   ```
4. **Click Start**
5. **Watch agent work** - logs appear in real-time

### Example Tasks

#### Simple Extraction
```
Find all email addresses and phone numbers on this page
```

#### Multi-Step Navigation
```
Go to hh.ru, search for Python developer jobs in Moscow, show top 3 results
```

#### Form Filling
```
Find the contact form and fill it with: 
Name: Test User
Email: test@example.com
(don't submit)
```

#### Complex Task
```
Navigate to GitHub trending page, find the top 3 Python repositories, 
extract their names, stars, and descriptions
```

### Security Modes

**Autonomous Mode** (default):
- Fast execution
- Security gate logs warnings but doesn't block
- Best for trusted sites

**Careful Mode** (checkbox enabled):
- Asks for confirmation before:
  - Submitting forms
  - Clicking "Pay/Buy/Delete" buttons
  - Actions on checkout/payment pages
- Safer for unfamiliar sites

---

## 🛠️ Development

### Extension Development

```bash
# Watch mode (rebuilds on changes)
npm run dev

# Production build
npm run build

# After changes, reload extension:
# chrome://extensions → Click reload icon
```

### Server Development

```bash
cd agent-proxy

# Watch mode (restarts on changes)
npm run dev

# Production mode
npm start
```

### Project Structure

```
src/                          # Extension source
├── background/
│   └── serviceWorker.ts      # Thin executor (no agent loop)
├── content/
│   └── contentScript.ts      # DOM automation
├── panel/
│   ├── panel.html            # UI
│   ├── panel.ts              # UI logic
│   └── panel.css             # Styles
└── shared/
    └── types.ts              # TypeScript types

agent-proxy/                  # Proxy server source
├── src/
│   ├── server.ts             # Express API
│   ├── runManager.ts         # Run management
│   ├── agentLogic.ts         # Agent brain
│   ├── agentState.ts         # State storage
│   ├── llmClient.ts          # LLM integration
│   └── types.ts              # Shared types
└── .env                      # Configuration

dist/                         # Built extension (git-ignored)
```

---

## 📖 Documentation

- **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)**: High-level project description
- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Technical architecture details
- **[API.md](API.md)**: Proxy server API documentation
- **[agent-proxy/README.md](agent-proxy/README.md)**: Server-specific docs

---

## 🔧 Troubleshooting

### Extension Not Starting

**Symptom**: Click Start, nothing happens

**Solutions**:
1. Check proxy server is running:
   ```bash
   curl http://localhost:3131/health
   ```
2. Check Service Worker console:
   - Go to `chrome://extensions`
   - Find "AI Web Agent"
   - Click "service worker" link
   - Look for errors

3. Reload extension:
   - `chrome://extensions` → Click reload icon

### Elements Not Found

**Symptom**: Agent says "ELEMENT_NOT_FOUND"

**Solutions**:
1. Ensure page is fully loaded (wait 2-3 seconds)
2. Try refreshing the page (F5)
3. Check if elements are visible (not hidden by CSS)
4. Some sites have dynamic content - agent will retry

### Connection Failed

**Symptom**: "Failed to start run: Connection refused"

**Solutions**:
1. Start proxy server:
   ```bash
   cd agent-proxy
   npm start
   ```
2. Check proxy URL in extension (should be `http://localhost:3131`)
3. Test connection with:
   ```bash
   curl http://localhost:3131/health
   ```

### LLM API Errors

**Symptom**: "LLM API error: 401" or "500"

**Solutions**:
1. Check API key in `agent-proxy/.env`
2. Verify API key is valid (test on provider's website)
3. Check provider status page
4. Check proxy server logs for detailed error

### Chrome:// Pages

**Symptom**: "Cannot execute actions on chrome:// pages"

**Explanation**: Chrome security prevents extensions from accessing browser internal pages.

**Solution**: Navigate to a regular website (http:// or https://)

---

## 🧪 Testing

### Smoke Test

See [test-scenario.md](test-scenario.md) for detailed smoke test procedure.

**Quick test**:
1. Open https://example.com
2. Start task: "Find the link and click it"
3. Verify agent clicks the "More information" link

---

## 🔐 Security

### Security Gate

In **Careful Mode**, the agent will ask for confirmation before:

- **Dangerous URLs**: `checkout`, `payment`, `bank`, `cart`
- **Dangerous Button Text**: `Pay`, `Buy`, `Delete`, `Submit`, `Remove`
- **Form Submission**: Any `type()` action with `submit: true`

In **Autonomous Mode**, these are only logged as warnings.

### API Keys

- ✅ API keys stored only on proxy server (not in extension)
- ✅ Extension connects to localhost only by default
- ⚠️ For production, add authentication and HTTPS

### Content Security Policy

- ✅ No remote code execution
- ✅ Strict CSP in manifest.json
- ✅ All code bundled at build time

---

## 🌍 Supported LLM Providers

| Provider | Models | Speed | Cost | Setup |
|----------|--------|-------|------|-------|
| **OpenRouter** | Many (Claude, GPT-4, Llama, etc.) | Medium | Varies | [Guide](agent-proxy/OPENROUTER-SETUP.md) |
| **OpenAI** | GPT-4, GPT-4-turbo | Medium | High | Direct API |
| **Groq** | Llama 3.3, Mixtral | Very Fast | Free tier | [Guide](agent-proxy/GROQ-SETUP.md) |
| **GigaChat** | GigaChat | Medium | Free (Russia) | [Guide](agent-proxy/GIGACHAT-SETUP.md) |

---

## 📊 Limitations

- **Max Steps**: 150 per task (configurable in server)
- **Snapshot Size**: ~6000 chars visible text, max 100 interactive elements
- **History**: Last 20 steps sent to LLM
- **Chrome Pages**: Cannot interact with `chrome://` URLs
- **Service Worker**: Can be terminated by Chrome (state maintained on server)
- **Concurrent Runs**: Supported, but limited by server resources

---

## 🎯 Use Cases

### ✅ Good Use Cases

- Data extraction (prices, contacts, job listings)
- Form filling (test data, repetitive forms)
- Multi-step navigation (search → filter → extract)
- Website testing
- Monitoring website changes

### ❌ Not Recommended

- Financial transactions (security risk)
- CAPTCHA solving (not supported)
- Real-time trading/bidding
- Deleting important data

---

## 🚢 Deployment

### Production Checklist

**Server:**
- [ ] Use PostgreSQL/MongoDB for run storage (not in-memory)
- [ ] Add API key authentication
- [ ] Add rate limiting
- [ ] Deploy with HTTPS (Let's Encrypt)
- [ ] Set up monitoring (logs, metrics, errors)
- [ ] Configure CORS for specific extension IDs
- [ ] Use PM2 or systemd for process management

**Extension:**
- [ ] Build production bundle: `npm run build`
- [ ] Update manifest.json (version, permissions)
- [ ] Create Chrome Web Store listing
- [ ] Submit for review
- [ ] Monitor error reports

See [ARCHITECTURE.md](ARCHITECTURE.md) for deployment details.

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

- Chrome Extension Manifest V3 documentation
- OpenRouter, OpenAI, and other LLM providers
- The autonomous agent community

---

## 📞 Support

**Issues**: Open an issue on GitHub

**Documentation**:
- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) - Project introduction
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [API.md](API.md) - API reference
- [test-scenario.md](test-scenario.md) - Testing guide

**Logs**:
- Extension: `chrome://extensions` → service worker console
- Server: Terminal output
- Content Script: Browser DevTools console (F12)

---

## 🔮 Roadmap

### Near Term
- [ ] Persistent storage (database)
- [ ] WebSocket streaming logs
- [ ] Better error recovery
- [ ] More LLM providers

### Future
- [ ] Multi-tab coordination
- [ ] Vision API (screenshot analysis)
- [ ] Action recording/playback
- [ ] Collaborative runs
- [ ] Browser extension for Firefox

---

**Ready to automate your browsing? Follow the installation steps above and start your first task!** 🚀
