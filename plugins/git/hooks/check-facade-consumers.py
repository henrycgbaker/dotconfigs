#!/usr/bin/env python3
# === METADATA ===
# NAME: check-facade-consumers
# TYPE: git-hook
# PLUGIN: git
# DESCRIPTION: Verify every facade __all__ entry has at least one external consumer
# CONFIGURABLE: none
# ================
"""Verify every facade __all__ entry has at least one external consumer.

A "facade" is any ``__init__.py`` under ``src/`` whose body declares
``__all__`` as a list of string literals. Re-exporting a symbol that
nothing imports leaves dead surface in the public API; this check fails
loudly so a contributor either wires up a consumer or removes the entry.

For each ``<module>.<name>`` (where ``<module>`` is the dotted import
path of the facade and ``<name>`` is an entry of ``__all__``), the check
looks for any of the following outside the facade ``__init__.py`` files
themselves:

1. Fully-qualified reference: ``<module>.<name>`` (covers attribute
   access, string references like ``@patch("pkg.mod.func")``, etc.).
2. Direct import: ``from <module> import ...`` plus the bare name in
   the same file (covers single-line and multi-line imports).
3. Module-as-namespace (nested modules only): the parent imports the
   facade module under its last segment, then dots into it, e.g.
   ``from pkg import mod; mod.func()``.

No-op on repos with no facades. Project-agnostic: lives in dotconfigs
and works against any ``src/<project>/.../__init__.py`` layout.
"""

import ast
import re
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(out.stdout.strip())


def get_facade_exports(init_path: Path) -> set[str]:
    tree = ast.parse(init_path.read_text(encoding="utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if (
                    isinstance(target, ast.Name)
                    and target.id == "__all__"
                    and isinstance(node.value, ast.List)
                ):
                    return {
                        elt.value
                        for elt in node.value.elts
                        if isinstance(elt, ast.Constant) and isinstance(elt.value, str)
                    }
    return set()


def module_path(init_path: Path, src_root: Path) -> str:
    rel = init_path.parent.relative_to(src_root)
    return ".".join(rel.parts)


def git_grep_files(pattern: str, root: Path, excludes: list[str]) -> list[str]:
    result = subprocess.run(
        ["git", "grep", "-l", "-P", pattern, "--", ".", *excludes],
        cwd=root,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def has_consumer(name: str, module: str, all_facades: list[Path], root: Path) -> bool:
    name_re = re.escape(name)
    module_re = re.escape(module)
    excludes = [f":(exclude){f.relative_to(root)}" for f in all_facades]

    # 1. Fully-qualified: <module>.<name>
    if git_grep_files(rf"\b{module_re}\.{name_re}\b", root, excludes):
        return True

    # 2. Direct import: file imports <module> AND uses <name> as a word
    files = git_grep_files(rf"from {module_re}\b|import {module_re}\b", root, excludes)
    name_word = re.compile(rf"\b{name_re}\b")
    for f in files:
        try:
            if name_word.search(
                (root / f).read_text(encoding="utf-8", errors="ignore")
            ):
                return True
        except (OSError, UnicodeDecodeError):
            continue

    # 3. Module-as-namespace (nested modules only):
    #    file imports the parent under the facade's last segment, then uses <last>.<name>
    if "." in module:
        parent, last = module.rsplit(".", 1)
        parent_re = re.escape(parent)
        last_re = re.escape(last)
        files = git_grep_files(
            rf"from {parent_re} import [^\n]*\b{last_re}\b|import {module_re}\b",
            root,
            excludes,
        )
        short_use = re.compile(rf"\b{last_re}\.{name_re}\b")
        for f in files:
            try:
                if short_use.search(
                    (root / f).read_text(encoding="utf-8", errors="ignore")
                ):
                    return True
            except (OSError, UnicodeDecodeError):
                continue

    return False


def main() -> int:
    root = repo_root()
    src = root / "src"
    if not src.is_dir():
        return 0

    facades = [p for p in sorted(src.rglob("__init__.py")) if get_facade_exports(p)]
    if not facades:
        return 0

    failures: list[str] = []
    for init in facades:
        module = module_path(init, src)
        for name in sorted(get_facade_exports(init)):
            if not has_consumer(name, module, facades, root):
                failures.append(f"  {init.relative_to(root)}  ->  {module}.{name}")

    if failures:
        sys.stderr.write(
            "Facade orphan exports (in __all__ but no consumer outside facade files):\n"
        )
        sys.stderr.write("\n".join(failures) + "\n")
        sys.stderr.write("\nAdd a real consumer, or remove the entry from __all__.\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
