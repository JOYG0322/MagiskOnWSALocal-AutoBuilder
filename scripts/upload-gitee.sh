#!/usr/bin/env bash
set -e

GITEE_USER="$1"
GITEE_REPO="$2"
TAG_NAME="$3"
FILE_PATH="$4"

if [[ -z "$GITEE_USER" || -z "$GITEE_REPO" || -z "$TAG_NAME" || -z "$FILE_PATH" ]]; then
  echo "❌ 参数不足：upload-gitee.sh <user> <repo> <tag> <file>"
  exit 1
fi

echo "🆙 Uploading ${FILE_PATH} to Gitee as tag ${TAG_NAME}"
echo "📦 正在上传文件: $(basename "$FILE_PATH")"
echo "➡️ 目标仓库: ${GITEE_USER}/${GITEE_REPO}"
echo "➡️ 标签: ${TAG_NAME}"

API_BASE="https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}"
AUTH_HEADER="Authorization: token ${GITEE_TOKEN}"

# 检查 Tag 是否存在
echo "🔍 检查 Tag 是否存在..."
TAG_RESPONSE=$(curl -s -H "${AUTH_HEADER}" "${API_BASE}/tags/${TAG_NAME}" || true)
if echo "$TAG_RESPONSE" | grep -q "\"name\":\s*\"${TAG_NAME}\""; then
  echo "✅ Tag 已存在：${TAG_NAME}"
else
  echo "🆕 创建新标签 ${TAG_NAME}..."
  CREATE_TAG_RESPONSE=$(curl -s -X POST -H "${AUTH_HEADER}" \
    -d "tag_name=${TAG_NAME}" \
    -d "ref=master" \
    "${API_BASE}/tags")
  if echo "$CREATE_TAG_RESPONSE" | grep -q '"name"'; then
    echo "✅ 成功创建 Tag：${TAG_NAME}"
  else
    echo "⚠️ 创建 Tag 失败：$CREATE_TAG_RESPONSE"
  fi
fi

# 检查 Release 是否存在
echo "🔍 检查 Release 是否存在..."
RELEASE_RESPONSE=$(curl -s -H "${AUTH_HEADER}" "${API_BASE}/releases/tags/${TAG_NAME}" || true)
if echo "$RELEASE_RESPONSE" | grep -q "\"tag_name\":\s*\"${TAG_NAME}\""; then
  echo "✅ Release 已存在，尝试直接上传资源..."
  RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
else
  echo "🆕 创建新的 Release..."
  CREATE_RELEASE_RESPONSE=$(curl -s -X POST -H "${AUTH_HEADER}" \
    -d "tag_name=${TAG_NAME}" \
    -d "target_commitish=master" \
    -d "name=${TAG_NAME}" \
    -d "body=Auto build upload from GitHub Actions" \
    "${API_BASE}/releases")
  if echo "$CREATE_RELEASE_RESPONSE" | grep -q '"id"'; then
    RELEASE_ID=$(echo "$CREATE_RELEASE_RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
    echo "✅ 成功创建 Release（ID: ${RELEASE_ID}）"
  else
    echo "❌ 创建 Release 失败！响应：${CREATE_RELEASE_RESPONSE}"
    exit 1
  fi
fi

# 上传构建产物
echo "📤 上传构建产物（可能需要几分钟，请耐心等待）..."
(
  # 每 10 秒输出一个点作为心跳
  while true; do
    echo -n "·"
    sleep 10
  done
) &
HEARTBEAT_PID=$!

UPLOAD_RESPONSE=$(curl --progress-bar -X POST -H "${AUTH_HEADER}" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@${FILE_PATH}" \
  "${API_BASE}/releases/${RELEASE_ID}/assets" 2>&1)

kill $HEARTBEAT_PID 2>/dev/null || true
echo ""

if echo "$UPLOAD_RESPONSE" | grep -q '"browser_download_url"'; then
  echo "✅ 上传完成！"
else
  echo "❌ 上传失败：${UPLOAD_RESPONSE}"
  exit 1
fi
