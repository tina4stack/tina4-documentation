# Exercise 1: The Cafe Menu

**Module 1** | Code 30 marks, comprehension 70 marks | Pass mark 60

A cafe wants an endpoint their till software can call to look up the price of an item.

---

## Part A: Build it (30 marks)

Write a route in `submission/src/routes/menu.py` that answers `GET /api/menu/{item}`.

The menu:

| Item | Price |
|--------|-------|
| coffee | 25 |
| tea | 20 |
| juice | 30 |

**It must:**

1. Return JSON, not plain text
2. For a known item, return status `200` with exactly these two keys:
   `{"item": "coffee", "price": 25}`
3. For an item not on the menu, return status `404`
4. Treat `Coffee`, `COFFEE` and `coffee` as the same item

A starter file is in `starter/src/routes/menu.py`. Copy it to `submission/` and work there.

Check your work by running it:

```bash
tina4python serve
```

Then visit `http://localhost:7145/api/menu/coffee` and
`http://localhost:7145/api/menu/unicorn`.

---

## Part B: Explain yourself (70 marks)

Copy `answers.template.md` to `submission/answers.md` and fill in all four.

Write in your own words. Sentences copied from the chapter score zero, and the examiner is
built to notice. A short honest answer beats a long borrowed one. If you are unsure, say
what you think and why. Reasoning that is wrong but genuine scores better than a correct
sentence you cannot explain.

### Q1. Explain (20 marks)

You returned a Python dictionary from your function and the caller received JSON. Explain
what happened in between. Why did you not have to convert it yourself, and how did the
framework know you wanted data rather than text?

### Q2. Predict (15 marks)

You change `@get("/api/menu/{item}")` to `@post("/api/menu/{item}")` and change nothing
else. You then visit `http://localhost:7145/api/menu/coffee` in your browser.

What happens? Say what you expect **before** you try it, and explain why. Two separate
things are going on here. Full marks need both.

### Q3. Diagnose (15 marks)

A classmate's route returns `null` for every item. Here is their code:

```python
from tina4_python.core.router import get

MENU = {"coffee": 25, "tea": 20, "juice": 30}


@get("/api/menu/{item}")
async def menu(request, response):
    item = request.body["item"]
    return response({"item": item, "price": MENU.get(item)})
```

Name the fault and explain why it produces that result. Do not just say what to change.
Say why the broken version behaves the way it does.

### Q4. Judge (20 marks)

The cafe now wants the price board in their window to update the moment a price changes,
without anyone refreshing anything.

Is the endpoint you built the right tool for that job? Argue your position. If you say no,
say what you would reach for instead and what it costs you. If you say yes, explain how you
would make it work and why that is acceptable.

There is no single correct answer here. The marks are in the reasoning.

---

## Submitting

Your `submission/` folder should contain:

```
submission/
├── src/routes/menu.py
└── answers.md
```

Then run:

```bash
python3 grader/tina4grade.py exercises/module-01 --submission exercises/module-01/submission
```
