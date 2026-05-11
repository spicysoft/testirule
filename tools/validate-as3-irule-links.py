#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


REFERENCE_RE = re.compile(r"(?m)^\s*(pool|virtual)\s+([^\s\]\};]+)")
CLASS_MATCH_RE = re.compile(
    r"(?m)class\s+match\b.*?\b(?:equals|eq|starts-with|starts_with|ends-with|contains)\s+([^\s\]\};]+)"
)
CLASS_LOOKUP_RE = re.compile(r"(?m)class\s+lookup\s+[^\s]+\s+([^\s\]\};]+)")
CLASS_EXISTS_RE = re.compile(r"(?m)class\s+exists\s+([^\s\]\};]+)")


@dataclass
class Issue:
    level: str
    kind: str
    source: str
    reference: str
    reason: str

    def to_dict(self) -> dict:
        return {
            "level": self.level,
            "kind": self.kind,
            "source": self.source,
            "reference": self.reference,
            "reason": self.reason,
        }


@dataclass
class ApplicationContext:
    tenant: str
    application: str
    pools: dict[str, str]
    services: dict[str, str]
    irules: dict[str, str]
    data_groups: dict[str, str]
    service_attached_irules: dict[str, list[str]]

    @property
    def prefix(self) -> str:
        return f"/{self.tenant}/{self.application}"

    def resolve_relative(self, name: str) -> str:
        return f"{self.prefix}/{name}"


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def load_context(path: Path) -> dict:
    if not path.exists():
        fail(f"context file not found: {path}")
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON: {exc}")
    if not isinstance(data, dict) or not isinstance(data.get("tenants"), dict):
        fail("invalid AS3 context: missing tenants object")
    return data


def build_application_contexts(context: dict) -> list[ApplicationContext]:
    applications: list[ApplicationContext] = []
    for tenant_name, tenant_obj in context["tenants"].items():
        if not isinstance(tenant_obj, dict):
            continue
        applications_obj = tenant_obj.get("applications", {})
        if not isinstance(applications_obj, dict):
            continue
        for app_name, app_obj in applications_obj.items():
            if not isinstance(app_obj, dict):
                continue
            services = {}
            service_attached_irules = {}
            for service_name, service_obj in app_obj.get("services", {}).items():
                if not isinstance(service_name, str) or not isinstance(service_obj, dict):
                    continue
                services[service_name] = f"/{tenant_name}/{app_name}/{service_name}"
                attached = service_obj.get("attachedIRules", [])
                service_attached_irules[service_name] = attached if isinstance(attached, list) else []

            pools = {
                name: path
                for name, path in app_obj.get("pools", {}).items()
                if isinstance(name, str) and isinstance(path, str)
            }
            irules = {
                name: path
                for name, path in app_obj.get("iRules", {}).items()
                if isinstance(name, str) and isinstance(path, str)
            }
            data_groups = {}
            for name, dg_obj in app_obj.get("dataGroups", {}).items():
                if isinstance(name, str) and isinstance(dg_obj, dict) and isinstance(dg_obj.get("path"), str):
                    data_groups[name] = dg_obj["path"]

            applications.append(
                ApplicationContext(
                    tenant=tenant_name,
                    application=app_name,
                    pools=pools,
                    services=services,
                    irules=irules,
                    data_groups=data_groups,
                    service_attached_irules=service_attached_irules,
                )
            )

    if not applications:
        fail("invalid AS3 context: no applications found")
    return applications


def gather_files(irules_dir: Path | None, irule_file: Path | None) -> list[Path]:
    if irules_dir is not None:
        if not irules_dir.exists():
            fail(f"iRules directory not found: {irules_dir}")
        return sorted(path for path in irules_dir.rglob("*.tcl") if path.is_file())
    if irule_file is None or not irule_file.exists():
        fail(f"iRule file not found: {irule_file}")
    return [irule_file]


def normalize_token(token: str) -> str:
    return token.strip().strip("\"{}")


def is_dynamic_reference(token: str) -> bool:
    return token.startswith("$") or token.startswith("[")


