# GardenerOS 实验环境

Windows 实验目录：`G:\GardenerOS`；容器中的对应目录：`/mnt`。

当前状态：环境已配置完成，镜像 `myopeneuler:latest`（`9985c4f7e0de`，Author `Di Zhang`）已保存并通过新容器复验，明细见 [SETUP-STATUS.md](SETUP-STATUS.md)。

## 配置环境

安装并启动 Docker Desktop，确保使用 Linux containers，然后在 PowerShell 执行：

```powershell
Set-Location G:\GardenerOS
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

脚本创建 `gardeneros-dev` 容器，将当前目录挂载到 `/mnt`，安装 openEuler 开发依赖、Rust nightly、指定工具链 `nightly-2026-05-08`、RISC-V target、cargo-binutils、llvm-tools-preview、rust-src 和 QEMU 11.0.0。验证通过后执行 docker commit，保存为 `myopeneuler`。默认使用 4 个编译任务，可通过 `-BuildJobs 8` 调整。

Cargo 镜像按提供的实际 URL 使用 USTC（科大），使用官方当前支持的 sparse 协议；原说明中的“tuna”与给出的科大 URL 不一致。

openEuler 软件包默认使用南京大学镜像，保留 GPG 签名校验；原仓库配置有备份，更换镜像时复用已有下载缓存。可通过容器中的 `OPENEULER_MIRROR` 环境变量指定其他 HTTPS 镜像根地址。

安装日志位于 `logs/`，下载缓存位于 `.downloads/`，均不提交 Git。安装脚本可重新执行；遇到失败会停止，不会将失败环境提交为镜像。

若环境安装和验证已经完成，但保存镜像时 Docker 服务中断，先恢复 Docker Desktop，再执行以下命令，仅验证已有容器、保存镜像并验证新镜像：

```powershell
powershell -ExecutionPolicy Bypass -File G:\GardenerOS\setup.ps1 -SaveOnly
```

保存镜像使用 `--no-pause`，执行时请保持实验容器空闲。需要写入镜像作者时加 `-Author "Di Zhang"`，该参数与实验指导中的 `docker commit -a` 等价。

## 故障恢复：WSL 无响应

现象：`wsl -l -v` 与 `wsl --shutdown` 都卡住无输出，Docker Desktop 提示 `WSL is unresponsive`，后端日志出现 `DockerDesktop/Wsl/CommandTimedOut`。此时 Docker 引擎起不来，但容器数据仍在 `G:\GardenerOS-DockerData\disk\docker_data.vhdx`，不要删除该目录。

以管理员身份执行：

```powershell
powershell -ExecutionPolicy Bypass -File G:\GardenerOS\recover-wsl.ps1
```

脚本会强杀 `wslservice`、`vmmemWSL` 等卡死进程并重启 `WSLService`，再用带超时的方式探测发行版列表，日志写入 `logs\wsl-recovery.log`。恢复后如果 `docker-desktop` 发行版不在列表中，用 Docker Desktop 自带的 CLI 重新注册：

```powershell
docker desktop stop
docker desktop start
docker desktop status
```

进程重新拉起后 `docker ps -a` 应能看到 `gardeneros-dev`，再执行 `setup.ps1 -SaveOnly` 保存镜像即可，无需重装依赖或重编 QEMU。

如果 `docker commit` 报 `502` 或引擎假死，优先检查磁盘空间（镜像约需 7 GB 可用空间）与 `--no-pause` 是否生效；提交期间容器应保持空闲。


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
