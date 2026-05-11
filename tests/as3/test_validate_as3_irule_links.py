import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "validate-as3-irule-links.py"
SAMPLE_CONTEXT = REPO_ROOT / "examples" / "as3" / "app-web.context.json"
SAMPLE_IRULES = REPO_ROOT / "examples" / "irules"


def run_cli(*args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )


class ValidateAs3IruleLinksCliTest(unittest.TestCase):
    def test_success_directory_validation(self):
        result = run_cli("--context", "examples/as3/app-web.context.json", "--irules-dir", "examples/irules")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("OK: AS3/iRule references are valid.", result.stdout)
        self.assertIn("warnings:", result.stdout)

    def test_missing_pool_reference_fails(self):
        result = run_cli("--context", "examples/as3/app-web.context.json", "--irule", "examples/broken-irules/broken_missing_pool.tcl")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pool is not defined in AS3 context", result.stdout)

    def test_relative_pool_reference_resolves_from_application_context(self):
        result = run_cli("--context", "examples/as3/app-web.context.json", "--irule", "examples/irules/route_by_uri.tcl")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("pools: 1", result.stdout)

    def test_common_pool_reference_must_exist_in_context(self):
        context = json.loads(SAMPLE_CONTEXT.read_text(encoding="utf-8"))
        app = context["tenants"]["Tenant_Web"]["applications"]["App_Web"]
        app["pools"]["shared_pool"] = "/Common/shared_pool"

        with tempfile.TemporaryDirectory() as tmpdir:
            context_path = Path(tmpdir) / "context.json"
            irule_path = Path(tmpdir) / "route_by_uri.tcl"
            context_path.write_text(json.dumps(context), encoding="utf-8")
            irule_path.write_text("when HTTP_REQUEST {\n  pool /Common/shared_pool\n}\n", encoding="utf-8")
            result = run_cli("--context", str(context_path), "--irule", str(irule_path))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_data_group_reference_is_validated(self):
        result = run_cli("--context", "examples/as3/app-web.context.json", "--irule", "examples/irules/host_datagroup_routing.tcl")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("data groups: 1", result.stdout)

    def test_class_lookup_reference_is_validated(self):
        result = run_cli("--context", "examples/as3/app-web.context.json", "--irule", "examples/irules/uri_to_pool_map.tcl")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("data groups: 1", result.stdout)

    def test_virtual_reference_to_application_service_is_valid(self):
        context = json.loads(SAMPLE_CONTEXT.read_text(encoding="utf-8"))
        app = context["tenants"]["Tenant_Web"]["applications"]["App_Web"]
        app["services"]["legacy_vs"] = {
            "class": "Service_HTTP",
            "virtualAddresses": [],
            "virtualPort": 80,
            "defaultPool": None,
            "attachedIRules": [],
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            context_path = Path(tmpdir) / "context.json"
            irule_path = Path(tmpdir) / "route_by_uri.tcl"
            context_path.write_text(json.dumps(context), encoding="utf-8")
            irule_path.write_text("when HTTP_REQUEST {\n  virtual legacy_vs\n}\n", encoding="utf-8")
            result = run_cli("--context", str(context_path), "--irule", str(irule_path))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_common_virtual_reference_is_warning_only(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            irule_path = Path(tmpdir) / "route_by_uri.tcl"
            irule_path.write_text("when HTTP_REQUEST {\n  virtual /Common/legacy_vs\n}\n", encoding="utf-8")
            result = run_cli("--context", "examples/as3/app-web.context.json", "--irule", str(irule_path))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("/Common virtual reference cannot be validated", result.stdout)

    def test_attached_irule_missing_from_application_is_error(self):
        context = json.loads(SAMPLE_CONTEXT.read_text(encoding="utf-8"))
        context["tenants"]["Tenant_Web"]["applications"]["App_Web"]["services"]["service_web"]["attachedIRules"] = [
            "/Tenant_Web/App_Web/missing_rule"
        ]
        with tempfile.TemporaryDirectory() as tmpdir:
            context_path = Path(tmpdir) / "context.json"
            context_path.write_text(json.dumps(context), encoding="utf-8")
            result = run_cli("--context", str(context_path), "--irules-dir", "examples/irules")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("attached iRule is not defined in application", result.stdout)

    def test_missing_irule_file_is_error(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            irules_dir = Path(tmpdir) / "irules"
            irules_dir.mkdir()
            result = run_cli("--context", "examples/as3/app-web.context.json", "--irules-dir", str(irules_dir))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing iRule file for AS3 definition", result.stdout)

    def test_dynamic_pool_reference_is_warning_and_strict_fails(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            irule_path = Path(tmpdir) / "route_by_uri.tcl"
            irule_path.write_text("when HTTP_REQUEST {\n  pool $target_pool\n}\n", encoding="utf-8")
            relaxed = run_cli("--context", "examples/as3/app-web.context.json", "--irule", str(irule_path))
            strict = run_cli("--context", "examples/as3/app-web.context.json", "--irule", str(irule_path), "--strict")
        self.assertEqual(relaxed.returncode, 0, relaxed.stdout + relaxed.stderr)
        self.assertNotEqual(strict.returncode, 0)
        self.assertIn("dynamic pool reference cannot be statically validated", strict.stdout)

    def test_json_output_reports_errors_and_warnings(self):
        result = run_cli(
            "--context",
            "examples/as3/app-web.context.json",
            "--irule",
            "examples/broken-irules/broken_missing_pool.tcl",
            "--json",
        )
        self.assertNotEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertFalse(payload["ok"])
        self.assertGreaterEqual(len(payload["errors"]), 1)

    def test_missing_data_group_reference_fails(self):
        result = run_cli("--context", "examples/as3/app-web.context.json", "--irule", "examples/broken-irules/broken_missing_datagroup.tcl")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("data group is not defined in AS3 context", result.stdout)
