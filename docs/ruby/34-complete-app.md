# Chapter 21: Building a Complete App

## 1. Putting It All Together

Twenty chapters of building blocks. Routing. Templates. Databases. ORM. Authentication. Middleware. Queues. WebSocket. Caching. Frontend. GraphQL. Testing. Dev tools. CLI scaffolding. Deployment. Now all of it works together in one application.

**TaskFlow** -- a task management system with:

- User registration and JWT authentication
- Task creation, assignment, and tracking
- A dashboard with real-time updates via WebSocket
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
tina4 init taskflow --lang ruby
cd taskflow
bundle install
```

Update `.env`:

```env
TINA4_DEBUG=true
JWT_SECRET=taskflow-dev-secret-change-in-production
JWT_EXPIRY=86400
```

### Create Migrations

Create `src/migrations/20260322150000_create_users_table.sql`:

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

Create `src/migrations/20260322150100_create_tasks_table.sql`:

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
  [UP] 20260322150000_create_users_table.sql
  [UP] 20260322150100_create_tasks_table.sql

  2 migrations applied
```

Verify the database:

```bash
curl http://localhost:7147/health
```

```json
{"status": "ok", "database": "connected"}
```

---

## 4. Step 2: ORM Models

Create `src/orm/user.rb`:

```ruby
class User < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  string_field :email
  string_field :password_hash
  string_field :role, default: "user"
  string_field :created_at

  table_name "users"

  has_many :created_tasks, class_name: "Task", foreign_key: "created_by"
  has_many :assigned_tasks, class_name: "Task", foreign_key: "assigned_to"
end
```

Create `src/orm/task.rb`:

```ruby
class Task < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :title
  string_field :description, default: ""
  string_field :status, default: "todo"
  string_field :priority, default: "medium"
  integer_field :created_by
  integer_field :assigned_to
  string_field :due_date
  string_field :completed_at
  string_field :created_at
  string_field :updated_at

  table_name "tasks"

  belongs_to :creator, class_name: "User", foreign_key: "created_by"
  belongs_to :assignee, class_name: "User", foreign_key: "assigned_to"
end
```

---

## 5. Step 3: Authentication

Create `src/routes/middleware.rb`:

```ruby
def auth_middleware(request, response, next_handler)
  auth_header = request.headers["Authorization"] || ""

  if auth_header.empty? || !auth_header.start_with?("Bearer ")
    return response.json({ error: "Authorization required" }, 401)
  end

  token = auth_header.sub("Bearer ", "")

  unless Tina4::Auth.valid_token(token)
    return response.json({ error: "Invalid or expired token" }, 401)
  end

  request.user = Tina4::Auth.get_payload(token)
  next_handler.call(request, response)
end
```

Create `src/routes/auth.rb`:

```ruby
# @noauth
Tina4::Router.post("/api/auth/register") do |request, response|
  body = request.body

  errors = []
  errors << "Name is required" if body["name"].nil? || body["name"].empty?
  errors << "Email is required" if body["email"].nil? || body["email"].empty?
  errors << "Password must be at least 8 characters" if body["password"].nil? || body["password"].to_s.length < 8

  return response.json({ errors: errors }, 400) unless errors.empty?

  db = Tina4.database
  existing = db.fetch_one("SELECT id FROM users WHERE email = ?", [body["email"]])
  return response.json({ error: "Email already registered" }, 409) unless existing.nil?

  hash = Tina4::Auth.hash_password(body["password"])
  db.execute("INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
    [body["name"], body["email"], hash])

  user = db.fetch_one("SELECT id, name, email, role FROM users WHERE id = last_insert_rowid()")
  response.json({ message: "Registration successful", user: user }, 201)
end

# @noauth
Tina4::Router.post("/api/auth/login") do |request, response|
  body = request.body

  db = Tina4.database
  user = db.fetch_one("SELECT * FROM users WHERE email = ?", [body["email"]])

  if user.nil? || !Tina4::Auth.check_password(body["password"] || "", user["password_hash"])
    return response.json({ error: "Invalid email or password" }, 401)
  end

  token = Tina4::Auth.get_token({
    user_id: user["id"], email: user["email"], name: user["name"], role: user["role"]
  })

  response.json({
    message: "Login successful",
    token: token,
    user: { id: user["id"], name: user["name"], email: user["email"], role: user["role"] }
  })
end

Tina4::Router.get("/api/profile", middleware: "auth_middleware") do |request, response|
  db = Tina4.database
  user = db.fetch_one("SELECT id, name, email, role, created_at FROM users WHERE id = ?",
    [request.user["user_id"]])
  response.json(user)
end
```

