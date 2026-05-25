"""
Fetch PRoot binaries from Termux packages for Windows.
Extracts proot, loader, and libtalloc from Termux .deb packages
using Python's built-in `ar` module and `tarfile`.
"""
import io
import os
import shutil
import struct
import tarfile
import tempfile
import urllib.request
from pathlib import Path

TERMUX_REPO = "https://packages.termux.dev/apt/termux-main"
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
JNILIBS_DIR = PROJECT_DIR / "flutter_app" / \
    "android" / "app" / "src" / "main" / "jniLibs"
MIRROR_JNILIBS_DIR = PROJECT_DIR / "flutter_app" / "android" / "app" / "jniLibs"

ARCH_MAP = {
    "arm64-v8a": "aarch64",
    "armeabi-v7a": "arm",
    "x86_64": "x86_64",
}

# Packages to fetch: (jni_dir_name, deb_arch, pkg_name)
PACKAGES = [
    ("proot", "proot"),
    ("talloc", "libtalloc"),
]


def read_ar_archive(data: bytes):
    """Parse a .deb (ar archive) and extract file contents."""
    if data[:8] != b"!<arch>\n":
        raise ValueError("Not a valid ar archive")

    pos = 8
    files = {}
    while pos < len(data):
        if pos + 60 > len(data):
            break
        header = data[pos: pos + 60]
        name_raw = header[:16].rstrip(
            b" /").decode("ascii", errors="replace").strip()
        # Parse size (last 10 bytes before magic)
        size_str = header[48:58].decode("ascii", errors="replace").strip()
        try:
            size = int(size_str)
        except ValueError:
            size = 0
        # Skip special entries
        if name_raw in ("", "/", "//", "__.SYMDEF"):
            pos += 60 + size
            if pos % 2:
                pos += 1
            continue
        content = data[pos + 60: pos + 60 + size]
        files[name_raw] = content
        pos += 60 + size
        if pos % 2:
            pos += 1
    return files


def fetch_package(pkg_name: str, deb_arch: str, tmp_dir: Path) -> dict | None:
    """Download a Termux .deb package and return its ar archive contents."""
    # Fetch Packages index to find the .deb filename
    packages_url = f"{TERMUX_REPO}/dists/stable/main/binary-{deb_arch}/Packages"
    print(f"    Fetching package index for {pkg_name} ({deb_arch})...")
    try:
        req = urllib.request.Request(packages_url)
        with urllib.request.urlopen(req, timeout=30) as resp:
            index = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"    ERROR: Failed to fetch package index: {e}")
        return None

    # Find the package entry
    in_pkg = False
    filename = None
    for line in index.splitlines():
        if line.startswith(f"Package: {pkg_name}"):
            in_pkg = True
            continue
        if in_pkg:
            if line.startswith("Filename:"):
                filename = line.split(":", 1)[1].strip()
            if line == "":
                break

    if not filename:
        print(f"    WARN: {pkg_name} not found for {deb_arch}")
        return None

    # Download the .deb file
    deb_url = f"{TERMUX_REPO}/{filename}"
    print(f"    Downloading {pkg_name} from {deb_url}...")
    try:
        req = urllib.request.Request(deb_url)
        with urllib.request.urlopen(req, timeout=60) as resp:
            deb_data = resp.read()
    except Exception as e:
        print(f"    ERROR: Failed to download: {e}")
        return None

    # Parse ar archive
    print(f"    Extracting {pkg_name} ({len(deb_data)} bytes)...")
    files = read_ar_archive(deb_data)
    return files


def extract_data(files: dict) -> bytes | None:
    """Extract data.tar.* from ar archive contents."""
    for name in files:
        if name.startswith("data.tar"):
            content = files[name]
            # Might be xz, gz, or zst compressed
            if name.endswith(".xz"):
                import lzma
                return lzma.decompress(content)
            elif name.endswith(".gz"):
                import gzip
                return gzip.decompress(content)
            elif name.endswith(".zst"):
                print(f"    WARN: zstd compression not supported in Python stdlib")
                return None
            else:
                return content
    return None