def extract_references(content: str) -> dict[str, list[str]]:
    pools: list[str] = []
    virtuals: list[str] = []
    for command, value in REFERENCE_RE.findall(content):
        if command == "pool":
            pools.append(normalize_token(value))
        elif command == "virtual":
            virtuals.append(normalize_token(value))

    data_groups = [normalize_token(value) for value in CLASS_MATCH_RE.findall(content)]
    data_groups.extend(normalize_token(value) for value in CLASS_LOOKUP_RE.findall(content))
    data_groups.extend(normalize_token(value) for value in CLASS_EXISTS_RE.findall(content))

    return {
        "pool": pools,
        "virtual": virtuals,
        "data group": data_groups,
    }


def select_application_for_file(
    path: Path,
    applications: list[ApplicationContext],
    single_file_mode: bool,
) -> tuple[ApplicationContext | None, list[Issue]]:
    stem = path.stem
    matches = [app for app in applications if stem in app.irules]
    if len(matches) == 1:
        return matches[0], []
    if len(matches) > 1:
        return None, [
            Issue(
                level="WARNING",
                kind="application context",
                source=str(path),
                reference=stem,
                reason="multiple AS3 applications define the same iRule name",
            )
        ]
    if single_file_mode and len(applications) == 1:
        return applications[0], []
    return None, [
        Issue(
            level="WARNING",
            kind="application context",
            source=str(path),
            reference=stem,
            reason="cannot resolve relative references without application context",
        )
    ]


def build_existing_paths(applications: list[ApplicationContext]) -> tuple[set[str], set[str], set[str]]:
    pool_paths = {path for app in applications for path in app.pools.values()}
    service_paths = {path for app in applications for path in app.services.values()}
    data_group_paths = {path for app in applications for path in app.data_groups.values()}
    return pool_paths, service_paths, data_group_paths


def validate_reference(
    kind: str,
    source: Path,
    token: str,
    app: ApplicationContext | None,
    existing_paths: set[str],
) -> list[Issue]:
    if is_dynamic_reference(token):
        return [
            Issue(
                level="WARNING",
                kind=f"dynamic {kind}",
                source=str(source),
                reference=token,
                reason=f"dynamic {kind} reference cannot be statically validated",
            )
        ]

    if token.startswith("/Common/") and kind == "virtual":
        return [
            Issue(
                level="WARNING",
                kind="virtual",
                source=str(source),
                reference=token,
                reason="/Common virtual reference cannot be validated from AS3 context alone",
            )
        ]

    if token.startswith("/"):
        resolved = token
    elif app is not None:
        resolved = app.resolve_relative(token)
    else:
        return [
            Issue(
                level="WARNING",
                kind=kind,
                source=str(source),
                reference=token,
                reason="cannot resolve relative reference without application context",
            )
        ]

    if resolved in existing_paths:
        return []

    return [
        Issue(
            level="ERROR",
            kind=kind,
            source=str(source),
            reference=resolved,
            reason=f"{kind} is not defined in AS3 context",
        )
    ]


def validate_irule_file(
    path: Path,
    app: ApplicationContext | None,
    pool_paths: set[str],
    service_paths: set[str],
    data_group_paths: set[str],
) -> tuple[list[Issue], dict[str, int]]:
    content = path.read_text(encoding="utf-8")
    references = extract_references(content)
    issues: list[Issue] = []

    for token in references["pool"]:
        issues.extend(validate_reference("pool", path, token, app, pool_paths))
    for token in references["virtual"]:
        issues.extend(validate_reference("virtual", path, token, app, service_paths))
    for token in references["data group"]:
        issues.extend(validate_reference("data group", path, token, app, data_group_paths))

    return issues, {
        "pools": len(references["pool"]),
        "virtuals": len(references["virtual"]),
        "data groups": len(references["data group"]),
        "iRules": 1,
    }


def validate_attached_irules(applications: list[ApplicationContext]) -> list[Issue]:
    issues: list[Issue] = []
    for app in applications:
        defined_irules = set(app.irules.values())
        for service_name, attached_irules in app.service_attached_irules.items():
            service_path = app.services[service_name]
            for irule_path in attached_irules:
                if irule_path not in defined_irules:
                    issues.append(
                        Issue(
                            level="ERROR",
                            kind="attached iRule",
                            source=service_path,
                            reference=str(irule_path),
                            reason="attached iRule is not defined in application",
                        )
                    )
    return issues


