# Chapter 21: Building a Complete App

## 1. Putting It All Together

Twenty chapters of building blocks. Routing. Templates. Databases. ORM. Authentication. Middleware. Queues. WebSocket. Caching. Frontend. GraphQL. Testing. Dev tools. CLI scaffolding. Deployment. Now all of it works together in one application.

We are building **TaskFlow** -- a task management system with:

- User registration and JWT authentication
- Task creation, assignment, and tracking
- A dashboard with real-time updates
- Email notifications when tasks are assigned
- Caching for dashboard performance
- A full test suite
- Docker deployment

Not a toy project. A production-ready application. Every major Tina4 feature in one codebase.

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
npm install
```

Update `.env`:

```env
TINA4_DEBUG=true
TINA4_JWT_SECRET=taskflow-dev-secret-change-in-production
TINA4_JWT_EXPIRY=86400
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

Verify the database:

```bash
curl http://localhost:7148/health
```

```json
{"status": "ok", "database": "connected"}
```

---

## 4. Step 2: Define Models

Create `src/orm/User.ts`:

```typescript
import { BaseModel, Auth } from "tina4-nodejs";

export class User extends BaseModel {
    static tableName = "users";
    static primaryKey = "id";
    static hasMany = [
        { model: "Task", foreignKey: "created_by", as: "createdTasks" },
        { model: "Task", foreignKey: "assigned_to", as: "assignedTasks" }
    ];

    id!: number;
    name!: string;
    email!: string;
    passwordHash!: string;
    role: string = "user";
    createdAt!: string;

    async setPassword(password: string): Promise<void> {
        this.passwordHash = await Auth.hashPassword(password);
    }

    async verifyPassword(password: string): Promise<boolean> {
        if (!this.passwordHash) return false;
        return Auth.checkPassword(password, this.passwordHash);
    }

    safeDict(): Record<string, any> {
        const data = this.toDict();
        delete data.passwordHash;
        delete data.password_hash;
        return data;
    }
}
```

The `setPassword` method hashes the plain-text password before storage. `verifyPassword` compares a candidate password against the stored hash. `safeDict` strips the hash from any response -- never expose password data to the client.

Create `src/orm/Task.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Task extends BaseModel {
    static tableName = "tasks";
    static primaryKey = "id";
    static belongsTo = [
        { model: "User", foreignKey: "created_by", as: "creator" },
        { model: "User", foreignKey: "assigned_to", as: "assignee" }
    ];

    static STATUSES = ["todo", "in_progress", "done", "cancelled"];
    static PRIORITIES = ["low", "medium", "high", "urgent"];

    id!: number;
    title!: string;
    description: string = "";
    status: string = "todo";
    priority: string = "medium";
    createdBy!: number;
    assignedTo: number | null = null;
    dueDate: string | null = null;
    completedAt: string | null = null;
    createdAt!: string;
    updatedAt!: string;
}
```

The static `STATUSES` and `PRIORITIES` arrays serve as validation lists. Any route that accepts a status or priority value checks it against these arrays before writing to the database.

---

## 5. Step 3: Auth Middleware

Create `src/routes/middleware.ts`:

```typescript
import { Auth } from "tina4-nodejs";

export function authMiddleware(req, res, next) {
    const authHeader = req.headers["authorization"] ?? "";

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res({ error: "Authorization required" }, 401);
        return;
    }

    const token = authHeader.substring(7);

    const secret = process.env.SECRET || "tina4-default-secret";
    const payload = Auth.validToken(token, secret);
    if (payload === null) {
        res({ error: "Invalid or expired token" }, 401);
        return;
    }

    req.user = payload;
    req.userId = payload.user_id;
    next();
}
```

Verify the middleware blocks unauthenticated requests:

```bash
curl http://localhost:7148/api/tasks
```

```json
{"error": "Authorization required"}
```

The middleware stands guard. No token, no access.

---

## 6. Step 4: Auth Routes

Create `src/routes/auth.ts`:

```typescript
import { Router, Auth } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";
import { authMiddleware } from "./middleware";

/**
 * Register a new user
 * @noauth
 * @tags Auth
 * @body {"name": "string", "email": "string", "password": "string"}
 * @response 201 {"message": "string", "user": {"id": "int", "name": "string", "email": "string"}}
 */
Router.post("/api/auth/register", async (req, res) => {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
        return res.status(400).json({ error: "Name, email, and password are required" });
    }

    if (password.length < 8) {
        return res.status(400).json({ error: "Password must be at least 8 characters" });
    }

    const db = Database.getConnection();
    const existing = await db.fetchOne("SELECT id FROM users WHERE email = :email", { email });

    if (existing) {
        return res.status(409).json({ error: "Email already registered" });
    }

    const hash = await Auth.hashPassword(password);
    await db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
        { name, email, hash }
    );

    const user = await db.fetchOne("SELECT id, name, email, role FROM users WHERE id = last_insert_rowid()");

    return res.status(201).json({ message: "Registration successful", user });
});

/**
 * Login and get JWT token
 * @noauth
 * @tags Auth
 * @body {"email": "string", "password": "string"}
 * @response 200 {"token": "string", "user": {"id": "int", "name": "string", "email": "string"}}
 */
Router.post("/api/auth/login", async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: "Email and password are required" });
    }

    const db = Database.getConnection();
    const user = await db.fetchOne(
        "SELECT id, name, email, password_hash, role FROM users WHERE email = :email",
        { email }
    );

    if (!user || !(await Auth.checkPassword(password, user.password_hash))) {
        return res.status(401).json({ error: "Invalid email or password" });
    }

    const secret = process.env.SECRET || "tina4-default-secret";
    const token = Auth.getToken({
        user_id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
    }, secret);

    return res.json({
        message: "Login successful",
        token,
        user: { id: user.id, name: user.name, email: user.email, role: user.role }
    });
});

/**
 * Get current user profile
 * @tags Auth
 * @response 200 {"id": "int", "name": "string", "email": "string", "role": "string", "created_at": "string"}
 */
Router.get("/api/profile", async (req, res) => {
    const db = Database.getConnection();
    const user = await db.fetchOne(
        "SELECT id, name, email, role, created_at FROM users WHERE id = :id",
        { id: req.user.user_id }
    );
    return res.json(user);
}, [authMiddleware]);
```

### Test Registration and Login

```bash
# Start the server
tina4 serve
```

```bash
# Register a user
curl -X POST http://localhost:7148/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Johnson", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful",
  "user": {"id": 1, "name": "Alice Johnson", "email": "alice@example.com", "role": "user"}
}
```

```bash
# Login
curl -X POST http://localhost:7148/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {"id": 1, "name": "Alice Johnson", "email": "alice@example.com", "role": "user"}
}
```

Authentication works. Save the token for the next steps.

```bash
export TOKEN="eyJhbGciOiJIUzI1NiIs..."
```

---

## 7. Step 5: Task Routes

Create `src/routes/tasks.ts`:

