# Chapter 21: Building a Complete App

## 1. Putting It All Together

Twenty chapters. Routing, templates, databases, ORM, authentication, middleware, queues, WebSocket, caching, frontend, GraphQL, testing, dev tools, CLI scaffolding, deployment. Now all of it works together in one application.

**TaskFlow** -- a task management system:

- User registration and JWT authentication
- Task creation, assignment, and tracking
- A dashboard with real-time updates
- Email notifications when tasks are assigned
- Caching for dashboard performance
- A full test suite
- Docker deployment

Not a toy project. A complete, production-ready application. Every major Tina4 feature in one codebase.

---

## 2. Planning the App

### Models

| Model | Table | Fields |
|-------|-------|--------|
| User | users | id, name, email, passwordHash, role, createdAt |
| Task | tasks | id, title, description, status, priority, createdBy, assignedTo, dueDate, completedAt, createdAt, updatedAt |

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
tina4 init taskflow
cd taskflow
composer install
```

Update `.env`:

```env
TINA4_DEBUG=true
JWT_SECRET=taskflow-dev-secret-change-in-production
JWT_EXPIRY=86400
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
    description TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'todo',
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

Run the migrations:

```bash
tina4 migrate
```

```
Running migrations...
  [APPLIED] 20260322000100_create_users_table.sql
  [APPLIED] 20260322000200_create_tasks_table.sql
Migrations complete. 2 applied.
```

---

## 4. Step 2: User Model with Registration and Login

Create `src/orm/User.php`:

```php
<?php
use Tina4\ORM;

class User extends ORM
{
    public int $id;
    public string $name;
    public string $email;
    public string $passwordHash;
    public string $role = "user";
    public string $createdAt;

    public string $tableName = "users";
    public string $primaryKey = "id";

    /**
     * Get tasks created by this user
     */
    public function createdTasks(): array
    {
        return $this->hasMany(Task::class, "created_by");
    }

    /**
     * Get tasks assigned to this user
     */
    public function assignedTasks(): array
    {
        return $this->hasMany(Task::class, "assigned_to");
    }

    /**
     * Hash a password
     */
    public static function hashPassword(string $password): string
    {
        return password_hash($password, PASSWORD_DEFAULT);
    }

    /**
     * Verify a password against the stored hash
     */
    public function verifyPassword(string $password): bool
    {
        return password_verify($password, $this->passwordHash);
    }

    /**
     * Convert to dict without the password hash
     */
    public function toSafeDict(): array
    {
        $dict = $this->toArray();
        unset($dict["password_hash"]);
        return $dict;
    }
}
```

### Authentication Routes

Create `src/routes/auth.php`:

```php
<?php
use Tina4\Router;
use Tina4\Auth;

/**
 * @noauth
 */
Router::post("/api/auth/register", function ($request, $response) {
    $body = $request->body;

    // Validate input
    if (empty($body["name"]) || empty($body["email"]) || empty($body["password"])) {
        return $response->json(["error" => "name, email, and password are required"], 400);
    }

    if (strlen($body["password"]) < 8) {
        return $response->json(["error" => "Password must be at least 8 characters"], 400);
    }

    if (!filter_var($body["email"], FILTER_VALIDATE_EMAIL)) {
        return $response->json(["error" => "Invalid email address"], 400);
    }

    // Check for existing user
    $existing = new User();
    $found = $existing->select("*", "email = :email", ["email" => $body["email"]]);
    if (count($found) > 0) {
        return $response->json(["error" => "Email already registered"], 409);
    }

    // Create user
    $user = new User();
    $user->name = $body["name"];
    $user->email = $body["email"];
    $user->passwordHash = User::hashPassword($body["password"]);
    $user->role = "user";
    $user->save();

    return $response->json($user->toSafeDict(), 201);
});

/**
 * @noauth
 */
Router::post("/api/auth/login", function ($request, $response) {
    $body = $request->body;

    if (empty($body["email"]) || empty($body["password"])) {
        return $response->json(["error" => "email and password are required"], 400);
    }

    // Find user by email
    $user = new User();
    $found = $user->select("*", "email = :email", ["email" => $body["email"]]);

    if (count($found) === 0) {
        return $response->json(["error" => "Invalid email or password"], 401);
    }

    $user = $found[0];

    // Verify password
    if (!$user->verifyPassword($body["password"])) {
        return $response->json(["error" => "Invalid email or password"], 401);
    }

    // Generate JWT token
    $token = Auth::getToken([
        "user_id" => $user->id,
        "email" => $user->email,
        "role" => $user->role
    ]);

    return $response->json([
        "token" => $token,
        "user" => $user->toSafeDict()
    ]);
});

/**
 * @secured
 */
Router::get("/api/profile", function ($request, $response) {
    $userId = $request->user["user_id"];

    $user = new User();
    $user->load($userId);

    if (empty($user->id)) {
        return $response->json(["error" => "User not found"], 404);
    }

    return $response->json(["user" => $user->toSafeDict()]);
});
```