def validate_irule_files_exist(irule_files: list[Path], applications: list[ApplicationContext]) -> list[Issue]:
    issues: list[Issue] = []
    by_stem: dict[str, list[Path]] = {}
    for path in irule_files:
        by_stem.setdefault(path.stem, []).append(path)

    for app in applications:
        for irule_name, irule_path in app.irules.items():
            matches = by_stem.get(irule_name, [])
            if not matches:
                issues.append(
                    Issue(
                        level="ERROR",
                        kind="iRule file",
                        source=irule_path,
                        reference=irule_name,
                        reason=f"missing iRule file for AS3 definition (expected {irule_name}.tcl)",
                    )
                )
            elif len(matches) > 1:
                issues.append(
                    Issue(
                        level="WARNING",
                        kind="iRule file",
                        source=irule_path,
                        reference=irule_name,
                        reason="multiple iRule files match the same AS3 iRule name",
                    )
                )
    return issues


def render_text(errors: list[Issue], warnings: list[Issue], counts: dict[str, int]) -> str:
    lines: list[str] = []
    for issue in errors + warnings:
        lines.extend(
            [
                f"{issue.level}: {issue.kind}",
                f"  source: {issue.source}",
                f"  reference: {issue.reference}",
                f"  reason: {issue.reason}",
                "",
            ]
        )

    if not errors:
        lines.extend(
            [
                "OK: AS3/iRule references are valid.",
                "Checked:",
                f"- pools: {counts['pools']}",
                f"- virtuals: {counts['virtuals']}",
                f"- data groups: {counts['data groups']}",
                f"- iRules: {counts['iRules']}",
            ]
        )
        if warnings:
            lines.append(f"- warnings: {len(warnings)}")

    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate AS3 context references against iRule files.")
    parser.add_argument("--context", required=True, help="Path to extracted AS3 context JSON")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--irules-dir", help="Directory containing iRule Tcl files")
    group.add_argument("--irule", help="Single iRule Tcl file to validate")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as validation failures")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable validation results")
    args = parser.parse_args()

    context = load_context(Path(args.context))
    applications = build_application_contexts(context)
    pool_paths, service_paths, data_group_paths = build_existing_paths(applications)
    all_irule_files = gather_files(Path(args.irules_dir) if args.irules_dir else None, Path(args.irule) if args.irule else None)

    issues: list[Issue] = []
    issues.extend(validate_attached_irules(applications))

    if args.irules_dir:
        issues.extend(validate_irule_files_exist(all_irule_files, applications))
        context_irule_names = {name for app in applications for name in app.irules}
        irule_files = [path for path in all_irule_files if path.stem in context_irule_names]
    else:
        irule_files = all_irule_files

    counts = {"pools": 0, "virtuals": 0, "data groups": 0, "iRules": len(irule_files)}
    for irule_file in irule_files:
        app, app_issues = select_application_for_file(irule_file, applications, single_file_mode=bool(args.irule))
        issues.extend(app_issues)
        file_issues, file_counts = validate_irule_file(irule_file, app, pool_paths, service_paths, data_group_paths)
        issues.extend(file_issues)
        counts["pools"] += file_counts["pools"]
        counts["virtuals"] += file_counts["virtuals"]
        counts["data groups"] += file_counts["data groups"]

    errors = [issue for issue in issues if issue.level == "ERROR"]
    warnings = [issue for issue in issues if issue.level == "WARNING"]
    exit_code = 1 if errors or (args.strict and warnings) else 0

    if args.json:
        payload = {
            "ok": exit_code == 0,
            "strict": args.strict,
            "checked": counts,
            "errors": [issue.to_dict() for issue in errors],
            "warnings": [issue.to_dict() for issue in warnings],
        }
        sys.stdout.write(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    else:
        sys.stdout.write(render_text(errors, warnings, counts))

    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
