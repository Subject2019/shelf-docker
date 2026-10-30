<div align="center">
  <img src="./assets/shelf-logo.png" width="150" alt="声架 shelf logo，含 SHELF 字标" />
  <h1>声架 <sub>shelf</sub></h1>
  <p><strong>自托管有声书服务器</strong><br />把有声书放进 NAS，打开浏览器或 Android App 就能听。</p>
  <p>
    <img alt="version" src="https://img.shields.io/badge/version-0.2.7-2f6f4e?style=flat-square" />
    <img alt="docker" src="https://img.shields.io/badge/GHCR-ghcr.io%2Fsubject2019%2Fshelf-2496ED?style=flat-square&logo=docker&logoColor=white" />
    <img alt="android" src="https://img.shields.io/badge/Android-0.2.7-3DDC84?style=flat-square&logo=android&logoColor=white" />
  </p>
</div>

---

**声架**是一个面向 NAS 的自托管有声书服务器。把有声书目录挂载进容器，它会自动扫描标签、章节、CUE 和封面；网页端和 Android App 共用一套书库与播放进度。

整个服务只需要 **一个 Docker 容器 + SQLite**，不需要 Postgres、Redis 或其他外部服务，普通 NAS 就能运行。

> 本仓库是公开的 **Docker 部署仓库**，只包含部署配置、脚本、APK 和校验值；shelf 源码在主项目中维护。

## 快速开始

### 环境要求

- Docker 20.10+
- Docker Compose v2（`docker compose` 命令可用）

### 一键安装

```bash
git clone --depth 1 https://github.com/Subject2019/shelf-docker.git
cd shelf-docker
bash install.sh
```

脚本会依次询问：

1. 媒体目录；
2. 数据目录；
3. 管理员用户名；
4. 宿主机端口；
5. 管理员密码（留空则随机生成）。

完成后打开：

```text
http://<NAS_IP>:<端口>/
```

首次登录后，进入「设置 → 书库」，添加容器内的 `/audiobooks` 即可开始扫描。

> `install.sh` 依赖同目录的 `docker-compose.yaml` 和 `.env.example`，请在仓库根目录运行，不要单独复制脚本执行。

## 在线体验

- 地址：<http://123.56.254.152>
- 用户名：`shelf`
- 密码：`shelf2026`

> 公开演示账号，仅供体验；请勿存放隐私数据。

## 界面预览

<p align="center">
  <img src="./assets/screenshots/01-desktop-home.png" width="49%" alt="声架桌面端首页" />
  <img src="./assets/screenshots/04-desktop-player.png" width="49%" alt="声架桌面端播放页" />
</p>
<p align="center">
  <img src="./assets/screenshots/08-mobile-home.png" width="32%" alt="声架手机端首页" />
  <img src="./assets/screenshots/11-mobile-player.png" width="32%" alt="声架手机端播放页" />
</p>

<details>
<summary>查看更多截图</summary>

### 桌面端

<p align="center">
  <img src="./assets/screenshots/02-desktop-library.png" width="49%" alt="书库" />
  <img src="./assets/screenshots/03-desktop-book.png" width="49%" alt="书籍详情" />
</p>
<p align="center">
  <img src="./assets/screenshots/05-desktop-settings.png" width="49%" alt="设置" />
  <img src="./assets/screenshots/06-desktop-settings-library.png" width="49%" alt="书库设置" />
</p>
<p align="center">
  <img src="./assets/screenshots/07-desktop-authors.png" width="70%" alt="作者视图" />
</p>

### 手机端

<p align="center">
  <img src="./assets/screenshots/09-mobile-library.png" width="32%" alt="手机书库" />
  <img src="./assets/screenshots/10-mobile-book.png" width="32%" alt="手机书籍详情" />
  <img src="./assets/screenshots/12-mobile-settings.png" width="32%" alt="手机设置" />
</p>

</details>

## 功能特性

| 能力 | 说明 |
|---|---|
| 自动扫描 | 识别标题、作者、演播者、系列、内嵌章节、CUE 分轨和封面 |
| 多格式播放 | mp3 / m4a / m4b / aac / flac / ogg / opus / wav；不支持的格式由 ffmpeg 转码 |
| 多端同步 | 同一账号在网页和 Android App 之间同步播放进度、书签和收藏 |
| 原生后台播放 | Android 使用 Media3 前台服务，支持锁屏控制、状态栏进度条和息屏续播 |
| 单容器部署 | 内置 WebUI 和 SQLite，数据目录挂载后即可迁移和备份 |
| 一键升级 | `upgrade.sh` 自动备份数据库、拉取新镜像、重建容器并等待健康检查 |

## Android 客户端

<p align="left">
  <a href="https://github.com/Subject2019/shelf-docker/releases/download/v0.2.7/shelf-0.2.7.apk">
    <img src="https://img.shields.io/badge/下载-Android%200.2.7-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="下载 Android 0.2.7" />
  </a>
</p>

