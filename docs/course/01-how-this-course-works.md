# Chapter 1: How This Course Works

## What You Are Signing Up For

You will not learn a framework. You will learn to build software, and Tina4 will be the
workbench you learn it on.

That distinction matters. A framework teaches you where files go. This course teaches you
why they go there, what happens when they do not, and how to make that call yourself on a
codebase nobody has written yet. Tina4 is a good workbench because it has opinions. Every
opinion is a decision somebody made, and a decision you can be taught to interrogate.

The skills transfer. Every module names the practice it teaches, shows you how Django,
Rails, Laravel, Spring or Express does the same thing, and tells you when the practice is
wrong. Walk out of here and you can read a Rails codebase. That is the point.

## Three Levels

The course runs on Kent Beck's old instruction: make it work, make it right, make it fast.
We changed the last one. Fast is a property. Lasting is a discipline.

**Level 1: Make It Work.** You have never written a line of code. You finish able to build
a small web application and explain every line of it.

**Level 2: Make It Right.** You can write code that runs. You finish able to write code
another person can maintain without phoning you.

**Level 3: Make It Last.** You can structure an application. You finish able to make an
architectural decision, write down why, and defend it to a room that disagrees.

Each level is twelve modules. Each level ends with a capstone you build and defend.

## Every Module Has the Same Six Parts

**1. The Idea.** The concept in plain language, before any code. If you cannot say it in
a sentence you do not have it yet.

**2. Build It.** Hands on the keyboard. Working Tina4 code you type, run, and break.

**3. The Principle.** The named industry practice underneath. Not "the Tina4 way" but the
actual practice, with the source it comes from. Convention over configuration has an
author. Guard clauses have a reason. You get both.

**4. Elsewhere.** The same principle in Django, Rails, Laravel, Express or Spring. Tina4
made one choice. Other people made others. You need to recognise all of them.

**5. When Not To.** The counter-case. Every practice in this course has a situation where
applying it makes your software worse. A developer who only knows the rule is a liability.
A developer who knows the edge of the rule is worth hiring.

**6. Check Yourself.** The graded part. Explained below.

## How You Are Graded

Here is the uncomfortable bit. Your code working is worth almost nothing.

Anyone can copy a working route from a chapter and paste it into a file. Software gets
built by people who understand what they pasted, and it gets maintained by people who can
explain it eighteen months later at 2am. So this course grades comprehension, and it grades
it hard.

Every exercise has two gates.

**Gate one: does it run.** A test client dispatches real requests through the real
framework and checks the real answers. No mocks. Your code either produces the contract or
it does not. This gate is pass or fail, and it is worth 30 percent at Level 1, dropping to
15 percent by Level 3.

**Gate two: do you understand it.** You write answers. An AI examiner grades them against
a rubric across four dimensions:

- **Explain.** Say why your code works, in your own words. Restating the chapter scores
  zero. The examiner is built to catch parroting.
- **Predict.** Given a change, say what happens before you run it. Guessing is visible.
- **Diagnose.** Given broken code, name the fault and the reason. Symptom-spotting scores
  half. Cause scores full.
- **Judge.** Given a scenario, choose an approach and defend it. There is often no single
  right answer, and the mark lives in the justification.

Gate two is worth 70 percent at Level 1, rising to 85 percent at Level 3. As you advance,
the course cares less and less whether your code runs and more and more whether you can
say why it should.

You can fail an exercise with working code. That is deliberate.

## The Examiner

The examiner is Tina4's own engine, reached over the Tina4 stack. The grading harness is
itself a Tina4 application: routes take the submission, the ORM stores it, the built-in
test client runs gate one, and the HTTP client carries gate two to the model. The course
grades itself with the thing it teaches.

The examiner sees your code and your written answers together. It cannot be talked out of
a mark. Instructions written inside a submission get treated as what they are, which is
text a student typed, not orders.

## What You Need

A computer, a terminal, and Python 3.12 or newer. Nothing else. Tina4 installs as one
package with no third-party dependencies, which means your first hour goes into writing
code instead of resolving a dependency tree.

```bash
pip install tina4-python
```

Module 1 starts with an empty folder. By the end of it you will have a running server
answering real requests, and you will be able to say what every part of that sentence
means.