### Test Registration and Login

```bash
# Start the server
tina4 serve
```

```bash
# Register a user
curl -X POST http://localhost:7147/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Johnson", "email": "alice@example.com", "password": "securepass123"}'
```

```json
{
  "message": "Registration successful",
  "user": {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "role": "user"
  }
}
```

```bash
# Login
curl -X POST http://localhost:7147/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securepass123"}'
```

```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "role": "user"
  }
}
```

Authentication works. Save the token for the next steps.

---

## 6. Step 4: Task CRUD

Create `src/routes/tasks.rb`:

```ruby
Tina4::Router.group("/api/tasks", middleware: "auth_middleware") do

  # List tasks with filters
  Tina4::Router.get("") do |request, response|
    db = Tina4.database
    user_id = request.user["user_id"]

    status = request.params["status"]
    priority = request.params["priority"]
    assigned = request.params["assigned_to_me"]

    sql = "SELECT t.*, u1.name AS creator_name, u2.name AS assignee_name FROM tasks t LEFT JOIN users u1 ON t.created_by = u1.id LEFT JOIN users u2 ON t.assigned_to = u2.id"
    conditions = []
    params = {}

    if assigned == "true"
      conditions << "t.assigned_to = :user_id"
      params[:user_id] = user_id
    end

    if status && !status.empty?
      conditions << "t.status = :status"
      params[:status] = status
    end

    if priority && !priority.empty?
      conditions << "t.priority = :priority"
      params[:priority] = priority
    end

    sql += " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
    sql += " ORDER BY t.created_at DESC"

    tasks = db.fetch(sql, params)
    response.json({ tasks: tasks, count: tasks.length })
  end

  # Get single task
  Tina4::Router.get("/{id:int}") do |request, response|
    db = Tina4.database
    id = request.params["id"]

    task = db.fetch_one("SELECT t.*, u1.name AS creator_name, u2.name AS assignee_name FROM tasks t LEFT JOIN users u1 ON t.created_by = u1.id LEFT JOIN users u2 ON t.assigned_to = u2.id WHERE t.id = ?", [id])

    if task.nil?
      return response.json({ error: "Task not found" }, 404)
    end

    response.json(task)
  end

  # Create task
  Tina4::Router.post("") do |request, response|
    body = request.body
    user_id = request.user["user_id"]

    if body["title"].nil? || body["title"].empty?
      return response.json({ error: "Title is required" }, 400)
    end

    db = Tina4.database
    db.execute(
      "INSERT INTO tasks (title, description, status, priority, created_by, assigned_to, due_date) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [body["title"], body["description"] || "", body["status"] || "todo", body["priority"] || "medium", user_id, body["assigned_to"], body["due_date"]]
    )

    task = db.fetch_one("SELECT * FROM tasks WHERE id = last_insert_rowid()")

    # Queue notification if assigned to someone else
    if body["assigned_to"] && body["assigned_to"].to_i != user_id
      assignee = db.fetch_one("SELECT name, email FROM users WHERE id = ?", [body["assigned_to"]])
      if assignee
        Tina4::Queue.produce("send-email", {
          to: assignee["email"],
          subject: "New task assigned: #{body['title']}",
          template: "emails/task-assigned.html",
          data: { task_title: body["title"], assignee_name: assignee["name"], assigner_name: request.user["name"] }
        })
      end
    end

    # Push WebSocket update
    Tina4::WebSocket.broadcast("/ws/tasks", {
      type: "task_update",
      action: "created",
      task: task
    }.to_json)

    # Invalidate cache
    Tina4.cache_delete("dashboard:stats:#{user_id}")

    response.json(task, 201)
  end

  # Update task
  Tina4::Router.put("/{id:int}") do |request, response|
    db = Tina4.database
    id = request.params["id"]
    body = request.body

    existing = db.fetch_one("SELECT * FROM tasks WHERE id = ?", [id])
    return response.json({ error: "Task not found" }, 404) if existing.nil?

    completed_at = existing["completed_at"]
    if body["status"] == "done" && existing["status"] != "done"
      completed_at = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    elsif body["status"] && body["status"] != "done"
      completed_at = nil
    end

    db.execute(
      "UPDATE tasks SET title = ?, description = ?, status = ?, priority = ?, assigned_to = ?, due_date = ?, completed_at = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      [
        body["title"] || existing["title"],
        body["description"] || existing["description"],
        body["status"] || existing["status"],
        body["priority"] || existing["priority"],
        body.key?("assigned_to") ? body["assigned_to"] : existing["assigned_to"],
        body["due_date"] || existing["due_date"],
        completed_at,
        id
      ]
    )

    # Push WebSocket update
    task = db.fetch_one("SELECT * FROM tasks WHERE id = ?", [id])
    Tina4::WebSocket.broadcast("/ws/tasks", {
      type: "task_update",
      action: "updated",
      task: task
    }.to_json)

    # Invalidate cache
    Tina4.cache_delete("dashboard:stats:#{request.user['user_id']}")

    response.json(task)
  end

  # Delete task
  Tina4::Router.delete("/{id:int}") do |request, response|
    db = Tina4.database
    id = request.params["id"]

    existing = db.fetch_one("SELECT * FROM tasks WHERE id = ?", [id])
    return response.json({ error: "Task not found" }, 404) if existing.nil?

    db.execute("DELETE FROM tasks WHERE id = ?", [id])

    Tina4::WebSocket.broadcast("/ws/tasks", {
      type: "task_update",
      action: "deleted",
      task: { id: id }
    }.to_json)

    Tina4.cache_delete("dashboard:stats:#{request.user['user_id']}")

    response.json(nil, 204)
  end

end
```