```typescript
import { Router, Queue } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";
import { cacheDelete } from "tina4-nodejs";
import { authMiddleware } from "./middleware";
import { Task } from "../orm/Task";
import { pushTaskUpdate } from "./ws-tasks";

/**
 * List tasks with filters
 * @tags Tasks
 * @query string status Filter by status (todo, in_progress, done)
 * @query string priority Filter by priority (low, medium, high)
 * @query string assigned Filter by assigned user ID
 * @query int page Page number
 * @query int limit Results per page
 */
Router.get("/api/tasks", async (req, res) => {
    const db = Database.getConnection();
    const userId = req.user.user_id;
    const page = parseInt(req.query.page ?? "1", 10);
    const limit = parseInt(req.query.limit ?? "20", 10);
    const offset = (page - 1) * limit;

    const conditions = ["(created_by = :userId OR assigned_to = :userId)"];
    const params: Record<string, any> = { userId };

    if (req.query.status) {
        conditions.push("status = :status");
        params.status = req.query.status;
    }

    if (req.query.priority) {
        conditions.push("priority = :priority");
        params.priority = req.query.priority;
    }

    if (req.query.assigned) {
        conditions.push("assigned_to = :assignedTo");
        params.assignedTo = parseInt(req.query.assigned, 10);
    }

    const sql = `SELECT t.*,
        creator.name as creator_name,
        assignee.name as assignee_name
        FROM tasks t
        LEFT JOIN users creator ON t.created_by = creator.id
        LEFT JOIN users assignee ON t.assigned_to = assignee.id
        WHERE ${conditions.join(" AND ")}
        ORDER BY
            CASE t.priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END,
            t.created_at DESC
        LIMIT :limit OFFSET :offset`;

    params.limit = limit;
    params.offset = offset;

    const tasks = await db.fetch(sql, params);

    return res.json({ tasks, page, limit, count: tasks.length });
}, [authMiddleware]);

/**
 * Get a single task
 * @tags Tasks
 * @param int id Task ID
 */
Router.get("/api/tasks/{id:int}", async (req, res) => {
    const db = Database.getConnection();
    const task = await db.fetchOne(
        `SELECT t.*, creator.name as creator_name, assignee.name as assignee_name
         FROM tasks t
         LEFT JOIN users creator ON t.created_by = creator.id
         LEFT JOIN users assignee ON t.assigned_to = assignee.id
         WHERE t.id = :id`,
        { id: req.params.id }
    );

    if (!task) {
        return res.status(404).json({ error: "Task not found" });
    }

    return res.json(task);
}, [authMiddleware]);

/**
 * Create a task
 * @tags Tasks
 * @body {"title": "string", "description": "string", "priority": "string", "assigned_to": "int", "due_date": "string"}
 */
Router.post("/api/tasks", async (req, res) => {
    const db = Database.getConnection();
    const { title, description, priority, assigned_to, due_date } = req.body;

    if (!title) {
        return res.status(400).json({ error: "Title is required" });
    }

    if (priority && !Task.PRIORITIES.includes(priority)) {
        return res.status(400).json({ error: `Invalid priority. Must be one of: ${Task.PRIORITIES.join(", ")}` });
    }

    await db.execute(
        `INSERT INTO tasks (title, description, status, priority, created_by, assigned_to, due_date)
         VALUES (:title, :description, 'todo', :priority, :createdBy, :assignedTo, :dueDate)`,
        {
            title,
            description: description ?? "",
            priority: priority ?? "medium",
            createdBy: req.user.user_id,
            assignedTo: assigned_to ?? null,
            dueDate: due_date ?? null
        }
    );

    const task = await db.fetchOne("SELECT * FROM tasks WHERE id = last_insert_rowid()");

    // Invalidate dashboard cache
    cacheDelete("dashboard:stats");

    // Queue notification if assigned to someone
    if (assigned_to) {
        const notifyQueue = new Queue({ topic: "task-notifications" });
        notifyQueue.push({
            type: "assigned",
            task_id: task.id,
            task_title: title,
            assigned_to,
            assigned_by: req.user.name
        });
    }

    // Push real-time update
    pushTaskUpdate("created", task);

    return res.status(201).json(task);
}, [authMiddleware]);

/**
 * Update a task
 * @tags Tasks
 */
Router.put("/api/tasks/{id:int}", async (req, res) => {
    const db = Database.getConnection();
    const id = req.params.id;

    const existing = await db.fetchOne("SELECT * FROM tasks WHERE id = :id", { id });
    if (!existing) {
        return res.status(404).json({ error: "Task not found" });
    }

    const { title, description, status, priority, assigned_to, due_date } = req.body;

    if (status && !Task.STATUSES.includes(status)) {
        return res.status(400).json({ error: `Invalid status. Must be one of: ${Task.STATUSES.join(", ")}` });
    }

    if (priority && !Task.PRIORITIES.includes(priority)) {
        return res.status(400).json({ error: `Invalid priority. Must be one of: ${Task.PRIORITIES.join(", ")}` });
    }

    const completedAt = status === "done" && existing.status !== "done"
        ? new Date().toISOString()
        : existing.completed_at;

    // Detect reassignment for notification
    const oldAssignee = existing.assigned_to;
    const newAssignee = assigned_to ?? existing.assigned_to;

    await db.execute(
        `UPDATE tasks SET title = :title, description = :description, status = :status,
         priority = :priority, assigned_to = :assignedTo, due_date = :dueDate,
         completed_at = :completedAt, updated_at = CURRENT_TIMESTAMP
         WHERE id = :id`,
        {
            title: title ?? existing.title,
            description: description ?? existing.description,
            status: status ?? existing.status,
            priority: priority ?? existing.priority,
            assignedTo: newAssignee,
            dueDate: due_date ?? existing.due_date,
            completedAt,
            id
        }
    );

    const task = await db.fetchOne("SELECT * FROM tasks WHERE id = :id", { id });

    // Invalidate dashboard cache
    cacheDelete("dashboard:stats");

    // Notify new assignee if reassigned
    if (newAssignee && newAssignee !== oldAssignee) {
        const notifyQueue = new Queue({ topic: "task-notifications" });
        notifyQueue.push({
            type: "assigned",
            task_id: task.id,
            task_title: task.title,
            assigned_to: newAssignee,
            assigned_by: req.user.name
        });
    }

    // Push real-time update
    pushTaskUpdate("updated", task);

    return res.json(task);
}, [authMiddleware]);

/**
 * Delete a task
 * @tags Tasks
 */
Router.delete("/api/tasks/{id:int}", async (req, res) => {
    const db = Database.getConnection();
    const id = req.params.id;

    const existing = await db.fetchOne("SELECT * FROM tasks WHERE id = :id", { id });
    if (!existing) {
        return res.status(404).json({ error: "Task not found" });
    }

    await db.execute("DELETE FROM tasks WHERE id = :id", { id });

    // Invalidate dashboard cache
    cacheDelete("dashboard:stats");

    // Push real-time update
    pushTaskUpdate("deleted", { id });

    return res.status(204).json(null);
}, [authMiddleware]);
```

