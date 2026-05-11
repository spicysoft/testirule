import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "extract-as3-context.py"
SAMPLE_INPUT = REPO_ROOT / "examples" / "as3" / "app-web.json"
SAMPLE_OUTPUT = REPO_ROOT / "examples" / "as3" / "app-web.context.json"


def run_cli(*args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )


class ExtractAs3ContextCliTest(unittest.TestCase):
    def test_sample_output_matches_expected(self):
        result = run_cli("examples/as3/app-web.json")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), json.loads(SAMPLE_OUTPUT.read_text(encoding="utf-8")))

    def test_output_option_writes_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output = Path(tmpdir) / "context.json"
            result = run_cli("examples/as3/app-web.json", "--output", str(output))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(output.exists())
            self.assertEqual(json.loads(output.read_text(encoding="utf-8")), json.loads(SAMPLE_OUTPUT.read_text(encoding="utf-8")))

    def test_multiple_tenants_applications_and_services(self):
        payload = {
            "class": "ADC",
            "Tenant_Web": {
                "class": "Tenant",
                "App_Web": {
                    "class": "Application",
                    "service_web": {
                        "class": "Service_HTTP",
                        "pool": "web_pool",
                        "iRules": ["rule_web"],
                    },
                    "service_api": {
                        "class": "Service_HTTPS",
                        "pool": {"use": "api_pool"},
                        "iRules": [{"use": "rule_api"}],
                    },
                    "web_pool": {"class": "Pool"},
                    "api_pool": {"class": "Pool"},
                    "rule_web": {"class": "iRule"},
                    "rule_api": {"class": "iRule"},
                },
                "App_Admin": {
                    "class": "Application",
                    "service_admin": {
                        "class": "Service_TCP"
                    },
                    "admin_pool": {"class": "Pool"},
                },
            },
            "Tenant_Admin": {
                "class": "Tenant",
                "App_Ops": {
                    "class": "Application",
                    "service_ops": {
                        "class": "Service_L4",
                        "pool": "ops_pool",
                    },
                    "ops_pool": {"class": "Pool"},
                    "ops_rule": {"class": "iRule"},
                    "ops_addresses": {"class": "Data_Group_Address"},
                },
            },
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "multi.json"
            input_path.write_text(json.dumps(payload), encoding="utf-8")
            result = run_cli(str(input_path))
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(result.stdout)

        self.assertIn("Tenant_Web", data["tenants"])
        self.assertIn("Tenant_Admin", data["tenants"])
        self.assertIn("App_Web", data["tenants"]["Tenant_Web"]["applications"])
        self.assertIn("App_Admin", data["tenants"]["Tenant_Web"]["applications"])
        self.assertIn("service_web", data["tenants"]["Tenant_Web"]["applications"]["App_Web"]["services"])
        self.assertIn("service_api", data["tenants"]["Tenant_Web"]["applications"]["App_Web"]["services"])
        self.assertEqual(
            data["tenants"]["Tenant_Web"]["applications"]["App_Web"]["services"]["service_api"]["defaultPool"],
            "/Tenant_Web/App_Web/api_pool",
        )
        self.assertEqual(
            data["tenants"]["Tenant_Web"]["applications"]["App_Web"]["services"]["service_api"]["attachedIRules"],
            ["/Tenant_Web/App_Web/rule_api"],
        )
        self.assertEqual(
            data["tenants"]["Tenant_Admin"]["applications"]["App_Ops"]["dataGroups"]["ops_addresses"]["class"],
            "Data_Group_Address",
        )

    def test_service_without_pool_or_irules_is_not_an_error(self):
        payload = {
            "class": "ADC",
            "Tenant_Web": {
                "class": "Tenant",
                "App_Web": {
                    "class": "Application",
                    "service": {
                        "class": "Service_HTTP"
                    }
                },
            },
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "service.json"
            input_path.write_text(json.dumps(payload), encoding="utf-8")
            result = run_cli(str(input_path))
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(result.stdout)

        service = data["tenants"]["Tenant_Web"]["applications"]["App_Web"]["services"]["service"]
        self.assertIsNone(service["defaultPool"])
        self.assertEqual(service["attachedIRules"], [])

    def test_invalid_json_fails(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "broken.json"
            input_path.write_text("{not-json", encoding="utf-8")
            result = run_cli(str(input_path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid JSON", result.stderr)

    def test_missing_file_fails(self):
        result = run_cli("does-not-exist.json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("input file not found", result.stderr)

    def test_missing_tenant_fails(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "no-tenant.json"
            input_path.write_text(json.dumps({"class": "ADC"}), encoding="utf-8")
            result = run_cli(str(input_path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no Tenant objects found", result.stderr)
