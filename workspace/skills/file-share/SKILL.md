---
name: file-share
description: Share files (HTML, images, etc.) with users by writing to the workspace and providing a download link via the built-in file server.
metadata: { "openclaw": { "emoji": "🔗" } }
---

# File Share

## Overview

A static file server runs alongside OpenClaw, serving everything under the workspace directory. Write a file to the workspace, then share its URL — the user can open it in any browser on the Tailnet.

## Base URL

```
http://100.112.147.39:8080/
```

Any file written to the workspace root is served at `http://100.112.147.39:8080/<filename>`.

## How to use

1. Write the file to the workspace root using the `write` tool with a **relative path** (just the filename).
2. Reply with the URL so the user can open it.

### Example: HTML report

```
write path: report-20260210.html
```

Then reply:

> Here is the report: http://100.112.147.39:8080/report-20260210.html

### Example: Generated image or PDF

Same pattern — write the file with a relative filename, share the link.

**Important:** Always use relative paths (e.g., `report.html`) — never absolute paths like `/home/node/...`.

## Guidelines

- Use descriptive filenames with dates to avoid collisions (e.g., `ai-news-20260210.html`).
- For HTML, include inline CSS so it renders well standalone.
- The file server is read-only from the network; only the agent can write files.
- Links are accessible only within the Tailnet (private network).
- For large results, tables, or formatted content, **prefer HTML over plain text** when the user asks for rich output.
