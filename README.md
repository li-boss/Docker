# GardenerOS 实验环境

Windows 实验目录：`G:\GardenerOS`；容器中的对应目录：`/mnt`。

## 配置环境

安装并启动 Docker Desktop，确保使用 Linux containers，然后在 PowerShell 执行：

```powershell
Set-Location G:\GardenerOS
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

脚本创建 `gardeneros-dev` 容器，将当前目录挂载到 `/mnt`，安装 openEuler 开发依赖、Rust nightly、指定工具链 `nightly-2026-05-08`、RISC-V target、cargo-binutils、llvm-tools-preview、rust-src 和 QEMU 11.0.0。验证通过后执行 docker commit，保存为 `myopeneuler`。默认使用 4 个编译任务，可通过 `-BuildJobs 8` 调整。

Cargo 镜像按提供的实际 URL 使用 USTC（科大），使用官方当前支持的 sparse 协议；原说明中的“tuna”与给出的科大 URL 不一致。

安装日志位于 `logs/`，下载缓存位于 `.downloads/`，均不提交 Git。安装脚本可重新执行；遇到失败会停止，不会将失败环境提交为镜像。

## 日常访问

```powershell
docker start gardeneros-dev
docker exec -it gardeneros-dev bash
docker exec gardeneros-dev bash /mnt/verify-container.sh
```

容器使用交互式 bash，也可使用 `docker restart gardeneros-dev` 和 `docker attach gardeneros-dev`。attach 后使用 Ctrl+P、Ctrl+Q 分离，输入 exit 会停止该 shell 和容器。

Windows PowerShell 中使用 `${PWD}` 或完整路径，不能直接照搬 Bash 的 `$(PWD)`：

```powershell
docker run -it --mount "type=bind,source=G:\GardenerOS,destination=/mnt" openeuler/openeuler bash
```

`docker commit` 保存容器内安装的工具，不包含 `/mnt` 的宿主机文件；实验代码由本地 Git 仓库保存。

## Git

远程仓库：<https://github.com/li-boss/Docker>

```powershell
git status
git add .
git commit -m "Update GardenerOS lab"
git push --all origin
```

推送需要有该 GitHub 仓库的访问权限；如果已有远端历史导致拒绝，请先检查并合并，勿强制推送。

## 参考

- [科大 Cargo 镜像说明](https://mirrors.ustc.edu.cn/help/crates.io-index.html)
- [QEMU 11.0.0 发布公告](https://www.qemu.org/2026/04/22/qemu-11-0-0/)
- [Docker Desktop Windows 安装说明](https://docs.docker.com/desktop/setup/install/windows-install/)