### Test Registration and Login

```bash
# Start the server
tina4 serve
```

```bash
# Register a user
curl -X POST http://localhost:7146/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Johnson", "email": "alice@example.com", "password": "securepass123"}'
```

```json
{
  "id": 1,
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "role": "user",
  "created_at": "2026-03-22 10:00:00"
}
```

```bash
# Login
curl -X POST http://localhost:7146/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securepass123"}'
```

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "role": "user"
  }
}
```

```bash
# Access protected route
curl http://localhost:7146/api/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

```json
{
  "user": {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "role": "user"
  }
}
```

---

## 5. Step 3: Task Model with CRUD

Create `src/orm/Task.php`:

```php
<?php
use Tina4\ORM;

class Task extends ORM
{
    public int $id;
    public string $title;
    public string $description = "";
    public string $status = "todo";
    public string $priority = "medium";
    public int $createdBy;
    public ?int $assignedTo = null;
    public ?string $dueDate = null;
    public ?string $completedAt = null;
    public string $createdAt;
    public string $updatedAt;

    public string $tableName = "tasks";
    public string $primaryKey = "id";

    /**
     * Get the user who created this task
     */
    public function creator(): ?User
    {
        return $this->belongsTo(User::class, "created_by");
    }

    /**
     * Get the user this task is assigned to
     */
    public function assignee(): ?User
    {
        return $this->belongsTo(User::class, "assigned_to");
    }

    /**
     * Convert to dict with nested user data
     */
    public function toDetailedDict(): array
    {
        $dict = $this->toArray();

        $creator = $this->creator();
        $dict["creator"] = $creator ? $creator->toSafeDict() : null;

        $assignee = $this->assignee();
        $dict["assignee"] = $assignee ? $assignee->toSafeDict() : null;

        return $dict;
    }
}
```

### Task Routes

Create `src/routes/tasks.php`:

```php
<?php
use Tina4\Router;

Router::group("/api", function () {

    // List tasks with filters
    /**
     * @secured
     */
    Router::get("/tasks", function ($request, $response) {
        $userId = $request->user["user_id"];

        $status = $request->params["status"] ?? "";
        $priority = $request->params["priority"] ?? "";
        $assigned = $request->params["assigned"] ?? "";
        $page = (int) ($request->params["page"] ?? 1);
        $perPage = (int) ($request->params["per_page"] ?? 20);

        $conditions = [];
        $params = [];

        // Show tasks created by or assigned to the current user
        $conditions[] = "(created_by = :userId OR assigned_to = :userId2)";
        $params["userId"] = $userId;
        $params["userId2"] = $userId;

        if (!empty($status)) {
            $conditions[] = "status = :status";
            $params["status"] = $status;
        }

        if (!empty($priority)) {
            $conditions[] = "priority = :priority";
            $params["priority"] = $priority;
        }

        if ($assigned === "me") {
            $conditions[] = "assigned_to = :assignedTo";
            $params["assignedTo"] = $userId;
        } elseif ($assigned === "unassigned") {
            $conditions[] = "assigned_to IS NULL";
        }

        $filter = implode(" AND ", $conditions);
        $offset = ($page - 1) * $perPage;

        $task = new Task();
        $tasks = $task->select("*", $filter, $params, "created_at DESC", $perPage, $offset);

        $results = array_map(fn($t) => $t->toDetailedDict(), $tasks);

        return $response->json([
            "tasks" => $results,
            "page" => $page,
            "per_page" => $perPage,
            "count" => count($results)
        ]);
    });

    // Get a single task
    /**
     * @secured
     */
    Router::get("/tasks/{id:int}", function ($request, $response) {
        $task = new Task();
        $task->load($request->params["id"]);

        if (empty($task->id)) {
            return $response->json(["error" => "Task not found"], 404);
        }

        return $response->json($task->toDetailedDict());
    });

    // Create a task
    Router::post("/tasks", function ($request, $response) {
        $userId = $request->user["user_id"];
        $body = $request->body;

        if (empty($body["title"])) {
            return $response->json(["error" => "title is required"], 400);
        }

        $validStatuses = ["todo", "in_progress", "review", "done"];
        $validPriorities = ["low", "medium", "high", "urgent"];

        $status = $body["status"] ?? "todo";
        if (!in_array($status, $validStatuses)) {
            return $response->json([
                "error" => "Invalid status. Must be one of: " . implode(", ", $validStatuses)
            ], 400);
        }

        $priority = $body["priority"] ?? "medium";
        if (!in_array($priority, $validPriorities)) {
            return $response->json([
                "error" => "Invalid priority. Must be one of: " . implode(", ", $validPriorities)
            ], 400);
        }

        $task = new Task();
        $task->title = $body["title"];
        $task->description = $body["description"] ?? "";
        $task->status = $status;
        $task->priority = $priority;
        $task->createdBy = $userId;
        $task->dueDate = $body["due_date"] ?? null;

        // Handle assignment
        if (!empty($body["assigned_to"])) {
            $assignee = new User();
            $assignee->load((int) $body["assigned_to"]);
            if (empty($assignee->id)) {
                return $response->json(["error" => "Assigned user not found"], 400);
            }
            $task->assignedTo = $assignee->id;
        }

        $task->save();

        return $response->json($task->toDetailedDict(), 201);
    });

    // Update a task
    Router::put("/tasks/{id:int}", function ($request, $response) {
        $task = new Task();
        $task->load($request->params["id"]);

        if (empty($task->id)) {
            return $response->json(["error" => "Task not found"], 404);
        }

        $body = $request->body;

        if (isset($body["title"])) $task->title = $body["title"];
        if (isset($body["description"])) $task->description = $body["description"];
        if (isset($body["priority"])) $task->priority = $body["priority"];
        if (isset($body["due_date"])) $task->dueDate = $body["due_date"];

        // Handle status change
        if (isset($body["status"])) {
            $oldStatus = $task->status;
            $task->status = $body["status"];

            // Mark completion time
            if ($body["status"] === "done" && $oldStatus !== "done") {
                $task->completedAt = date("Y-m-d H:i:s");
            } elseif ($body["status"] !== "done") {
                $task->completedAt = null;
            }
        }

        // Handle reassignment
        if (isset($body["assigned_to"])) {
            if ($body["assigned_to"] === null) {
                $task->assignedTo = null;
            } else {
                $assignee = new User();
                $assignee->load((int) $body["assigned_to"]);
                if (empty($assignee->id)) {
                    return $response->json(["error" => "Assigned user not found"], 400);
                }
                $task->assignedTo = $assignee->id;
            }
        }

        $task->save();

        return $response->json($task->toDetailedDict());
    });

    // Delete a task
    Router::delete("/tasks/{id:int}", function ($request, $response) {
        $task = new Task();
        $task->load($request->params["id"]);

        if (empty($task->id)) {
            return $response->json(["error" => "Task not found"], 404);
        }

        $task->delete();
        return $response->json(null, 204);
    });
});
```

