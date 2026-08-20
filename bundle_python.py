import os

EXTENSIONS = [
    ".dart",
    ".yaml",
    
]

EXCLUDE_DIRS = {
    ".git",
    ".dart_tool",
    "build",
    ".idea",
    ".vscode",
    "__pycache__",
    "android/.gradle",
    "ios/Pods"
}

OUTPUT_FILE = "ai_flutter_project_bundle.txt"
ROOT_DIR = os.path.abspath(".")


def bundle_project():
    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        out.write("FLUTTER PROJECT BUNDLE\n")
        out.write(f"ROOT: {ROOT_DIR}\n\n")

        for root, dirs, files in os.walk(ROOT_DIR):
            dirs[:] = [
                d for d in dirs
                if d not in EXCLUDE_DIRS and not d.startswith(".")
            ]

            for file in files:
                if any(file.endswith(ext) for ext in EXTENSIONS):
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, ROOT_DIR)

                    out.write("\n" + "=" * 80 + "\n")
                    out.write(f"FILE: {rel_path}\n")
                    out.write("=" * 80 + "\n\n")

                    try:
                        with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                            out.write(f.read())
                    except Exception as e:
                        out.write(f"[ERROR READING FILE: {e}]")


bundle_project()
print("✅ Flutter project dibundle ke ai_flutter_project_bundle.txt")
