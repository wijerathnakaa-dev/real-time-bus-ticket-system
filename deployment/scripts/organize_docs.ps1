Copy-Item "docs/requirements.md" "docs/requirements/requirements.md" -Force
Copy-Item "docs/architecture-and-approval-checklist.md" "docs/architecture/architecture.md" -Force
Copy-Item "docs/database-schema.md" "docs/database/database-schema.md" -Force
Copy-Item "docs/wireframes-passenger.md" "docs/diagrams/wireframes-passenger.md" -Force
Copy-Item "docs/wireframes-conductor.md" "docs/diagrams/wireframes-conductor.md" -Force
Write-Output "Organized docs into subdirectories successfully."