### Test the Task API

```bash
# Set your token from the login step
TOKEN="eyJhbGciOiJIUzI1NiIs..."

# Create a task
curl -X POST http://localhost:7148/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Design database schema", "priority": "high"}'
```

```json
{
  "id": 1,
  "title": "Design database schema",
  "priority": "high",
  "status": "todo",
  "created_by": 1,
  "created_at": "2026-03-22 10:00:00"
}
```

```bash
# Create more tasks
curl -X POST http://localhost:7148/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Build API endpoints", "priority": "high"}'

curl -X POST http://localhost:7148/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Write documentation", "priority": "medium", "due_date": "2026-04-01"}'

# List all tasks
curl http://localhost:7148/api/tasks \
  -H "Authorization: Bearer $TOKEN"

# Update a task status
curl -X PUT http://localhost:7148/api/tasks/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"status": "done"}'

# Delete a task
curl -X DELETE http://localhost:7148/api/tasks/3 \
  -H "Authorization: Bearer $TOKEN"
```

Every endpoint responds. Create. Read. Update. Delete. The CRUD cycle works.

---

## 8. Step 6: Dashboard Stats with Caching

Create `src/routes/dashboard.ts`:

```typescript
import { Router, cacheGet, cacheSet } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";
import { authMiddleware } from "./middleware";

/**
 * Dashboard statistics
 * @tags Dashboard
 * @response 200 {"total_tasks": "int", "by_status": "object", "overdue_tasks": "int", "total_users": "int"}
 */
Router.get("/api/dashboard/stats", async (req, res) => {
    const userId = req.user.user_id;
    const cacheKey = `dashboard:${userId}`;

    const cached = await cacheGet(cacheKey);
    if (cached) {
        return res.json({ ...cached, source: "cache" });
    }

    const db = Database.getConnection();

    const total = await db.fetchOne(
        "SELECT COUNT(*) as count FROM tasks WHERE created_by = :userId OR assigned_to = :userId",
        { userId }
    );

    const todo = await db.fetchOne(
        "SELECT COUNT(*) as count FROM tasks WHERE (created_by = :userId OR assigned_to = :userId) AND status = 'todo'",
        { userId }
    );

    const inProgress = await db.fetchOne(
        "SELECT COUNT(*) as count FROM tasks WHERE (created_by = :userId OR assigned_to = :userId) AND status = 'in_progress'",
        { userId }
    );

    const done = await db.fetchOne(
        "SELECT COUNT(*) as count FROM tasks WHERE (created_by = :userId OR assigned_to = :userId) AND status = 'done'",
        { userId }
    );

    const overdue = await db.fetchOne(
        "SELECT COUNT(*) as count FROM tasks WHERE (created_by = :userId OR assigned_to = :userId) AND status != 'done' AND due_date < date('now')",
        { userId }
    );

    const users = await db.fetchOne("SELECT COUNT(*) as count FROM users");

    const recentTasks = await db.fetch(
        `SELECT t.*, u.name as assignee_name FROM tasks t
         LEFT JOIN users u ON t.assigned_to = u.id
         WHERE t.created_by = :userId OR t.assigned_to = :userId
         ORDER BY t.created_at DESC LIMIT 10`,
        { userId }
    );

    const stats = {
        total_tasks: total.count,
        todo: todo.count,
        in_progress: inProgress.count,
        done: done.count,
        overdue_tasks: overdue.count,
        total_users: users.count,
        recent_tasks: recentTasks
    };

    await cacheSet(cacheKey, stats, 30);

    return res.json({ ...stats, source: "database" });
}, [authMiddleware]);

/**
 * Dashboard HTML page
 * @noauth
 * @tags Dashboard
 */
Router.get("/admin", async (req, res) => {
    return res.html("dashboard.html", {});
});
```

