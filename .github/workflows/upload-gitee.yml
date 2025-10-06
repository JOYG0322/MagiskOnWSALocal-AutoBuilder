name: Upload Artifacts to Gitee

on:
  workflow_dispatch:        # 允许手动触发
  workflow_run:             # 主构建完成后自动触发
    workflows: ["Build & Release WSA Variants"]
    types:
      - completed

permissions:
  contents: read

jobs:
  upload-to-gitee:
    name: Upload to Gitee Releases
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}

    strategy:
      matrix:
        include:
          - { winver: 10, root: magisk, gapps: none }
          - { winver: 10, root: magisk, gapps: mindthegapps }
          - { winver: 10, root: kernelsu, gapps: none }
          - { winver: 10, root: none, gapps: mindthegapps }
          - { winver: 11, root: magisk, gapps: none }
          - { winver: 11, root: magisk, gapps: mindthegapps }
          - { winver: 11, root: kernelsu, gapps: none }
          - { winver: 11, root: none, gapps: mindthegapps }

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: WSA_${{ matrix.winver }}_${{ matrix.root }}_${{ matrix.gapps }}
          path: ./release

      - name: Setup upload script
        run: chmod +x scripts/upload-gitee.sh

      - name: Upload to Gitee
        env:
          GITEE_USER: JOYG0322                  # 改成你的 Gitee 用户名（区分大小写）
          GITEE_REPO: magisk-on-wsalocal-auto-builder
          GITEE_TOKEN: ${{ secrets.GITEE_TOKEN }}
          TAG_NAME: latest
        run: |
          FILE_PATH=$(find release -name "*.7z" | head -n 1)
          if [ -f "$FILE_PATH" ]; then
            echo "Found file: $FILE_PATH"
            bash scripts/upload-gitee.sh "$GITEE_USER" "$GITEE_REPO" "$TAG_NAME" "$FILE_PATH"
          else
            echo "❌ No .7z file found for ${{ matrix.winver }} ${{ matrix.root }} ${{ matrix.gapps }}"
            exit 1
          fi
