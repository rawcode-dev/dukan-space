#!/usr/bin/env python3
"""
DukanSpace CI Analysis & Lint Report Generator
Parses output from `flutter analyze` (supporting both '•' and '-' separators, and all terminals)
Generates an actionable Markdown report with exact locations, rules, and fix instructions.
Always prints the report to stdout so logs are immediately visible in GitHub Actions.
"""

import os
import re
import sys

FIX_SUGGESTIONS = {
    'unused_import': "Remove the unused `import '...'` line, or use the imported class/symbol.",
    'prefer_const_constructors': "Prefix the widget or object constructor with `const` to enable memory caching.",
    'prefer_const_declarations': "Declare the variable with `const` instead of `final` if its value is constant at compile time.",
    'prefer_const_literals_to_create_immutables': "Add `const` before `[...]` or `{...}` literals.",
    'avoid_print': "Replace `print(...)` with `DiagnosticService.instance.logInfo(...)` or `debugPrint(...)`.",
    'use_build_context_synchronously': "Add `if (!mounted) return;` (for State classes) or `if (!context.mounted) return;` immediately after the `await` statement before using `context`.",
    'curly_braces_in_flow_control_structures': "Wrap the body of the `if/else/for/while` statement with `{ ... }`.",
    'empty_catches': "Add an explanatory comment or error log `DiagnosticService.instance.logError(...)` inside the catch block.",
    'missing_required_param': "Pass the required named argument to the constructor or function call.",
    'missing_return': "Ensure all code paths return a value matching the declared return type.",
    'dead_code': "Remove or correct conditions that make this code block unreachable.",
    'avoid_empty_else': "Remove the empty `else;` or supply a body.",
    'avoid_relative_lib_imports': "Use package imports `import 'package:accessory_inventory/...'` instead of `../` reaching outside lib.",
    'await_only_futures': "Remove `await` from an expression that is not a `Future`.",
    'prefer_is_empty': "Use `.isEmpty` instead of `.length == 0`.",
    'prefer_is_not_empty': "Use `.isNotEmpty` instead of `!isEmpty` or `.length > 0`.",
    'unnecessary_string_interpolations': "Use the variable directly instead of `'$variable'`.",
    'unnecessary_new': "Remove the `new` keyword.",
    'unnecessary_const': "Remove redundant `const` inside an already const context.",
}

def parse_line(line):
    line = line.strip()
    if not line:
        return None

    # Matches bullet '•' or dash '-' or pipe '|' separators:
    # "  warning • Unused import: '...' • lib/views/search_screen.dart:3:8 • unused_import"
    # "  warning - Unused import: '...' - lib/views/search_screen.dart:3:8 - unused_import"
    sep_match = re.match(
        r'^(error|warning|info)\s+[\u2022\-\|]\s+(.+?)\s+[\u2022\-\|]\s+([^:]+):(\d+):(\d+)\s+[\u2022\-\|]\s+(.+)$',
        line,
        re.IGNORECASE,
    )
    if sep_match:
        sev, msg, fpath, row, col, rule = sep_match.groups()
        return {
            'severity': sev.lower(),
            'message': msg.strip(),
            'file': fpath.strip(),
            'line': int(row),
            'column': int(col),
            'rule': rule.strip(),
            'raw': line,
        }

    # Matches file-first format:
    # "lib/views/search_screen.dart:3:8: warning: Unused import [unused_import]"
    file_first_match = re.match(
        r'^([^:]+):(\d+):(\d+):\s*(error|warning|info):\s*(.+?)(?:\s*\[([a-zA-Z0-9_]+)\])?$',
        line,
        re.IGNORECASE,
    )
    if file_first_match:
        fpath, row, col, sev, msg, rule = file_first_match.groups()
        return {
            'severity': sev.lower(),
            'message': msg.strip(),
            'file': fpath.strip(),
            'line': int(row),
            'column': int(col),
            'rule': (rule or 'general').strip(),
            'raw': line,
        }

    # Check if line indicates error/warning generally
    lower = line.lower()
    if ('error:' in lower or 'warning:' in lower or 'error •' in lower or 'warning •' in lower):
        sev = 'error' if 'error' in lower else 'warning'
        return {
            'severity': sev,
            'message': line,
            'file': 'codebase',
            'line': 1,
            'column': 1,
            'rule': 'general',
            'raw': line,
        }

    return None