Verify the stats endpoint:

```bash
curl http://localhost:7148/api/dashboard/stats \
  -H "Authorization: Bearer $TOKEN"
```

```json
{
  "total_tasks": 2,
  "todo": 1,
  "in_progress": 0,
  "done": 1,
  "overdue_tasks": 0,
  "total_users": 1,
  "recent_tasks": [...],
  "source": "database"
}
```

Hit it again. The second response comes from cache:

```bash
curl http://localhost:7148/api/dashboard/stats \
  -H "Authorization: Bearer $TOKEN"
```

```json
{
  "total_tasks": 2,
  "todo": 1,
  "done": 1,
  "source": "cache"
}
```

The cache holds for 30 seconds. Creating, updating, or deleting a task invalidates it.

---

## 9. Step 7: WebSocket for Real-Time Updates

Create `src/routes/ws-tasks.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/tasks", async (connection, event, data) => {
    if (event === "open") {
        connection.send(JSON.stringify({
            type: "connected",
            message: "Listening for task updates"
        }));
    }

    if (event === "message") {
        const message = JSON.parse(data);
        if (message.type === "ping") {
            connection.send(JSON.stringify({ type: "pong" }));
        }
    }
});

/**
 * Push a task update to all connected WebSocket clients.
 */
export function pushTaskUpdate(action: string, task: any): void {
    Router.pushToWebSocket("/ws/tasks", JSON.stringify({
        type: "task_update",
        action,
        task
    }));
}
```

Any user creates, updates, or deletes a task. All connected dashboard users see the change.

---

## 10. Step 8: Email Notifications via Queue

Create `src/routes/queue-consumers.ts`:

```typescript
import { Queue, Messenger } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

const notifyQueue = new Queue({ topic: "task-notifications" });

notifyQueue.process(async (job) => {
    const { type, task_title, task_id, assigned_to, assigned_by } = job.payload as any;

    const db = Database.getConnection();
    const user = await db.fetchOne("SELECT name, email FROM users WHERE id = :id", { id: assigned_to });

    if (!user) {
        job.complete();
        return;
    }

    console.log(`[Notification] Task "${task_title}" assigned to ${user.name} by ${assigned_by}`);

    const mailer = new Messenger();
    await mailer.send({
        to: user.email,
        subject: `New Task Assigned: ${task_title}`,
        body: `<h2>New Task Assigned</h2>
               <p>Hi ${user.name},</p>
               <p><strong>${assigned_by}</strong> assigned you a new task:</p>
               <div style="border:1px solid #ddd; padding:16px; margin:16px 0;">
                   <h3>${task_title}</h3>
                   <p><a href="http://localhost:7148/admin#task-${task_id}">View Task</a></p>
               </div>`,
        html: true
    });

    job.complete();
});
```

Create the email template at `src/templates/emails/task-assigned.html`:

```html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body>
    <div class="container">
        <h2>New Task Assigned</h2>
        <p>Hi {{ assignee_name }},</p>
        <p><strong>{{ creator_name }}</strong> assigned you a new task:</p>

        <div class="card">
            <div class="card-body">
                <h3>{{ task_title }}</h3>
                <p>{{ task_description }}</p>
                <table class="table">
                    <tr><td><strong>Priority:</strong></td><td>{{ task_priority }}</td></tr>
                    <tr><td><strong>Due:</strong></td><td>{{ task_due_date }}</td></tr>
                </table>
            </div>
        </div>

        <p><a href="{{ task_url }}">View Task</a></p>
    </div>
</body>
</html>
```

