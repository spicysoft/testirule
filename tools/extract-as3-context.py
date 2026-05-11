#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


SERVICE_CLASSES = {
    "Service_HTTP",
    "Service_HTTPS",
    "Service_TCP",
    "Service_UDP",
    "Service_L4",
}

DATA_GROUP_CLASSES = {
    "Data_Group",
    "Data_Group_String",
    "Data_Group_Integer",
    "Data_Group_Address",
}


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict:
    if not path.exists():
        fail(f"input file not found: {path}")
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON: {exc}")
    if not isinstance(data, dict):
        fail("invalid AS3 declaration: root JSON value must be an object")
    return data


def full_path(tenant: str, application: str, name: str) -> str:
    return f"/{tenant}/{application}/{name}"


def resolve_reference(value, tenant: str, application: str) -> str | None:
    if isinstance(value, str):
        return full_path(tenant, application, value)
    if isinstance(value, dict) and isinstance(value.get("use"), str):
        return full_path(tenant, application, value["use"])
    return None


def extract_service(service_obj: dict, tenant: str, application: str) -> dict:
    attached_irules = []
    for item in service_obj.get("iRules", []):
        resolved = resolve_reference(item, tenant, application)
        if resolved is not None:
            attached_irules.append(resolved)

    return {
        "class": service_obj.get("class"),
        "virtualAddresses": service_obj.get("virtualAddresses", []),
        "virtualPort": service_obj.get("virtualPort"),
        "defaultPool": resolve_reference(service_obj.get("pool"), tenant, application),
        "attachedIRules": attached_irules,
    }


def extract_application(app_name: str, app_obj: dict, tenant: str) -> dict:
    services = {}
    pools = {}
    irules = {}
    data_groups = {}

    for obj_name, obj in app_obj.items():
        if not isinstance(obj, dict):
            continue
        obj_class = obj.get("class")
        if obj_class in SERVICE_CLASSES:
            services[obj_name] = extract_service(obj, tenant, app_name)
        elif obj_class == "Pool":
            pools[obj_name] = full_path(tenant, app_name, obj_name)
        elif obj_class == "iRule":
            irules[obj_name] = full_path(tenant, app_name, obj_name)
        elif obj_class in DATA_GROUP_CLASSES:
            data_groups[obj_name] = {
                "path": full_path(tenant, app_name, obj_name),
                "class": obj_class,
            }

    return {
        "services": services,
        "pools": pools,
        "iRules": irules,
        "dataGroups": data_groups,
    }


def extract_context(data: dict, source: str) -> dict:
    tenants = {}

    for tenant_name, tenant_obj in data.items():
        if not isinstance(tenant_obj, dict) or tenant_obj.get("class") != "Tenant":
            continue

        applications = {}
        for app_name, app_obj in tenant_obj.items():
            if not isinstance(app_obj, dict) or app_obj.get("class") != "Application":
                continue
            applications[app_name] = extract_application(app_name, app_obj, tenant_name)

        tenants[tenant_name] = {"applications": applications}

    if not tenants:
        fail("invalid AS3 declaration: no Tenant objects found")

    return {
        "source": source,
        "tenants": tenants,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract iRule test context from an AS3 declaration.")
    parser.add_argument("input", help="Path to AS3 declaration JSON")
    parser.add_argument("--output", help="Write extracted context JSON to this file")
    args = parser.parse_args()

    input_path = Path(args.input)
    data = load_json(input_path)
    context = extract_context(data, args.input)
    rendered = json.dumps(context, indent=2, ensure_ascii=False) + "\n"

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)


if __name__ == "__main__":
    main()
