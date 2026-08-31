# 推送项目到 GitHub

本项目需要先创建一个 GitHub 远程仓库，才能推送。

## 第一步：在 GitHub 上创建空仓库

1. 登录 GitHub，点击右上角的加号（+），选择 **New repository**。
2. 仓库名称建议填写 `esp32-wifi-scanner`。
3. 可见性选择 **Private**（私有）或 **Public**（公开），按你的需要选择。
4. **不要**勾选“Add a README file”、“Add .gitignore”、“Choose a license”这三项，保持空仓库，避免和本地提交冲突。
5. 点击 **Create repository**。
6. 创建成功后，复制仓库地址，形如：

```
https://github.com/Eiralan/esp32-wifi-scanner.git
```

## 第二步：运行推送脚本

1. 双击工作区里的 `setup-git-push.bat`。
2. 提示输入仓库地址时，粘贴上一步复制的地址。
3. 脚本会自动完成初始化、设置作者（Eiralan <2954564954@qq.com>）、提交、设置远程地址和推送。

## 第三步：首次推送的登录验证

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

**推送成功后仓库页没有文件**

刷新浏览器页面。GitHub 页面有缓存，刷新即可看到。

## 关于本项目已忽略的文件

`.gitignore` 已经配置好，会忽略以下内容，不会提交到仓库：

- 编译产物（`build`、`.pio`）
- 本地会话配置（`.claude`）
- 第三方驱动（`.drivers`）
- 编辑器配置（`.vscode`、`.idea`）
