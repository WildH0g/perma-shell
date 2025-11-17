#!/usr/bin/bash
export CI=true
REPO_URL="repos/$1/commits/$2"
API=$(gh api "$REPO_URL" --jq ".commit")
VERIFIED=$(echo "$API" | jq -r ".verification.verified")
REASON=$(echo "$API" | jq -r ".verification.reason")
AUTHOR=$(echo "$API" | jq -r ".author.name")
DATE=$(echo "$API" | jq -r ".author.date")
MESSAGE=$(echo "$API" | jq -r ".message")
cat << EOF
-------------------------------------------------------------------------------
| Commit Details for SHA: ${2}
-------------------------------------------------------------------------------
| Author:    ${AUTHOR}
| Date:      ${DATE}
| Verified:  ${VERIFIED}
| Reason:    ${REASON}

${MESSAGE}
-------------------------------------------------------------------------------
EOF
exit
