#!/bin/bash

# This script resolves a DID, retrieves an API key, fetches a user's feed,
# and posts a message to the user's feed.

# Set these environment variables before running:
#   export BSKY_HANDLE='your-handle.bsky.social'
#   export BSKY_APP_PASSWORD='your-app-password'

if [ -z "$BSKY_HANDLE" ] || [ -z "$BSKY_APP_PASSWORD" ]; then
    echo "Error: BSKY_HANDLE and BSKY_APP_PASSWORD environment variables must be set."
    exit 1
fi

# Resolve DID for handle
HANDLE="$BSKY_HANDLE"
DID_URL="https://bsky.social/xrpc/com.atproto.identity.resolveHandle"
export DID=$(curl -G \
    --data-urlencode "handle=$HANDLE" \
    "$DID_URL" | jq -r .did)

# Get API key with the app password
API_KEY_URL='https://bsky.social/xrpc/com.atproto.server.createSession'
POST_DATA="{ \"identifier\": \"${DID}\", \"password\": \"${BSKY_APP_PASSWORD}\" }"
export API_KEY=$(curl -X POST \
    -H 'Content-Type: application/json' \
    -d "$POST_DATA" \
    "$API_KEY_URL" | jq -r .accessJwt)

# Post to your feed
POST_FEED_URL='https://bsky.social/xrpc/com.atproto.repo.createRecord'
POST_RECORD="{ \"collection\": \"app.bsky.feed.post\", \"repo\": \"${DID}\", \"record\": { \"text\": \"Hello from script\", \"createdAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"\$type\": \"app.bsky.feed.post\" } }"
curl -X POST \
    -H "Authorization: Bearer ${API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "$POST_RECORD" \
    "$POST_FEED_URL" | jq -r
