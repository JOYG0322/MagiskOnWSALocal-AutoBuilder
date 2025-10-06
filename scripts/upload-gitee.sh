#!/usr/bin/env bash
set -e

# 参数与环境变量
GITEE_USER="${GITEE_USER:-$1}"
GITEE_REPO="${GITEE_REPO:-$2}"
TAG_NAME="${TAG_NAME:-latest}"
FILE_PATH="${FILE_PATH:-$4}"
API="https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}"

echo "📦 正在上传文件: $(basename "$FILE_PATH")"
echo "➡️ 目标仓库: ${GITEE_USER}/${GITEE_REPO}"
echo "➡️ 标签: ${TAG_NAME}"

# 检查是否已有相同 tag 的 Release
EXISTING_RELEASE=$(curl -s "${API}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}" || true)

if echo "$EXISTING_RELEASE" | grep -q '"id":'; then
  RELEASE_ID=$(echo "$EXISTING_RELEASE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
  echo "🟡 Release 已存在（ID: $RELEASE_ID），更新资源..."
else
  echo "🆕 创建新的 Release..."
  CREATE_RESPONSE=$(curl -s -X POST "${API}/releases" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -d "{
      \"access_token\": \"${GITEE_TOKEN}\",
      \"tag_name\": \"${TAG_NAME}\",
      \"name\": \"${TAG_NAME}\",
      \"body\": \"Auto uploaded from GitHub Actions\",
      \"target_commitish\": \"main\"
    }")

  if echo "$CREATE_RESPONSE" | grep -q '"id":'; then
    RELEASE_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
    echo "✅ 成功创建 Release（ID: $RELEASE_ID）"
  else
    echo "❌ 创建 Release 失败！响应：$CREATE_RESPONSE"
    exit 1
  fi
fi

# 上传文件
echo "⬆️ 正在上传资源到 Gitee Release..."
UPLOAD_RESPONSE=$(curl -s -X POST \
  -F "access_token=${GITEE_TOKEN}" \
  -F "file=@${FILE_PATH}" \
  "${API}/releases/${RELEASE_ID}/assets")

if echo "$UPLOAD_RESPONSE" | grep -q '"id":'; then
  echo "✅ 上传成功！"
else
  echo "❌ 上传失败：$UPLOAD_RESPONSE"
  exit 1
fi
