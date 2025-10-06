# MagiskOnWSALocal 自动构建仓库

> ⚙️ 本仓库 **不是 [LSPosed/MagiskOnWSALocal](https://github.com/LSPosed/MagiskOnWSALocal) 的 fork**。  
> 仅用于 **自动化构建**，以**避免 GitHub 将 fork 仓库的 Actions 用量计入上游仓库**，  
> 防止上游因大量 fork 构建而被误判为滥用。

[English README](./README.md)

---

## 🧩 目的

- 自动同步上游最新代码  
- 保留自定义工作流文件（如 `build-wsa.yml`、`sync-upstream.yml`）  
- 自动构建并发布多种 WSA 变体（Magisk / KernelSU / GApps 等）  
- 除构建自动化外不作其他修改

---

## ⚖️ 许可证

- 上游源代码：**AGPL-3.0**  
- 构建与同步脚本：**MIT License**

> 基于 [LSPosed/MagiskOnWSALocal](https://github.com/LSPosed/MagiskOnWSALocal)
