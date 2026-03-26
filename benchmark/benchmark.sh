#!/usr/bin/env bash
#
# Tina4 Benchmark Suite
#
# Tests real framework endpoints with three tools: hey, wrk, ab.
# Four endpoints per framework:
#   /bench/json      — route match + small JSON response
#   /bench/list      — route match + 100-item JSON array
#   /bench/db        — SQLite query + JSON response (ORM/DB layer)
#   /bench/template  — render a template with data (template engine)
#
# Usage:
#   ./benchmark.sh              # Run all languages
#   ./benchmark.sh python       # Python only
#   ./benchmark.sh nodejs       # Node.js only
#   ./benchmark.sh php          # PHP only
#   ./benchmark.sh ruby         # Ruby only
#
# Requirements: hey, wrk, ab
#   brew install hey wrk    # ab ships with macOS

set +e

REQUESTS=5000
CONCURRENCY=50
WRK_DURATION="10s"
WRK_THREADS=4
RUNS=3
BASE_DIR="/Users/andrevanzuydam/IdeaProjects"
RESULTS_DIR="$(dirname "$0")/results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_FILE="$RESULTS_DIR/benchmark-$TIMESTAMP.md"

mkdir -p "$RESULTS_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cleanup_port() {
    local port=$1
    kill $(lsof -ti:$port) 2>/dev/null || true
    sleep 1
}