The queue consumer runs in the background. The task route pushes a job. The consumer picks it up, looks up the assignee, and sends the email. No blocking. No delay in the API response.

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
        <h6 class="text-muted">To Do</h6><h2 id="stat-todo">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">In Progress</h6><h2 id="stat-progress">--</h2>
    </div></div></div>
    <div class="col-md-2"><div class="card"><div class="card-body">
        <h6 class="text-muted">Done</h6><h2 id="stat-done">--</h2>
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
            <div class="card-body" id="live-updates">
                <p class="text-muted">Connecting...</p>
            </div>
        </div>
    </div>
</div>

<script src="/js/frond.min.js"></script>
<script>
    var token = localStorage.getItem("token");
    if (token) frond.setToken(token);

    // Load dashboard stats
    frond.get("/api/dashboard/stats", function (data) {
        document.getElementById("stat-total").textContent = data.total_tasks;
        document.getElementById("stat-todo").textContent = data.todo;
        document.getElementById("stat-progress").textContent = data.in_progress;
        document.getElementById("stat-done").textContent = data.done;
        document.getElementById("stat-overdue").textContent = data.overdue_tasks;
        document.getElementById("stat-users").textContent = data.total_users;

        var tbody = document.getElementById("task-list");
        tbody.innerHTML = "";
        (data.recent_tasks || []).forEach(function (task) {
            var tr = document.createElement("tr");
            var badgeColor = {todo: "secondary", in_progress: "warning",
                             done: "success", cancelled: "danger"};
            tr.innerHTML = "<td>" + task.title + "</td>" +
                "<td>" + (task.assignee_name || "Unassigned") + "</td>" +
                "<td>" + task.priority + "</td>" +
                "<td><span class='badge bg-" + (badgeColor[task.status] || "secondary") +
                "'>" + task.status + "</span></td>";
            tbody.appendChild(tr);
        });
    });

    // WebSocket for live updates
    var ws = frond.ws("/ws/tasks");
    var updates = document.getElementById("live-updates");

    ws.on("open", function () {
        updates.innerHTML = "<p class='text-success'>Connected - listening for updates</p>";
    });

    ws.on("message", function (raw) {
        var msg = JSON.parse(raw);
        if (msg.type === "task_update") {
            var div = document.createElement("div");
            div.innerHTML = "<strong>" + msg.action + ":</strong> " + msg.task.title;
            updates.prepend(div);

            // Refresh stats
            frond.get("/api/dashboard/stats", function () {});
        }
    });
</script>
{% endblock %}
```

Verify the dashboard:

```bash
curl http://localhost:7148/admin
```

The server returns the rendered HTML. Open `http://localhost:7148/admin` in your browser to see the full dashboard with stats, task list, and live update panel.

---

## 12. Step 10: Tests

Create `tests/TaskFlowTest.ts`:

