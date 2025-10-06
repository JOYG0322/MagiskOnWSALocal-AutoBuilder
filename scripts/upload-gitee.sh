  upload_to_gitee:
    name: Upload to Gitee
    runs-on: ubuntu-latest
    needs: build
    if: success()

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Find release file
        id: find_file
        run: |
          FILE_PATH=$(find release -name "*.7z" | head -n 1)
          if [ -z "$FILE_PATH" ]; then
            echo "No .7z file found."
            exit 1
          fi
          echo "file=$FILE_PATH" >> $GITHUB_OUTPUT
          echo "Found file: $FILE_PATH"

      - name: Upload to Gitee Release
        env:
          GITEE_TOKEN: ${{ secrets.GITEE_TOKEN }}
          OWNER: ${{ secrets.GITEE_USER }}
          REPO: ${{ secrets.GITEE_REPO }}
          TAG_NAME: build-${{ github.run_id }}
          FILE_PATH: ${{ steps.find_file.outputs.file }}
        run: |
          set -e
          echo "Uploading $FILE_PATH to Gitee as tag $TAG_NAME"
          echo "Target repo: ${OWNER}/${REPO}"

          DEFAULT_BRANCH=$(curl -s "https://gitee.com/api/v5/repos/${OWNER}/${REPO}?access_token=${GITEE_TOKEN}" | jq -r '.default_branch')
          COMMIT_SHA=$(curl -s "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/commits/${DEFAULT_BRANCH}?access_token=${GITEE_TOKEN}" | jq -r '.sha')

          EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}")
          if [ "$EXISTS" = "200" ]; then
            RELEASE_ID=$(curl -s "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/tags/${TAG_NAME}?access_token=${GITEE_TOKEN}" | jq -r '.id')
            curl -X DELETE "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/${RELEASE_ID}?access_token=${GITEE_TOKEN}"
          else
            curl -X POST \
              -H "Content-Type: application/json;charset=UTF-8" \
              -d "{\"tag_name\":\"${TAG_NAME}\",\"target_commitish\":\"${COMMIT_SHA}\"}" \
              "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/tags?access_token=${GITEE_TOKEN}"
          fi

          curl -X POST \
            -H "Content-Type: application/json;charset=UTF-8" \
            -d "{\"tag_name\":\"${TAG_NAME}\",\"name\":\"${TAG_NAME}\",\"body\":\"Auto-upload from GitHub Actions\"}" \
            "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases?access_token=${GITEE_TOKEN}"

          curl -X POST \
            -H "Content-Type: multipart/form-data" \
            -F "access_token=${GITEE_TOKEN}" \
            -F "file=@${FILE_PATH}" \
            "https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases/assets?tag_name=${TAG_NAME}"

          echo "Upload complete."