### Test the Task API

```bash
# Set your token from the login step
TOKEN="eyJhbGciOiJIUzI1NiIs..."

# Create a task
curl -X POST http://localhost:7147/api/tasks \
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
curl -X POST http://localhost:7147/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Build API endpoints", "priority": "high"}'

curl -X POST http://localhost:7147/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "Write documentation", "priority": "medium", "due_date": "2026-04-01"}'

# List all tasks
curl http://localhost:7147/api/tasks \
  -H "Authorization: Bearer $TOKEN"

# Update a task status
curl -X PUT http://localhost:7147/api/tasks/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"status": "done"}'

# Delete a task
curl -X DELETE http://localhost:7147/api/tasks/3 \
  -H "Authorization: Bearer $TOKEN"
```

Every endpoint responds. Create. Read. Update. Delete. The CRUD cycle works.

---

## 7. Step 5: Dashboard Stats with Caching

Create `src/routes/dashboard.rb`:

```ruby
Tina4::Router.get("/api/dashboard/stats", middleware: "auth_middleware") do |request, response|
  user_id = request.user["user_id"]

  cache_key = "dashboard:stats:#{user_id}"
  stats = Tina4.cache_get(cache_key)

  if stats.nil?
    db = Tina4.database

    total = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE assigned_to = ? OR created_by = ?", [user_id, user_id])
    todo = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = ? OR created_by = ?) AND status = 'todo'", [user_id, user_id])
    in_progress = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = ? OR created_by = ?) AND status = 'in_progress'", [user_id, user_id])
    done = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = ? OR created_by = ?) AND status = 'done'", [user_id, user_id])
    overdue = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = ? OR created_by = ?) AND due_date < date('now') AND status != 'done'", [user_id, user_id])

    recent = db.fetch(
      "SELECT t.*, u.name AS assignee_name FROM tasks t LEFT JOIN users u ON t.assigned_to = u.id ORDER BY t.created_at DESC LIMIT 10"
    )

    stats = {
      total_tasks: total["count"],
      todo: todo["count"],
      in_progress: in_progress["count"],
      done: done["count"],
      overdue: overdue["count"],
      recent_tasks: recent
    }

    Tina4.cache_set(cache_key, stats, 30)
  end

  response.json(stats)
end

Tina4::Router.get("/admin") do |request, response|
  response.render("dashboard.html", {
    title: "TaskFlow Dashboard"
  })
end
```

