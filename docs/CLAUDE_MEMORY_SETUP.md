# Claude Memory Setup Guide

## Project: NativeLocal_SLM_App

**Last Updated**: 2026-01-31
**Required For**: All developers working on this project

---

## Overview

This project uses **Claude Memory (claude-mem)** for cross-session context persistence. The system automatically captures everything Claude does during coding sessions, compresses it with AI, and injects relevant context back into future sessions.

**Benefits**:
- Continuity across sessions without re-explaining context
- Automatic capture of bugs, fixes, and decisions
- Smart retrieval of relevant historical information
- Efficient token usage with AI compression

---

## Prerequisites

### Required Software

1. **Claude Code CLI** - Latest version with plugin support
2. **Node.js** - v18.0.0 or higher
3. **Bun** - JavaScript runtime (auto-installed if missing)
4. **Python** - v3.13 (auto-installed if missing)

### Required Accounts

1. **OpenRouter Account** (for API access)
   - Free tier available
   - Sign up at https://openrouter.ai/
   - Required for AI model access

---

## Installation

### Step 1: Install claude-mem Plugin

Open a terminal and run:

```bash
# Add the plugin marketplace
claude plugin marketplace add thedotmack/claude-mem

# Install the plugin
claude plugin install claude-mem
```

**Restart Claude Code** after installation.

### Step 2: Get OpenRouter API Key

1. Go to https://openrouter.ai/
2. Click **"Sign Up"** (top right)
3. Sign up with:
   - GitHub (recommended)
   - Google
   - Email/password
4. Once signed in, navigate to **API Keys**
5. Click **"Create API Key"**
6. Copy your API key (starts with `sk-or-v1-`)

### Step 3: Configure API Provider

**Option A: Environment Variable (Recommended)**

```powershell
# Windows PowerShell
[System.Environment]::SetEnvironmentVariable('OPENROUTER_API_KEY', 'your-api-key-here', 'User')

# Windows CMD
setx OPENROUTER_API_KEY "your-api-key-here"
```

**Option B: Direct Configuration**

1. Open `C:\Users\YOUR_USERNAME\.claude-mem\settings.json`
2. Find the line:
   ```json
   "CLAUDE_MEM_OPENROUTER_API_KEY": ""
   ```
3. Replace with your API key:
   ```json
   "CLAUDE_MEM_OPENROUTER_API_KEY": "sk-or-v1-your-key-here"
   ```

### Step 4: Verify Installation

```bash
# Check worker service is running
curl http://localhost:37777/health

# Expected output: {"status":"ok","timestamp":...}

# Check database exists
ls C:\Users\YOUR_USERNAME\.claude-mem\claude-mem.db

# Expected output: File exists (~1-4 MB)
```

---

## Project-Specific Configuration

This project already has optimized memory configuration:

- ✅ Android-specific observation types configured
- ✅ Android-specific concepts configured
- ✅ Project context documented (`.claude/PROJECT_CONTEXT.md`)
- ✅ Excluded files configured (`.claude/excluded_files.txt`)
- ✅ Memory tool permissions set (`.claude/settings.local.json`)

**No additional configuration required** for this project.

---

## Usage

### Automatic Operation

Claude Memory works **automatically** - no manual intervention required:

1. **Capture**: Every file read, edit, bash command is captured
2. **Compress**: AI summarizes and structures the data
3. **Store**: Observations stored in SQLite database
4. **Retrieve**: Relevant context injected into future sessions

### What Gets Captured

**Captured Automatically**:
- File reads (Read tool)
- File edits (Edit, Write tools)
- Bash commands and output
- Search queries
- Build/test commands
- Error messages and fixes

**Excluded** (via `.claude/excluded_files.txt`):
- Build outputs (`app/build/`, `*.apk`)
- IDE files (`.idea/`, `*.iml`)
- Large assets (PNGs, WEBPs)
- Generated code
- Test fixtures

### Viewing Memory

#### Web Viewer

```bash
# Open in browser
start http://localhost:37777
```

**Features**:
- Real-time observation stream
- Search and filter by type/date/project
- View session summaries
- Timeline visualization
- Export functionality

#### In-Session Search

During Claude Code sessions, use natural language:

```
"What did we learn about MediaPipe configuration?"
"Show me recent gradle fixes"
"How did we solve the camera permission issue?"
```

---

## Configuration Files

### Global Settings

**Location**: `C:\Users\YOUR_USERNAME\.claude-mem\settings.json`

