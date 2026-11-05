# Team Contribution & Git Workflow Guide
## Project: Real-Time Bus Ticket Issuing and Seat Availability System
**Team Size:** 4 Students  
**Methodology:** Scrum (3-week sprints)

---

## 1. Branching Strategy

We follow a simplified **GitFlow** branching model designed for 4 team members:

```text
  main (production-ready code at end of sprint)
    ▲
    │ (Pull Request after sprint review)
  develop (active integration branch)
    ▲
    │ (Pull Request + 1 peer review approval)
  feature/RTBT-xx-<short-description>
```

### Permanent Branches:
- **`main`**: Represents fully tested, deliverable sprint releases. No direct commits allowed.
- **`develop`**: Central integration branch for current sprint work. All feature branches merge here via Pull Requests.

### Supporting Branches:
- **`feature/RTBT-xx-<short-name>`**: For individual Jira tasks.
  - *Example:* `feature/RTBT-14-login-role-selection`
  - Always branch off `develop`.
  - Always merge back into `develop`.

---

## 2. Commit Message Standards

Every commit message must begin with the exact Jira ticket identifier so changes automatically link to the Jira Scrum board:

```text
RTBT-<number>: <concise imperative description in lowercase>
```

### Examples:
- `RTBT-8: configure git repository and contributing guide`
- `RTBT-14: implement login and role selection screen`
- `RTBT-18: add visual seat grid widget with status colors`

---

## 3. Pull Request (PR) & Code Review Process

1. **Keep PRs focused:** One PR per Jira story (`RTBT-xx`).
2. **Peer Review Rule:** At least **1 other student team member** must review and approve the PR before merging into `develop`.
3. **PR Checklist for Reviewer:**
   - [ ] Does the code follow standard Flutter folder structure?
   - [ ] Are loading states and error handling present?
   - [ ] Are there any hardcoded credentials or API keys? (Must be zero)
   - [ ] Did the branch build cleanly without syntax errors?
4. **Merge Method:** Use **Squash and Merge** or **Rebase and Merge** to keep git history clean.

---

## 4. Jira Scrum Board Setup

### Board Columns & Statuses:
1. **Backlog / To Do:** Tasks planned for current sprint not yet started.
2. **In Progress:** Developer currently writing code/design. (Limit: Max 1 in-progress task per developer).
3. **In Review / PR:** Code written, PR opened, awaiting peer review and test verification.
4. **Done:** PR merged into `develop`, acceptance criteria validated.

---

## 5. Daily Commands Quick Reference

```bash
# 1. Update local develop branch
git checkout develop
git pull origin develop

# 2. Create a new feature branch for your Jira task
git checkout -b feature/RTBT-14-login-auth

# 3. Work and stage changes
git add .

# 4. Commit using Jira ticket key
git commit -m "RTBT-14: implement login screen and auth provider"

# 5. Push to GitHub
git push -u origin feature/RTBT-14-login-auth
```