Verify the stats endpoint:

```bash
curl http://localhost:7147/api/dashboard/stats \
  -H "Authorization: Bearer $TOKEN"
```

```json
{
  "total_tasks": 2,
  "todo": 1,
  "in_progress": 0,
  "done": 1,
  "overdue": 0,
  "recent_tasks": [...]
}
```

Hit it again within 30 seconds. The second response comes from cache -- no database queries.

---

## 8. Step 6: WebSocket Real-Time Updates

Create `src/routes/task_ws.rb`:

```ruby
Tina4::WebSocket.on("/ws/tasks") do |connection, event, data|
  case event
  when "open"
    connection.send({ type: "connected", message: "Listening for task updates" }.to_json)

  when "message"
    message = JSON.parse(data)
    if message["type"] == "ping"
      connection.send({ type: "pong" }.to_json)
    end

  when "close"
    # Connection closed -- cleanup if needed
  end
end
```

Any user creates, updates, or deletes a task. All connected dashboard users see the change. The `Tina4::WebSocket.broadcast` calls in the task routes (Step 4) push updates to every client connected to `/ws/tasks`.

---

## 9. Step 7: Email Notifications

Create the queue consumer for task assignment notifications:

```ruby
Tina4::Queue.consume("send-email") do |job|
  mail = Tina4::Messenger.new
  mail.to = job.payload["to"]
  mail.subject = job.payload["subject"]

  if job.payload["template"]
    mail.html_template = job.payload["template"]
    mail.template_data = job.payload["data"] || {}
  else
    mail.body = job.payload["body"] || ""
  end

  mail.send
  true
end
```

Create `src/templates/emails/task-assigned.html`:

```html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body>
    <div class="container">
        <h2>New Task Assigned</h2>
        <p>Hi {{ assignee_name }},</p>
        <p><strong>{{ assigner_name }}</strong> assigned you a new task:</p>

        <div class="card">
            <div class="card-body">
                <h3>{{ task_title }}</h3>
            </div>
        </div>

        <p><a href="http://localhost:7147/admin">View Dashboard</a></p>
    </div>
</body>
</html>
```

Start the queue worker in a separate terminal:

```bash
tina4 queue:work
```

---

## 10. Step 8: Dashboard Template

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
        <h6 class="text-muted">Todo</h6><h2 id="stat-todo">--</h2>
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
</div>

