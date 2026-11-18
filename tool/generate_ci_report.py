#!/usr/bin/env python3
"""
DukanSpace CI Analysis & Lint Report Generator
Parses output from `flutter analyze` and generates an actionable Markdown report
with exact locations, rule explanations, and fix instructions.
Outputs to GitHub Actions Step Summary ($GITHUB_STEP_SUMMARY) and writes analysis_report.md.
"""

import os
import re
import sys

# Rule-to-fix lookup dictionary
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

def parse_analysis_line(line):
    # Standard flutter analyze format:
    # "  info • Use 'const' with the constructor • lib/views/search_screen.dart:45:12 • prefer_const_constructors"
    # "  warning • Unused import • lib/main.dart:12:8 • unused_import"
    # "  error • Target of URI doesn't exist • lib/foo.dart:1:8 • uri_does_not_exist"
    line = line.strip()
    match = re.match(r'^(error|warning|info)\s+•\s+(.+?)\s+•\s+([^:]+):(\d+):(\d+)\s+•\s+(.+)$', line, re.IGNORECASE)
    if match:
        sev, msg, fpath, row, col, rule = match.groups()
        return {
            'severity': sev.lower(),
            'message': msg.strip(),
            'file': fpath.strip(),
            'line': int(row),
            'column': int(col),
            'rule': rule.strip()
        }
    return None

def generate_report(input_file_path, output_md_path="analysis_report.md"):
    issues = []
    raw_lines = []

    if os.path.exists(input_file_path):
        with open(input_file_path, "r", encoding="utf-8", errors="ignore") as f:
            raw_lines = f.readlines()

    for line in raw_lines:
        parsed = parse_analysis_line(line)
        if parsed:
            issues.append(parsed)

    errors = [i for i in issues if i['severity'] == 'error']
    warnings = [i for i in issues if i['severity'] == 'warning']
    infos = [i for i in issues if i['severity'] == 'info']

    total_issues = len(issues)
    is_success = len(errors) == 0

    # Build Markdown Content
    md = []
    md.append("# 🔍 DukanSpace Static Analysis & Lint Report")
    md.append("")

    if is_success:
        if total_issues == 0:
            md.append("> **Status**: 🟢 **PASSED** - Zero static analysis errors or warnings found!")
        else:
            md.append(f"> **Status**: 🟡 **PASSED WITH NOTICES** - 0 Errors, {len(warnings)} Warnings, {len(infos)} Stylistic Suggestions.")
    else:
        md.append(f"> **Status**: 🔴 **FAILED** - {len(errors)} Error(s), {len(warnings)} Warning(s) detected that must be resolved.")

    md.append("")
    md.append("### Summary Statistics")
    md.append(f"- 🔴 **Errors (Fatal)**: {len(errors)}")
    md.append(f"- 🟡 **Warnings**: {len(warnings)}")
    md.append(f"- 🔵 **Style / Optimizations (Infos)**: {len(infos)}")
    md.append("")

    if issues:
        md.append("### Detailed Issues & Actionable Fix Guide")
        md.append("")
        md.append("| Severity | Location | Rule | Issue Description | Recommended Fix |")
        md.append("| :--- | :--- | :--- | :--- | :--- |")

        for item in issues:
            sev_icon = "🔴" if item['severity'] == 'error' else ("🟡" if item['severity'] == 'warning' else "🔵")
            rule = item['rule']
            fix = FIX_SUGGESTIONS.get(rule, f"Review rule `{rule}` documentation on dart.dev or adjust in `analysis_options.yaml`.")
            loc = f"`{item['file']}:{item['line']}`"
            clean_msg = item['message'].replace('|', '/')
            md.append(f"| {sev_icon} {item['severity'].upper()} | {loc} | `{rule}` | {clean_msg} | {fix} |")

        md.append("")
        md.append("### How to Fix Locally")
        md.append("1. **Automatic formatting**: Run `dart format .` to format all Dart files.")
        md.append("2. **Fix warnings**: Open the referenced file and line numbers in your IDE.")
        md.append("3. **Re-run analysis**: Run `flutter analyze` to verify that 0 errors remain.")
    else:
        md.append("🎉 **All files are clean, strictly typed, and comply with DukanSpace standards!**")

    report_content = "\n".join(md) + "\n"

    # Write output to markdown file
    with open(output_md_path, "w", encoding="utf-8") as out:
        out.write(report_content)
    print(f"✅ Generated analysis report written to: {output_md_path}")

    # Write to GitHub Actions Step Summary if running in CI
    github_summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary_path and os.path.exists(os.path.dirname(github_summary_path)):
        try:
            with open(github_summary_path, "a", encoding="utf-8") as ghs:
                ghs.write("\n" + report_content)
            print(f"✅ Added analysis report to GitHub Step Summary: {github_summary_path}")
        except Exception as e:
            print(f"⚠️ Could not write to GITHUB_STEP_SUMMARY: {e}")

    # Print summary to stdout
    print("-" * 60)
    print(f"Analysis Result: {len(errors)} Errors, {len(warnings)} Warnings, {len(infos)} Infos")
    print("-" * 60)

    return 0 if is_success else 1

if __name__ == "__main__":
    input_file = sys.argv[1] if len(sys.argv) > 1 else "flutter_analysis.txt"
    out_file = sys.argv[2] if len(sys.argv) > 2 else "analysis_report.md"
    sys.exit(generate_report(input_file, out_file))
