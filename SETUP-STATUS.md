# 本机配置状态

更新时间：2026-11-09（北京时间）。

- 实验目录：`G:\GardenerOS`，容器挂载位置：`/mnt`。
- Git 仓库已初始化并推送至 <https://github.com/li-boss/Docker> 的 `main` 分支。
- Docker Desktop 4.98.0 已安装；数据目录为 `G:\GardenerOS-DockerData`。
- 已创建容器 `gardeneros-dev`（ID 前缀 `6e201e4218e7`）。
- openEuler 24.03 LTS-SP4 开发依赖安装完成。
- 默认 nightly 和实验固定版本 `nightly-2026-05-08` 均已安装。
- 固定版本验证：rustc 1.97.0-nightly，cargo 1.97.0-nightly。
- RISC-V target、llvm-tools-preview、rust-src 和 cargo-binutils 0.4.0 已安装。
- RISC-V 裸机目标编译检查通过。
- QEMU 11.0.0 源码构建和安装完成；system 和 linux-user 两个版本检查通过。
- 容器环境验证脚本已通过。

**尚未完成：`myopeneuler` 镜像保存及新镜像验证。** 保存时 Docker API 返回 502，随后 Docker Desktop 启动报残留 `sailor-ingest.sock` 错误，内置重启命令超时。目前不能确认该镜像存在。

请先手动恢复 Docker Desktop（退出后重开；若仍失败则重启 Windows），然后执行：

```powershell
powershell -ExecutionPolicy Bypass -File G:\GardenerOS\setup.ps1 -SaveOnly
```

恢复入口不会重复下载和安装。只有验证容器通过后才会保存镜像，并会新建临时容器验证保存的镜像。
