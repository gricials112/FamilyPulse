#!/usr/bin/env python3
import json
import sys
from pathlib import Path


CORE_FILES = {
    "ios/FamilyPulse/Services/APIClient.swift",
    "ios/FamilyPulse/Services/AppConfiguration.swift",
    "ios/FamilyPulse/Shared/Models.swift",
}


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print("usage: check_ios_coverage.py <xccov-report.json> [threshold]", file=sys.stderr)
        return 2

    report_path = Path(sys.argv[1])
    threshold = float(sys.argv[2]) if len(sys.argv) == 3 else 0.95
    report = json.loads(report_path.read_text())

    by_file = {}
    for target in report.get("targets", []):
        for entry in target.get("files", []):
            path = entry.get("path", "")
            normalized = path[path.rfind("/ios/") + 1:] if "/ios/" in path else path
            if normalized not in CORE_FILES:
                continue
            current = by_file.get(normalized)
            if current is None or entry.get("lineCoverage", 0) > current.get("lineCoverage", 0):
                by_file[normalized] = entry

    missing = sorted(CORE_FILES - set(by_file))
    if missing:
        print("Missing coverage entries:")
        for path in missing:
            print(f"  - {path}")
        return 1

    covered = sum(int(entry.get("coveredLines", 0)) for entry in by_file.values())
    executable = sum(int(entry.get("executableLines", 0)) for entry in by_file.values())
    coverage = covered / executable if executable else 1.0

    print("iOS core coverage:")
    for path in sorted(by_file):
        entry = by_file[path]
        print(
            f"  {path}: {entry.get('lineCoverage', 0) * 100:.2f}% "
            f"({entry.get('coveredLines', 0)}/{entry.get('executableLines', 0)})"
        )
    print(f"  aggregate: {coverage * 100:.2f}% ({covered}/{executable})")

    if coverage < threshold:
        print(f"Coverage {coverage * 100:.2f}% is below threshold {threshold * 100:.2f}%", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
