# Chapter 21: Building a Complete App

## 1. Putting It All Together

Twenty chapters. Routing. Templates. Databases. ORM. Authentication. Middleware. Queues. WebSocket. Caching. Frontend. GraphQL. Testing. Dev tools. CLI scaffolding. Deployment. Now they all converge into one application.

**TaskFlow** -- a task management system with:

- User registration and JWT authentication
- Task creation, assignment, and tracking
- A dashboard with real-time updates
- Email notifications when tasks are assigned
- Caching for dashboard performance
- A full test suite
- Docker deployment

This is not a toy. It is a production-ready application where every major Tina4 feature works in concert.

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

-- DOWN
DROP TABLE IF EXISTS tasks;
```

Run migrations:

```bash
tina4 migrate
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

  db = Tina4::Database.connection
  existing = db.fetch_one("SELECT id FROM users WHERE email = :email", { email: body["email"] })
  return response.json({ error: "Email already registered" }, 409) unless existing.nil?

  hash = Tina4::Auth.hash_password(body["password"])
  db.execute("INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
    { name: body["name"], email: body["email"], hash: hash })

  user = db.fetch_one("SELECT id, name, email, role FROM users WHERE id = last_insert_rowid()")
  response.json({ message: "Registration successful", user: user }, 201)
end

# @noauth
Tina4::Router.post("/api/auth/login") do |request, response|
  body = request.body

  db = Tina4::Database.connection
  user = db.fetch_one("SELECT * FROM users WHERE email = :email", { email: body["email"] })

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
  db = Tina4::Database.connection
  user = db.fetch_one("SELECT id, name, email, role, created_at FROM users WHERE id = :id",
    { id: request.user["user_id"] })
  response.json(user)
end
```

---

## 6. Step 4: Task CRUD

Create `src/routes/tasks.rb`:

```ruby
Tina4::Router.group("/api/tasks", middleware: "auth_middleware") do

  # List tasks with filters
  Tina4::Router.get("") do |request, response|
    db = Tina4::Database.connection
    user_id = request.user["user_id"]

    status = request.query["status"]
    priority = request.query["priority"]
    assigned = request.query["assigned_to_me"]

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
    db = Tina4::Database.connection
    id = request.params["id"]

    task = db.fetch_one("SELECT t.*, u1.name AS creator_name, u2.name AS assignee_name FROM tasks t LEFT JOIN users u1 ON t.created_by = u1.id LEFT JOIN users u2 ON t.assigned_to = u2.id WHERE t.id = :id", { id: id })

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

    db = Tina4::Database.connection
    db.execute(
      "INSERT INTO tasks (title, description, status, priority, created_by, assigned_to, due_date) VALUES (:title, :description, :status, :priority, :created_by, :assigned_to, :due_date)",
      {
        title: body["title"],
        description: body["description"] || "",
        status: body["status"] || "todo",
        priority: body["priority"] || "medium",
        created_by: user_id,
        assigned_to: body["assigned_to"],
        due_date: body["due_date"]
      }
    )

    task = db.fetch_one("SELECT * FROM tasks WHERE id = last_insert_rowid()")

    # Queue notification if assigned to someone else
    if body["assigned_to"] && body["assigned_to"].to_i != user_id
      assignee = db.fetch_one("SELECT name, email FROM users WHERE id = :id", { id: body["assigned_to"] })
      if assignee
        Tina4::Queue.produce("send-email", {
          to: assignee["email"],
          subject: "New task assigned: #{body['title']}",
          template: "emails/task-assigned.html",
          data: { task_title: body["title"], assignee_name: assignee["name"], assigner_name: request.user["name"] }
        })
      end
    end

    response.json(task, 201)
  end

  # Update task
  Tina4::Router.put("/{id:int}") do |request, response|
    db = Tina4::Database.connection
    id = request.params["id"]
    body = request.body

    existing = db.fetch_one("SELECT * FROM tasks WHERE id = :id", { id: id })
    return response.json({ error: "Task not found" }, 404) if existing.nil?

    completed_at = existing["completed_at"]
    if body["status"] == "done" && existing["status"] != "done"
      completed_at = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    elsif body["status"] && body["status"] != "done"
      completed_at = nil
    end

    db.execute(
      "UPDATE tasks SET title = :title, description = :description, status = :status, priority = :priority, assigned_to = :assigned_to, due_date = :due_date, completed_at = :completed_at, updated_at = CURRENT_TIMESTAMP WHERE id = :id",
      {
        title: body["title"] || existing["title"],
        description: body["description"] || existing["description"],
        status: body["status"] || existing["status"],
        priority: body["priority"] || existing["priority"],
        assigned_to: body.key?("assigned_to") ? body["assigned_to"] : existing["assigned_to"],
        due_date: body["due_date"] || existing["due_date"],
        completed_at: completed_at,
        id: id
      }
    )

    # Invalidate cache
    Tina4::Cache.delete_pattern("dashboard:*")

    task = db.fetch_one("SELECT * FROM tasks WHERE id = :id", { id: id })
    response.json(task)
  end

  # Delete task
  Tina4::Router.delete("/{id:int}") do |request, response|
    db = Tina4::Database.connection
    id = request.params["id"]

    existing = db.fetch_one("SELECT * FROM tasks WHERE id = :id", { id: id })
    return response.json({ error: "Task not found" }, 404) if existing.nil?

    db.execute("DELETE FROM tasks WHERE id = :id", { id: id })
    Tina4::Cache.delete_pattern("dashboard:*")

    response.json(nil, 204)
  end