- 包名：`com.shelf.pwa`
- 最新版本：`0.2.7`，release 签名，约 3.1 MB
- 首次启动填写服务器地址；Android 13+ 需要允许通知权限
- 状态栏/锁屏媒体卡片支持上一集、快退 15 秒、播放/暂停、快进 15 秒、下一集
- 当前版本会在系统媒体卡片显示当前单集的播放进度条
- 之前安装过 debug 签名的设备，需要先卸载旧 App
- 校验值与安装说明见 [`release/README.md`](./release/README.md)

## Docker 镜像

| 标签 | 用途 |
|---|---|
| `ghcr.io/subject2019/shelf:0.2.7` | 固定版本，适合生产 |
| `ghcr.io/subject2019/shelf:latest` | 最新构建，适合测试 |

- GHCR 包页面：[shelf](https://github.com/users/Subject2019/packages/container/shelf)
- 公开包可以直接拉取：

```bash
docker pull ghcr.io/subject2019/shelf:0.2.7
```

如果包是 Private，先登录：

```bash
docker login ghcr.io
```

## 升级

在部署目录执行：

```bash
git pull
bash upgrade.sh
```

脚本会：

1. 在线备份数据库和 `secret.key` 到 `backups/`；
2. 拉取最新的 `ghcr.io/subject2019/shelf:latest`；
3. 使用现有 `.env`、媒体目录和数据目录重建容器；
4. 等待健康检查，并打印升级后的版本。

数据目录、媒体挂载、管理员密码和 `.env` 都不会被重置。默认保留最近 5 份升级备份。

跳过升级前备份：

```bash
bash upgrade.sh --no-backup
```

## 卸载

```bash
bash uninstall.sh
```

脚本会停止并移除容器，并询问是否一并移除镜像与数据目录。数据目录删除不可逆，默认保留。

## 手动部署

不使用一键脚本时，可以直接 `docker run`：

```bash
docker run -d --name shelf -p 8080:8080 \
  -v /你的媒体目录:/audiobooks:ro \
  -v /你的数据目录:/data \
  -e ECHOSHELF_ADMIN_USERNAME=admin \
  -e ECHOSHELF_ADMIN_PASSWORD=你的密码 \
  ghcr.io/subject2019/shelf:latest
```

把第一个 `8080` 换成宿主机端口即可自定义访问端口。

## 环境变量

完整配置见 [`.env.example`](./.env.example)，常用项：

| 变量 | 默认 | 说明 |
|---|---|---|
| `AUDIOBOOKS_PATH` | `/volume1/media/audiobooks` | 宿主机媒体目录，**必改**；容器内固定 `/audiobooks:ro` |
| `ECHOSHELF_DATA_PATH` | `/volume1/docker/shelf` | 数据库和缓存目录，必须使用本地盘 |
| `SHELF_HOST_PORT` | `8080` | 宿主机映射端口，容器内固定 8080 |
| `ECHOSHELF_ADMIN_USERNAME` | `admin` | 初始管理员用户名，会自动转小写 |
| `ECHOSHELF_ADMIN_PASSWORD` | 空 | 初始密码，至少 8 位；也可用 `ECHOSHELF_ADMIN_PASSWORD_FILE` |
| `ECHOSHELF_ALLOW_REGISTRATION` | `false` | 是否允许自助注册 |
| `ECHOSHELF_ENABLE_TRANSCODE` | `true` | 是否启用服务端转码，弱机器建议关闭 |
| `PUID` / `PGID` | `1000` | 运行身份，必须对媒体目录有读取权限 |

## 数据持久化

- **数据库/缓存**：`${ECHOSHELF_DATA_PATH}`，卸载后默认保留；删除目录即彻底清理。
- **媒体库**：`${AUDIOBOOKS_PATH}` 以只读方式挂载，shelf 不会修改原始音频文件。

## 常见问题

**GHCR 拉取返回 401？**

先把镜像包设为 Public，或在 NAS 上执行 `docker login ghcr.io`。

**Android 没有媒体卡片或进度条？**

先确认手机允许通知权限，并确认服务端已经升级到 0.2.7。部分 ROM 会折叠媒体卡片，展开后才能看到进度条。

**升级后数据还在吗？**

在。升级只重建容器，`.env`、数据目录和媒体目录都会保留；`upgrade.sh` 会先做在线备份。

**卸载会删除我的有声书吗？**

不会删除媒体文件；数据目录是否删除会在卸载时单独询问。

## 项目结构

```text
shelf-docker/
├── docker-compose.yaml
├── .env.example
├── install.sh
├── upgrade.sh
├── uninstall.sh
├── README.md
├── release/
│   ├── shelf-0.2.7.apk
│   └── shelf-0.2.7.apk.sha256
└── assets/
    ├── shelf-logo.png
    └── screenshots/
```

---

<div align="center">
  <p><strong>声架 · shelf</strong></p>
  <p>自托管有声书服务器 · 单容器 · 多端同步</p>
</div>
