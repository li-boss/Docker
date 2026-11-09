"""Configure a reachable openEuler mirror while retaining downloaded RPMs."""
import os
import shutil
from pathlib import Path
from urllib.parse import urlparse

import dnf


def cache_paths():
    with dnf.Base() as base:
        base.read_all_repos()
        return {repo.id: Path(repo._repo.getCachedir()) for repo in base.repos.iter_enabled()}


mirror = os.environ.get("OPENEULER_MIRROR", "https://mirrors.nju.edu.cn/openeuler").rstrip("/")
parsed = urlparse(mirror)
if parsed.scheme != "https" or not parsed.netloc or parsed.query or parsed.fragment:
    raise SystemExit("OPENEULER_MIRROR must be an HTTPS repository root URL")
repo_file = Path("/etc/yum.repos.d/openEuler.repo")
original = repo_file.read_text()
old_paths = cache_paths()
backup = repo_file.with_suffix(".repo.gardener-backup")
if not backup.exists():
    shutil.copy2(repo_file, backup)
lines = []
for line in original.splitlines():
    if line.startswith("metalink="):
        line = "#" + line
    elif line.startswith(("baseurl=", "gpgkey=")) and "/openEuler-" in line:
        key, _ = line.split("=", 1)
        suffix = line.split("/openEuler-", 1)[1]
        line = f"{key}={mirror}/openEuler-{suffix}"
    lines.append(line)
repo_file.write_text("\n".join(lines) + "\n")
for repo_id, new_path in cache_paths().items():
    old_path = old_paths.get(repo_id)
    if old_path and old_path != new_path and old_path.is_dir():
        shutil.copytree(old_path, new_path, dirs_exist_ok=True)
print(f"openEuler package mirror: {mirror}; GPG verification remains enabled", flush=True)
