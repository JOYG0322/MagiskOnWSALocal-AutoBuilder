#!/usr/bin/env bash
set -e

# === 参数 ===
USER="$1"
REPO="$2"
TAG="$3"
FILE="$4"
TOKEN="$GITEE_TOKEN"
API="https://gitee.com/api/v5/repos/$USER/$REPO"

# === 打印基本信息 ===
echo "🆙 Uploading $FILE to Gitee as tag $TAG"
echo "📦 正在上传文件: $(basename "$FILE")"
echo "➡️  目标仓库: $USER/$REPO"
echo "➡️  标签: $TAG"

# === 检查文件存在 ===
if [ ! -f "$FILE" ]; then
  echo "❌ 文件不存在：$FILE"
  exit 1
fi

# === 检测默认分支 ===
echo "🔍 检查默认分支..."
DEFAULT_BRANCH=$(curl -s "$API?access_token=$TOKEN" | grep -oE '"default_branch":"[^"]+' | cut -d'"' -f4)
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH="main"
fi
echo "📄 默认分支: $DEFAULT_BRANCH"

# === 检查 Tag 是否存在（忽略 404） ===
echo "🔍 检查 Tag 是否存在..."
TAG_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/tag_check.json \
  "$API/tags/$TAG?access_token=$TOKEN" || true)

if [ "$TAG_RESPONSE" = "200" ]; then
  echo "✅ Tag 已存在，继续使用。"
else
  echo "🆕 创建新标签 $TAG..."
  CREATE_TAG_RESP=$(curl -s -X POST "$API/tags?access_token=$TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$TAG\",\"ref\":\"$DEFAULT_BRANCH\",\"message\":\"Auto build $TAG\"}" \
    -w "%{http_code}" -o /tmp/create_tag.json || true)

  if [ "$CREATE_TAG_RESP" != "201" ]; then
    echo "⚠️ 创建 Tag 可能失败（HTTP $CREATE_TAG_RESP）："
    cat /tmp/create_tag.json
  else
    echo "✅ 成功创建 Tag。"
  fi
fi

# === 检查 Release 是否存在 ===
echo "🔍 检查 Release 是否存在..."
REL_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/release_check.json \
  "$API/releases/tags/$TAG?access_token=$TOKEN" || true)

if [ "$REL_RESPONSE" = "200" ]; then
  RELEASE_ID=$(jq -r '.id' /tmp/release_check.json)
  echo "✅ Release 已存在（ID: $RELEASE_ID）"
else
  echo "🆕 创建新的 Release..."
  CREATE_REL_RESP=$(curl -s
