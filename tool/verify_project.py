#!/usr/bin/env python3
import glob
import os
import re
import sys

APPROVED_DEPENDENCIES = {
    'flutter',
    'cupertino_icons',
    'sqflite',
    'path_provider',
    'path',
    'file_picker',
    'excel',
    'provider',
    'google_fonts',
    'share_plus',
    'flutter_test',
    'flutter_lints',
}

BANNED_DEPENDENCY_PATTERNS = [
    r'http',
    r'dio',
    r'firebase',
    r'analytics',
    r'advert',
    r'admob',
    r'facebook',
    r'tracking',
    r'telemetry',
    r'socket',
    r'mqtt',
]

def check_dependencies():
    print("[1/5] Checking dependencies in pubspec.yaml...")
    pubspec_path = "pubspec.yaml"
    if not os.path.exists(pubspec_path):
        print("  ❌ pubspec.yaml not found!")
        return False

    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find dependencies section
    in_deps = False
    in_dev_deps = False
    found_deps = []

    for line in content.split("\n"):
        raw_line = line
        line = line.strip()
        if line.startswith("dependencies:"):
            in_deps = True
            in_dev_deps = False
            continue
        elif line.startswith("dev_dependencies:"):
            in_deps = False
            in_dev_deps = True
            continue
        elif not raw_line.startswith(" ") and not raw_line.startswith("\t") and line.endswith(":"):
            in_deps = False
            in_dev_deps = False
            continue

        if (in_deps or in_dev_deps) and ":" in line and not line.startswith("#"):
            pkg = line.split(":")[0].strip()
            if pkg and pkg != "sdk":
                found_deps.append(pkg)

    errors = []
    for dep in found_deps:
        # Check against banned patterns
        for pattern in BANNED_DEPENDENCY_PATTERNS:
            if re.search(pattern, dep, re.IGNORECASE):
                errors.append(f"Disallowed network/tracking dependency found: '{dep}' (matches pattern '{pattern}')")

        # Check against approved allowlist
        if dep not in APPROVED_DEPENDENCIES:
            errors.append(f"Unverified dependency '{dep}' is not in approved allowlist.")

    if errors:
        for err in errors:
            print(f"  ❌ {err}")
        return False

    print(f"  ✅ All {len(found_deps)} dependencies are verified and adhere to offline, zero-tracking policy.")
    return True


