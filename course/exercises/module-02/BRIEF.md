# Exercise 2: The Receipt

**Module 2** | Code 30 marks, comprehension 70 marks | Pass mark 60

The cafe from exercise 1 now wants a receipt for a whole order, with VAT added.

---

## Part A: Build it (30 marks)

Write a route in `submission/src/routes/receipt.py` answering `GET /api/receipt/{order}`.

The `order` is item names separated by commas: `coffee,tea,coffee`.

The menu, and VAT at 15 percent:

| Item | Price |
|--------|-------|
| coffee | 25 |
| tea | 20 |
| juice | 30 |

**It must:**

1. Return JSON with exactly four keys: `items`, `subtotal`, `vat`, `total`
2. `items` is the list of item names in the order given
3. `subtotal` is the sum of the prices
4. `vat` is 15 percent of the subtotal, rounded to 2 decimal places
5. `total` is subtotal plus vat, rounded to 2 decimal places
6. Items are case insensitive, so `Coffee` and `coffee` are the same
7. If any item is not on the menu, return `404` and do not price the order

So `GET /api/receipt/coffee,tea` returns:

```json
{"items": ["coffee", "tea"], "subtotal": 45, "vat": 6.75, "total": 51.75}
```

A starter file is in `starter/src/routes/receipt.py`. Copy it to `submission/`.

**Name things properly.** The code gate cannot see your names, but question 1 asks you to
defend them, and the examiner will read your file.

---

## Part B: Explain yourself (70 marks)

Copy `answers.template.md` to `submission/answers.md` and fill in all four.

Write in your own words. Copied sentences score zero, and the check for that is measured
before your answer reaches the examiner. A short honest answer beats a long borrowed one.

### Q1. Explain (20 marks)

Your `subtotal` holds a whole number and your `vat` holds a number with decimals. You never
declared either type.

Explain where the type of `vat` came from. At what exact moment in your code did it stop
being a whole number, and why did Python do that instead of throwing away the fraction?

### Q2. Predict (15 marks)

Before running anything, predict the output of each line and say why:

```python
10 / 2
10 // 2
25 + "25"
"25" + "25"
```

Then run them. If any surprised you, say which and what you had expected. Being wrong and
noticing scores better than being right by luck.

### Q3. Diagnose (15 marks)

A classmate wrote this. Something is wrong with it.

```python
MENU = {"coffee": 25, "tea": 20, "juice": 30}
VAT_RATE = 0.15

subtotal = 0
for item in ordered_items:
    subtotal = subtotal + MENU[item]
    total = subtotal + subtotal * VAT_RATE
```

Name the fault and explain the mechanism.

Then answer two specific things. What does this return for an order of two coffees? And what
happens when `ordered_items` is empty?

Be careful. Check the two-coffee case by working through the loop rather than assuming the
answer is wrong because the code is. Part of diagnosis is knowing exactly how far a fault
reaches, and a bug that produces the right answer today is still a bug.

### Q4. Judge (20 marks)

You stored money in a float. The chapter says real systems never do that, and stores an
integer number of cents instead.

This cafe has one till and sells about 200 items a day.

Do you change your code to use integer cents, or leave it as floats? Argue your position.
Whichever you pick, state honestly what it costs you and what could go wrong.

There is a defensible answer on both sides. The marks are in the reasoning, not the choice.

---

## Submitting

```bash
python3 course/grader/tina4grade.py course/exercises/module-02 \
    --submission course/exercises/module-02/submission
```
