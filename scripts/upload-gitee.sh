#!/usr/bin/env bash
set -e

USER="$1"
REPO="$2"
TAG="$3"
FILE="$4"

if [ -z "$USER" ] || [ -z "$REPO" ] || [ -z "$TAG" ] || [ -z "$FILE" ]; then
  echo "❌ 参数错误: 用法 upload-gitee.sh <USER> <REPO> <TAG> <FILE>"
  exit 1
fi

echo "🆙 Uploading $FILE to Gitee as tag $TAG"
echo "➡️  目标仓库: $USER/$REPO"
echo "➡️  标签: $TAG"

API="https://gitee.com/api/v5/repos/$USER/$REPO"
TOKEN="$GITEE_TOKEN"

# ---------------------------
# 检查 Tag 是否存在
# ---------------------------
echo "🔍 检查 Tag 是否存在..."
TAG_EXISTS=$(curl -s -H "Content-Type: application/json" \
  "$API/tags/$TAG?access_token=$TOKEN" | grep -c '"name"')

if [ "$TAG_EXISTS" -eq 0 ]; then
  echo "🆕 创建新标签 $TAG..."
  CREATE_TAG=$(curl -s -X POST "$API/tags" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$TAG\",\"ref\":\"main\",\"message\":\"Auto build $TAG\"}" \
    "?access_token=$TOKEN")

  if echo "$CREATE_TAG" | grep -q "refs is missing"; then
    echo "⚠️ 创建 Tag 失败：缺少 ref，请检查分支名是否是 main 或 master"
    exit 1
  elif echo "$CREATE_TAG" | grep -q "\"message\""; then
    echo "⚠️ 创建 Tag 失败：$CREATE_TAG"
  else
    echo "✅ Tag 创建成功"
  fi
else
  echo "✅ Tag 已存在"
fi

# ---------------------------
# 创建 Release
# ---------------------------
echo "🔍 检查 Release 是否存在..."
RELEASE=$(curl -s "$API/releases/tags/$TAG?access_token=$TOKEN")
RELEASE_ID=$(echo "$RELEASE" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2)

if [ -z "$RELEASE_ID" ]; then
  echo "🆕 创建新的 Release..."
  CREATE_RELEASE=$(curl -s -X POST "$API/releases?access_token=$TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"body\":\"Automated build upload\"}")
  RELEASE_ID=$(echo "$CREATE_RELEASE" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2)
  echo "✅ 成功创建 Release（ID: $RELEASE_ID）"
else
  echo "✅ Release 已存在（ID: $RELEASE_ID）"
fi

# ---------------------------
# 上传构建产物
# ---------------------------
echo "📤 上传构建产物（可能需要几分钟，请耐心等待）..."

UPLOAD_URL="$API/releases/$RELEASE_ID/attach_files?access_token=$TOKEN"

curl -X POST "$UPLOAD_URL" \
  -F "file=@$FILE" \
  --progress-bar \
  -o /tmp/upload.log || true

# 检查上传结果
if grep -q "404" /tmp/upload.log; then
  echo "❌ 上传失败：仓库或 Token 无效（404 Not Found）"
  cat /tmp/upload.log
  exit 1
fi

if grep -q '"id":' /tmp/upload.log; then
  echo "✅ 上传完成：$(basename "$FILE")"
else
  echo "⚠️ 上传可能失败，请检查日志："
  cat /tmp/upload.log
fi

# ---------------------------
# 心跳显示 (fake progress)
# ---------------------------
for i in {1..10}; do
  printf "."
  sleep 0.5
done
echo ""