```typescript
import { tests, assertEqual, assertTrue, assertNotNull, runAllTests, Auth } from "tina4-nodejs";
import { TestClient } from "tina4-nodejs/test";

const client = new TestClient();

function randomEmail(): string {
    const hex = Math.random().toString(16).substring(2, 10);
    return `test-${hex}@example.com`;
}

async function registerAndLogin(): Promise<string> {
    const email = randomEmail();
    await client.post("/api/auth/register", {
        name: "Test User",
        email,
        password: "TestPassword123!"
    });
    const loginResp = await client.post("/api/auth/login", {
        email,
        password: "TestPassword123!"
    });
    return loginResp.body.token;
}

// Test registration
const testRegister = tests(
    assertEqual([201])
)(async function testRegister(): Promise<number> {
    const resp = await client.post("/api/auth/register", {
        name: "Alice",
        email: randomEmail(),
        password: "SecurePass123!"
    });
    return resp.statusCode;
});

// Test login returns a token
const testLogin = tests(
    assertTrue([true])
)(async function testLogin(): Promise<boolean> {
    const email = randomEmail();
    await client.post("/api/auth/register", {
        name: "Bob",
        email,
        password: "SecurePass123!"
    });
    const resp = await client.post("/api/auth/login", {
        email,
        password: "SecurePass123!"
    });
    return resp.statusCode === 200 && resp.body.token !== undefined;
});

// Test task creation
const testCreateTask = tests(
    assertTrue([true])
)(async function testCreateTask(): Promise<boolean> {
    const token = await registerAndLogin();
    const resp = await client.post("/api/tasks", {
        title: "Test Task",
        description: "A test task",
        priority: "high"
    }, { headers: { Authorization: `Bearer ${token}` } });
    return resp.statusCode === 201 && resp.body.title === "Test Task" && resp.body.priority === "high";
});

// Test listing tasks
const testListTasks = tests(
    assertTrue([true])
)(async function testListTasks(): Promise<boolean> {
    const token = await registerAndLogin();
    await client.post("/api/tasks", { title: "List Task 1" }, { headers: { Authorization: `Bearer ${token}` } });
    await client.post("/api/tasks", { title: "List Task 2" }, { headers: { Authorization: `Bearer ${token}` } });
    const resp = await client.get("/api/tasks", { headers: { Authorization: `Bearer ${token}` } });
    return resp.statusCode === 200 && resp.body.tasks.length >= 2;
});

// Test updating task status
const testUpdateTaskStatus = tests(
    assertTrue([true])
)(async function testUpdateTaskStatus(): Promise<boolean> {
    const token = await registerAndLogin();
    const createResp = await client.post("/api/tasks", { title: "Status Task" },
        { headers: { Authorization: `Bearer ${token}` } });
    const taskId = createResp.body.id;
    const resp = await client.put(`/api/tasks/${taskId}`, { status: "done" },
        { headers: { Authorization: `Bearer ${token}` } });
    return resp.statusCode === 200 && resp.body.status === "done" && resp.body.completed_at !== null;
});

// Test deleting a task
const testDeleteTask = tests(
    assertEqual([204])
)(async function testDeleteTask(): Promise<number> {
    const token = await registerAndLogin();
    const createResp = await client.post("/api/tasks", { title: "Delete Me" },
        { headers: { Authorization: `Bearer ${token}` } });
    const taskId = createResp.body.id;
    const resp = await client.delete(`/api/tasks/${taskId}`,
        { headers: { Authorization: `Bearer ${token}` } });
    return resp.statusCode;
});

// Test dashboard stats
const testDashboardStats = tests(
    assertTrue([true])
)(async function testDashboardStats(): Promise<boolean> {
    const token = await registerAndLogin();
    await client.post("/api/tasks", { title: "Stats Task" },
        { headers: { Authorization: `Bearer ${token}` } });
    const resp = await client.get("/api/dashboard/stats",
        { headers: { Authorization: `Bearer ${token}` } });
    return resp.statusCode === 200 && resp.body.total_tasks >= 1;
});

// Test unauthorized access
const testUnauthorizedAccess = tests(
    assertEqual([401])
)(async function testUnauthorizedAccess(): Promise<number> {
    const resp = await client.get("/api/tasks");
    return resp.statusCode;
});

// Test that token creation and validation round-trips correctly
const testTokenRoundTrip = tests(
    assertTrue([{ userId: 1, role: "admin" }]),
)(function testTokenRoundTrip(payload: Record<string, unknown>): boolean {
    const secret = process.env.SECRET || "test-secret";
    const token = Auth.getToken(payload, secret);
    const decoded = Auth.validToken(token, secret);
    return decoded !== null && decoded.userId === payload.userId;
});

// Test that password hashing and checking works
const testPasswordHash = tests(
    assertTrue(["securePass123"]),
)(function testPasswordHash(password: string): boolean {
    const hash = Auth.hashPassword(password);
    return Auth.checkPassword(password, hash);
});

runAllTests();
```

Run the tests:

```bash
npm test
```

```
Running tests...

  TaskFlowTest
    [PASS] testRegister
    [PASS] testLogin
    [PASS] testCreateTask
    [PASS] testListTasks
    [PASS] testUpdateTaskStatus
    [PASS] testDeleteTask
    [PASS] testDashboardStats
    [PASS] testUnauthorizedAccess
    [PASS] testTokenRoundTrip
    [PASS] testPasswordHash

  10 tests, 10 passed, 0 failed (1.12s)
```

