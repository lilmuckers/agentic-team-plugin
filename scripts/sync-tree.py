#!/usr/bin/env python3
import argparse
import fnmatch
import os
import shutil
from pathlib import Path


def should_exclude(rel_path: str, patterns: list[str]) -> bool:
    rel_path = rel_path.replace(os.sep, '/')
    if rel_path in ('', '.'):  # root
        return False
    for pattern in patterns:
        if fnmatch.fnmatch(rel_path, pattern) or fnmatch.fnmatch(rel_path + '/', pattern):
            return True
    return False


def copy_tree(src: Path, dst: Path, excludes: list[str]) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()

    for root, dirs, files in os.walk(src):
        root_path = Path(root)
        rel_root = root_path.relative_to(src)
        rel_root_str = '' if str(rel_root) == '.' else str(rel_root).replace(os.sep, '/')

        dirs[:] = [d for d in dirs if not should_exclude(f"{rel_root_str}/{d}".strip('/'), excludes)]

        for file_name in files:
            rel_file = f"{rel_root_str}/{file_name}".strip('/')
            if should_exclude(rel_file, excludes):
                continue
            src_file = root_path / file_name
            dst_file = dst / rel_file
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, dst_file)
            seen.add(rel_file)

    for root, dirs, files in os.walk(dst, topdown=False):
        root_path = Path(root)
        rel_root = root_path.relative_to(dst)
        rel_root_str = '' if str(rel_root) == '.' else str(rel_root).replace(os.sep, '/')

        for file_name in files:
            rel_file = f"{rel_root_str}/{file_name}".strip('/')
            if rel_file not in seen and not should_exclude(rel_file, excludes):
                (root_path / file_name).unlink()

        for dir_name in dirs:
            rel_dir = f"{rel_root_str}/{dir_name}".strip('/')
            dir_path = root_path / dir_name
            if should_exclude(rel_dir, excludes):
                continue
            if not any(dir_path.iterdir()):
                dir_path.rmdir()


def main() -> int:
    parser = argparse.ArgumentParser(description='Sync a tree with exclusion patterns.')
    parser.add_argument('src')
    parser.add_argument('dst')
    parser.add_argument('--exclude', action='append', default=[])
    args = parser.parse_args()

    src = Path(args.src).resolve()
    dst = Path(args.dst).resolve()
    copy_tree(src, dst, args.exclude)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
