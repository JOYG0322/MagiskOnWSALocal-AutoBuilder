#!/usr/bin/env bash
# ==========================================
# 上传 WSA 构建产物到 Gitee Release
# 支持断点重试、多线程构建兼容、安全上传
# ==========================================

set -e

# 参数检查
if [ $# -lt 4 ]; then
  echo "用法: $0 <GITEE_USER> <GITEE_REPO> <TAG_NAME> <FILE_PATH>"
  exit 1
fi

GITEE_USER="$1"
GITEE_REPO="$2"
TAG_NAME="$3"
FILE_PATH="$4"

# 从环境变量读取 Gitee Token
if [ -z "$GITEE_TOKEN" ]; then
  echo "❌ GITEE_TOKEN 未设置，请在 GitHub Secrets 添加该凭证。"
  exit 1
fi

# 文件检查
if [ ! -f "$FILE_PATH" ]; then
  echo "❌ 找不到文件：$FILE_PATH"
  exit 1
fi

FILE_NAME=$(basename "$FILE_PATH")

echo "📦 正在上传文件: $FILE_NAME"
echo "➡️ 目标仓库: $GITEE_USER/$GITEE_REPO"
echo "➡️ 标签: $TAG_NAME"

# -------------------------
# 创建或更新 Release
# -------------------------
echo "🔍 检查 Gitee Release 是否存在..."
RELEASE_INFO=$(curl -s -H "Authorization: token $GITEE_TOKEN" \
  "https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}/releases/tags/${TAG_NAME}")

if echo "$RELEASE_INFO" | grep -q '"id":'; then
  RELEASE_ID=$(echo "$RELEASE_INFO" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2)
  echo "✅ 已存在 Release（ID: ${RELEASE_ID}）"
else
  echo "🆕 创建新的 Release..."
  CREATE_RESPONSE=$(curl -s -X POST "https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}/releases" \
    -H "Content-Type: application/json" \
    -H "Authorization: token ${GITEE_TOKEN}" \
    -d "{\"tag_name\":\"${TAG_NAME}\",\"name\":\"${TAG_NAME}\",\"body\":\"Auto-uploaded WSA build\"}")

  RELEASE_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2)

  if [ -z "$RELEASE_ID" ]; then
    echo "❌ 创建 Release 失败！响应：$CREATE_RESPONSE"
    exit 1
  fi
  echo "✅ 已创建 Release（ID: ${RELEASE_ID}）"
fi

# -------------------------
# 上传文件（带重试）
# -------------------------
UPLOAD_URL="https://gitee.com/api/v5/repos/${GITEE_USER}/${GITEE_REPO}/releases/${RELEASE_ID}/assets"

MAX_RETRIES=3
RETRY_DELAY=10
ATTEMPT=1

while [ $ATTEMPT -le $MAX_RETRIES ]; do
  echo "🚀 尝试上传（第 $ATTEMPT 次，共 $MAX_RETRIES 次）..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$UPLOAD_URL" \
    -H "Authorization: token ${GITEE_TOKEN}" \
    -F "name=${FILE_NAME}" \
    -F "attachment=@${FILE_PATH}")
  
  BODY=$(echo "$RESPONSE" | head -n1)
  STATUS=$(echo "$RESPONSE" | tail -n1)

  if [ "$STATUS" == "201" ]; then
    echo "✅ 上传成功：$FILE_NAME"
    break
  else
    echo "⚠️ 上传失败（HTTP $STATUS）"
    echo "返回信息: $BODY"
    if [ $ATTEMPT -lt $MAX_RETRIES ]; then
      echo "⏳ 等待 $RETRY_DELAY 秒后重试..."
      sleep $RETRY_DELAY
    fi
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

if
