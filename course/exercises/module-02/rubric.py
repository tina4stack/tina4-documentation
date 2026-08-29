"""Exercise 2 rubric. Read by grader/tina4grade.py."""

RUBRIC = {
    "module": 2,
    "title": "The Receipt",
    "level": 1,
    "pass_mark": 60,
    "route_file": "src/routes/receipt.py",
    "answers_file": "answers.md",
    "chapter": "course/04-module-02-naming-things-and-holding-them.md",

    "weights": {"code": 30, "comprehension": 70},

    "code_checks": [
        {
            "name": "two_items_priced_with_vat",
            "method": "GET",
            "path": "/api/receipt/coffee,tea",
            "expect_status": 200,
            "expect_json": {"items": ["coffee", "tea"], "subtotal": 45,
                            "vat": 6.75, "total": 51.75},
            "marks": 10,
        },
        {
            "name": "repeated_item_counts_twice",
            "method": "GET",
            "path": "/api/receipt/coffee,coffee,juice",
            "expect_status": 200,
            "expect_json": {"subtotal": 80, "vat": 12.0, "total": 92.0},
            "marks": 8,
        },
        {
            "name": "single_item",
            "method": "GET",
            "path": "/api/receipt/juice",
            "expect_status": 200,
            "expect_json": {"items": ["juice"], "subtotal": 30,
                            "vat": 4.5, "total": 34.5},
            "marks": 4,
        },
        {
            "name": "case_insensitive",
            "method": "GET",
            "path": "/api/receipt/Coffee,TEA",
            "expect_status": 200,
            "expect_json": {"items": ["coffee", "tea"], "subtotal": 45},
            "marks": 4,
        },
        {
            "name": "unknown_item_returns_404",
            "method": "GET",
            "path": "/api/receipt/coffee,unicorn",
            "expect_status": 404,
            "marks": 4,
        },
    ],

    "questions": [
        {
            "id": "q1",
            "dimension": "Explain",
            "marks": 20,
            "prompt": (
                "subtotal holds a whole number, vat holds decimals, neither was "
                "declared. Where did the type of vat come from, at what exact moment "
                "did it stop being whole, and why did Python widen rather than "
                "discard the fraction?"
            ),
            "looking_for": [
                "The type came from the multiplication, not from any declaration",
                "int * float produces a float, so the change happened on the line "
                "computing vat",
                "Python widens to avoid silently losing information, since narrowing "
                "to int would discard the fraction",
                "Understands types as a property of values flowing through operations, "
                "not a label attached to a name",
            ],
            "partial_credit": [
                "Identifying the multiplication line without explaining why widening "
                "happens is roughly half",
            ],
            "zero_if": [
                "Claims the type was declared somewhere",
                "Describes the types with no account of where the change occurred",
            ],
        },
        {
            "id": "q2",
            "dimension": "Predict",
            "marks": 15,
            "prompt": (
                "Predict 10 / 2, 10 // 2, 25 + '25', '25' + '25', then run them and "
                "report surprises honestly."
            ),
            "looking_for": [
                "10 / 2 is 5.0, a float, because true division always yields a float",
                "10 // 2 is 5, an int, floor division",
                "25 + '25' raises TypeError, int and str do not add",
                "'25' + '25' is '2525', string concatenation not arithmetic",
            ],
            "partial_credit": [
                "Three of four correct with sound reasoning is most of the marks",
                "Award credit for honestly reporting a wrong prediction and "
                "identifying why it was wrong",
            ],
            "zero_if": [
                "No reasoning offered, just four bare answers that read as copied "
                "output",
            ],
        },
        {
            "id": "q3",
            "dimension": "Diagnose",
            "marks": 15,
            "prompt": (
                "total is computed INSIDE the loop, so it is recalculated per item "
                "against a growing subtotal. Name the fault and explain why the "
                "result is too large. What does two coffees return?"
            ),
            "looking_for": [
                "total sits inside the loop and should sit after it",
                "Explains that the final loop pass overwrites total, so it reflects "
                "the last iteration",
                "For two coffees the answer is actually correct at 57.5, because the "
                "last pass sees the full subtotal of 50",
                "Recognises the real bug is structural, and that it produces a wrong "
                "answer only when the loop body is reordered or the list is empty",
            ],
            "note": (
                "VERIFIED BY RUNNING IT. The buggy code returns the CORRECT total for "
                "every non-empty order: two coffees give 57.5, which matches the "
                "correct calculation exactly. This is because the final loop pass "
                "recomputes total against the completed subtotal. A student who "
                "asserts the number is wrong has not traced the loop and should lose "
                "marks for that, however confident they sound. An empty order raises "
                "UnboundLocalError (a subclass of NameError, so accept either name) "
                "because total is never assigned. Award full marks for identifying "
                "the misplaced line with a sound mechanism plus the correct "
                "two-coffee value. The empty-order case is the distinguishing insight "
                "for the top of the band."
            ),
            "partial_credit": [
                "Naming the misplaced line without explaining the mechanism is "
                "roughly half",
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
                "Floats versus integer cents for a one-till cafe selling 200 items a "
                "day. Argue a position and state its cost."
            ),
            "looking_for": [
                "Understands why floats are inexact, that binary cannot represent some "
                "decimal fractions",
                "Weighs that against the actual scale rather than reciting the rule",
                "States a real cost of the chosen option: cents means converting at "
                "every boundary and a migration later, floats means accepting drift",
            ],
            "note": (
                "No single correct answer. A well-argued 'keep floats, 200 items a day "
                "will not drift meaningfully, and I would switch the day we take card "
                "payments' earns full marks. So does 'use cents now, it is cheaper "
                "than migrating later'. Reciting 'never use floats for money' with no "
                "engagement with the scale is a rule, not judgement, and scores about "
                "half."
            ),
            "zero_if": [
                "Picks a side with no reasoning",
                "Shows no understanding of why floats are inexact",
            ],
        },
    ],

    "integrity": {
        "parroting_penalty": (
            "Answers restating chapter sentences without independent reasoning score "
            "zero on that question regardless of correctness."
        ),
        "reward_honest_uncertainty": (
            "A student who reports a wrong prediction and works out why scores higher "
            "than one who states the right answer with no mechanism. Question 2 asks "
            "for this directly."
        ),
    },
}