<div class="row">
    <div class="col-md-8">
        <div class="card">
            <div class="card-header d-flex justify-content-between">
                <span>Recent Tasks</span>
                <button class="btn btn-sm btn-primary" onclick="showNewTaskForm()">
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
        document.getElementById("stat-overdue").textContent = data.overdue;

        var tbody = document.getElementById("task-list");
        tbody.innerHTML = "";
        (data.recent_tasks || []).forEach(function (task) {
            var tr = document.createElement("tr");
            var badgeColor = {todo: "secondary", in_progress: "warning",
                             done: "success"};
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

Open `http://localhost:7147/admin` in your browser to see the full dashboard with stats, task list, and live update panel.

---

## 11. Step 9: Tests

Create `tests/taskflow_spec.rb`:

```ruby
require "tina4"

RSpec.describe "TaskFlow" do
  let(:client) { Tina4::TestClient.new }
  let(:token) do
    email = "test#{rand(100000)}@example.com"
    client.post("/api/auth/register", {
      name: "Test User", email: email, password: "password123"
    })
    result = client.post("/api/auth/login", {
      email: email, password: "password123"
    })
    result.json["token"]
  end

  it "registers a user" do
    result = client.post("/api/auth/register", {
      name: "Alice", email: "alice#{rand(100000)}@example.com", password: "securePass123"
    })
    expect(result.status).to eq(201)
  end

  it "rejects duplicate email" do
    email = "dup#{rand(100000)}@example.com"
    client.post("/api/auth/register", {
      name: "First", email: email, password: "password123"
    })
    result = client.post("/api/auth/register", {
      name: "Second", email: email, password: "password123"
    })
    expect(result.status).to eq(409)
  end

  it "creates a task" do
    result = client.post("/api/tasks", { title: "Test Task" },
      headers: { "Authorization" => "Bearer #{token}" })
    expect(result.status).to eq(201)
    expect(result.json["title"]).to eq("Test Task")
    expect(result.json["status"]).to eq("todo")
  end

  it "lists tasks" do
    client.post("/api/tasks", { title: "Task 1" }, headers: { "Authorization" => "Bearer #{token}" })
    client.post("/api/tasks", { title: "Task 2" }, headers: { "Authorization" => "Bearer #{token}" })

    result = client.get("/api/tasks", headers: { "Authorization" => "Bearer #{token}" })
    expect(result.status).to eq(200)
    expect(result.json["tasks"]).to be_an(Array)
  end

  it "updates a task status" do
    created = client.post("/api/tasks", { title: "Update Me" },
      headers: { "Authorization" => "Bearer #{token}" })
    id = created.json["id"]

    result = client.put("/api/tasks/#{id}", { status: "done" },
      headers: { "Authorization" => "Bearer #{token}" })
    expect(result.status).to eq(200)
    expect(result.json["status"]).to eq("done")
    expect(result.json["completed_at"]).not_to be_nil
  end

  it "deletes a task" do
    created = client.post("/api/tasks", { title: "Delete Me" },
      headers: { "Authorization" => "Bearer #{token}" })
    id = created.json["id"]

    result = client.delete("/api/tasks/#{id}",
      headers: { "Authorization" => "Bearer #{token}" })
    expect(result.status).to eq(204)
  end

  it "returns dashboard stats" do
    client.post("/api/tasks", { title: "Stats Task" },
      headers: { "Authorization" => "Bearer #{token}" })

    result = client.get("/api/dashboard/stats",
      headers: { "Authorization" => "Bearer #{token}" })
    expect(result.status).to eq(200)
    expect(result.json["total_tasks"]).to be >= 1
  end

  it "requires authentication for tasks" do
    result = client.get("/api/tasks")
    expect(result.status).to eq(401)
  end
end
```

Run the tests:

```bash
tina4 test
```

```
Running tests...

  TaskFlow
    registers a user
    rejects duplicate email
    creates a task
    lists tasks
    updates a task status
    deletes a task
    returns dashboard stats
    requires authentication for tasks

  8 examples, 0 failures (0.84s)
```

All green. The application works.

---

## 12. Step 10: Docker Deployment

Use the Dockerfile and docker-compose.yml from Chapter 20. Create `.env.production`:

```env
TINA4_DEBUG=false
TINA4_LOG_LEVEL=WARNING
JWT_SECRET=your-production-secret-at-least-32-characters
DATABASE_URL=sqlite:///data/app.db
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_HOST=redis
```

Deploy:

```bash
docker compose up -d --build
```

Verify:

```bash
curl http://localhost:7147/health
```

```json
{"status": "ok", "version": "1.0.0", "database": "connected"}
```

TaskFlow runs in production. Authenticated APIs. Real-time WebSocket updates. Email notifications. Cached dashboard stats. Tested. Dockerized.

---

## 13. The Complete Project Structure

```
taskflow/
├── .env
├── .env.example
├── .gitignore
├── Gemfile
├── Gemfile.lock
├── app.rb
├── Dockerfile
├── docker-compose.yml
├── config/
│   └── puma.rb
├── src/
│   ├── routes/
│   │   ├── auth.rb                # Registration, login
│   │   ├── tasks.rb               # Task CRUD
│   │   ├── dashboard.rb           # Dashboard stats + page
│   │   ├── middleware.rb          # Auth middleware
│   │   └── task_ws.rb             # WebSocket event handlers
│   ├── orm/
│   │   ├── user.rb                # User model with relationships
│   │   └── task.rb                # Task model with relationships
│   ├── migrations/
│   │   ├── 20260322150000_create_users_table.sql
│   │   └── 20260322150100_create_tasks_table.sql
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
├── logs/
├── secrets/
└── tests/
    └── taskflow_spec.rb
```

Every file has a purpose. Every directory follows the convention. A new developer looks at this structure and knows where to find things.

---

## 14. What You Built

This chapter used every major concept from the book:

| Feature | Chapter |
|---------|---------|
| Route definitions | Chapter 2 |
| Request/response handling | Chapter 3 |
| Frond templates | Chapter 4 |
| Database queries | Chapter 5 |
| ORM models (User, Task) | Chapter 6 |
| JWT authentication | Chapter 7 |
| Auth middleware | Chapter 8 |
| Queue-based email | Chapter 14 |
| Email notifications (Messenger) | Chapter 13 |
| Cache (dashboard stats) | Chapter 14 |
| Frontend (tina4css dashboard) | Chapter 15 |
| WebSocket (live updates) | Chapter 12 |
| Testing (full test suite) | Chapter 17 |
| Docker deployment | Chapter 20 |

---

## 15. What to Build Next

TaskFlow is a solid foundation. Here are ideas for extending it.

**Features:**
- **Task comments** -- Add a Comment model with a `task_id` foreign key. Display comments on the task detail page.
- **File attachments** -- Let users upload files to tasks. Store them in `data/uploads/` and serve them via a route.
- **Team management** -- Add a Team model. Users belong to teams. Tasks are scoped to teams.
- **Task labels/tags** -- Many-to-many relationship between tasks and labels for categorization.
- **Due date reminders** -- Use the queue system to schedule reminder emails 24 hours before a task's due date.
- **Activity log** -- Record every change to a task (who changed what, when) for audit trails.
- **Search** -- Full-text search across task titles and descriptions.
- **Calendar view** -- Render tasks on a calendar based on their due dates.
- **Mobile API** -- The API already works for mobile apps. Add push notification support.

**Technical improvements:**
- **Rate limiting per user** -- Replace the global rate limiter with per-user limits.
- **Database upgrade** -- Switch from SQLite to PostgreSQL for better concurrency.
- **CI/CD pipeline** -- Add GitHub Actions to run tests on every push.
- **API documentation** -- Generate OpenAPI/Swagger docs from your route definitions.
- **Internationalization** -- Add `src/locales/` files for multiple languages.

---

## 16. Gotchas

### 1. Circular Dependencies Between Models

**Problem:** User loads tasks, tasks load users, infinite loop.

**Fix:** Use lazy loading. Do not eager-load relationships that create cycles.

### 2. Cache Not Invalidated on Related Model Changes

**Problem:** Dashboard stats are stale after task updates.

**Fix:** Invalidate cache in every write operation: `Tina4.cache_delete("dashboard:stats:#{user_id}")`.

### 3. Queue Worker Not Processing Emails

**Problem:** Task assignment emails are queued but never sent.

**Fix:** Run `tina4 queue:work` in a separate terminal or as a systemd service.

### 4. Token Expired During Long Sessions

**Problem:** Users get logged out while actively using the dashboard.

**Fix:** Set a reasonable JWT expiry (`86400` for 24 hours) and implement token refresh.

### 5. WebSocket Notifications Not Received

**Problem:** Real-time dashboard updates do not work.

**Fix:** Ensure the WebSocket endpoint is configured, the server is running, and the client JavaScript connects to the correct URL. Check the browser console for connection errors.

### 6. Database Locked Under Load

**Problem:** SQLite returns "database is locked" errors with concurrent requests.

**Fix:** For production with concurrent users, switch to PostgreSQL. SQLite handles one writer at a time.

### 7. Missing Migration Before Deployment

**Problem:** The app crashes in production because a table does not exist.

**Fix:** Always run `tina4 migrate` as part of your deployment pipeline. Add it to your Dockerfile or CI/CD script.

---

## 17. Closing Thoughts -- The Tina4 Philosophy

You built a complete application. User auth. CRUD. Real-time updates. Email. Caching. Tests. Deployment. Your project has one dependency: `tina4`.

No separate ORM gem. No template engine gem. No authentication library. No WebSocket server. No caching library. No testing framework. No CLI tool. No CSS framework. No JavaScript helpers. All built in.

**One framework. Zero extra dependencies. Everything you need.**

The same patterns work in PHP, Python, and Node.js. Same project structure. Same CLI commands. Same `.env` variables. Same template syntax. Learn Tina4 once. Use it everywhere.

Build things. Ship them. Keep it simple.
