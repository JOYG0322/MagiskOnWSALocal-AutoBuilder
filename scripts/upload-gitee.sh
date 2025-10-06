#!/usr/bin/env bash
# usage: bash scripts/upload-gitee.sh <GITEE_USER> <GITEE_REPO> <TAG_NAME> <FILE_PATH>
set -e

OWNER="$1"
REPO="$2"
TAG_NAME="$3"
FILE_PATH="$4"

if [ -z "$GITEE_TOKEN" ]; then
  echo "❌ GITEE_TOKEN not set in environment."
  exit 1
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  echo "❌ File not found: $FILE_PATH"
  exit 1
fi

echo "🆙 Uploading $FILE_PATH to Gitee as tag $TAG_NAME"
echo "➡️  Repo: ${OWNER}/${REPO}"

# Get default branch
DEFAULT_BRANCH=$(curl -s "https://gitee.com/api/v5/repos/${OWNER}/${REPO}?access_token=${GITEE_TOKEN}" | jq -r '.default_branch')
echo "📄 Default branch: $DEFAULT_BRANCH"

# Get commit SHA of default branch
COMMIT_SHA=$(curl -s "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/commits/${DEFAULT_BRANCH}?access_token=${GITEE_TOKEN}" | jq -r '.sha')

# Check if release tag exists
EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}")
if [ "$EXISTS" = "200" ]; then
  echo "⚠️  Tag exists, deleting old release..."
  RELEASE_ID=$(curl -s "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}" | jq -r '.id')
  curl -X DELETE "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/${RELEASE_ID}?access_token=${GITEE_TOKEN}"
else
  echo "🆕 Creating new tag..."
  curl -X POST \
    -H "Content-Type: application/json;charset=UTF-8" \
    -d "{\"tag_name\":\"${TAG_NAME}\",\"target_commitish\":\"${COMMIT_SHA}\"}" \
    "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/tags?access_token=${GITEE_TOKEN}"
fi

# Create release
echo "📦 Creating release..."
curl -X POST \
  -H "Content-Type: application/json;charset=UTF-8" \
  -d "{\"tag_name\":\"${TAG_NAME}\",\"name\":\"${TAG_NAME}\",\"body\":\"Auto-upload from GitHub Actions\"}" \
  "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases?access_token=${GITEE_TOKEN}"

# Upload file
echo "📤 Uploading file: $(basename "$FILE_PATH")"
curl -X POST \
  -H "Content-Type: multipart/form-data" \
  -F "access_token=${GITEE_TOKEN}" \
  -F "file=@${FILE_PATH}" \
  "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/assets?tag_name=${TAG_NAME}"

echo "✅ Upload complete."