def generate_report(input_file_path, output_md_path="analysis_report.md"):
    raw_lines = []
    if os.path.exists(input_file_path):
        with open(input_file_path, "r", encoding="utf-8", errors="ignore") as f:
            raw_lines = [l.rstrip() for l in f.readlines()]

    issues = []
    for line in raw_lines:
        parsed = parse_line(line)
        if parsed:
            issues.append(parsed)

    errors = [i for i in issues if i['severity'] == 'error']
    warnings = [i for i in issues if i['severity'] == 'warning']
    infos = [i for i in issues if i['severity'] == 'info']

    total_issues = len(issues)
    is_success = len(errors) == 0 and len(warnings) == 0

    md = []
    md.append("# 🔍 DukanSpace Static Analysis & Lint Report")
    md.append("")

    if is_success:
        if total_issues == 0:
            md.append("> **Status**: 🟢 **ALL CHECKS PASSED** - Zero errors and zero warnings found!")
        else:
            md.append(f"> **Status**: 🟢 **PASSED** - 0 Errors, 0 Warnings, {len(infos)} Stylistic Suggestion(s).")
    else:
        md.append(f"> **Status**: 🔴 **FAILED** - {len(errors)} Fatal Error(s), {len(warnings)} Warning(s) detected.")

    md.append("")
    md.append("### Diagnostic Counts")
    md.append(f"- 🔴 **Errors (Fatal)**: {len(errors)}")
    md.append(f"- 🟡 **Warnings (Fatal)**: {len(warnings)}")
    md.append(f"- 🔵 **Style / Optimizations (Informational)**: {len(infos)}")
    md.append("")

    if issues:
        md.append("### Actionable Issues & Recommended Fixes")
        md.append("")
        md.append("| Severity | Location | Rule | Issue Description | Recommended Fix |")
        md.append("| :--- | :--- | :--- | :--- | :--- |")

        for item in issues:
            sev_icon = "🔴" if item['severity'] == 'error' else ("🟡" if item['severity'] == 'warning' else "🔵")
            rule = item['rule']
            fix = FIX_SUGGESTIONS.get(rule, f"Review rule `{rule}` documentation on dart.dev or check `analysis_options.yaml`.")
            loc = f"`{item['file']}:{item['line']}`"
            clean_msg = item['message'].replace('|', '/')
            md.append(f"| {sev_icon} {item['severity'].upper()} | {loc} | `{rule}` | {clean_msg} | {fix} |")

        md.append("")
        md.append("### Raw Analyzer Output")
        md.append("```text")
        for line in raw_lines:
            if line.strip():
                md.append(line)
        md.append("```")
        md.append("")
        md.append("### How to Fix Locally")
        md.append("1. **Remove unused imports / fix syntax**: Open the files and lines listed above.")
        md.append("2. **Format**: Run `dart format .`")
        md.append("3. **Verify**: Run `flutter analyze` to ensure 0 errors and 0 warnings.")
    else:
        md.append("🎉 **No issues found! The codebase is strictly typed, properly imported, and clean.**")
        if raw_lines:
            md.append("")
            md.append("### Raw Analyzer Output")
            md.append("```text")
            for line in raw_lines:
                if line.strip():
                    md.append(line)
            md.append("```")

    report_content = "\n".join(md) + "\n"

    # Always write report file
    with open(output_md_path, "w", encoding="utf-8") as out:
        out.write(report_content)

    # Print entire report to stdout so it appears directly in the GitHub Actions Console Log
    print("=" * 70)
    print("           DUKANSPACE ANALYSIS & LINT REPORT")
    print("=" * 70)
    print(report_content)
    print("=" * 70)

    # Append to GITHUB_STEP_SUMMARY if available
    github_summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary_path:
        try:
            with open(github_summary_path, "a", encoding="utf-8") as ghs:
                ghs.write("\n" + report_content + "\n")
            print(f"✅ Appended report to GITHUB_STEP_SUMMARY: {github_summary_path}")
        except Exception as e:
            print(f"Notice: Could not append to GITHUB_STEP_SUMMARY: {e}")

    return 0 if is_success else 1


if __name__ == "__main__":
    input_file = sys.argv[1] if len(sys.argv) > 1 else "flutter_analysis.txt"
    out_file = sys.argv[2] if len(sys.argv) > 2 else "analysis_report.md"
    sys.exit(generate_report(input_file, out_file))
