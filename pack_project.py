import os
from pathlib import Path

# File types to collect
INCLUDED_EXTENSIONS = {".gd", ".tscn", ".tres"}

# Folders to ignore completely
IGNORED_DIRS = {
    ".godot",
    ".git",
    ".github",
    "export_presets",
    "builds",
    "addons",  # Remove if you want to include third-party plugins
}

OUTPUT_FILE = "project_code_dump.md"


def should_skip(path: Path) -> bool:
    for part in path.parts:
        if part in IGNORED_DIRS or part.startswith("."):
            return True
    return False


def build_tree(root_dir: Path) -> list:
    tree_lines = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Exclude ignored directories in-place
        dirnames[:] = [
            d for d in dirnames if d not in IGNORED_DIRS and not d.startswith(".")
        ]

        current_path = Path(dirpath)
        rel_path = current_path.relative_to(root_dir)

        if rel_path == Path("."):
            depth = 0
            tree_lines.append(f"{root_dir.name}/")
        else:
            depth = len(rel_path.parts)
            tree_lines.append(f"{'  ' * depth}📁 {current_path.name}/")

        filtered_files = [
            f for f in filenames if Path(f).suffix.lower() in INCLUDED_EXTENSIONS
        ]
        for f in sorted(filtered_files):
            tree_lines.append(f"{'  ' * (depth + 1)}📄 {f}")

    return tree_lines


def get_syntax_lang(ext: str) -> str:
    if ext == ".gd":
        return "gdscript"
    return "ini"  # tscn and tres use an INI-like syntax


def pack_project():
    root = Path.cwd()
    collected_files = []

    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in INCLUDED_EXTENSIONS:
            if not should_skip(path):
                collected_files.append(path)

    collected_files.sort()

    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        # Title and file tree
        out.write("# Project Code Dump\n\n")
        out.write("## File Tree\n\n```text\n")
        out.write("\n".join(build_tree(root)))
        out.write("\n```\n\n---\n\n")

        # File contents
        for file_path in collected_files:
            rel_path = file_path.relative_to(root).as_posix()
            ext = file_path.suffix.lower()
            lang = get_syntax_lang(ext)

            out.write(f"## File: `res://{rel_path}`\n\n")
            out.write(f"```{lang}\n")
            try:
                content = file_path.read_text(encoding="utf-8", errors="replace")
                out.write(content.strip())
            except Exception as e:
                out.write(f"# Error reading file: {e}")
            out.write("\n```\n\n---\n\n")

    print(
        f"Done! Collected {len(collected_files)} files into '{OUTPUT_FILE}'."
    )


if __name__ == "__main__":
    pack_project()