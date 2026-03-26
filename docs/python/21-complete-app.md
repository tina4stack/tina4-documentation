# Chapter 21: Building a Complete App

## 1. Putting It All Together

Twenty chapters of building blocks. Routing. Templates. Databases. ORM. Authentication. Middleware. Queues. WebSocket. Caching. Frontend. GraphQL. Testing. Dev tools. CLI scaffolding. Deployment. Now all of it comes together in one application.

**TaskFlow** -- a task management system with:

- User registration and JWT authentication
- Task creation, assignment, and tracking
- A dashboard with real-time updates
- Email notifications when tasks are assigned
- Caching for dashboard performance
- A full test suite
- Docker deployment

Not a toy project. A complete, production-ready application. Every major Tina4 feature working together.

---

## 2. Planning the App

### Models

| Model | Table | Fields |
|-------|-------|--------|
| User | users | id, name, email, password_hash, role, created_at |
| Task | tasks | id, title, description, status, priority, created_by, assigned_to, due_date, completed_at, created_at, updated_at |

### Relationships

- A User has many Tasks (created by them)
- A User has many Tasks (assigned to them)
- A Task belongs to a User (creator)
- A Task belongs to a User (assignee)

### Routes

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | /api/auth/register | Register a new user | public |
| POST | /api/auth/login | Login, get JWT | public |
| GET | /api/profile | Get current user profile | secured |
| GET | /api/tasks | List tasks (with filters) | secured |
| GET | /api/tasks/{id} | Get a single task | secured |
| POST | /api/tasks | Create a task | secured |
| PUT | /api/tasks/{id} | Update a task | secured |
| DELETE | /api/tasks/{id} | Delete a task | secured |
| GET | /api/dashboard/stats | Dashboard statistics | secured |
| GET | /admin | Dashboard HTML page | public |

### Templates

- `base.html` -- Base layout with sidebar and topbar
- `dashboard.html` -- Dashboard with stats, task list, quick actions
- `login.html` -- Login page
- `register.html` -- Registration page

---

## 3. Step 1: Init Project and Set Up Database

```bash
tina4 init python taskflow
cd taskflow
uv sync
```

Update `.env`:

```env
TINA4_DEBUG=true
SECRET=taskflow-dev-secret-change-in-production
TINA4_TOKEN_EXPIRES_IN=1440
```

### Create Migrations

Create `src/migrations/20260322000100_create_users_table.sql`:

```sql
-- UP
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);

-- DOWN
DROP TABLE IF EXISTS users;
```

Create `src/migrations/20260322000200_create_tasks_table.sql`:

```sql
-- UP
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    priority TEXT NOT NULL DEFAULT 'medium',
    created_by INTEGER NOT NULL,
    assigned_to INTEGER,
    due_date TEXT,
    completed_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id),
    FOREIGN KEY (assigned_to) REFERENCES users(id)
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX idx_tasks_created_by ON tasks(created_by);

-- DOWN
DROP TABLE IF EXISTS tasks;
```

Run migrations:

```bash
tina4 migrate
```

```
Running migrations...
  [UP] 20260322000100_create_users_table.sql
  [UP] 20260322000200_create_tasks_table.sql

  2 migrations applied
```

---

## 4. Step 2: ORM Models

Create `src/orm/user.py`:

```python
from tina4_python.orm import ORM
import hashlib
import hmac
import os

class User(ORM):
    table_name = "users"
    auto_crud = True

    id: int
    name: str
    email: str
    password_hash: str
    role: str
    created_at: str

    def set_password(self, password):
        salt = os.urandom(32)
        key = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100000)
        self.password_hash = salt.hex() + ":" + key.hex()

    def verify_password(self, password):
        if not self.password_hash:
            return False
        salt_hex, key_hex = self.password_hash.split(":")
        salt = bytes.fromhex(salt_hex)
        key = bytes.fromhex(key_hex)
        new_key = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100000)
        return hmac.compare_digest(key, new_key)

    def safe_dict(self):
        data = self.to_dict()
        data.pop("password_hash", None)
        return data
```

Create `src/orm/task.py`:

```python
from tina4_python.orm import ORM

class Task(ORM):
    table_name = "tasks"
    auto_crud = True

    id: int
    title: str
    description: str
    status: str
    priority: str
    created_by: int
    assigned_to: int
    due_date: str
    completed_at: str
    created_at: str
    updated_at: str

    STATUSES = ["pending", "in_progress", "completed", "cancelled"]
    PRIORITIES = ["low", "medium", "high", "urgent"]
```

---

## 5. Step 3: Authentication Routes

Create `src/routes/auth.py`:

```python
from tina4_python.core.router import post, get
from tina4_python.auth import Auth

@post("/api/auth/register")
async def register(request, response):
    body = request.body

    if not body.get("name") or not body.get("email") or not body.get("password"):
        return response({"error": "Name, email, and password are required"}, 400)

    # Check for existing user
    existing = User()
    results = existing.select("*", "email = :email", {"email": body["email"]})
    if results:
        return response({"error": "Email already registered"}, 409)

    user = User()
    user.name = body["name"]
    user.email = body["email"]
    user.set_password(body["password"])
    user.role = "user"
    user.save()

    return response({
        "message": "Registration successful",
        "id": user.id,
        "name": user.name,
        "email": user.email
    }, 201)


@post("/api/auth/login")
async def login(request, response):
    body = request.body

    if not body.get("email") or not body.get("password"):
        return response({"error": "Email and password are required"}, 400)

    user = User()
    results = user.select("*", "email = :email", {"email": body["email"]})

    if not results:
        return response({"error": "Invalid credentials"}, 401)

    user = results[0]
    if not user.verify_password(body["password"]):
        return response({"error": "Invalid credentials"}, 401)

    token = Auth.get_token({
        "user_id": user.id,
        "email": user.email,
        "role": user.role
    })

    return response({
        "token": token,
        "user": user.safe_dict()
    })
```

---

## 6. Step 4: Auth Middleware

Create `src/middleware/auth.py`:

```python
from tina4_python.auth import Auth

async def auth_middleware(request, response, next_handler):
    auth_header = request.headers.get("Authorization", "")

    if not auth_header.startswith("Bearer "):
        return response({"error": "Authentication required"}, 401)

    token = auth_header.replace("Bearer ", "")

    payload = Auth.valid_token(token)
    if payload is None:
        return response({"error": "Invalid or expired token"}, 401)

    request.user = payload
    request.user_id = payload["user_id"]

    return await next_handler(request, response)
```

---

## 7. Step 5: Task CRUD Routes

Create `src/routes/tasks.py`:

```python
from datetime import datetime, timezone
from tina4_python.core.router import get, post, put, delete
from tina4_python.cache import cache_get, cache_set, cache_delete

@get("/api/tasks", middleware=["auth_middleware"])
async def list_tasks(request, response):
    status = request.query.get("status")
    assigned_to = request.query.get("assigned_to")
    page = int(request.query.get("page", 1))
    limit = int(request.query.get("limit", 20))
    offset = (page - 1) * limit

    task = Task()
    where = "1=1"
    params = {}

    if status:
        where += " AND status = :status"
        params["status"] = status
    if assigned_to:
        where += " AND assigned_to = :assigned_to"
        params["assigned_to"] = int(assigned_to)

    tasks = task.select("*", where, params, order_by="created_at DESC",
                        limit=limit, offset=offset)

    return response({
        "tasks": [t.to_dict() for t in tasks],
        "page": page,
        "limit": limit
    })


@get("/api/tasks/{task_id}", middleware=["auth_middleware"])
async def get_task(request, response):
    task_id = request.params["task_id"]

    task = Task()
    task.load(task_id)

    if not task.id:
        return response({"error": "Task not found"}, 404)

    # Load creator and assignee names
    creator = User()
    creator.load(task.created_by)

    result = task.to_dict()
    result["creator_name"] = creator.name if creator.id else "Unknown"

    if task.assigned_to:
        assignee = User()
        assignee.load(task.assigned_to)
        result["assignee_name"] = assignee.name if assignee.id else "Unassigned"

    return response(result)


@post("/api/tasks", middleware=["auth_middleware"])
async def create_task(request, response):
    body = request.body

    if not body.get("title"):
        return response({"error": "Title is required"}, 400)

    task = Task()
    task.title = body["title"]
    task.description = body.get("description", "")
    task.status = body.get("status", "pending")
    task.priority = body.get("priority", "medium")
    task.created_by = request.user_id
    task.assigned_to = body.get("assigned_to")
    task.due_date = body.get("due_date")
    task.save()

    # Invalidate dashboard cache
    cache_delete("dashboard:stats")

    # Send email notification if assigned
    if task.assigned_to:
        await notify_assignee(task)

    # Push WebSocket update
    await push_task_update("created", task)

    return response(task.to_dict(), 201)


@put("/api/tasks/{task_id}", middleware=["auth_middleware"])
async def update_task(request, response):
    task_id = request.params["task_id"]
    body = request.body

    task = Task()
    task.load(task_id)

    if not task.id:
        return response({"error": "Task not found"}, 404)

    if "title" in body:
        task.title = body["title"]
    if "description" in body:
        task.description = body["description"]
    if "status" in body:
        if body["status"] not in Task.STATUSES:
            return response({"error": f"Invalid status. Must be one of: {Task.STATUSES}"}, 400)
        task.status = body["status"]
        if body["status"] == "completed":
            task.completed_at = datetime.now(timezone.utc).isoformat()
    if "priority" in body:
        if body["priority"] not in Task.PRIORITIES:
            return response({"error": f"Invalid priority. Must be one of: {Task.PRIORITIES}"}, 400)
        task.priority = body["priority"]
    if "assigned_to" in body:
        old_assignee = task.assigned_to
        task.assigned_to = body["assigned_to"]
        if body["assigned_to"] != old_assignee and body["assigned_to"]:
            await notify_assignee(task)
    if "due_date" in body:
        task.due_date = body["due_date"]

    task.updated_at = datetime.now(timezone.utc).isoformat()
    task.save()

    # Invalidate dashboard cache
    cache_delete("dashboard:stats")

    # Push WebSocket update
    await push_task_update("updated", task)

    return response(task.to_dict())


@delete("/api/tasks/{task_id}", middleware=["auth_middleware"])
async def delete_task(request, response):
    task_id = request.params["task_id"]

    task = Task()
    task.load(task_id)

    if not task.id:
        return response({"error": "Task not found"}, 404)

    task.delete()

    cache_delete("dashboard:stats")

    return response(None, 204)
```

---

## 8. Step 6: Dashboard Stats with Caching

Create `src/routes/dashboard.py`:

```python
from tina4_python.core.router import get, template
from tina4_python.cache import cache_get, cache_set

@get("/api/dashboard/stats", middleware=["auth_middleware"])
async def dashboard_stats(request, response):
    cached = cache_get("dashboard:stats")
    if cached:
        return response({**cached, "source": "cache"})

    db = Database.get_connection()

    total = db.fetch_one("SELECT COUNT(*) as count FROM tasks")
    pending = db.fetch_one("SELECT COUNT(*) as count FROM tasks WHERE status = 'pending'")
    in_progress = db.fetch_one("SELECT COUNT(*) as count FROM tasks WHERE status = 'in_progress'")
    completed = db.fetch_one("SELECT COUNT(*) as count FROM tasks WHERE status = 'completed'")
    overdue = db.fetch_one(
        "SELECT COUNT(*) as count FROM tasks WHERE due_date < date('now') AND status != 'completed'"
    )
    users = db.fetch_one("SELECT COUNT(*) as count FROM users")

    recent = db.fetch_all(
        "SELECT t.*, u.name as assignee_name FROM tasks t "
        "LEFT JOIN users u ON t.assigned_to = u.id "
        "ORDER BY t.created_at DESC LIMIT 10"
    )

    stats = {
        "total_tasks": total["count"],
        "pending": pending["count"],
        "in_progress": in_progress["count"],
        "completed": completed["count"],
        "overdue": overdue["count"],
        "total_users": users["count"],
        "recent_tasks": recent
    }

    cache_set("dashboard:stats", stats, ttl=30)

    return response({**stats, "source": "database"})


@get("/admin")
async def admin_dashboard(request, response):
    return response(template("dashboard.html"))
```

---

## 9. Step 7: WebSocket Real-Time Updates

Create `src/routes/task_ws.py`:

```python
import json
from tina4_python.core.router import websocket, push_to_websocket

@websocket("/ws/tasks")
async def task_updates(connection, event, data):
    if event == "open":
        await connection.send(json.dumps({
            "type": "connected",
            "message": "Listening for task updates"
        }))

    if event == "message":
        message = json.loads(data)
        if message.get("type") == "ping":
            await connection.send(json.dumps({"type": "pong"}))


async def push_task_update(action, task):
    """Push a task update to all connected WebSocket clients."""
    await push_to_websocket("/ws/tasks", json.dumps({
        "type": "task_update",
        "action": action,
        "task": task.to_dict()
    }))
```

---

## 10. Step 8: Email Notifications

Create `src/routes/notifications.py`:

```python
from tina4_python.messenger import Messenger
from tina4_python.core.router import template

async def notify_assignee(task):
    """Send email notification when a task is assigned."""
    assignee = User()
    assignee.load(task.assigned_to)

    if not assignee.id:
        return

    creator = User()
    creator.load(task.created_by)

    html_body = template("emails/task-assigned.html",
        assignee_name=assignee.name,
        task_title=task.title,
        task_description=task.description or "No description",
        task_priority=task.priority,
        task_due_date=task.due_date or "No due date",
        creator_name=creator.name if creator.id else "Unknown",
        task_url=f"http://localhost:7145/admin#task-{task.id}"
    )

    mailer = Messenger()
    mailer.send(
        to=assignee.email,
        subject=f"Task assigned: {task.title}",
        body=html_body,
        text_body=f"Hi {assignee.name},\n\n"
                  f"{creator.name} assigned you a task: {task.title}\n"
                  f"Priority: {task.priority}\n"
                  f"Due: {task.due_date or 'No due date'}\n\n"
                  f"Description:\n{task.description or 'No description'}"
    )
```

Create `src/templates/emails/task-assigned.html`:

```html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <div style="background: #1a1a2e; color: white; padding: 20px; text-align: center;">
        <h2 style="margin: 0;">New Task Assigned</h2>
    </div>
    <div style="padding: 20px; background: white;">
        <p>Hi {{ assignee_name }},</p>
        <p><strong>{{ creator_name }}</strong> assigned you a new task:</p>

        <div style="background: #f8f9fa; padding: 16px; border-radius: 8px; border-left: 4px solid #1a1a2e;">
            <h3 style="margin-top: 0;">{{ task_title }}</h3>
            <p>{{ task_description }}</p>
            <table style="width: 100%;">
                <tr><td><strong>Priority:</strong></td><td>{{ task_priority }}</td></tr>
                <tr><td><strong>Due:</strong></td><td>{{ task_due_date }}</td></tr>
            </table>
        </div>

        <p style="margin-top: 16px;">
            <a href="{{ task_url }}" style="background: #1a1a2e; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px;">
                View Task
            </a>
        </p>
    </div>
</body>
</html>
```

---

## 11. Step 9: Dashboard Template

Create `src/templates/dashboard.html`:

```html
{% extends "base.html" %}

{% block title %}TaskFlow Dashboard{% endblock %}

{% block content %}
<h1>Dashboard</h1>

<div id="stats" class="row mb-4">
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">Total</h6><h2 id="stat-total">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">Pending</h6><h2 id="stat-pending">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">In Progress</h6><h2 id="stat-progress">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">Completed</h6><h2 id="stat-completed">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">Overdue</h6><h2 id="stat-overdue" class="text-danger">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">Users</h6><h2 id="stat-users">--</h2>
    </div></div></div>
</div>

<div class="row">
    <div class="col-md-8">
        <div class="card">
            <div class="card-header d-flex justify-content-between">
                <span>Recent Tasks</span>
                <button class="btn btn-sm btn-primary" data-toggle="modal" data-target="#newTaskModal">
                    New Task
                </button>
            </div>
            <div class="card-body">
                <table class="table table-striped" id="task-table">
                    <thead>
                        <tr><th>Title</th><th>Assignee</th><th>Priority</th><th>Status</th></tr>
                    </thead>
                    <tbody id="task-list"></tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card">
            <div class="card-header">Live Updates</div>
            <div class="card-body" id="live-updates" style="height: 300px; overflow-y: auto;">
                <p class="text-muted">Connecting...</p>
            </div>
        </div>
    </div>
</div>

<script src="/js/frond.js"></script>
<script>
    const token = localStorage.getItem("token");
    if (token) frond.setToken(token);

    // Load dashboard stats
    frond.get("/api/dashboard/stats", function (data) {
        document.getElementById("stat-total").textContent = data.total_tasks;
        document.getElementById("stat-pending").textContent = data.pending;
        document.getElementById("stat-progress").textContent = data.in_progress;
        document.getElementById("stat-completed").textContent = data.completed;
        document.getElementById("stat-overdue").textContent = data.overdue;
        document.getElementById("stat-users").textContent = data.total_users;

        const tbody = document.getElementById("task-list");
        tbody.innerHTML = "";
        (data.recent_tasks || []).forEach(function (task) {
            const tr = document.createElement("tr");
            const badgeColor = {pending: "secondary", in_progress: "warning",
                               completed: "success", cancelled: "danger"};
            tr.innerHTML = "<td>" + task.title + "</td>" +
                "<td>" + (task.assignee_name || "Unassigned") + "</td>" +
                "<td>" + task.priority + "</td>" +
                "<td><span class='badge bg-" + (badgeColor[task.status] || "secondary") +
                "'>" + task.status + "</span></td>";
            tbody.appendChild(tr);
        });
    });

    // WebSocket for live updates
    const ws = frond.ws("/ws/tasks");
    const updates = document.getElementById("live-updates");

    ws.on("open", function () {
        updates.innerHTML = "<p class='text-success'>Connected - listening for updates</p>";
    });

    ws.on("message", function (raw) {
        const msg = JSON.parse(raw);
        if (msg.type === "task_update") {
            const div = document.createElement("div");
            div.style.marginBottom = "8px";
            div.innerHTML = "<strong>" + msg.action + ":</strong> " + msg.task.title;
            updates.prepend(div);

            // Refresh stats
            frond.get("/api/dashboard/stats", function () {});
        }
    });
</script>
{% endblock %}
```

---

## 12. Step 10: Tests

Create `tests/test_taskflow.py`:

```python
import uuid
import json
from tina4_python.test import Test, assert_equal, assert_true, assert_not_none

class TaskFlowTest(Test):

    def _register_and_login(self):
        email = f"test-{uuid.uuid4().hex[:8]}@example.com"
        self.post("/api/auth/register", {
            "name": "Test User",
            "email": email,
            "password": "TestPassword123!"
        })
        login_resp = self.post("/api/auth/login", {
            "email": email,
            "password": "TestPassword123!"
        })
        return json.loads(login_resp.body)["token"]

    def test_register(self):
        resp = self.post("/api/auth/register", {
            "name": "Alice",
            "email": f"alice-{uuid.uuid4().hex[:8]}@example.com",
            "password": "SecurePass123!"
        })
        assert_equal(resp.status_code, 201, "Registration should succeed")

    def test_login(self):
        email = f"login-{uuid.uuid4().hex[:8]}@example.com"
        self.post("/api/auth/register", {
            "name": "Bob",
            "email": email,
            "password": "SecurePass123!"
        })
        resp = self.post("/api/auth/login", {
            "email": email,
            "password": "SecurePass123!"
        })
        assert_equal(resp.status_code, 200, "Login should succeed")
        body = json.loads(resp.body)
        assert_not_none(body.get("token"), "Should return token")

    def test_create_task(self):
        token = self._register_and_login()
        resp = self.post("/api/tasks", {
            "title": "Test Task",
            "description": "A test task",
            "priority": "high"
        }, headers={"Authorization": f"Bearer {token}"})

        assert_equal(resp.status_code, 201, "Task creation should succeed")
        body = json.loads(resp.body)
        assert_equal(body["title"], "Test Task", "Title should match")
        assert_equal(body["priority"], "high", "Priority should match")

    def test_list_tasks(self):
        token = self._register_and_login()
        self.post("/api/tasks", {"title": "List Task 1"}, headers={"Authorization": f"Bearer {token}"})
        self.post("/api/tasks", {"title": "List Task 2"}, headers={"Authorization": f"Bearer {token}"})

        resp = self.get("/api/tasks", headers={"Authorization": f"Bearer {token}"})
        assert_equal(resp.status_code, 200, "Should return 200")
        body = json.loads(resp.body)
        assert_true(len(body["tasks"]) >= 2, "Should have at least 2 tasks")

    def test_update_task_status(self):
        token = self._register_and_login()
        create_resp = self.post("/api/tasks", {"title": "Status Task"},
                                headers={"Authorization": f"Bearer {token}"})
        task_id = json.loads(create_resp.body)["id"]

        resp = self.put(f"/api/tasks/{task_id}", {"status": "completed"},
                        headers={"Authorization": f"Bearer {token}"})
        assert_equal(resp.status_code, 200, "Update should succeed")
        body = json.loads(resp.body)
        assert_equal(body["status"], "completed", "Status should be updated")
        assert_not_none(body.get("completed_at"), "Should have completion timestamp")

    def test_delete_task(self):
        token = self._register_and_login()
        create_resp = self.post("/api/tasks", {"title": "Delete Me"},
                                headers={"Authorization": f"Bearer {token}"})
        task_id = json.loads(create_resp.body)["id"]

        resp = self.delete(f"/api/tasks/{task_id}",
                           headers={"Authorization": f"Bearer {token}"})
        assert_equal(resp.status_code, 204, "Delete should succeed")

    def test_dashboard_stats(self):
        token = self._register_and_login()
        self.post("/api/tasks", {"title": "Stats Task"},
                  headers={"Authorization": f"Bearer {token}"})

        resp = self.get("/api/dashboard/stats",
                        headers={"Authorization": f"Bearer {token}"})
        assert_equal(resp.status_code, 200, "Should return stats")
        body = json.loads(resp.body)
        assert_true(body["total_tasks"] >= 1, "Should have at least 1 task")

    def test_unauthorized_access(self):
        resp = self.get("/api/tasks")
        assert_equal(resp.status_code, 401, "Should reject unauthenticated request")
```