def check_security_and_permissions():
    print("[2/5] Checking Android permissions & offline architecture...")
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if not os.path.exists(manifest_path):
        print(f"  ❌ {manifest_path} not found!")
        return False

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = f.read()

    # Verify NO INTERNET permission
    if "android.permission.INTERNET" in manifest:
        print("  ❌ SECURITY CONCERN: android.permission.INTERNET is present in AndroidManifest.xml!")
        print("     DukanSpace is designed as a 100% offline app with zero data leakage.")
        return False

    # Check for excessive dangerous permissions
    dangerous = ["ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "RECORD_AUDIO", "CAMERA", "READ_CONTACTS"]
    for perm in dangerous:
        if f"android.permission.{perm}" in manifest:
            print(f"  ❌ SECURITY CONCERN: Dangerous permission '{perm}' declared in AndroidManifest.xml!")
            return False

    print("  ✅ AndroidManifest.xml confirmed 100% offline (no INTERNET, no telemetry, no tracking permissions).")
    return True


def check_secrets_and_credentials():
    print("[3/5] Scanning codebase for leaked secrets, API keys, and credentials...")
    secret_patterns = [
        (r'-----BEGIN (?:RSA )?PRIVATE KEY-----', 'Private Key'),
        (r'AIzaSy[0-9A-Za-z-_]{33}', 'Google API Key'),
        (r'AKIA[0-9A-Z]{16}', 'AWS Access Key'),
        (r'ghp_[0-9a-zA-Z]{36}', 'GitHub Personal Access Token'),
        (r'bearer\s+[a-zA-Z0-9_\-\.]{40,}', 'Bearer Token'),
    ]

    files_to_scan = glob.glob("lib/**/*.dart", recursive=True) + [
        "pubspec.yaml",
        "android/app/src/main/AndroidManifest.xml"
    ]

    leaks = []
    for fpath in files_to_scan:
        if not os.path.isfile(fpath):
            continue
        with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
        for idx, line in enumerate(lines, 1):
            for pat, desc in secret_patterns:
                if re.search(pat, line):
                    leaks.append(f"{fpath}:{idx} - Potential {desc} detected!")

    if leaks:
        for leak in leaks:
            print(f"  ❌ {leak}")
        return False

    print(f"  ✅ Scanned {len(files_to_scan)} source files. Zero secrets or keys detected.")
    return True


def check_sql_injection_safety():
    print("[4/5] Checking SQL queries for injection vulnerabilities in lib/database/...")
    db_files = glob.glob("lib/database/**/*.dart", recursive=True)
    vulnerabilities = []

    # Look for rawQuery/execute with string interpolation containing variables: rawQuery("... $variable ...")
    # Allowed: table name constants (${DBProvider.tableInventory}), placeholders (?)
    interpolation_pattern = re.compile(r'(?:rawQuery|execute)\s*\(\s*[\'"][^\'"]*\$([a-zA-Z0-9_]+)')

    for fpath in db_files:
        with open(fpath, "r", encoding="utf-8") as f:
            lines = f.readlines()
        for idx, line in enumerate(lines, 1):
            if "rawQuery" in line or "execute" in line:
                # Exclude static table references
                clean = re.sub(r'\$\{?DBProvider\.[a-zA-Z0-9_]+\}?', '', line)
                clean = re.sub(r'\$tableInventory', '', clean)
                clean = re.sub(r'\$tablePhoneModels', '', clean)
                clean = re.sub(r'\$_databaseVersion', '', clean)
                match = interpolation_pattern.search(clean)
                if match:
                    var = match.group(1)
                    vulnerabilities.append(f"{fpath}:{idx} - Unescaped SQL variable interpolation '${var}' detected! Use '?' parameterized queries instead.")

    if vulnerabilities:
        for v in vulnerabilities:
            print(f"  ❌ {v}")
        return False

    print(f"  ✅ All SQL queries in lib/database/ are fully parameterized and safe.")
    return True


def check_code_hygiene():
    print("[5/5] Checking code hygiene, naming, and print statements...")
    dart_files = glob.glob("lib/**/*.dart", recursive=True)
    issues = []

    for fpath in dart_files:
        basename = os.path.basename(fpath)
        # Check snake_case file naming
        if not re.match(r'^[a-z0-9_]+\.dart$', basename):
            issues.append(f"File naming violation: '{fpath}' is not snake_case.")

        with open(fpath, "r", encoding="utf-8") as f:
            lines = f.readlines()

        for idx, line in enumerate(lines, 1):
            trimmed = line.strip()
            # Production code should use DiagnosticService instead of raw print()
            if trimmed.startswith("print(") and not fpath.startswith("lib/services/diagnostic_service.dart"):
                issues.append(f"{fpath}:{idx} - Avoid raw 'print()'. Use DiagnosticService instead.")

    if issues:
        for issue in issues:
            print(f"  ⚠️ {issue}")
        # If any file naming violations, fail
        naming_errors = [i for i in issues if "File naming violation" in i]
        if naming_errors:
            return False

    print(f"  ✅ Checked {len(dart_files)} Dart files for hygiene and clean architecture.")
    return True


def main():
    print("=" * 60)
    print("   DukanSpace CI Pre-Validation & Security Verifier")
    print("=" * 60)

    checks = [
        ("Dependency Hygiene & Offline Allowlist", check_dependencies),
        ("Android Permissions & Offline Architecture", check_security_and_permissions),
        ("Secret, Key & Credential Scanning", check_secrets_and_credentials),
        ("SQL Injection Vulnerability Check", check_sql_injection_safety),
        ("Code Hygiene & Print Scanner", check_code_hygiene),
    ]

    all_passed = True
    report_rows = []

    for name, check_fn in checks:
        passed = check_fn()
        if not passed:
            all_passed = False
        status_icon = "🟢 PASSED" if passed else "🔴 FAILED"
        report_rows.append((name, status_icon))
        print()

    print("=" * 60)
    if all_passed:
        print("  🎉 ALL VERIFICATION CHECKS PASSED SUCCESSFULLY!")
        print("=" * 60)
    else:
        print("  ❌ VERIFICATION CHECKS FAILED. PLEASE FIX THE ISSUES ABOVE.")
        print("=" * 60)

    # Write Markdown summary report
    md = []
    md.append("# 🛡️ DukanSpace Security & Pre-Validation Report")
    md.append("")
    overall_status = "🟢 **PASSED**" if all_passed else "🔴 **FAILED**"
    md.append(f"> **Overall Security & Hygiene Status**: {overall_status}")
    md.append("")
    md.append("| Security / Architecture Gate | Status |")
    md.append("| :--- | :--- |")
    for name, stat in report_rows:
        md.append(f"| {name} | {stat} |")
    md.append("")

    report_path = "verify_project_report.md"
    with open(report_path, "w", encoding="utf-8") as rf:
        rf.write("\n".join(md) + "\n")

    github_summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary_path and os.path.exists(os.path.dirname(github_summary_path)):
        try:
            with open(github_summary_path, "a", encoding="utf-8") as ghs:
                ghs.write("\n" + "\n".join(md) + "\n")
        except Exception:
            pass

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
