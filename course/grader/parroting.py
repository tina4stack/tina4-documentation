"""Deterministic parroting detection.

The first version of this grader asked the examiner to notice copied text. It
did not. A submission lifted word for word from the chapter scored 20/20,
because a rule buried in a long prompt competes with everything else in that
prompt and loses.

So the check moved out of the model and into code. Overlap against the chapter
is a measurable property of two strings, and measuring beats asking. The model
now only grades answers that already passed this gate, which is the job it is
actually good at.

Method: shingle both texts into overlapping n-word windows, then ask what
fraction of the answer's windows also appear in the chapter. Copying a sentence
puts every window of that sentence into the chapter's set. Writing the same idea
in your own words does not, because word order diverges within a few words.
"""
import re

SHINGLE = 6          # words per window
PARROT_THRESHOLD = 0.45   # fraction of an answer's windows found in the chapter


def normalise(text: str) -> list:
    """Lowercase, strip punctuation, collapse whitespace, return words."""
    text = text.lower()
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)   # drop code blocks
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    return text.split()


def shingles(words: list, size: int = SHINGLE) -> set:
    if len(words) < size:
        return {" ".join(words)} if words else set()
    return {" ".join(words[i:i + size]) for i in range(len(words) - size + 1)}


def overlap_ratio(answer: str, source: str) -> float:
    """Fraction of the answer's windows that also occur in the source."""
    answer_shingles = shingles(normalise(answer))
    if not answer_shingles:
        return 0.0
    source_shingles = shingles(normalise(source))
    if not source_shingles:
        return 0.0
    hits = len(answer_shingles & source_shingles)
    return hits / len(answer_shingles)


def longest_lifted_run(answer: str, source: str) -> int:
    """Longest run of consecutive words the answer shares with the source.

    Reported to the student so the feedback can point at the actual sentence
    rather than making an unevidenced accusation.
    """
    answer_words = normalise(answer)
    source_text = " " + " ".join(normalise(source)) + " "

    best = 0
    for start in range(len(answer_words)):
        for end in range(start + best + 1, len(answer_words) + 1):
            candidate = " ".join(answer_words[start:end])
            if f" {candidate} " in source_text:
                best = max(best, end - start)
            else:
                break
    return best


def check(answer: str, source: str) -> dict:
    """Verdict for one answer against the chapter text."""
    ratio = overlap_ratio(answer, source)
    run = longest_lifted_run(answer, source)
    return {
        "parroted": ratio >= PARROT_THRESHOLD,
        "overlap": round(ratio, 3),
        "longest_run": run,
    }
