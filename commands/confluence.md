---
description: Read a Confluence page and display its contents (read-only, safe)
---

Display the following Confluence page content. The output contains a metadata header followed by HTML body content.

!`~/.jirasik/scripts/fetch_confluence.sh $ARGUMENTS`

If the output above contains `no_config` or `Missing JIRA_URL`, the config file is missing. Tell the user to run `setup.sh` from the jirasik repo.

If the output above contains `Session expired` or `Failed to validate session`, the session has expired. Start Firefox in visible (non-headless) mode with headless=false, profilePath=`~/.jirasik/firefox-profile`, startUrl=`__JIRA_URL__`. Tell the user to log in (do NOT fill in credentials). After login, close Firefox and re-run the command.

If the output above contains `Could not extract page ID`, tell the user the URL format wasn't recognized. Accepted formats:
- Short link: `__JIRA_URL__/wiki/x/ABC123`
- Full page URL: `__JIRA_URL__/wiki/spaces/SPACE/pages/12345/Page+Title`
- Bare page ID: `12345`

Otherwise, parse the HTML content and present it as clean, readable markdown. The HTML may contain:
- `<ac:structured-macro ac:name="code">` blocks — render these as fenced code blocks with the language from `<ac:parameter ac:name="language">`
- `<ac:structured-macro ac:name="info">` or `<ac:structured-macro ac:name="note">` — render as blockquotes
- Standard HTML (`<h2>`, `<p>`, `<table>`, `<ul>`, `<ol>`, `<strong>`, `<code>`, `<a>`, `<hr>`) — render as equivalent markdown
- `local-id` and `ac:local-id` attributes — ignore these

After displaying the content, ask the user what they'd like to do. This is read-only. Never modify any Confluence content.
