#!/bin/bash
set -e

FILE="$1"
FILENAME=$(basename "$FILE")
REPO="$GITEE_REPO"
TOKEN="$GITEE_TOKEN"

# 获取最新 Release ID
RELEASE_ID=$(curl -s -H "Authorization: token $TOKEN" \
  "https://gitee.com/api/v5/repos/$REPO/releases/latest" | jq -r .id)

if [ "$RELEASE_ID" == "null" ] || [ -z "$RELEASE_ID" ]; then
  echo "❌ 无法获取 Release ID，请确认 Gitee 仓库中存在一个 Release。"
  exit 1
fi

echo "🎯 目标 Release ID: $RELEASE_ID"
echo "📦 上传文件: $FILENAME"

for i in {1..5}; do
  echo "🔁 第 $i 次尝试上传..."
  RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/gitee_upload.json \
    -X POST "https://gitee.com/api/v5/repos/$REPO/releases/$RELEASE_ID/assets?access_token=$TOKEN" \
    -F "name=$FILENAME" \
    -F "attachment=@$FILE")

  if [ "$RESPONSE" == "201" ] || [ "$RESPONSE" == "200" ]; then
    echo "✅ 上传成功: $FILENAME"
    exit 0
  fi

  echo "⚠️ 上传失败（HTTP $RESPONSE），60 秒后重试..."
  sleep 60
done

echo "❌ 上传失败（已重试 5 次）"
exit 1
