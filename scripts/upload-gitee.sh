#!/usr/bin/env bash
set -e

USER="$1"
REPO="$2"
TAG="$3"
FILE="$4"

API="https://gitee.com/api/v5/repos/${USER}/${REPO}"
TOKEN="${GITEE_TOKEN}"

echo "📦 正在上传文件: $(basename "$FILE")"
echo "➡️ 目标仓库: ${USER}/${REPO}"
echo "➡️ 标签: ${TAG}"

# 检查 Tag 是否存在
echo "🔍 检查 Tag 是否存在..."
TAG_EXIST=$(curl -s -H "Authorization: token ${TOKEN}" \
  "${API}/tags/${TAG}" | jq -r '.name' 2>/dev/null || true)

if [ "$TAG_EXIST" != "$TAG" ]; then
  echo "🆕 创建新标签 ${TAG}..."
  DEFAULT_BRANCH=$(curl -s -H "Authorization: token ${TOKEN}" "${API}" | jq -r '.default_branch')
  LATEST_COMMIT=$(curl -s -H "Authorization: token ${TOKEN}" "${API}/commits/${DEFAULT_BRANCH}" | jq -r '.sha')

  # ⚙️ 创建 tag（Gitee 必须要 refs 参数）
  CREATE_TAG_RESPONSE=$(curl -s -X POST "${API}/tags" \
    -H "Authorization: token ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"tag_name\": \"${TAG}\",
      \"refs\": \"${LATEST_COMMIT}\",
      \"message\": \"Auto tag ${TAG}\"
    }")

  if echo "$CREATE_TAG_RESPONSE" | grep -q '"message"'; then
    echo "⚠️ 创建 Tag 失败：$CREATE_TAG_RESPONSE"
  else
    echo "✅ Tag 创建成功。"
  fi
else
  echo "✅ Tag 已存在，跳过创建。"
fi

# 检查 Release 是否存在
EXISTING_RELEASE=$(curl -s -H "Authorization: token ${TOKEN}" "${API}/releases/tags/${TAG}" | jq -r '.tag_name' 2>/dev/null || true)

if [ "$EXISTING_RELEASE" == "$TAG" ]; then
  echo "⚠️ Release 已存在，尝试删除旧版本..."
  RELEASE_ID=$(curl -s -H "Authorization: token ${TOKEN}" "${API}/releases/tags/${TAG}" | jq -r '.id')
  curl -s -X DELETE -H "Authorization: token ${TOKEN}" "${API}/releases/${RELEASE_ID}" || true
fi

# 获取默认分支的最新提交
DEFAULT_BRANCH=$(curl -s -H "Authorization: token ${TOKEN}" "${API}" | jq -r '.default_branch')
LATEST_COMMIT=$(curl -s -H "Authorization: token ${TOKEN}" "${API}/commits/${DEFAULT_BRANCH}" | jq -r '.sha')

# 创建 Release（Gitee 必须传 target_commitish）
echo "🆕 创建新的 Release..."
RELEASE_RESPONSE=$(curl -s -X POST "${API}/releases" \
  -H "Authorization: token ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"tag_name\": \"${TAG}\",
    \"target_commitish\": \"${LATEST_COMMIT}\",
    \"name\": \"WSA Auto Build ${TAG}\",
    \"body\": \"Automated upload from GitHub Actions.\"
  }")

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | jq -r '.id')

if [ "$RELEASE_ID" == "null" ] || [ -z "$RELEASE_ID" ]; then
  echo "❌ 创建 Release 失败！响应：${RELEASE_RESPONSE}"
  exit 1
fi

# 上传附件
echo "📤 上传构建产物..."
UPLOAD_RESPONSE=$(curl -s -X POST "${API}/releases/${RELEASE_ID}/attach_files" \
  -H "Authorization: token ${TOKEN}" \
  -F "file=@${FILE}")

if echo "$UPLOAD_RESPONSE" | grep -q '"id"'; then
  echo "✅ 上传成功：$(basename "$FILE")"
else
  echo "⚠️ 上传失败：${UPLOAD_RESPONSE}"
  exit 1
fi