**Current Configuration**:
```json
{
  "CLAUDE_MEM_PROVIDER": "openrouter",
  "CLAUDE_MEM_OPENROUTER_MODEL": "z-ai/glm-4.5-air:free",
  "CLAUDE_MEM_CONTEXT_OBSERVATIONS": "30",
  "CLAUDE_MEM_CONTEXT_FULL_COUNT": "3",
  "CLAUDE_MEM_CONTEXT_SESSION_COUNT": "5",
  "CLAUDE_MEM_CONTEXT_DATE_RANGE_DAYS": "30"
}
```

### Project Settings

**Location**: `.claude/settings.local.json`

**Contains**:
- Memory tool permissions
- Bash tool permissions
- Project-specific overrides

### Project Context

**Location**: `.claude/PROJECT_CONTEXT.md`

**Contains**:
- Project overview
- Technology stack
- Architecture details
- Important file locations
- Build commands
- Common issues and solutions

### Excluded Files

**Location**: `.claude/excluded_files.txt`

**Contains**:
- Build artifacts
- Large binaries
- Generated files
- Test fixtures

---

## Troubleshooting

### Problem: No Observations Stored

**Symptoms**:
- Database has 0 observations
- Search returns no results
- No context injected in new sessions

**Solutions**:

1. **Check API Key**:
   ```bash
   # Verify API key is set
   powershell -Command "Write-Output $env:OPENROUTER_API_KEY"
   ```

2. **Test API Access**:
   ```bash
   curl -X POST https://openrouter.ai/api/v1/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -d '{"model":"z-ai/glm-4.5-air:free","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}'
   ```

3. **Check Worker Logs**:
   - Open web viewer: http://localhost:37777
   - Look for error messages

### Problem: Worker Service Not Running

**Symptoms**:
- Port 37777 not accessible
- `curl http://localhost:37777/health` fails

**Solutions**:

1. **Restart Claude Code** (worker starts automatically)

2. **Check Port Conflict**:
   ```bash
   # Check if port 37777 is in use
   netstat -ano | findstr :37777
   ```

3. **Restart Worker**:
   - Kill process using port 37777
   - Restart Claude Code

### Problem: High Token Usage

**Symptoms**:
- Memory context > 15,000 tokens
- Slow context generation
- Expensive API costs

**Solutions**:

1. **Reduce Observation Count**:
   - Edit `~/.claude-mem/settings.json`
   - Change `"CLAUDE_MEM_CONTEXT_OBSERVATIONS": "30"` to `"20"`

2. **Reduce Date Range**:
   - Change `"CLAUDE_MEM_CONTEXT_DATE_RANGE_DAYS": "30"` to `"14"`

3. **Filter Observation Types**:
   - Remove less relevant types from `CLAUDE_MEM_CONTEXT_OBSERVATION_TYPES`

### Problem: Missing Relevant Context

**Symptoms**:
- Can't find recent work
- Important fixes not appearing
- Gaps in context

**Solutions**:

1. **Increase Observation Count**:
   - Change `"CLAUDE_MEM_CONTEXT_OBSERVATIONS": "30"` to `"40"`

2. **Increase Sessions**:
   - Change `"CLAUDE_MEM_CONTEXT_SESSION_COUNT": "5"` to `"10"`

3. **Extend Date Range**:
   - Change `"CLAUDE_MEM_CONTEXT_DATE_RANGE_DAYS": "30"` to `"60"`

---

## Performance Expectations

### Token Usage

**Typical Session**:
- Memory context: 7,000-12,000 tokens
- Worker processing: < 0.5 seconds
- Compression savings: 30-50%

**Cost**:
- **Free model** (GLM 4.5 Air): $0.00
- **Paid models** (if upgraded): ~$0.10-0.30 per 100 observations

### Storage

**Database Growth**:
- ~1-2 KB per observation
- ~500 observations per MB
- Typical project: 5-20 MB after 1 year

---

## Best Practices

### Do's ✅

1. **Use specific prompts** when searching memory:
   - ❌ "What about the bug?"
   - ✅ "How did we fix the MediaPipe hair segmentation crash?"

2. **Update PROJECT_CONTEXT.md** when architecture changes

3. **Review excluded files** periodically to ensure relevant files aren't excluded

4. **Check token usage** in context injection to monitor efficiency

5. **Keep API key secure** - use environment variables, not committed files

### Don'ts ❌

1. **Don't commit API keys** to git

2. **Don't manually edit the database** - may corrupt state

3. **Don't exclude source files** - only build artifacts and binaries

4. **Don't set observations below 10** - insufficient context

5. **Don't use "facts" format for Android** - need narrative detail

---

## Privacy & Security

