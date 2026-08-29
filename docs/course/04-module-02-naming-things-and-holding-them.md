# Module 2: Naming Things and Holding Them

**Level 1: Make It Work** | Code gate 30, comprehension gate 70

---

## 1. The Idea

A program needs somewhere to put things while it works.

You already did this in module 1 without noticing. `request.params["name"]` held a value
that arrived from the outside world, and you handed it straight back out. Most programs are
not that lucky. They receive something, keep it for a while, change it, combine it with
other things, and hand back a result that did not exist when the request arrived.

The place you keep a thing is a **variable**. The name you give it is the most important
decision on the line.

That sounds like an overstatement. It is not. A variable name is the only chance you get to
explain, in one word, what a value means. The computer does not care. It would run the same
program if you named everything `x1` through `x40`. The next person to read it cares
enormously, and the next person is usually you, eight months later, with no memory of what
you were thinking.

Here is the whole idea in two lines:

```python
t = p * 0.15
vat = price * 0.15
```

Both compute the same number. One of them tells you what the number means.

---

## 2. Build It

### Holding a value

```python
price = 25
```

Read that as "the name `price` now refers to the value 25". Python did not reserve a box or
ask you what kind of thing you intended to store. You said a name, you said a value, and the
two are connected until you say otherwise.

Change it whenever you want:

```python
price = 25
price = 30
```

The name now refers to 30. Nothing remembers the 25.

### Values have types

Every value in Python is a kind of thing, and the kind matters.

```python
price = 25            # int, a whole number
vat = 3.75            # float, a number with a fractional part
item = "coffee"       # str, text
in_stock = True       # bool, true or false
```

Ask Python what something is:

```python
type(25)        # <class 'int'>
type(3.75)      # <class 'float'>
type("coffee")  # <class 'str'>
```

The type decides what the value can do. Two ints add up. Two strings join end to end. An int
and a string do neither, and Python will say so rather than guess:

```python
25 + 25        # 50
"25" + "25"    # "2525"
25 + "25"      # TypeError: unsupported operand type(s) for +: 'int' and 'str'
```

That error is a kindness. A language that guessed would give you `"2525"` in a bank
transfer.

### Types change under you

This one catches everybody:

```python
subtotal = 45           # int
vat = subtotal * 0.15   # 6.75, and now a float
```

You never asked for a float. You multiplied an int by a float, and Python widened the result
so nothing was lost. Multiply an int by an int and you keep an int. Divide, and you get a
float even when the answer is whole:

```python
10 / 2      # 5.0, a float
10 // 2     # 5, an int, floor division
```

Types shift as values flow through arithmetic. Knowing when is most of what separates a
program that adds up from one that does not.

### Naming, done twice

Here is a working route that computes a receipt:

```python
from tina4_python.core.router import get

M = {"coffee": 25, "tea": 20, "juice": 30}


@get("/api/bad/{o}")
async def bad(request, response):
    a = request.params["o"].split(",")
    b = 0
    for c in a:
        b = b + M[c]
    d = b * 0.15
    return response({"t": b + d})
```

It runs. It is correct. Now the same logic with the names doing their job:

```python
from tina4_python.core.router import get

MENU = {"coffee": 25, "tea": 20, "juice": 30}
VAT_RATE = 0.15


@get("/api/receipt/{order}")
async def receipt(request, response):
    ordered_items = request.params["order"].split(",")

    subtotal = 0
    for item in ordered_items:
        subtotal = subtotal + MENU[item]

    vat = subtotal * VAT_RATE
    total = subtotal + vat

    return response({"subtotal": subtotal, "vat": vat, "total": total})
```

Same arithmetic. Same speed. The second one answers questions the first one raises. What is
`d`? What does `0.15` mean, and where else in this codebase does that number appear with a
different meaning?

Notice `VAT_RATE` in capitals. That is a convention, not a rule Python enforces. Capitals
say "this is a fixed value set once and never changed while the program runs." Python will
happily let you reassign it. Every Python developer reading your code will assume you did
not.

---

## 3. The Principle

