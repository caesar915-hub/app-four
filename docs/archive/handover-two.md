> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. This file is a pre-app-four scratch note and does not reflect current project state. See [docs/BACKLOG.md](../BACKLOG.md), [docs/DEVLOG.md](../DEVLOG.md), and the Notion `app-two` DB for current architecture.
>
> **🔑 SECURITY:** This file previously contained two live `sk-ant-api03-…` Anthropic API keys (committed in git history at `88f423b` and earlier). The keys have been **redacted from the working tree** below but REMAIN IN GIT HISTORY — they MUST be revoked at console.anthropic.com. Redaction here does not neutralize the leak; rotation does.

---

[REDACTED — Anthropic API key removed 2026-06-15; revoke in git history]

[REDACTED — Anthropic API key removed 2026-06-15; revoke in git history]

```bash
curl https://api.anthropic.com/v1/messages \
  --header "x-api-key: [REDACTED]" \
  --header "anthropic-version: 2023-06-01" \
  --header "content-type: application/json" \
  --data '{"model": "claude-sonnet-4-6", "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello, world"}]}'
```