### Data Stored

**Stored Locally**:
- All observations in `C:\Users\YOUR_USERNAME\.claude-mem\claude-mem.db`
- Database is local only (not synced to cloud)

**Sent to API**:
- Tool usage data for AI compression
- Code snippets, error messages, commands
- Project file paths and content

### Privacy Controls

**Exclude Sensitive Content**:
Use `<private>` tags in conversations:
```
Here's the API key: <private>sk-or-v1-secret-key</private>
```
Content within `<private>` tags is excluded from memory.

**Exclude Files**:
Add to `.claude/excluded_files.txt`:
```
# Don't track secrets
app/src/main/java/secrets/
*.env
*.keystore
```

---

## Advanced Configuration

### Changing Models

**Free Models**:
- `z-ai/glm-4.5-air:free` (current)
- `deepseek/deepseek-r1t2-chimera:free`
- `meta-llama/llama-3-70b-instruct:free`

**Paid Models** (if needed):
- Edit `~/.claude-mem/settings.json`
- Change `"CLAUDE_MEM_OPENROUTER_MODEL"`

### Custom Observation Types

Add to `CLAUDE_MEM_CONTEXT_OBSERVATION_TYPES`:
```json
"bugfix,feature,refactor,discovery,decision,change,my-custom-type"
```

### Custom Concepts

Add to `CLAUDE_MEM_CONTEXT_OBSERVATION_CONCEPTS`:
```json
"how-it-works,why-it-exists,my-custom-concept"
```

---

## Resources

### Documentation

- [Claude-Mem Documentation](https://docs.claude-mem.ai)
- [GitHub Repository](https://github.com/thedotmack/claude-mem)
- [MCP Tools Reference](https://docs.claude-mem.ai/mcp-tools)
- [Architecture Overview](https://docs.claude-mem.ai/architecture)

### Project Documentation

- `CLAUDE.md` - Project overview and guidance
- `.claude/PROJECT_CONTEXT.md` - Project-specific context
- `.claude/TOKEN_OPTIMIZATION.md` - Token usage optimization
- `.claude/MEMORY_SETUP_PLAN.md` - Setup plan and phases

### Support

- **Issues**: https://github.com/thedotmack/claude-mem/issues
- **Discord**: https://discord.gg/claude-memory
- **X/Twitter**: @Claude_Memory

---

## FAQ

**Q: Is Claude Memory required for this project?**

A: Strongly recommended but not required. The project will work without it, but you'll lose cross-session context continuity.

**Q: How much does it cost?**

A: Free with the default configuration (GLM 4.5 Air model). Paid models available if needed.

**Q: Can I use a different AI provider?**

A: Yes. Supports Anthropic Claude, OpenAI, Azure, AWS Bedrock, and OpenRouter.

**Q: Is my code sent to external servers?**

A: Yes, to the AI provider (OpenRouter) for compression. Stored locally after processing.

**Q: Can I disable it for sensitive work?**

A: Yes. Use `<private>` tags or stop the worker service.

**Q: How do I know it's working?**

A: Check web viewer (http://localhost:37777) or look for `<claude-mem-context>` tags in new sessions.

---

## Quick Reference

### Essential Commands

```bash
# Check worker status
curl http://localhost:37777/health

# Open web viewer
start http://localhost:37777

# Query observation count
sqlite3 "C:\Users\YOUR_USERNAME\.claude-mem\claude-mem.db" "SELECT COUNT(*) FROM observations;"

# View recent observations
sqlite3 "C:\Users\YOUR_USERNAME\.claude-mem\claude-mem.db" "SELECT id, type, title, created_at FROM observations ORDER BY created_at_epoch DESC LIMIT 10;"
```

### Configuration Files

- **Global**: `C:\Users\YOUR_USERNAME\.claude-mem\settings.json`
- **Project**: `.claude/settings.local.json`
- **Context**: `.claude/PROJECT_CONTEXT.md`
- **Excluded**: `.claude/excluded_files.txt`

### Key Settings

```json
{
  "CLAUDE_MEM_PROVIDER": "openrouter",
  "CLAUDE_MEM_OPENROUTER_MODEL": "z-ai/glm-4.5-air:free",
  "CLAUDE_MEM_CONTEXT_OBSERVATIONS": "30",
  "CLAUDE_MEM_CONTEXT_SESSION_COUNT": "5",
  "CLAUDE_MEM_CONTEXT_DATE_RANGE_DAYS": "30"
}
```

---

**Setup Status**: ✅ Configured for this project
**Required**: Yes (strongly recommended)
**Support**: See resources above