def extract_file_from_tar(tar_data: bytes, pattern: str) -> bytes | None:
    """Find and extract a file from a tar archive by pattern."""
    buf = io.BytesIO(tar_data)
    with tarfile.open(fileobj=buf, mode="r|") as tar:
        for member in tar:
            if member.isfile() and pattern in member.name:
                f = tar.extractfile(member)
                if f:
                    return f.read()
    return None


def find_files_in_tar(tar_data: bytes, patterns: list[str]) -> dict[str, bytes]:
    """Find and extract multiple files from a tar archive."""
    results = {}
    buf = io.BytesIO(tar_data)
    with tarfile.open(fileobj=buf, mode="r|") as tar:
        for member in tar:
            if not member.isfile():
                continue
            for pattern in patterns:
                if pattern in member.name:
                    f = tar.extractfile(member)
                    if f:
                        results[member.name] = f.read()
    return results


def fetch_for_abi(jni_abi: str, deb_arch: str):
    """Fetch all needed binaries for one ABI."""
    out_dir = JNILIBS_DIR / jni_abi
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n  [{jni_abi}] Processing...")

    # --- Fetch proot package ---
    print(f"  [{jni_abi}] Fetching proot package...")
    proot_files = fetch_package("proot", deb_arch, Path(tempfile.mkdtemp()))
    if not proot_files:
        return False

    data_tar = extract_data(proot_files)
    if not data_tar:
        return False

    # Find proot binary
    proot_bin = extract_file_from_tar(data_tar, "/bin/proot")
    if proot_bin:
        (out_dir / "libproot.so").write_bytes(proot_bin)
        print(f"  [{jni_abi}] Copied libproot.so ({len(proot_bin)} bytes)")
    else:
        print(f"  [{jni_abi}] ERROR: proot binary not found")

    # Find loader
    loader = extract_file_from_tar(data_tar, "/proot/loader")
    if loader:
        (out_dir / "libprootloader.so").write_bytes(loader)
        print(f"  [{jni_abi}] Copied libprootloader.so ({len(loader)} bytes)")

    # Find loader32 (for 32-bit compat on 64-bit)
    loader32 = extract_file_from_tar(data_tar, "/proot/loader32")
    if loader32:
        (out_dir / "libprootloader32.so").write_bytes(loader32)
        print(f"  [{jni_abi}] Copied libprootloader32.so ({len(loader32)} bytes)")

    # --- Fetch libtalloc package ---
    print(f"  [{jni_abi}] Fetching libtalloc package...")
    talloc_files = fetch_package(
        "libtalloc", deb_arch, Path(tempfile.mkdtemp()))
    if talloc_files:
        talloc_data = extract_data(talloc_files)
        if talloc_data:
            # Find libtalloc.so.* (the actual file, not symlink)
            all_files = find_files_in_tar(talloc_data, ["libtalloc.so"])
            for name, content in all_files.items():
                if not name.endswith(".py"):  # Skip Python files
                    (out_dir / "libtalloc.so").write_bytes(content)
                    print(
                        f"  [{jni_abi}] Copied libtalloc.so ({len(content)} bytes) from {name}")
                    break

    # Show results
    existing = list(out_dir.glob("lib*.so"))
    if existing:
        print(f"  [{jni_abi}] OK — {' '.join(f.name for f in existing)}")
        return True
    else:
        print(f"  [{jni_abi}] FAILED — no binaries extracted")
        return False


def main():
    print("=== Fetching PRoot + libtalloc from Termux packages ===\n")

    success = 0
    failed = 0

    for jni_abi, deb_arch in ARCH_MAP.items():
        if fetch_for_abi(jni_abi, deb_arch):
            success += 1
        else:
            failed += 1

    print(f"\n=== Summary ===")
    print(f"Success: {success} / {len(ARCH_MAP)}")
    if failed:
        print(f"Failed: {failed}")

    print()
    for jni_abi in ARCH_MAP:
        d = JNILIBS_DIR / jni_abi
        if d.exists():
            files = list(d.glob("lib*.so"))
            if files:
                print(f"  {jni_abi}/: {' '.join(f.name for f in files)}")
            else:
                print(f"  {jni_abi}/: (empty)")
        else:
            print(f"  {jni_abi}/: (missing)")


if __name__ == "__main__":
    main()
