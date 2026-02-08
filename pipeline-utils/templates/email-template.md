Subject: [{{SEVERITY}}] {{TITLE}} - {{PROJECT_NAME}} Build #{{BUILD_ID}} Failed

{{EMOJI}} Build Notification - {{TITLE}}

Hello {{OWNER_NAME}},

A build failure has occurred in {{PROJECT_NAME}} that requires your attention.

==========================================
FAILURE DETAILS
==========================================

Pattern:       {{PATTERN_NAME}}
Severity:      {{SEVERITY}}
Category:      {{CATEGORY}}
Build Number:  #{{BUILD_ID}}
Branch:        {{BRANCH}}

==========================================
ERROR MESSAGE
==========================================

{{ERROR_MESSAGE}}

==========================================
LOCATION
==========================================

File: {{FILE_PATH}}
Line: {{LINE_NUMBER}}

==========================================
SUGGESTED FIX
==========================================

{{REMEDIATION}}

{% if AUTO_FIXABLE %}
==========================================
AUTO-FIX AVAILABLE
==========================================

This issue can be automatically fixed. Run:

  {{AUTO_FIX_COMMAND}}

Or wait for the CI system to apply the fix automatically.
{% endif %}

==========================================
CODE OWNERS
==========================================

The following owners have been notified:
{{OWNERS_LIST}}

==========================================
BUILD DETAILS
==========================================

Build:        #{{BUILD_ID}}
Commit:       {{COMMIT_SHORT}} ({{COMMIT_SHA}})
Commit URL:   {{COMMIT_URL}}
Author:       {{AUTHOR}}
Message:      {{COMMIT_MESSAGE}}

Build URL:    {{BUILD_URL}}
Logs URL:     {{LOGS_URL}}
Started:      {{START_TIME}}
Duration:     {{DURATION}}

==========================================
NEXT STEPS
==========================================

1. Review the error message and suggested fix above
2. Check the build logs for more details: {{LOGS_URL}}
3. Apply the suggested fix or investigate further
4. Push your changes to trigger a new build
5. If this is a false positive, please update the failure patterns

{% if NEEDS_REVIEW %}
⚠️  This failure requires manual review and cannot be auto-fixed.
{% endif %}

==========================================

Timestamp: {{TIMESTAMP}}
Notification ID: {{NOTIFICATION_ID}}

You're receiving this email because you're listed as a code owner for the affected files.

---
Woodpecker CI - Autonomous Notification System
{{UNSUBSCRIBE_URL}}
