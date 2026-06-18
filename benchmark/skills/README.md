# Skills benchmark — vanilla vs skills

Does loading a Tina4 skill actually change what an AI agent writes? This harness
measures it, the way [ponytail](https://github.com/DietrichGebert/ponytail) measures
its ruleset: same prompt, two arms, many runs, median reported, fully reproducible.

This is **not** the runtime throughput benchmark (`../benchmark.sh`). This measures
**code-generation quality** — whether the skill stops the model from reaching for
Flask/FastAPI patterns and gets it to use Tina4's conventions and built-ins.

## The two arms

| arm | what the model sees |
|-----|---------------------|
| **vanilla** | the bare task prompt, no Tina4 skill |
| **skills**  | the same prompt, with `tina4-developer/SKILL.md` prepended as a system prompt (exactly how a loaded skill reaches the model) |

## What it scores (automated, in `score.py`)

| metric | meaning | better |
|--------|---------|--------|
| **idiom** | markers of correct Tina4 usage (`@get(`, `from tina4_python`, `ORM`, `response(`, `Queue`, `Auth`…) | higher |
| **halluc** | patterns proving the model used the wrong framework or invented APIs (`from flask`, `@app.route`, `jsonify(`, `import jwt`, `render_template(`…) | **lower** — this is the skill's whole job |
| **loc** | lines inside fenced code blocks | lower (leaner) |

The headline number is **halluc**. Tina4 skills exist because "AI agents
consistently get tina4 patterns wrong"; the test is whether the skill drives that
to zero. LOC is secondary (it's ponytail's headline, not ours).

## Run it

```bash
export ANTHROPIC_API_KEY=sk-ant-...        # the harness calls the Anthropic API
cd benchmark/skills
python run.py --model claude-sonnet-4-6 --runs 10   # generate (costs API tokens)
python score.py                                       # score for free, re-runnable
```

`run.py` writes every completion to `results/<task>-<arm>-<run>.md`, so scoring is
free to repeat and you can eyeball the raw output. Re-run across models
(`--model claude-haiku-4-5-20251001`, `claude-opus-4-8`) to see where the skill
helps most — expect the biggest lift on smaller/faster models, which drift to
generic patterns without it.

## Tasks

Four realistic Tina4 tasks (`tasks.json`): a products endpoint + model, JWT login,
background email, and an HTML products page. Each is a place where a model with no
skill predictably reaches for Flask/FastAPI/Jinja/PyJWT instead of Tina4's
built-ins. Add your own — each task lists its `idiom` and `halluc` marker sets.

## Honesty notes (borrowed from ponytail's methodology)

- Marker-counting is a proxy, not a compiler. It catches the gross failures
  (wrong framework, invented API) reliably; it won't catch subtle misuse. Read a
  few `results/*.md` by hand to sanity-check the scores.
- A skill is context the model *may* follow, not a guarantee. If `halluc` doesn't
  fall in the skills arm, that's a real finding: the skill text needs to be more
  directive, or the rule belongs in the per-turn MCP supervisor, not a load-once skill.
- Default language is Python; the markers in `tasks.json` are Python-flavoured.
  Fork the marker sets per language to benchmark the PHP/Ruby/Node skills.
