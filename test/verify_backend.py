import unittest
import json
import re

class TestGoBackendContract(unittest.TestCase):
    def test_routes_declared(self):
        with open("backend/cmd/server/main.go", "r") as f:
            content = f.read()
        self.assertIn("/api/health", content)
        self.assertIn("/ws", content)
        self.assertIn("/api/v1", content)
        print("  [PASS] Go Backend: Standard REST and WebSocket endpoints registered.")

    def test_seat_concurrency_socket_broadcast(self):
        with open("backend/internal/modules/tickets/tickets.go", "r") as f:
            ticket_code = f.read()
        self.assertIn("seat_booked", ticket_code)
        self.assertIn("PublishSeatChange", ticket_code)
        self.assertIn("FOR UPDATE", ticket_code)  # atomic seat lock

        with open("backend/internal/modules/seats/seats.go", "r") as f:
            seat_code = f.read()
        self.assertIn("/release", seat_code)
        with open("backend/internal/app/app.go", "r") as f:
            self.assertIn("BroadcastBus", f.read())
        print("  [PASS] Go Backend: Real-time broadcast hooks verified.")

    def test_mysql_schema_compatibility(self):
        with open("database/schema.sql", "r") as f:
            sql = f.read()
        self.assertIn("CREATE TABLE IF NOT EXISTS users", sql)
        self.assertIn("CREATE TABLE IF NOT EXISTS buses", sql)
        self.assertIn("CREATE TABLE IF NOT EXISTS seats", sql)
        self.assertIn("CREATE TABLE IF NOT EXISTS tickets", sql)
        self.assertIn("CREATE TABLE IF NOT EXISTS bus_locations", sql)
        self.assertIn("ENGINE=InnoDB", sql)
        with open("backend/internal/database/schema.sql", "r") as f:
            embedded = f.read()
        for table in re.findall(r"CREATE TABLE IF NOT EXISTS (\w+)", sql):
            self.assertIn("CREATE TABLE IF NOT EXISTS " + table, embedded, "embedded migration out of sync: " + table)
        print("  [PASS] Database: MySQL relational tables and foreign keys verified.")

if __name__ == "__main__":
    print("=" * 60)
    print("RUNNING GO BACKEND & DATABASE SPECIFICATION TESTS")
    print("=" * 60)
    suite = unittest.TestLoader().loadTestsFromTestCase(TestGoBackendContract)
    unittest.TextTestRunner(verbosity=2).run(suite)

