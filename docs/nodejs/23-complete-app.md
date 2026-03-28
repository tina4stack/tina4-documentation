# Chapter 21: Building a Complete App

## 1. Putting It All Together

Twenty chapters. Routing. Templates. Databases. ORM. Authentication. Middleware. Queues. WebSocket. Caching. Frontend. GraphQL. Testing. Dev tools. CLI scaffolding. Deployment.

Time to use all of it. From scratch.

We are building **TaskFlow** -- a task management system with:

- User registration and JWT authentication
- Task creation, assignment, and tracking
- A dashboard with real-time updates
- Email notifications when tasks are assigned
- Caching for dashboard performance
- A full test suite
- Docker deployment

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

```bash
tina4 migrate
```

---

## 4. Step 2: Define Models

Create `src/orm/User.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

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
}
```

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
    next();
}
```

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

Router.get("/api/profile", async (req, res) => {
    const db = Database.getConnection();
    const user = await db.fetchOne(
        "SELECT id, name, email, role, created_at FROM users WHERE id = :id",
        { id: req.user.user_id }
    );
    return res.json(user);
}, [authMiddleware]);
```

---

## 7. Step 5: Task Routes

Create `src/routes/tasks.ts`:

```typescript
import { Router, Queue } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";
import { authMiddleware } from "./middleware";

/**
 * List tasks with filters
 * @tags Tasks
 * @query string status Filter by status (todo, in_progress, done)
 * @query string priority Filter by priority (low, medium, high)
 * @query string assigned Filter by assigned user ID
 * @query int page Page number
 */
Router.get("/api/tasks", async (req, res) => {
    const db = Database.getConnection();
    const userId = req.user.user_id;

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

    const sql = `SELECT t.*, 
        creator.name as creator_name, 
        assignee.name as assignee_name
        FROM tasks t
        LEFT JOIN users creator ON t.created_by = creator.id
        LEFT JOIN users assignee ON t.assigned_to = assignee.id
        WHERE ${conditions.join(" AND ")}
        ORDER BY 
            CASE t.priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END,
            t.created_at DESC`;

    const tasks = await db.fetch(sql, params);

    return res.json({ tasks, count: tasks.length });
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
    Router.pushToWebSocket("/ws/tasks", JSON.stringify({
        type: "task_created",
        task
    }));

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

    const completedAt = status === "done" && existing.status !== "done"
        ? new Date().toISOString()
        : existing.completed_at;

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
            assignedTo: assigned_to ?? existing.assigned_to,
            dueDate: due_date ?? existing.due_date,
            completedAt,
            id
        }
    );

    const task = await db.fetchOne("SELECT * FROM tasks WHERE id = :id", { id });

    Router.pushToWebSocket("/ws/tasks", JSON.stringify({ type: "task_updated", task }));

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

    Router.pushToWebSocket("/ws/tasks", JSON.stringify({ type: "task_deleted", task_id: id }));

    return res.status(204).json(null);
}, [authMiddleware]);
```

---

## 8. Step 6: Dashboard Stats

Create `src/routes/dashboard.ts`:

```typescript
import { Router, cacheGet, cacheSet } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";
import { authMiddleware } from "./middleware";

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

    const byStatus = await db.fetch(
        "SELECT status, COUNT(*) as count FROM tasks WHERE created_by = :userId OR assigned_to = :userId GROUP BY status",
        { userId }
    );

    const overdue = await db.fetchOne(
        "SELECT COUNT(*) as count FROM tasks WHERE (created_by = :userId OR assigned_to = :userId) AND status != 'done' AND due_date < date('now')",
        { userId }
    );

    const recentlyCompleted = await db.fetch(
        "SELECT * FROM tasks WHERE (created_by = :userId OR assigned_to = :userId) AND status = 'done' ORDER BY completed_at DESC LIMIT 5",
        { userId }
    );

    const stats = {
        total_tasks: total.count,
        by_status: Object.fromEntries(byStatus.map(r => [r.status, r.count])),
        overdue_tasks: overdue.count,
        recently_completed: recentlyCompleted
    };

    await cacheSet(cacheKey, stats, 30);

    return res.json({ ...stats, source: "database" });
}, [authMiddleware]);

Router.get("/admin", async (req, res) => {
    return res.html("dashboard.html", {});
});
```

---

## 9. Step 7: WebSocket for Real-Time Updates

Create `src/routes/ws-tasks.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/tasks", async (connection, event, data) => {
    if (event === "open") {
        connection.send(JSON.stringify({ type: "connected", message: "Listening for task updates" }));
    }
});
```

---

## 10. Step 8: Queue Consumer for Notifications

Create `src/routes/queue-consumers.ts`:

```typescript
import { Queue, Messenger } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

const notifyQueue = new Queue({ topic: "task-notifications" });

notifyQueue.process(async (job) => {
    const { type, task_title, assigned_to, assigned_by } = job.payload as any;

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
        body: `<h2>New Task Assigned</h2><p>Hi ${user.name},</p><p>${assigned_by} assigned you a new task: <strong>${task_title}</strong></p>`,
        html: true
    });

    job.complete();
});
```

---

## 11. Step 9: Tests

Create `tests/TaskFlowTest.ts`:

```typescript
import { tests, assertEqual, assertTrue, runAllTests, Auth } from "tina4-nodejs";

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

Run tests:

```bash
npm test
```

---

## 12. Step 10: Docker Deployment

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY dist/ ./dist/
COPY src/templates/ ./src/templates/
COPY src/public/ ./src/public/
COPY src/migrations/ ./src/migrations/
ENV TINA4_DEBUG=false
EXPOSE 7148
CMD ["node", "dist/app.js"]
```

```bash
tina4 build
docker build -t taskflow .
docker run -p 7148:7148 -v taskflow-data:/app/data taskflow
```

---

## 13. What We Built

TaskFlow exercises every major Tina4 feature:

- **Routing** -- RESTful API with explicit route registration
- **ORM** -- User and Task models with relationships
- **Database** -- SQLite with migrations, parameterised queries
- **Authentication** -- JWT tokens, password hashing, auth middleware
- **Middleware** -- Auth protection on route groups
- **Queues** -- Background email notifications
- **WebSocket** -- Real-time task updates
- **Caching** -- Dashboard stats cached for 30 seconds
- **Templates** -- Dashboard HTML page with tina4css
- **Swagger** -- Annotated API documentation
- **Testing** -- Full test suite
- **Deployment** -- Docker with Nginx

All of this in a single npm package. Zero dependencies. One framework doing the work of twelve.