### Test the Task API

```bash
# Get token (from login)
TOKEN="eyJhbGciOiJIUzI1NiIs..."

# Create tasks
curl -X POST http://localhost:7146/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Design database schema", "priority": "high", "status": "done"}'

curl -X POST http://localhost:7146/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Build API endpoints", "priority": "high", "status": "in_progress"}'

curl -X POST http://localhost:7146/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Write documentation", "priority": "medium", "due_date": "2026-04-01"}'

# List all tasks
curl http://localhost:7146/api/tasks \
  -H "Authorization: Bearer $TOKEN"

# Filter by status
curl "http://localhost:7146/api/tasks?status=in_progress" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 6. Step 4: Dashboard Template with tina4css

Create `src/templates/app/layout.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}TaskFlow{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
    <script>
        (function() {
            var t = localStorage.getItem("theme");
            if (t) document.documentElement.setAttribute("data-theme", t);
            else if (window.matchMedia("(prefers-color-scheme: dark)").matches)
                document.documentElement.setAttribute("data-theme", "dark");
        })();
    </script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        .app { display: flex; min-height: 100vh; }
        .sidebar {
            width: 240px; background: #1a1a2e; color: #ccc; flex-shrink: 0;
        }
        .sidebar-brand {
            padding: 20px; font-size: 1.3em; font-weight: bold; color: #fff;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .sidebar-nav { list-style: none; padding: 12px 0; }
        .sidebar-nav a {
            display: block; padding: 10px 20px; color: rgba(255,255,255,0.6);
            text-decoration: none; transition: 0.2s;
        }
        .sidebar-nav a:hover, .sidebar-nav a.active {
            color: #fff; background: rgba(255,255,255,0.08);
        }
        .main { flex: 1; background: #f4f5f7; display: flex; flex-direction: column; }
        .topbar {
            background: #fff; padding: 14px 24px; border-bottom: 1px solid #e1e4e8;
            display: flex; justify-content: space-between; align-items: center;
        }
        .topbar-left { font-size: 1.1em; font-weight: 600; }
        .topbar-right { display: flex; gap: 12px; align-items: center; }
        .content { padding: 24px; flex: 1; }
        .stats-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .stat-card {
            background: #fff; border-radius: 8px; padding: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }
        .stat-card .value { font-size: 2em; font-weight: bold; }
        .stat-card .label { color: #6c757d; margin-top: 4px; font-size: 0.9em; }
        .task-row {
            background: #fff; border-radius: 6px; padding: 14px 18px; margin-bottom: 8px;
            display: flex; align-items: center; gap: 12px;
            box-shadow: 0 1px 2px rgba(0,0,0,0.05);
        }
        .task-row .task-title { flex: 1; font-weight: 500; }
        .priority-dot {
            width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0;
        }
        .priority-dot.urgent { background: #dc3545; }
        .priority-dot.high { background: #fd7e14; }
        .priority-dot.medium { background: #ffc107; }
        .priority-dot.low { background: #28a745; }
        @media (max-width: 768px) {
            .sidebar { display: none; }
            .stats-row { grid-template-columns: 1fr 1fr; }
        }
    </style>
    {% block extra_css %}{% endblock %}
</head>
<body>
    <div class="app">
        <aside class="sidebar">
            <div class="sidebar-brand">TaskFlow</div>
            <ul class="sidebar-nav">
                <li><a href="/admin" class="{% if page == 'dashboard' %}active{% endif %}">Dashboard</a></li>
                <li><a href="/admin/tasks" class="{% if page == 'tasks' %}active{% endif %}">All Tasks</a></li>
                <li><a href="/admin/my-tasks" class="{% if page == 'my-tasks' %}active{% endif %}">My Tasks</a></li>
            </ul>
        </aside>
        <div class="main">
            <div class="topbar">
                <div class="topbar-left">{% block page_title %}Dashboard{% endblock %}</div>
                <div class="topbar-right">
                    <button class="btn btn-sm btn-outline-secondary" onclick="toggleTheme()">Theme</button>
                    <span id="userName">{{ user_name | default("User") }}</span>
                    <button class="btn btn-sm btn-outline-danger" onclick="logout()">Logout</button>
                </div>
            </div>
            <div class="content">
                {% block content %}{% endblock %}
            </div>
        </div>
    </div>
    <script src="/js/frond.js"></script>
    <script>
        function toggleTheme() {
            var html = document.documentElement;
            var next = html.getAttribute("data-theme") === "dark" ? "light" : "dark";
            html.setAttribute("data-theme", next);
            localStorage.setItem("theme", next);
        }
        function logout() {
            frond.clearToken();
            window.location.href = "/login";
        }
    </script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```

Create `src/templates/app/dashboard.html`:

```html
{% extends "app/layout.html" %}

{% block title %}Dashboard - TaskFlow{% endblock %}
{% block page_title %}Dashboard{% endblock %}

{% block content %}
    <div class="stats-row">
        <div class="stat-card">
            <div class="value" id="statTotal">--</div>
            <div class="label">Total Tasks</div>
        </div>
        <div class="stat-card">
            <div class="value" id="statTodo">--</div>
            <div class="label">To Do</div>
        </div>
        <div class="stat-card">
            <div class="value" id="statInProgress">--</div>
            <div class="label">In Progress</div>
        </div>
        <div class="stat-card">
            <div class="value" id="statDone">--</div>
            <div class="label">Completed</div>
        </div>
    </div>

    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3>Recent Tasks</h3>
        <button class="btn btn-primary btn-sm" data-toggle="modal" data-target="#newTaskModal">
            New Task
        </button>
    </div>

    <div id="taskList">
        <p class="text-muted">Loading tasks...</p>
    </div>

    <!-- New Task Modal -->
    <div class="modal" id="newTaskModal">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Create Task</h5>
                    <button type="button" class="close" data-dismiss="modal">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="form-group">
                        <label>Title</label>
                        <input type="text" class="form-control" id="taskTitle">
                    </div>
                    <div class="form-group">
                        <label>Description</label>
                        <textarea class="form-control" id="taskDescription" rows="3"></textarea>
                    </div>
                    <div class="form-group">
                        <label>Priority</label>
                        <select class="form-control" id="taskPriority">
                            <option value="low">Low</option>
                            <option value="medium" selected>Medium</option>
                            <option value="high">High</option>
                            <option value="urgent">Urgent</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Due Date</label>
                        <input type="date" class="form-control" id="taskDueDate">
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                    <button class="btn btn-primary" onclick="createTask()">Create</button>
                </div>
            </div>
        </div>
    </div>

    <div id="alertArea" style="position: fixed; top: 80px; right: 24px; width: 300px; z-index: 1000;"></div>
{% endblock %}

{% block extra_js %}
<script>
    function loadStats() {
        frond.get("/api/dashboard/stats", function (data) {
            document.getElementById("statTotal").textContent = data.total;
            document.getElementById("statTodo").textContent = data.todo;
            document.getElementById("statInProgress").textContent = data.in_progress;
            document.getElementById("statDone").textContent = data.done;
        });
    }

    function loadTasks() {
        frond.get("/api/tasks?per_page=10", function (data) {
            var html = "";
            if (data.tasks.length === 0) {
                html = '<p class="text-muted">No tasks yet. Create your first task!</p>';
            } else {
                data.tasks.forEach(function (task) {
                    html += '<div class="task-row">'
                        + '<span class="priority-dot ' + task.priority + '"></span>'
                        + '<span class="task-title">' + task.title + '</span>'
                        + '<span class="badge badge-' + statusColor(task.status) + '">' + task.status.replace("_", " ") + '</span>'
                        + (task.due_date ? '<span class="text-muted" style="font-size:0.85em;">' + task.due_date + '</span>' : '')
                        + '</div>';
                });
            }
            document.getElementById("taskList").innerHTML = html;
        });
    }

    function statusColor(status) {
        var colors = { "todo": "secondary", "in_progress": "primary", "review": "warning", "done": "success" };
        return colors[status] || "secondary";
    }

    function createTask() {
        var data = {
            title: document.getElementById("taskTitle").value,
            description: document.getElementById("taskDescription").value,
            priority: document.getElementById("taskPriority").value,
            due_date: document.getElementById("taskDueDate").value || null
        };

        frond.post("/api/tasks", data, function (result) {
            showAlert("Task created: " + result.title, "success");
            loadTasks();
            loadStats();
            // Clear form
            document.getElementById("taskTitle").value = "";
            document.getElementById("taskDescription").value = "";
        }, function (error) {
            showAlert("Error creating task", "danger");
        });
    }

    function showAlert(message, type) {
        var area = document.getElementById("alertArea");
        area.innerHTML = '<div class="alert alert-' + type + '">' + message + '</div>';
        setTimeout(function () { area.innerHTML = ""; }, 3000);
    }

    // Initial load
    loadStats();
    loadTasks();

    // Auto-refresh every 30 seconds
    setInterval(function () {
        loadStats();
        loadTasks();
    }, 30000);
</script>
{% endblock %}
```

### Dashboard Stats Route

Create `src/routes/dashboard.php`:

```php
<?php
use Tina4\Router;

/**
 * @secured
 */
Router::get("/api/dashboard/stats", function ($request, $response) {
    $userId = $request->user["user_id"];

    $task = new Task();
    $filter = "(created_by = :uid OR assigned_to = :uid2)";
    $params = ["uid" => $userId, "uid2" => $userId];

    $all = $task->select("*", $filter, $params);

    $stats = [
        "total" => count($all),
        "todo" => 0,
        "in_progress" => 0,
        "review" => 0,
        "done" => 0
    ];

    foreach ($all as $t) {
        if (isset($stats[$t->status])) {
            $stats[$t->status]++;
        }
    }

    return $response->json($stats);
});

/**
 * @noauth
 */
Router::get("/admin", function ($request, $response) {
    return $response->render("app/dashboard.html", [
        "page" => "dashboard"
    ]);
});
```

---

## 7. Step 5: Real-Time Updates via WebSocket

Real-time task updates. All connected dashboard users see changes the moment they happen.

Create `src/routes/websocket.php`:

```php
<?php
use Tina4\WebSocket;

WebSocket::on("connect", function ($client) {
    error_log("Client connected: " . $client->id);
});

WebSocket::on("disconnect", function ($client) {
    error_log("Client disconnected: " . $client->id);
});

WebSocket::on("message", function ($client, $message) {
    $data = json_decode($message, true);

    if ($data["type"] === "subscribe" && $data["channel"] === "tasks") {
        WebSocket::subscribe($client, "tasks");
    }
});
```

Broadcast task changes by updating the task routes. Add this helper function at the top of `src/routes/tasks.php`:

```php
function broadcastTaskUpdate(string $event, array $taskData): void
{
    \Tina4\WebSocket::broadcast("tasks", json_encode([
        "type" => "task_update",
        "event" => $event,
        "task" => $taskData
    ]));
}
```

Call it after each write operation:

```php
// After creating a task
$task->save();
broadcastTaskUpdate("created", $task->toDetailedDict());

// After updating a task
$task->save();
broadcastTaskUpdate("updated", $task->toDetailedDict());

// After deleting a task
$task->delete();
broadcastTaskUpdate("deleted", ["id" => $request->params["id"]]);
```

Add WebSocket client code to the dashboard template. Add this inside the `{% block extra_js %}` block:

```javascript
// WebSocket connection for real-time updates
var ws = new WebSocket("ws://localhost:7146/ws");

ws.onopen = function () {
    ws.send(JSON.stringify({ type: "subscribe", channel: "tasks" }));
};

ws.onmessage = function (event) {
    var data = JSON.parse(event.data);
    if (data.type === "task_update") {
        loadTasks();
        loadStats();
        showAlert("Task " + data.event + ": " + (data.task.title || ""), "info");
    }
};

ws.onclose = function () {
    // Reconnect after 3 seconds
    setTimeout(function () {
        ws = new WebSocket("ws://localhost:7146/ws");
    }, 3000);
};
```

Any user creates, updates, or deletes a task. All connected dashboard users see the change.

---

## 8. Step 6: Email Notifications on Task Assignment

A task is assigned to a user. Send them an email notification.

Create `src/routes/notifications.php`:

```php
<?php
use Tina4\Mail;

function sendTaskAssignmentEmail(Task $task, User $assignee, User $assigner): void
{
    $subject = "New task assigned: " . $task->title;

    $body = "Hi " . $assignee->name . ",\n\n"
        . $assigner->name . " has assigned you a new task:\n\n"
        . "Title: " . $task->title . "\n"
        . "Priority: " . strtoupper($task->priority) . "\n"
        . "Due: " . ($task->dueDate ?? "No due date") . "\n\n"
        . "Description:\n" . ($task->description ?: "(No description)") . "\n\n"
        . "View it at: http://localhost:7146/admin\n";

    Mail::send(
        $assignee->email,
        $subject,
        $body
    );
}
```

In the task creation and update routes, call this function when `assigned_to` is set:

```php
// After setting assigned_to and saving
if ($task->assignedTo && $task->assignedTo !== $userId) {
    $assignee = new User();
    $assignee->load($task->assignedTo);

    $assigner = new User();
    $assigner->load($userId);

    if (!empty($assignee->id) && !empty($assigner->id)) {
        sendTaskAssignmentEmail($task, $assignee, $assigner);
    }
}
```

Configure email in `.env`:

```env
TINA4_MAIL_HOST=smtp.example.com
TINA4_MAIL_PORT=587
TINA4_MAIL_USER=notifications@example.com
TINA4_MAIL_PASS=your-email-password
TINA4_MAIL_FROM=notifications@example.com
TINA4_MAIL_FROM_NAME=TaskFlow
```

For development, you can use a local mail trap like MailHog or Mailtrap.io so emails are captured without actually sending.

---

## 9. Step 7: Add Caching for the Dashboard

The dashboard stats query runs on every page load. With many tasks, this gets slow. Cache the stats. Compute once. Serve from cache for subsequent requests.

Update the dashboard stats route:

```php
/**
 * @secured
 */
Router::get("/api/dashboard/stats", function ($request, $response) {
    $userId = $request->user["user_id"];
    $cacheKey = "dashboard_stats_" . $userId;

    // Try cache first
    $cached = \Tina4\Cache::get($cacheKey);
    if ($cached !== null) {
        return $response->json($cached);
    }

    // Compute stats
    $task = new Task();
    $filter = "(created_by = :uid OR assigned_to = :uid2)";
    $params = ["uid" => $userId, "uid2" => $userId];

    $all = $task->select("*", $filter, $params);

    $stats = [
        "total" => count($all),
        "todo" => 0,
        "in_progress" => 0,
        "review" => 0,
        "done" => 0
    ];

    foreach ($all as $t) {
        if (isset($stats[$t->status])) {
            $stats[$t->status]++;
        }
    }

    // Cache for 60 seconds
    \Tina4\Cache::set($cacheKey, $stats, 60);

    return $response->json($stats);
});
```

Invalidate the cache when tasks change. Add this to the `broadcastTaskUpdate` function:

```php
function broadcastTaskUpdate(string $event, array $taskData): void
{
    // Invalidate dashboard cache for all affected users
    if (isset($taskData["created_by"])) {
        \Tina4\Cache::delete("dashboard_stats_" . $taskData["created_by"]);
    }
    if (isset($taskData["assigned_to"]) && $taskData["assigned_to"]) {
        \Tina4\Cache::delete("dashboard_stats_" . $taskData["assigned_to"]);
    }

    \Tina4\WebSocket::broadcast("tasks", json_encode([
        "type" => "task_update",
        "event" => $event,
        "task" => $taskData
    ]));
}
```

---

## 10. Step 8: Write Tests

Create `tests/TaskFlowTest.php`:

```php
<?php
use Tina4\Test;

class TaskFlowTest extends Test
{
    private ?string $token = null;
    private ?int $userId = null;

    public function setUp(): void
    {
        // Register a test user
        $email = "test-" . uniqid() . "@taskflow.test";
        $regResponse = $this->post("/api/auth/register", [
            "name" => "Test User",
            "email" => $email,
            "password" => "testpassword123"
        ]);

        $regBody = json_decode($regResponse->body, true);
        $this->userId = $regBody["id"] ?? null;

        // Login to get token
        $loginResponse = $this->post("/api/auth/login", [
            "email" => $email,
            "password" => "testpassword123"
        ]);

        $loginBody = json_decode($loginResponse->body, true);
        $this->token = $loginBody["token"] ?? null;
    }

    // --- Auth Tests ---

    public function testRegistrationReturns201()
    {
        $response = $this->post("/api/auth/register", [
            "name" => "New User",
            "email" => "new-" . uniqid() . "@test.com",
            "password" => "securepassword"
        ]);
        $this->assertEqual($response->statusCode, 201, "Registration should return 201");
    }

    public function testRegistrationRejectsShortPassword()
    {
        $response = $this->post("/api/auth/register", [
            "name" => "New User",
            "email" => "short-" . uniqid() . "@test.com",
            "password" => "abc"
        ]);
        $this->assertEqual($response->statusCode, 400, "Should reject short password");
    }

    public function testLoginReturnsToken()
    {
        $this->assertNotNull($this->token, "Login should return a token");
        $this->assertTrue(strlen($this->token) > 20, "Token should be substantial");
    }

    public function testProfileRequiresAuth()
    {
        $response = $this->get("/api/profile");
        $this->assertEqual($response->statusCode, 401, "Profile should require auth");
    }

    public function testProfileWithToken()
    {
        $response = $this->get("/api/profile", [
            "Authorization" => "Bearer " . $this->token
        ]);
        $this->assertEqual($response->statusCode, 200, "Profile should work with token");
    }

    // --- Task Tests ---

    public function testCreateTask()
    {
        $response = $this->post("/api/tasks", [
            "title" => "Test Task",
            "priority" => "high"
        ], ["Authorization" => "Bearer " . $this->token]);

        $this->assertEqual($response->statusCode, 201, "Should create task");

        $body = json_decode($response->body, true);
        $this->assertEqual($body["title"], "Test Task", "Title should match");
        $this->assertEqual($body["priority"], "high", "Priority should match");
        $this->assertEqual($body["status"], "todo", "Default status should be todo");
    }

    public function testCreateTaskRequiresTitle()
    {
        $response = $this->post("/api/tasks", [
            "priority" => "low"
        ], ["Authorization" => "Bearer " . $this->token]);

        $this->assertEqual($response->statusCode, 400, "Should reject task without title");
    }

    public function testListTasks()
    {
        // Create a task first
        $this->post("/api/tasks", [
            "title" => "List Test Task"
        ], ["Authorization" => "Bearer " . $this->token]);

        $response = $this->get("/api/tasks", [
            "Authorization" => "Bearer " . $this->token
        ]);

        $this->assertEqual($response->statusCode, 200, "Should list tasks");

        $body = json_decode($response->body, true);
        $this->assertTrue($body["count"] > 0, "Should have at least one task");
    }

    public function testUpdateTaskStatus()
    {
        // Create a task
        $createResponse = $this->post("/api/tasks", [
            "title" => "Status Test Task"
        ], ["Authorization" => "Bearer " . $this->token]);

        $taskId = json_decode($createResponse->body, true)["id"];

        // Update status to done
        $updateResponse = $this->put("/api/tasks/" . $taskId, [
            "status" => "done"
        ], ["Authorization" => "Bearer " . $this->token]);

        $this->assertEqual($updateResponse->statusCode, 200, "Should update task");

        $body = json_decode($updateResponse->body, true);
        $this->assertEqual($body["status"], "done", "Status should be done");
        $this->assertNotNull($body["completed_at"], "Should have completion timestamp");
    }

    public function testDeleteTask()
    {
        // Create a task
        $createResponse = $this->post("/api/tasks", [
            "title" => "Delete Me"
        ], ["Authorization" => "Bearer " . $this->token]);

        $taskId = json_decode($createResponse->body, true)["id"];

        // Delete it
        $deleteResponse = $this->delete("/api/tasks/" . $taskId, [
            "Authorization" => "Bearer " . $this->token
        ]);

        $this->assertEqual($deleteResponse->statusCode, 204, "Should return 204");

        // Verify it is gone
        $getResponse = $this->get("/api/tasks/" . $taskId, [
            "Authorization" => "Bearer " . $this->token
        ]);

        $this->assertEqual($getResponse->statusCode, 404, "Should return 404 after deletion");
    }

    public function testDashboardStats()
    {
        // Create tasks with different statuses
        $this->post("/api/tasks", ["title" => "Todo Task", "status" => "todo"],
            ["Authorization" => "Bearer " . $this->token]);
        $this->post("/api/tasks", ["title" => "In Progress Task", "status" => "in_progress"],
            ["Authorization" => "Bearer " . $this->token]);
        $this->post("/api/tasks", ["title" => "Done Task", "status" => "done"],
            ["Authorization" => "Bearer " . $this->token]);

        $response = $this->get("/api/dashboard/stats", [
            "Authorization" => "Bearer " . $this->token
        ]);

        $this->assertEqual($response->statusCode, 200, "Should return stats");

        $body = json_decode($response->body, true);
        $this->assertTrue($body["total"] >= 3, "Should have at least 3 tasks");
        $this->assertTrue($body["todo"] >= 1, "Should have at least 1 todo");
        $this->assertTrue($body["in_progress"] >= 1, "Should have at least 1 in progress");
        $this->assertTrue($body["done"] >= 1, "Should have at least 1 done");
    }
}
```

Run the tests:

```bash
tina4 test
```

```
Running tests...

  TaskFlowTest
    [PASS] test_registration_returns_201
    [PASS] test_registration_rejects_short_password
    [PASS] test_login_returns_token
    [PASS] test_profile_requires_auth
    [PASS] test_profile_with_token
    [PASS] test_create_task
    [PASS] test_create_task_requires_title
    [PASS] test_list_tasks
    [PASS] test_update_task_status
    [PASS] test_delete_task
    [PASS] test_dashboard_stats

  11 tests, 11 passed, 0 failed (0.62s)
```

---

## 11. Step 9: Deploy with Docker

Create `Dockerfile`:

```dockerfile
FROM dunglas/frankenphp:latest-php8.3-alpine

RUN install-php-extensions \
    pdo_sqlite \
    mbstring \
    openssl \
    fileinfo

WORKDIR /app

COPY composer.json composer.lock ./
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer install --no-dev --optimize-autoloader --no-interaction

COPY . .

RUN mkdir -p data logs secrets \
    && chown -R www-data:www-data data logs secrets

EXPOSE 7146

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:7146/health || exit 1

CMD ["tina4", "serve", "--production"]
```

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "7146:7146"
    environment:
      - TINA4_DEBUG=false
      - TINA4_LOG_LEVEL=WARNING
      - TINA4_CACHE_TEMPLATES=true
      - JWT_SECRET=${JWT_SECRET:-change-me-in-production}
      - DATABASE_URL=sqlite:///data/app.db
    volumes:
      - taskflow-data:/app/data
      - taskflow-logs:/app/logs
    restart: unless-stopped
    stop_grace_period: 35s

volumes:
  taskflow-data:
  taskflow-logs:
```

Build and deploy:

```bash
# Build
docker compose build

# Start
docker compose up -d

# Run migrations inside the container
docker compose exec app tina4 migrate

# Verify
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 5,
  "version": "3.0.0",
  "framework": "tina4-php"
}
```

---

## 12. The Complete Project Structure

```
taskflow/
├── .env
├── .env.example
├── .gitignore
├── composer.json
├── composer.lock
├── Dockerfile
├── docker-compose.yml
├── vendor/
├── src/
│   ├── routes/
│   │   ├── auth.php              # Registration, login, profile
│   │   ├── tasks.php             # Task CRUD
│   │   ├── dashboard.php         # Dashboard stats + page
│   │   ├── notifications.php     # Email notification helpers
│   │   └── websocket.php         # WebSocket event handlers
│   ├── orm/
│   │   ├── User.php              # User model with auth methods
│   │   └── Task.php              # Task model with relationships
│   ├── migrations/
│   │   ├── 20260322000100_create_users_table.sql
│   │   └── 20260322000200_create_tasks_table.sql
│   ├── templates/
│   │   ├── app/
│   │   │   ├── layout.html       # Base layout with sidebar
│   │   │   └── dashboard.html    # Dashboard page
│   │   └── errors/
│   │       ├── 404.html
│   │       └── 500.html
│   ├── public/
│   │   ├── css/
│   │   │   └── tina4.css
│   │   └── js/
│   │       └── frond.js
│   └── locales/
│       └── en.json
├── data/
│   └── app.db
├── logs/
├── secrets/
└── tests/
    └── TaskFlowTest.php
```

Every file has a purpose. Every directory follows the convention. A new developer looks at this structure and knows where to find things.

---

## 13. What to Build Next

TaskFlow is a solid foundation. Ideas for extending it:

**Features:**
- **Task comments** -- Add a Comment model with a `task_id` foreign key. Display comments on the task detail page.
- **File attachments** -- Let users upload files to tasks. Store them in `data/uploads/` and serve them via a route.
- **Team management** -- Add a Team model. Users belong to teams. Tasks are scoped to teams.
- **Task labels/tags** -- Many-to-many relationship between tasks and labels for categorization.
- **Due date reminders** -- Use the queue system to schedule reminder emails 24 hours before a task's due date.
- **Activity log** -- Record every change to a task (who changed what, when) for audit trails.
- **Search** -- Full-text search across task titles and descriptions.
- **Calendar view** -- Render tasks on a calendar based on their due dates.
- **Mobile API** -- The API already works for mobile apps. Add push notification support via Firebase Cloud Messaging.

**Technical improvements:**
- **Rate limiting per user** -- Replace the global rate limiter with per-user limits.
- **Database upgrade** -- Switch from SQLite to PostgreSQL for better concurrency.
- **CI/CD pipeline** -- Add GitHub Actions to run tests automatically on every push.
- **API documentation** -- Generate OpenAPI/Swagger docs from your route definitions.
- **Internationalization** -- Add `src/locales/` files for multiple languages.

---

## 14. Closing Thoughts -- The Tina4 Philosophy

You built a complete application. User auth. CRUD. Real-time updates. Email. Caching. Tests. Deployment. Your project has one dependency: `tina4/tina4-php`.

No ORM package. No template engine package. No authentication library. No WebSocket server. No caching library. No testing framework. No CLI tool. No CSS framework. No JavaScript helpers. All built in.

**One framework. Zero dependencies. Everything you need.**

The same patterns work in Python, Ruby, and Node.js. Same project structure. Same CLI commands. Same `.env` variables. Same template syntax. Learn Tina4 once. Use it everywhere.

Your `vendor/` directory is small. Your `composer.lock` has one entry. When PHP 9.0 ships, you update one package. Everything works. No dependency tree to untangle. No abandoned transitive dependency to replace. No security advisory for a package four levels deep that you never knew you were using.

Simple does not mean limited. TaskFlow has authentication, real-time WebSocket, email, caching, GraphQL, and a test suite. It deploys in a Docker container. It handles thousands of concurrent users. All of this runs on under 5,000 lines of framework code.

Build things. Ship them. Keep it simple.