The practice is called **intention-revealing names**, and the clearest statement of it is
chapter 2 of Robert Martin's *Clean Code*.

The argument runs like this. Code gets read far more often than it gets written. Every hour
you spend writing is repaid across years of people reading, and most of them will be reading
in a hurry, looking for one specific thing, at a moment when something is broken. A name
that explains itself saves each of those readers a trip into the definition.

Three rules carry most of the value.

**A name should answer why it exists, what it does, and how it is used.** If the name needs
a comment beside it to explain what it holds, the name failed and the comment is patching
it.

**Avoid disinformation.** `menu_list` that holds a dictionary is worse than useless, because
now the reader trusts a wrong thing. `account_list` for something that is not a list will
cost somebody an afternoon.

**Make distinctions meaningful.** `data`, `data2` and `info` in one function tell you the
author had three things and no vocabulary for them. Find the real difference and name it.

There is a fourth principle underneath all of them, and it is the one worth carrying out of
this module. **Naming is not documentation, it is design.** When you cannot name something,
that is usually the code telling you the thing has no clear job. A variable you cannot name
is often two variables. A function you cannot name is often two functions. The struggle to
name is diagnostic, and experienced developers listen to it.

---

## 4. Elsewhere

Every language community wrote this down, and they mostly agree.

**Python** has PEP 8: `snake_case` for variables and functions, `UPPER_SNAKE` for constants,
`PascalCase` for classes.

**Ruby** uses the same `snake_case` and `UPPER_SNAKE`, and adds punctuation with meaning.
A trailing `?` means it returns true or false (`empty?`). A trailing `!` warns you the
method changes the thing you gave it (`sort!`).

**JavaScript** and **Java** use `camelCase` for variables, `PascalCase` for classes,
`UPPER_SNAKE` for constants.

**PHP** follows PSR-12, which lands close to JavaScript.

The casing differs and nothing else does. Every one of them separates constants from
variables by shape, marks types differently from values, and tells you to write names a
stranger can read. Learn the reasoning once and you adjust the casing in an afternoon.

---

## 5. When Not To

### Short scopes tolerate short names

The advice above gets misread as "always use long names", and that produces its own mess:

```python
for individual_menu_item_identifier in ordered_items:
```

The value exists for two lines. Nobody is confused by `item`. The rule scales with distance:
the further a name travels from where it was set, the more work it has to do. A loop
variable used on the next line can be one word, and `i` for a numeric index is understood
everywhere.

### Established conventions beat descriptive names

In `for i in range(10)`, `i` is not lazy. It is a fifty-year-old convention that every
programmer reads instantly. `x` and `y` for coordinates, `n` for a count, `e` for an
exception in a catch block. Replacing these with prose makes code harder to read, not
easier. Match your reader's expectations.

### Never store money as a float

This one is not about naming and it is the most valuable thing in this module.

You wrote `vat = subtotal * VAT_RATE` above and got a float. Try this in Python:

```python
0.1 + 0.2        # 0.30000000000000004
```

That is not a Python bug. Floats store numbers in binary, and some decimal fractions have no
exact binary form, the same way one third has no exact decimal form. The tiny error is
usually invisible. Across a million transactions it is an accounting discrepancy nobody can
find.

Real systems hold money as an **integer number of cents**, or as a decimal type built for
the job (`decimal.Decimal` in Python, `BigDecimal` in Java). Store 2575, not 25.75. Divide by
100 at the very last moment, when a human is about to read it.

The course keeps floats for now because you are learning variables, not building a payment
system. Module 9 revisits it when money reaches a database. Carry the rule out of here
anyway: **if it is money, it is not a float.** Interviewers ask this one.

---

## 6. Check Yourself

Your exercise is in `course/exercises/module-02/`.

You will build a receipt endpoint, then answer four written questions. The code is worth 30
and the answers are worth 70.

Question 4 asks you to argue about floats and money. There is a defensible answer on both
sides for a small cafe. The marks are in whether you can weigh the cost of being right
against the cost of being simple, which is the judgement this whole course is teaching.
