# 推送项目到 GitHub

本项目需要先创建一个 GitHub 远程仓库，才能推送。

## 第一步：在 GitHub 上创建空仓库

1. 登录 GitHub，点击右上角的加号（+），选择 **New repository**。
2. 仓库名称填写 `esp32-wifi-scanner`。
3. 可见性选择 **Private**（私有）或 **Public**（公开）。
4. **不要**勾选“Add a README file”、“Add .gitignore”、“Choose a license”这三项，保持空仓库，避免和本地提交冲突。
5. 点击 **Create repository**。
6. 创建成功后，复制仓库地址。

## 第二步：选择推送地址（建议用 HTTPS）

| 方式 | 地址示例 | 说明 |
| --- | --- | --- |
| HTTPS（推荐） | `https://github.com/你的用户名/esp32-wifi-scanner.git` | 首次推送弹出登录窗口或让你输入令牌，不需要配置密钥 |
| SSH | `git@github.com:你的用户名/esp32-wifi-scanner.git` | 需要先在电脑上配置 SSH 密钥，否则会报 `Permission denied (publickey)` |

如果你的电脑没有配置过 SSH 密钥，**请使用 HTTPS 地址**。

> 注意：你上次使用的地址是 `git@github.com:Aurorapyc/esp32-wifi-scanner.git`，说明仓库建立在 **Aurorapyc** 这个账号下。请确认这是你准备使用的 GitHub 账号，后续生成令牌也要在该账号下操作。

## 第三步：运行推送脚本

1. 双击工作区里的 `setup-git-push.bat`。
2. 提示输入仓库地址时，粘贴 HTTPS 地址。
3. 脚本会自动完成初始化、设置作者（Eiralan <2954564954@qq.com>）、提交、设置远程地址和推送。
4. 如果上次使用了 SSH 地址，脚本检测到 SSH 失败后会自动把远程地址切换成 HTTPS 并重试。

## 第四步：首次推送的登录验证

- 如果弹出 GitHub 登录窗口，正常登录即可。
- 如果命令行提示输入用户名和密码，**密码位置填写 Personal Access Token**，而不是你的 GitHub 登录密码。
  - 生成方法：GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token。
  - 勾选 `repo` 权限，生成后复制 token，粘贴到密码位置。

## 常见问题

**推送被拒绝（non-fast-forward）**

说明远程仓库里已经有文件（例如创建时勾选了 README）。处理方法二选一：

- 删除这个仓库重新建一个空仓库，再运行脚本。
- 或在终端执行 `git pull --rebase origin main` 合并后再推送。

**提示 Git 未安装**

从 https://git-scm.com/download/win 安装 Git for Windows，再运行脚本。

**想要配置 SSH 密钥（可选）**

1. 在终端执行 `ssh-keygen -t ed25519 -C "2954564954@qq.com"`，一路回车。
2. 执行 `type %USERPROFILE%\.ssh\id_ed25519.pub`，复制输出的内容。
3. 在 GitHub → Settings → SSH and GPG keys → New SSH key 粘贴保存。
4. 执行 `ssh -T git@github.com`，看到确认信息即成功。

## 关于本项目已忽略的文件

`.gitignore` 已经配置好，会忽略以下内容，不会提交到仓库：

- 编译产物（`build`、`.pio`）
- 本地会话配置（`.claude`）
- 第三方驱动（`.drivers`）
- 编辑器配置（`.vscode`、`.idea`）
