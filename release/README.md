# release — Android 安装包

| 文件 | 说明 |
|---|---|
| `shelf-0.2.5.apk` | Android WebView 壳，版本 0.2.5，包名 `com.shelf.pwa`，3.1 MB，release 签名 |
| `shelf-0.2.5.apk.sha256` | SHA-256 校验值 |

## 安装

1. 下载 `shelf-0.2.5.apk` 到手机；
2. 允许「未知来源」安装；
3. 首次启动填写 shelf 服务器地址，例如 `http://192.168.1.10:8080`；
4. Android 13+ 首次启动需允许通知权限，否则状态栏/锁屏不会出现媒体卡片。

安装前可校验：

```bash
sha256sum -c shelf-0.2.5.apk.sha256
```

> 这是 **release 签名**包。之前安装过 debug 版的设备签名不同，需要先卸载旧 App 再安装。

## GitHub 下载

推送到 GitHub 后，可以直接访问：

```text
https://github.com/Subject2019/shelf-docker/blob/main/release/shelf-0.2.5.apk
```

在文件页点「Download」下载；校验值在同目录的 `.sha256` 文件。

如果要在 GitHub **Releases** 页面发布，可以建一个 `v0.2.5` tag，并把本目录的 APK 作为 release asset 上传。