wait_for_server() {
    local url=$1
    local max_wait=15
    local waited=0
    while [ $waited -lt $max_wait ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

# Extract req/s from each tool
hey_rps() {
    hey -n $REQUESTS -c $CONCURRENCY "$1" 2>&1 | grep "Requests/sec" | awk '{print $2}'
}

wrk_rps() {
    wrk -t$WRK_THREADS -c$CONCURRENCY -d$WRK_DURATION "$1" 2>&1 | grep "Requests/sec" | awk '{print $2}'
}

ab_rps() {
    ab -n $REQUESTS -c $CONCURRENCY -q "$1" 2>&1 | grep "Requests per second" | awk '{print $4}'
}

# Run a single endpoint through all three tools, averaged over $RUNS
benchmark_endpoint() {
    local url=$1
    local label=$2

    local hey_total=0 wrk_total=0 ab_total=0

    for run in $(seq 1 $RUNS); do
        local h=$(hey_rps "$url")
        local w=$(wrk_rps "$url")
        local a=$(ab_rps "$url")
        hey_total=$(echo "$hey_total + ${h:-0}" | bc)
        wrk_total=$(echo "$wrk_total + ${w:-0}" | bc)
        ab_total=$(echo "$ab_total + ${a:-0}" | bc)
        echo "    Run $run: hey=${h:-0} wrk=${w:-0} ab=${a:-0}"
    done

    HEY_AVG=$(echo "scale=1; $hey_total / $RUNS" | bc)
    WRK_AVG=$(echo "scale=1; $wrk_total / $RUNS" | bc)
    AB_AVG=$(echo "scale=1; $ab_total / $RUNS" | bc)

    echo -e "    ${CYAN}Average: hey=$HEY_AVG  wrk=$WRK_AVG  ab=$AB_AVG${NC}"
}

# Run all four endpoints for one framework
run_framework() {
    local name=$1
    local port=$2
    local start_cmd=$3

    echo ""
    echo -e "${YELLOW}=== $name ===${NC}"

    cleanup_port $port

    eval "$start_cmd" > /dev/null 2>&1 &
    local PID=$!

    if ! wait_for_server "http://127.0.0.1:$port/bench/json"; then
        echo -e "${RED}FAILED — $name did not start on port $port${NC}"
        kill $PID 2>/dev/null
        echo "| $name | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED |" >> $RESULTS_FILE
        return
    fi

    echo -e "${GREEN}Server running on port $port${NC}"

    echo "  /bench/json (routing + JSON):"
    benchmark_endpoint "http://127.0.0.1:$port/bench/json" "json"
    local json_hey=$HEY_AVG json_wrk=$WRK_AVG json_ab=$AB_AVG

    echo "  /bench/list (100-item JSON array):"
    benchmark_endpoint "http://127.0.0.1:$port/bench/list" "list"
    local list_hey=$HEY_AVG list_wrk=$WRK_AVG list_ab=$AB_AVG

    echo "  /bench/db (SQLite query + JSON):"
    benchmark_endpoint "http://127.0.0.1:$port/bench/db" "db"
    local db_hey=$HEY_AVG db_wrk=$WRK_AVG db_ab=$AB_AVG

    echo "  /bench/template (template rendering):"
    benchmark_endpoint "http://127.0.0.1:$port/bench/template" "template"
    local tpl_hey=$HEY_AVG tpl_wrk=$WRK_AVG tpl_ab=$AB_AVG

    echo "| $name | $json_hey | $json_wrk | $json_ab | $list_hey | $list_wrk | $list_ab | $db_hey | $db_wrk | $db_ab | $tpl_hey | $tpl_wrk | $tpl_ab |" >> $RESULTS_FILE

    kill $PID 2>/dev/null
    cleanup_port $port
    echo -e "${GREEN}=== $name DONE ===${NC}"
}

# ── Header ──────────────────────────────────────────────────────────
echo -e "${CYAN}"
echo "  Tina4 Benchmark Suite"
echo "  $(date)"
echo "  Tools: hey ($REQUESTS req, ${CONCURRENCY}c) | wrk (${WRK_THREADS}t, ${CONCURRENCY}c, ${WRK_DURATION}) | ab ($REQUESTS req, ${CONCURRENCY}c)"
echo "  Runs: $RUNS per endpoint per tool"
echo "  Endpoints: /bench/json, /bench/list, /bench/db, /bench/template"
echo -e "${NC}"

cat > $RESULTS_FILE << 'HEADER'
# Tina4 Benchmark Results

Four endpoints tested per framework:
- `/bench/json` — route match + small JSON response
- `/bench/list` — route match + 100-item JSON array
- `/bench/db` — SQLite query + JSON response
- `/bench/template` — render a template with variables

Three tools: hey, wrk, ab. All numbers are requests/second (higher is better).

| Framework | json hey | json wrk | json ab | list hey | list wrk | list ab | db hey | db wrk | db ab | tpl hey | tpl wrk | tpl ab |
|-----------|---------|---------|--------|---------|---------|--------|--------|--------|-------|---------|---------|--------|
HEADER

# ══════════════════════════════════════════════════════════════════════
#  FRAMEWORK APPS — each must implement four endpoints
# ══════════════════════════════════════════════════════════════════════

# ── Python ────────────────────────────────────────────────────────────
run_python() {
    local VENV="$BASE_DIR/tina4-python/.venv/bin"

    # tina4python
    cat > /tmp/bench_tina4py.py << 'APP'
import sqlite3, json, os
os.environ["TINA4_DEBUG_LEVEL"] = "NONE"

conn = sqlite3.connect(":memory:")
conn.row_factory = sqlite3.Row
conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
for i in range(100):
    conn.execute("INSERT INTO users VALUES (?,?,?)", (i+1, f"User_{i+1}", f"user{i+1}@test.com"))
conn.commit()

from tina4_python.core.router import get
from tina4_python.core.server import run

@get("/bench/json")
async def bench_json(req, res):
    return res({"message": "Hello", "framework": "tina4python"})

@get("/bench/list")
async def bench_list(req, res):
    return res([{"id": i, "name": f"Item {i}", "value": i * 1.5} for i in range(100)])

@get("/bench/db")
async def bench_db(req, res):
    rows = conn.execute("SELECT id, name, email FROM users LIMIT 20").fetchall()
    return res([dict(r) for r in rows])

@get("/bench/template")
async def bench_tpl(req, res):
    items = [{"name": f"Product {i}", "price": i * 9.99} for i in range(20)]
    html = "<html><body><h1>Products</h1><ul>"
    for item in items:
        html += f"<li>{item['name']} - ${item['price']:.2f}</li>"
    html += "</ul></body></html>"
    return res(html, content_type="text/html")

run()
APP
    run_framework "tina4python" 7145 \
        "cd $BASE_DIR/tina4-python && $VENV/python /tmp/bench_tina4py.py"

    # FastAPI
    cat > /tmp/bench_fastapi.py << 'APP'
import sqlite3
from fastapi import FastAPI
from fastapi.responses import HTMLResponse

conn = sqlite3.connect(":memory:")
conn.row_factory = sqlite3.Row
conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
for i in range(100):
    conn.execute("INSERT INTO users VALUES (?,?,?)", (i+1, f"User_{i+1}", f"user{i+1}@test.com"))
conn.commit()

app = FastAPI()

@app.get("/bench/json")
async def bench_json():
    return {"message": "Hello", "framework": "fastapi"}

@app.get("/bench/list")
async def bench_list():
    return [{"id": i, "name": f"Item {i}", "value": i * 1.5} for i in range(100)]

@app.get("/bench/db")
async def bench_db():
    rows = conn.execute("SELECT id, name, email FROM users LIMIT 20").fetchall()
    return [dict(r) for r in rows]

@app.get("/bench/template")
async def bench_tpl():
    items = [{"name": f"Product {i}", "price": i * 9.99} for i in range(20)]
    html = "<html><body><h1>Products</h1><ul>"
    for item in items:
        html += f"<li>{item['name']} - ${item['price']:.2f}</li>"
    html += "</ul></body></html>"
    return HTMLResponse(html)
APP
    run_framework "FastAPI" 7201 \
        "$VENV/python -m uvicorn --app-dir /tmp bench_fastapi:app --host 127.0.0.1 --port 7201 --log-level error"

    # Flask
    cat > /tmp/bench_flask.py << 'APP'
import sqlite3, json
from flask import Flask, jsonify, Response

conn = sqlite3.connect(":memory:")
conn.row_factory = sqlite3.Row
conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
for i in range(100):
    conn.execute("INSERT INTO users VALUES (?,?,?)", (i+1, f"User_{i+1}", f"user{i+1}@test.com"))
conn.commit()

app = Flask(__name__)

@app.route("/bench/json")
def bench_json():
    return jsonify({"message": "Hello", "framework": "flask"})

@app.route("/bench/list")
def bench_list():
    return jsonify([{"id": i, "name": f"Item {i}", "value": i * 1.5} for i in range(100)])

@app.route("/bench/db")
def bench_db():
    rows = conn.execute("SELECT id, name, email FROM users LIMIT 20").fetchall()
    return jsonify([dict(r) for r in rows])

@app.route("/bench/template")
def bench_tpl():
    items = [{"name": f"Product {i}", "price": i * 9.99} for i in range(20)]
    html = "<html><body><h1>Products</h1><ul>"
    for item in items:
        html += f"<li>{item['name']} - ${item['price']:.2f}</li>"
    html += "</ul></body></html>"
    return Response(html, content_type="text/html")

app.run(host="127.0.0.1", port=7202, debug=False)
APP
    run_framework "Flask" 7202 "$VENV/python /tmp/bench_flask.py"

    # Django
    mkdir -p /tmp/bench_django
    cat > /tmp/bench_django/settings.py << 'S'
SECRET_KEY='bench'
DEBUG=False
ALLOWED_HOSTS=['*']
ROOT_URLCONF='urls'
INSTALLED_APPS=[]
DATABASES={'default':{'ENGINE':'django.db.backends.sqlite3','NAME':':memory:'}}
S
    cat > /tmp/bench_django/urls.py << 'U'
import sqlite3, json
from django.http import JsonResponse, HttpResponse
from django.urls import path

conn = sqlite3.connect(":memory:")
conn.row_factory = sqlite3.Row
conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
for i in range(100):
    conn.execute("INSERT INTO users VALUES (?,?,?)", (i+1, f"User_{i+1}", f"user{i+1}@test.com"))
conn.commit()

def bench_json(r): return JsonResponse({"message":"Hello","framework":"django"})
def bench_list(r): return JsonResponse([{"id":i,"name":f"Item {i}","value":i*1.5} for i in range(100)], safe=False)
def bench_db(r):
    rows = conn.execute("SELECT id, name, email FROM users LIMIT 20").fetchall()
    return JsonResponse([dict(r) for r in rows], safe=False)
def bench_tpl(r):
    items = [{"name": f"Product {i}", "price": i * 9.99} for i in range(20)]
    html = "<html><body><h1>Products</h1><ul>"
    for item in items:
        html += f"<li>{item['name']} - ${item['price']:.2f}</li>"
    html += "</ul></body></html>"
    return HttpResponse(html, content_type="text/html")

urlpatterns=[path("bench/json",bench_json),path("bench/list",bench_list),path("bench/db",bench_db),path("bench/template",bench_tpl)]
U
    run_framework "Django" 7204 \
        "DJANGO_SETTINGS_MODULE=settings PYTHONPATH=/tmp/bench_django $VENV/python -c \"
import os,sys
os.environ['DJANGO_SETTINGS_MODULE']='settings'
sys.path.insert(0,'/tmp/bench_django')
from django.core.management import execute_from_command_line
execute_from_command_line(['m','runserver','127.0.0.1:7204','--noreload'])
\""
}

# ── Node.js ──────────────────────────────────────────────────────────
run_nodejs() {
    # tina4nodejs (TypeScript — needs tsx)
    cat > /tmp/bench_tina4node.ts << 'APP'
import { get, startServer } from "/Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/core/src/index.ts";
import { DatabaseSync } from "node:sqlite";

const db = new DatabaseSync(":memory:");
db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
const ins = db.prepare("INSERT INTO users VALUES (?,?,?)");
for (let i = 1; i <= 100; i++) ins.run(i, `User_${i}`, `user${i}@test.com`);

const sel = db.prepare("SELECT id, name, email FROM users LIMIT 20");

get("/bench/json", async (req, res) => res.json({message:"Hello",framework:"tina4nodejs"}));
get("/bench/list", async (req, res) => res.json(Array.from({length:100},(_,i)=>({id:i,name:`Item ${i}`,value:i*1.5}))));
get("/bench/db", async (req, res) => res.json(sel.all()));
get("/bench/template", async (req, res) => {
    const items = Array.from({length:20},(_,i)=>({name:`Product ${i}`,price:(i*9.99).toFixed(2)}));
    const html = `<html><body><h1>Products</h1><ul>${items.map(it=>`<li>${it.name} - $${it.price}</li>`).join("")}</ul></body></html>`;
    return res.html(html);
});

startServer({port:7148,debug:false});
APP
    run_framework "tina4nodejs" 7148 "npx tsx /tmp/bench_tina4node.ts"

    # Express
    cat > /tmp/bench_express.mjs << 'APP'
import express from "express";
import Database from "better-sqlite3";

const db = new Database(":memory:");
db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
const ins = db.prepare("INSERT INTO users VALUES (?,?,?)");
for (let i = 1; i <= 100; i++) ins.run(i, `User_${i}`, `user${i}@test.com`);
const sel = db.prepare("SELECT id, name, email FROM users LIMIT 20");

const app = express();
app.get("/bench/json", (req, res) => res.json({message:"Hello",framework:"express"}));
app.get("/bench/list", (req, res) => res.json(Array.from({length:100},(_,i)=>({id:i,name:`Item ${i}`,value:i*1.5}))));
app.get("/bench/db", (req, res) => res.json(sel.all()));
app.get("/bench/template", (req, res) => {
    const items = Array.from({length:20},(_,i)=>({name:`Product ${i}`,price:(i*9.99).toFixed(2)}));
    const html = `<html><body><h1>Products</h1><ul>${items.map(it=>`<li>${it.name} - $${it.price}</li>`).join("")}</ul></body></html>`;
    res.type("html").send(html);
});
app.listen(7230, "127.0.0.1");
APP
    run_framework "Express" 7230 "NODE_PATH=/Users/andrevanzuydam/IdeaProjects/carbonah/tests/node-benchmarks/frameworks/express/node_modules node /tmp/bench_express.mjs"

    # Fastify
    cat > /tmp/bench_fastify.mjs << 'APP'
import Fastify from "fastify";
import Database from "better-sqlite3";

const db = new Database(":memory:");
db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
const ins = db.prepare("INSERT INTO users VALUES (?,?,?)");
for (let i = 1; i <= 100; i++) ins.run(i, `User_${i}`, `user${i}@test.com`);
const sel = db.prepare("SELECT id, name, email FROM users LIMIT 20");

const app = Fastify({logger:false});
app.get("/bench/json", async () => ({message:"Hello",framework:"fastify"}));
app.get("/bench/list", async () => Array.from({length:100},(_,i)=>({id:i,name:`Item ${i}`,value:i*1.5})));
app.get("/bench/db", async () => sel.all());
app.get("/bench/template", async (req, reply) => {
    const items = Array.from({length:20},(_,i)=>({name:`Product ${i}`,price:(i*9.99).toFixed(2)}));
    const html = `<html><body><h1>Products</h1><ul>${items.map(it=>`<li>${it.name} - $${it.price}</li>`).join("")}</ul></body></html>`;
    reply.type("text/html").send(html);
});
app.listen({port:7231,host:"127.0.0.1"});
APP
    run_framework "Fastify" 7231 "NODE_PATH=/Users/andrevanzuydam/IdeaProjects/carbonah/tests/node-benchmarks/frameworks/fastify/node_modules node /tmp/bench_fastify.mjs"
}

# ── PHP ──────────────────────────────────────────────────────────────
run_php() {
    mkdir -p /tmp/tina4-php-bench/src/routes
    cat > /tmp/tina4-php-bench/src/routes/bench.php << 'R'
<?php
$db = new PDO("sqlite::memory:");
$db->exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
for ($i = 1; $i <= 100; $i++) {
    $db->exec("INSERT INTO users VALUES ($i, 'User_$i', 'user{$i}@test.com')");
}

\Tina4\Router::get("/bench/json", function ($request, $response) {
    return $response->json(["message" => "Hello", "framework" => "tina4php"]);
});
\Tina4\Router::get("/bench/list", function ($request, $response) {
    $items = [];
    for ($i = 0; $i < 100; $i++) { $items[] = ["id" => $i, "name" => "Item $i", "value" => $i * 1.5]; }
    return $response->json($items);
});
\Tina4\Router::get("/bench/db", function ($request, $response) use ($db) {
    $rows = $db->query("SELECT id, name, email FROM users LIMIT 20")->fetchAll(PDO::FETCH_ASSOC);
    return $response->json($rows);
});
\Tina4\Router::get("/bench/template", function ($request, $response) {
    $items = [];
    for ($i = 0; $i < 20; $i++) { $items[] = ["name" => "Product $i", "price" => number_format($i * 9.99, 2)]; }
    $html = "<html><body><h1>Products</h1><ul>";
    foreach ($items as $item) { $html .= "<li>{$item['name']} - \${$item['price']}</li>"; }
    $html .= "</ul></body></html>";
    return $response($html, 200, "text/html");
});
R
    cat > /tmp/tina4-php-bench/index.php << 'I'
<?php
require_once '/Users/andrevanzuydam/IdeaProjects/tina4-php/vendor/autoload.php';
(new \Tina4\App())->run();
I
    echo 'TINA4_DEBUG=false' > /tmp/tina4-php-bench/.env

    run_framework "tina4php" 7146 "cd /tmp/tina4-php-bench && php index.php"

    # Laravel (if installed)
    if [ -d "/tmp/bench-laravel" ] && [ -f "/tmp/bench-laravel/artisan" ]; then
        run_framework "Laravel" 7211 \
            "cd /tmp/bench-laravel && php artisan serve --host=127.0.0.1 --port=7211 --no-interaction"
    else
        echo -e "${YELLOW}Laravel not installed — skipping. Run: composer create-project laravel/laravel /tmp/bench-laravel${NC}"
    fi
}

# ── Ruby ──────────────────────────────────────────────────────────────
run_ruby() {
    cat > /tmp/bench_tina4ruby.rb << 'APP'
$LOAD_PATH.unshift '/Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib'
require 'tina4'
require 'sqlite3'
require 'json'

db = SQLite3::Database.new(":memory:")
db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
100.times { |i| db.execute("INSERT INTO users VALUES (?,?,?)", [i+1, "User_#{i+1}", "user#{i+1}@test.com"]) }

Tina4::Router.get '/bench/json' do |_r, response|
  response.json({message: "Hello", framework: "tina4ruby"})
end
Tina4::Router.get '/bench/list' do |_r, response|
  response.json((0...100).map { |i| {id: i, name: "Item #{i}", value: i * 1.5} })
end
Tina4::Router.get '/bench/db' do |_r, response|
  rows = db.execute2("SELECT id, name, email FROM users LIMIT 20")
  headers = rows.shift
  response.json(rows.map { |r| headers.zip(r).to_h })
end
Tina4::Router.get '/bench/template' do |_r, response|
  items = (0...20).map { |i| {name: "Product #{i}", price: format("%.2f", i * 9.99)} }
  html = "<html><body><h1>Products</h1><ul>"
  items.each { |it| html += "<li>#{it[:name]} - $#{it[:price]}</li>" }
  html += "</ul></body></html>"
  response.html(html)
end

Tina4.run!(port: 7147, debug: false)
APP
    run_framework "tina4ruby" 7147 "ruby /tmp/bench_tina4ruby.rb"

    # Sinatra
    cat > /tmp/bench_sinatra.rb << 'APP'
require "sinatra/base"
require "sqlite3"
require "json"

class BenchApp < Sinatra::Base
  set :bind, "127.0.0.1"
  set :port, 7220
  set :logging, false

  db = SQLite3::Database.new(":memory:")
  db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
  100.times { |i| db.execute("INSERT INTO users VALUES (?,?,?)", [i+1, "User_#{i+1}", "user#{i+1}@test.com"]) }

  get("/bench/json") { content_type :json; {message:"Hello",framework:"sinatra"}.to_json }
  get("/bench/list") { content_type :json; (0...100).map{|i|{id:i,name:"Item #{i}",value:i*1.5}}.to_json }
  get("/bench/db") do
    content_type :json
    rows = db.execute2("SELECT id, name, email FROM users LIMIT 20")
    headers = rows.shift
    rows.map { |r| headers.zip(r).to_h }.to_json
  end
  get("/bench/template") do
    content_type :html
    items = (0...20).map { |i| {name: "Product #{i}", price: format("%.2f", i * 9.99)} }
    html = "<html><body><h1>Products</h1><ul>"
    items.each { |it| html += "<li>#{it[:name]} - $#{it[:price]}</li>" }
    html + "</ul></body></html>"
  end

  run!
end
APP
    run_framework "Sinatra" 7220 "ruby /tmp/bench_sinatra.rb"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-all}" in
    python)  run_python ;;
    php)     run_php ;;
    ruby)    run_ruby ;;
    nodejs)  run_nodejs ;;
    all)
        run_nodejs
        run_python
        run_php
        run_ruby
        ;;
    *)
        echo "Usage: $0 [python|php|ruby|nodejs|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}=== RESULTS ===${NC}"
cat $RESULTS_FILE
echo ""
echo -e "${GREEN}Results saved to: $RESULTS_FILE${NC}"
