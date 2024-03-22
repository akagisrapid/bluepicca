#!/bin/bash

# This script resolves a DID, retrieves an API key, fetches a user's feed,
# and posts a "Hello, world" message to the user's feed.

# Resolve DID for handle
HANDLE='akagisrapid.bsky.social'
DID_URL="https://bsky.social/xrpc/com.atproto.identity.resolveHandle"
export DID=$(curl -G \
    --data-urlencode "handle=$HANDLE" \
    "$DID_URL" | jq -r .did)

# Get an app password from here: https://staging.bsky.app/settings/app-passwords
export APP_PASSWORD='qYmf0eXep-_Q8Iw'

# Get API key with the app password
API_KEY_URL='https://bsky.social/xrpc/com.atproto.server.createSession'
POST_DATA="{ \"identifier\": \"${DID}\", \"password\": \"${APP_PASSWORD}\" }"
export API_KEY=$(curl -X POST \
    -H 'Content-Type: application/json' \
    -d "$POST_DATA" \
    "$API_KEY_URL" | jq -r .accessJwt)

# Post "Hello, world" to your feed
POST_FEED_URL='https://bsky.social/xrpc/com.atproto.repo.createRecord'
POST_RECORD="{ \"collection\": \"app.bsky.feed.post\", \"repo\": \"${DID}\", \"record\": { \"text\": \"ダイヤ改正前だからみんな北陸に行ってる\", \"createdAt\": \"2024-03-15T15:00:00+09:00\", \"\$type\": \"app.bsky.feed.post\" } }"
curl -X POST \
    -H "Authorization: Bearer ${API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "$POST_RECORD" \
    "$POST_FEED_URL" | jq -r