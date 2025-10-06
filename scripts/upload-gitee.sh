#!/usr/bin/env bash
set -e

GITEE_USER="$1"
GITEE_REPO="$2"
TAG_NAME="$3"
FILE_PATH="$4"
API="https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}"

if [ -z "$GITEE_TOKEN" ]; then
  echo "❌ Missing GITEE_TOKEN!"
  exit 1
fi

echo "📦 正在上传文件: $(basename "$FILE_PATH")"
echo "➡️ 目标仓库: ${GITEE_USER}/${GITEE_REPO}"
echo "➡️ 标签: ${TAG_NAME}"

# 检查是否存在同名 Release
EXISTING_RELEASE=$(curl -s "${API}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}")
if echo "$EXISTING_RELEASE" | grep -q '"tag_name"'; then
  echo "🟡 发现同名 Release，先删除..."
  curl -s -X DELETE "${API}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}" || true
  sleep 2
fi

echo "🆕 创建新的 Release..."
CREATE_RESPONSE=$(curl -s -X POST "${API}/releases" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -d "{
    \"access_token\": \"${GITEE_TOKEN}\",
    \"tag_name\": \"${TAG_NAME}\",
    \"name\": \"${TAG_NAME}\",
    \"body\": \"Auto uploaded from GitHub Actions.\",
    \"target_commitish\": \"main\"
  }")

if echo "$CREATE_RESPONSE" | grep -q '"id"'; then
  RELEASE_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2)
  echo "✅ Release 已创建: ID=$RELEASE_ID"
else
  echo "❌ 创建 Release 失败！响应：$CREATE_RESPONSE"
  exit 1
fi

echo "⬆️ 上传文件中..."
UPLOAD_RESPONSE=$(curl -s -X POST "${API}/releases/${RELEASE_ID}/assets?access_token=${GITEE_TOKEN}" \
  -F "name=$(basename "$FILE_PATH")" \
  -F "attachment=@${FILE_PATH}")

if echo "$UPLOAD_RESPONSE" | grep -q '"browser_download_url"'; then
  echo "✅ 上传成功！"
else
  echo "❌ 上传失败！响应：$UPLOAD_RESPONSE"
  exit 1
fi
