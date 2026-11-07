"""
Runs the automated tests that prove each sprint's working increment (Agile "Definition of Done").

    python test/run_sprint_tests.py 3          # one sprint
    python test/run_sprint_tests.py all        # whole regression suite (Sprint 6)
    API_URL=http://127.0.0.1:5055 python test/run_sprint_tests.py 4

API tests need the Go backend running against MySQL with demo seed data.
Flutter / admin-web suites run when `flutter` / `npm` are on PATH (or FLUTTER=<path to flutter>).
"""
import os
import shutil
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "test"))

# Sprint -> (e2e API test names, extra suites)
SPRINTS = {
    "3": {
        "goal": "Core infrastructure: Go API on MySQL, JWT roles, bus/route APIs, Flutter on the API",
        "api": ["test_01_auth_and_roles", "test_02_routes_and_buses", "test_03_register_and_approve_bus"],
        "extra": ["spec", "flutter"],
    },
    "4": {
        "goal": "Alpha: seat booking (atomic), payments, conductor issue/free, admin web management",
        "api": ["test_04_concurrent_booking_only_one_wins", "test_05_passenger_buys_and_pays", "test_06_conductor_issue_and_release"],
        "extra": ["flutter", "admin_web"],
    },
    "5": {
        "goal": "Beta: live seat sync, GPS, per-stop ETA, stop events, trips, admin live monitoring",
        "api": ["test_07_gps_eta_and_stop_events", "test_08_admin_overview_and_trip_end"],
        "extra": ["websocket"],
    },
}
SPRINTS["6"] = {
    "goal": "Delivery: full regression of every increment",
    "api": [t for s in ("3", "4", "5") for t in SPRINTS[s]["api"]],
    "extra": ["spec", "flutter", "admin_web", "websocket"],
}


def run(cmd, cwd=ROOT):
    print("  $", " ".join(cmd))
    return subprocess.run(cmd, cwd=cwd, shell=os.name == "nt").returncode == 0


def extra_suite(name):
    if name == "spec":
        return run([sys.executable, "test/verify_backend.py"])
    if name == "websocket":
        env_url = os.environ.get("API_URL", "http://127.0.0.1:5000")
        return run(["node", "test/test_websocket.mjs"]) if shutil.which("node") else skip(name, f"node not found (API {env_url})")
    if name == "flutter":
        flutter = os.environ.get("FLUTTER") or shutil.which("flutter")
        return run([flutter, "test"], cwd=os.path.join(ROOT, "mobile_app")) if flutter else skip(name, "flutter not on PATH")
    if name == "admin_web":
        web = os.path.join(ROOT, "admin_web")
        if not shutil.which("npm"):
            return skip(name, "npm not on PATH")
        if not os.path.isdir(os.path.join(web, "node_modules")):
            run(["npm", "install", "--no-audit", "--no-fund"], cwd=web)
        return run(["npm", "test"], cwd=web) and run(["npm", "run", "build"], cwd=web)
    raise ValueError(name)


def skip(name, why):
    print(f"  [SKIP] {name}: {why}")
    return True


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    sprints = ["6"] if which == "all" else [which]
    ok = True
    for s in sprints:
        spec = SPRINTS[s]
        print("=" * 70)
        print(f"SPRINT {s}: {spec['goal']}")
        print("=" * 70)
        import test_e2e_api

        suite = unittest.TestSuite(test_e2e_api.E2E(name) for name in spec["api"])
        ok &= unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful()
        for extra in spec["extra"]:
            print(f"\n--- {extra} ---")
            ok &= extra_suite(extra)
    print("\nRESULT:", "PASS - increment is shippable" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
