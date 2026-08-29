"""Exercise 1 rubric. Read by grader/tina4grade.py.

Plain Python rather than YAML so the grader stays zero-dependency, the same
rule the framework holds itself to. Multi-line prose survives, comments survive,
and there is nothing to parse.
"""

RUBRIC = {
    "module": 1,
    "title": "The Cafe Menu",
    "level": 1,
    "pass_mark": 60,
    "route_file": "src/routes/menu.py",
    "answers_file": "answers.md",
    "chapter": "course/03-module-01-the-request-and-the-answer.md",

    # ── Gate one: deterministic. Real requests, real front controller.
    "code_checks": [
        {
            "name": "known_item_returns_200_json",
            "method": "GET",
            "path": "/api/menu/coffee",
            "expect_status": 200,
            "expect_json": {"item": "coffee", "price": 25},
            "marks": 10,
        },
        {
            "name": "second_item_correct",
            "method": "GET",
            "path": "/api/menu/juice",
            "expect_status": 200,
            "expect_json": {"item": "juice", "price": 30},
            "marks": 5,
        },
        {
            "name": "unknown_item_returns_404",
            "method": "GET",
            "path": "/api/menu/unicorn",
            "expect_status": 404,
            "marks": 10,
        },
        {
            "name": "case_insensitive",
            "method": "GET",
            "path": "/api/menu/COFFEE",
            "expect_status": 200,
            "expect_json": {"item": "coffee", "price": 25},
            "marks": 5,
        },
    ],

    # ── Gate two: comprehension, graded by the Tina4 engine.
    "questions": [
        {
            "id": "q1",
            "dimension": "Explain",
            "marks": 20,
            "prompt": (
                "Explain what happened between returning a Python dictionary and "
                "the caller receiving JSON. Why no manual conversion, and how did "
                "the framework know it was data rather than text?"
            ),
            "looking_for": [
                "The framework inspected the returned value and serialised a dict to JSON",
                "Content-type became application/json as a consequence of that decision",
                "Understands this as the framework acting on the shape of what was "
                "returned, not on anything the student declared",
            ],
            "zero_if": [
                "Sentences lifted from the chapter with no added reasoning",
                "Describes what happens with no account of why or by what mechanism",
            ],
        },
        {
            "id": "q2",
            "dimension": "Predict",
            "marks": 15,
            "prompt": (
                "@get changed to @post, nothing else changed, then visited in a "
                "browser. What happens and why? Two things are going on."
            ),
            "looking_for": [
                "A browser address bar issues GET, so the POST route does not match, "
                "giving 404 or 405",
                "Tina4 requires auth on write methods by default, so even a correct "
                "POST would be rejected without a token",
            ],
            "partial_credit": [
                "Only the method mismatch is most of the marks",
                "Only the auth default without the method mismatch is about half",
            ],
            "zero_if": [
                "Asserts it works normally",
                "Pure guess with no mechanism offered",
            ],
        },
        {
            "id": "q3",
            "dimension": "Diagnose",
            "marks": 15,
            "prompt": (
                "Route reads request.body['item'] instead of request.params['item'] "
                "and returns null for every item. Name the fault and explain the "
                "mechanism."
            ),
            "looking_for": [
                "Path parameters arrive in request.params, not request.body",
                "A GET request has no body, so the lookup yields nothing",
                "MENU.get() on a missing key returns None, which serialises to null, "
                "which is why it fails quietly rather than raising",
            ],
            "partial_credit": [
                "Naming params vs body without explaining the null is roughly half",
            ],
            "zero_if": [
                "Only states the fix with no account of the behaviour",
            ],
        },
        {
            "id": "q4",
            "dimension": "Judge",
            "marks": 20,
            "prompt": (
                "Cafe wants a window price board updating live with no refresh. Is "
                "this endpoint the right tool? Argue it."
            ),
            "looking_for": [
                "Recognises HTTP request/response cannot have the server speak first",
                "Names a real alternative (WebSocket or SSE), or defends polling with "
                "its costs stated",
                "States the trade honestly rather than reaching for the newest tool",
            ],
            "note": (
                "No single correct answer. A well-argued 'yes, poll every 30 seconds, "
                "the board is a display and staleness is cheap' earns full marks. So "
                "does a well-argued WebSocket answer. An unjustified answer either "
                "way does not."
            ),
            "zero_if": [
                "Picks a side with no reasoning",
                "Ignores the constraint that the server needs to initiate",
            ],
        },
    ],

    # ── Anti-parroting, applied across every answer.
    "integrity": {
        "parroting_penalty": (
            "Compare each answer against the module chapter text supplied below. "
            "Answers that restate chapter sentences without independent reasoning "
            "score zero on that question regardless of correctness. Reward reasoning "
            "in the student's own words even when the wording is clumsy or the "
            "grammar is poor."
        ),
        "reward_honest_uncertainty": (
            "A student who says 'I think X because Y, but I am not sure about Z' has "
            "shown more understanding than one who states X flatly with no mechanism. "
            "Mark accordingly."
        ),
    },
}
