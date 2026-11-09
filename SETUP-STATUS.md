# 本机配置状态

更新时间：2026-11-09（北京时间）。状态：**全部完成**。

## 成果

| 项目 | 结果 |
| --- | --- |
| 实验目录（宿主） | `G:\GardenerOS`，容器内挂载为 `/mnt` |
| 基础镜像 | `openeuler/openeuler:latest`（openEuler 24.03 LTS-SP4，`17c15554be2a`） |
| 工作容器 | `gardeneros-dev`（`6e201e4218e7`，Up，交互式 bash） |
| 自建镜像 | `myopeneuler:latest`（`9985c4f7e0de`，Author `Di Zhang`，内容 2.1 GB / 磁盘占用 8.71 GB） |
| 提交时间 | 2026-11-09T03:48:27Z（UTC），提交信息 `New configured environment` |
| Git 远程 | <https://github.com/li-boss/Docker>，`main` 分支 |

## 容器内环境

```
rustc 1.97.0-nightly (f964de49b 2026-05-07)
cargo 1.97.0-nightly (4f9b52075 2026-05-01)
nightly-2026-05-08-x86_64-unknown-linux-gnu (overridden by '/mnt/rust-toolchain')
riscv64gc-unknown-none-elf / llvm-tools / rust-src 已安装
cargo-objdump 0.4.0
QEMU emulator version 11.0.0
qemu-riscv64 version 11.0.0
```

`bash /mnt/verify-container.sh` 在**工作容器**与**由 `myopeneuler` 新建的临时容器**中各执行一次，均输出 `GardenerOS environment verification passed.`，说明镜像内环境可用。

## 与实验指导的差异（均为可用性调整）

1. Cargo 源使用 USTC 的 sparse 索引（`https://mirrors.ustc.edu.cn/crates.io-index/`），而非 tuna；实验指导给出的注册表地址本身就是 USTC。
2. openEuler 软件源改为南京大学镜像并保留 GPG 校验，官方海外源下载超时；原仓库配置已备份。
3. `docker commit` 使用 `--no-pause`（旧写法 `--pause=false` 已弃用），避免提交 6.4 GB 层时暂停容器造成引擎假死。
4. 容器以 `docker run -dit` 创建并保持交互式 bash，等价于实验指导中的 `docker run -it`，但可重复 `docker start` / `docker exec`。

## 已排除的故障

`docker commit` 首次执行时 Docker 引擎返回 502，随后 WSL 服务无响应（`wsl -l -v` 超时、Docker Desktop 报 `WSL is unresponsive`），`docker-desktop` 发行版注册丢失。恢复过程：

1. 以管理员身份运行 `recover-wsl.ps1`：强杀 `wslservice` / `vmmemWSL`，重启 `WSLService`，再带超时探测 `wsl -l -v`（恢复后仅剩 `Ubuntu`）。
2. `docker desktop stop` → `docker desktop start`：Docker Desktop 重新注册 `docker-desktop` 发行版并挂载 `G:\GardenerOS-DockerData\disk\docker_data.vhdx`，容器 `gardeneros-dev` 及其全部安装成果未丢失。
3. `powershell -ExecutionPolicy Bypass -File G:\GardenerOS\setup.ps1 -SaveOnly -Author "Di Zhang"`：验证容器、提交镜像、再用新镜像起临时容器验证。

注意：`G:\GardenerOS-DockerData` 存放 Docker 的 `docker_data.vhdx`（约 8.4 GB），不要删除或移动到网络盘。

## 程序目录迁移（C 盘 → G 盘）

Docker Desktop 的可执行文件原先装在 `C:\Users\Lenovo\AppData\Local\Programs\DockerDesktop`（3.22 GB / 171 个文件），已整体迁移到：

```
G:\Docker\DockerDesktop
```

原路径改为目录联接（junction），因此注册表、快捷方式、`docker-desktop://` 协议、WSL 集成和 Docker 自身的原地更新都继续走同一路径字符串：

```powershell
Get-Item "$env:LOCALAPPDATA\Programs\DockerDesktop" -Force | Select-Object LinkType,Target
# C:\Users\Lenovo\AppData\Local\Programs\DockerDesktop -> G:\Docker\DockerDesktop
```

迁移后验证：引擎 29.9.2 正常启动，`gardeneros-dev` 容器与 `myopeneuler`（`9985c4f7e0de`）、`openeuler/openeuler` 镜像均在，容器内 `rustc 1.97.0-nightly`、`QEMU 11.0.0` 复验通过，C 盘可用空间 30.7 → 33.2 GB。数据盘、WSL 发行版、宿主机仓库目录均未移动。

后续若 Docker Desktop 自动更新后 C 盘又出现实体程序目录（更新器可能重建目录、丢弃联接），重跑一次迁移即可，脚本幂等：

```powershell
powershell -ExecutionPolicy Bypass -File G:\GardenerOS\relocate-docker-desktop.ps1
powershell -ExecutionPolicy Bypass -File G:\GardenerOS\relocate-docker-desktop.ps1 -Restore   # 需要时搬回 C 盘
```