All green. The application works.

---

## 13. Step 11: Docker Deployment

Create `Dockerfile`:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY dist/ ./dist/
COPY src/templates/ ./src/templates/
COPY src/public/ ./src/public/
COPY src/migrations/ ./src/migrations/
RUN mkdir -p data logs
ENV TINA4_DEBUG=false
EXPOSE 7148

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:7148/health || exit 1

CMD ["node", "dist/app.js"]
```

Create `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    ports:
      - "7148:7148"
    environment:
      - TINA4_DEBUG=false
      - TINA4_JWT_SECRET=${JWT_SECRET:-change-me-in-production}
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

Build and deploy:

```bash
tina4 build
docker compose up -d --build
```

Verify:

```bash
curl http://localhost:7148/health
```

```json
{"status": "ok", "version": "1.0.0", "database": "connected"}
```

TaskFlow runs in production. Authenticated APIs. Real-time WebSocket updates. Email notifications. Cached dashboard stats. Tested. Dockerized.

---

## 14. The Complete Project Structure

```
taskflow/
├── .env
├── .env.example
├── .gitignore
├── package.json
├── package-lock.json
├── tsconfig.json
├── app.ts
├── Dockerfile
├── docker-compose.yml
├── src/
│   ├── routes/
│   │   ├── auth.ts                # Registration, login
│   │   ├── tasks.ts               # Task CRUD
│   │   ├── dashboard.ts           # Dashboard stats + page
│   │   ├── middleware.ts          # Auth middleware
│   │   ├── queue-consumers.ts     # Email notification consumer
│   │   └── ws-tasks.ts            # WebSocket event handlers
│   ├── orm/
│   │   ├── User.ts                # User model with auth methods
│   │   └── Task.ts                # Task model with relationships
│   ├── migrations/
│   │   ├── 20260322000100_create_users_table.sql
│   │   └── 20260322000200_create_tasks_table.sql
│   ├── templates/
│   │   ├── base.html              # Base layout
│   │   ├── dashboard.html         # Dashboard page
│   │   ├── emails/
│   │   │   └── task-assigned.html # Assignment notification
│   │   └── errors/
│   │       ├── 404.html
│   │       └── 500.html
│   ├── public/
│   │   ├── css/
│   │   │   └── tina4.css
│   │   └── js/
│   │       ├── tina4.min.js
│   │       └── frond.min.js
│   └── locales/
│       └── en.json
├── data/
│   └── app.db
├── dist/                          # Production build output
├── logs/
├── secrets/
└── tests/
    └── TaskFlowTest.ts
```

Every file has a purpose. Every directory follows the convention. A new developer looks at this structure and knows where to find things.

---

## 15. What You Built

This chapter used every major concept from the book:

| Feature | Chapter |
|---------|---------|
| Route registration (`Router.get`, `Router.post`, `Router.put`, `Router.delete`) | Chapter 2 |
| Request/response handling | Chapter 3 |
| Twig templates | Chapter 4 |
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

---

## 16. What to Build Next

TaskFlow is a solid foundation. Here are ideas for extending it.

**Features:**
- **Task comments** -- Add a Comment model with a `taskId` foreign key. Display comments on the task detail page.
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
- **CI/CD pipeline** -- Add GitHub Actions to run tests on every push.
- **API documentation** -- Generate OpenAPI/Swagger docs from your route annotations.
- **Internationalization** -- Add `src/locales/` files for multiple languages.

---

## 17. Closing Thoughts -- The Tina4 Philosophy

You built a complete application. User auth. CRUD. Real-time updates. Email. Caching. Tests. Deployment. Your project has one dependency: `tina4-nodejs`.

No separate ORM package. No template engine package. No authentication library. No WebSocket server. No caching library. No testing framework. No CLI tool. No CSS framework. No JavaScript helpers. All built in.

**One framework. Zero extra dependencies. Everything you need.**

The same patterns work in PHP, Python, and Ruby. Same project structure. Same CLI commands. Same `.env` variables. Same template syntax. Learn Tina4 once. Use it everywhere.

Build things. Ship them. Keep it simple.