end
```

---

## 7. Step 5: Dashboard

Create `src/routes/dashboard.rb`:

```ruby
Tina4::Router.get("/api/dashboard/stats", middleware: "auth_middleware") do |request, response|
  user_id = request.user["user_id"]

  stats = Tina4::Cache.fetch("dashboard:stats:#{user_id}", ttl: 60) do
    db = Tina4::Database.connection

    total = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE assigned_to = :id OR created_by = :id", { id: user_id })
    todo = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = :id OR created_by = :id) AND status = 'todo'", { id: user_id })
    in_progress = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = :id OR created_by = :id) AND status = 'in_progress'", { id: user_id })
    done = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = :id OR created_by = :id) AND status = 'done'", { id: user_id })
    overdue = db.fetch_one("SELECT COUNT(*) AS count FROM tasks WHERE (assigned_to = :id OR created_by = :id) AND due_date < date('now') AND status != 'done'", { id: user_id })

    {
      total: total["count"],
      todo: todo["count"],
      in_progress: in_progress["count"],
      done: done["count"],
      overdue: overdue["count"]
    }
  end

  response.json(stats)
end

Tina4::Router.get("/admin") do |request, response|
  response.render("dashboard.html", {
    title: "TaskFlow Dashboard"
  })
end
```

---

## 8. Step 6: Email Consumer

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

---

## 9. Step 7: Tests

Create `tests/taskflow_spec.rb`:

```ruby
require "tina4"

RSpec.describe "TaskFlow" do
  let(:client) { Tina4::TestClient.new }
  let(:token) do
    client.post("/api/auth/register", { name: "Test", email: "test#{rand(10000)}@example.com", password: "password123" })
    result = client.post("/api/auth/login", { email: "test@example.com", password: "password123" })
    result.json["token"]
  end

  it "registers a user" do
    result = client.post("/api/auth/register", {
      name: "Alice", email: "alice#{rand(10000)}@example.com", password: "securePass123"
    })
    expect(result.status).to eq(201)
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

  it "requires authentication for tasks" do
    result = client.get("/api/tasks")
    expect(result.status).to eq(401)
  end
end
```

---

## 10. Step 8: Docker Deployment

Use the Dockerfile and docker-compose.yml from Chapter 20 with the TaskFlow-specific `.env.production`.

---

## 11. Gotchas

### 1. Circular Dependencies Between Models

**Problem:** User loads tasks, tasks load users, infinite loop.

**Fix:** Use lazy loading. Do not eager-load relationships that create cycles.

### 2. Cache Not Invalidated on Related Model Changes

**Problem:** Dashboard stats are stale after task updates.

**Fix:** Invalidate cache in every write operation: `Tina4::Cache.delete_pattern("dashboard:*")`.

### 3. Queue Worker Not Processing Emails

**Problem:** Task assignment emails are queued but never sent.

**Fix:** Run `tina4 queue:work` in a separate terminal or as a systemd service.

### 4. Token Expired During Long Sessions

**Problem:** Users get logged out while actively using the dashboard.

**Fix:** Set a reasonable JWT expiry (`86400` for 24 hours) and implement token refresh.

### 5. WebSocket Notifications Not Received

**Problem:** Real-time dashboard updates do not work.

**Fix:** Ensure the WebSocket endpoint is configured and the client JavaScript connects correctly.

### 6. Database Locked Under Load

**Problem:** SQLite returns "database is locked" errors with concurrent requests.

**Fix:** For production with concurrent users, switch to PostgreSQL. SQLite handles one writer at a time.

### 7. Missing Migration Before Deployment

**Problem:** The app crashes in production because a table does not exist.

**Fix:** Always run `tina4 migrate` as part of your deployment pipeline.