Run the tests:

```bash
tina4 test
```

```
Running tests...

  TaskFlowTest
    [PASS] test_register
    [PASS] test_login
    [PASS] test_create_task
    [PASS] test_list_tasks
    [PASS] test_update_task_status
    [PASS] test_delete_task
    [PASS] test_dashboard_stats
    [PASS] test_unauthorized_access

  8 tests, 8 passed, 0 failed (0.84s)
```

---

## 13. Step 11: Docker Deployment

Create `Dockerfile`:

```dockerfile
FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY . .
RUN mkdir -p data logs

EXPOSE 7145

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:7145/health || exit 1

CMD ["uv", "run", "python", "app.py"]
```

Create `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    ports:
      - "7145:7145"
    environment:
      - TINA4_DEBUG=false
      - JWT_SECRET=${JWT_SECRET:-change-me-in-production}
      - DATABASE_URL=sqlite:///data/app.db
      - TINA4_CACHE_BACKEND=redis
      - TINA4_CACHE_HOST=redis
    volumes:
      - taskflow-data:/app/data
      - taskflow-logs:/app/logs
    depends_on:
      - redis
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped

volumes:
  taskflow-data:
  taskflow-logs:
```

Deploy:

```bash
docker compose up -d --build
```

Verify:

```bash
curl http://localhost:7145/health
```

```json
{"status": "ok", "version": "1.0.0", "database": "connected"}
```

TaskFlow is running in production. Authenticated APIs. Real-time WebSocket updates. Email notifications. Cached dashboard stats. Tested. Dockerized. Every major Tina4 feature, working together in a single application.

---

## 14. What You Built

This chapter used every major concept from the book:

| Feature | Chapter |
|---------|---------|
| Route decorators (`@get`, `@post`, `@put`, `@delete`) | Chapter 2 |
| Request/response handling | Chapter 3 |
| Jinja templates | Chapter 4 |
| Database queries | Chapter 5 |
| ORM models (User, Task) | Chapter 6 |
| JWT authentication | Chapter 7 |
| Auth middleware | Chapter 8 |
| Email notifications (Messenger) | Chapter 13 |
| Cache (dashboard stats) | Chapter 14 |
| Frontend (tina4css dashboard) | Chapter 15 |
| WebSocket (live updates) | Chapter 12 |
| Testing (full test suite) | Chapter 17 |
| Docker deployment | Chapter 20 |

A production-ready task management application. From here, add features: file attachments, team management, calendar integration, reporting. The foundation holds.
