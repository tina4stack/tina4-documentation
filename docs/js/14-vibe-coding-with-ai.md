# Chapter 14: Vibe Coding with AI

## Let AI Write Your tina4-js

You type a prompt: "Build a todo app." The AI generates 200 lines of code. You paste it in. The build fails. The state management is wrong. The router syntax is backwards. You spend 30 minutes fixing what the AI wrote. You could have written it from scratch in 20.

That is what happens with ambiguous frameworks. tina4-js is different. One state primitive. One template system. One router. One way to do everything. The AI has no wrong choices to make -- and the code it generates works on the first try.

---

## 1. Why tina4-js Works Well with AI

Most JavaScript frameworks are ambiguous. React offers three ways to manage state (useState, useReducer, external stores). Vue offers four ways to style components (scoped, modules, Tailwind, CSS-in-JS). An AI agent faces these choices and guesses. It often guesses wrong.

tina4-js has one way to do everything:

- One state primitive: `signal()`
- One template system: `html` tagged templates
- One component base: `Tina4Element`
- One router: `route()` + `router.start()`
- One API client: `api`
- One WebSocket client: `ws`

One choice. One answer. One correct output.

When an AI reads the tina4-js documentation, there is no ambiguity. No "it depends on your preference." No "you could also use X." The AI generates correct code on the first try because there is only one way to write it.

---

## 2. CLAUDE.md -- The AI's Instruction Manual

Every tina4-js project includes a `CLAUDE.md` file at the root. AI assistants (Claude Code, Cursor, GitHub Copilot) read this file when they open the project.

`CLAUDE.md` contains:

- **Build and test commands** -- `npm run build`, `npm run test`, `npm run dev`
- **Project structure** -- where signals, components, routes, and pages live
- **Key conventions** -- `route(pattern, handler)` pattern-first, `api.get(path, options)` with `{ params, headers }`
- **Template binding syntax** -- the complete table of `${signal}`, `@click`, `?disabled`, `.value`, etc.
- **Package exports** -- all seven entry points
- **Publishing instructions** -- version, build, publish

When an AI opens a tina4-js project and reads `CLAUDE.md`, it knows:

- How to build and test
- Where to put new code
- What syntax to use in templates
- What the API signatures look like
- What pitfalls to avoid

No guessing. No hallucinating method names. No inventing conventions. The instruction manual is in the repository, and the AI reads it before writing a single line.

---

## 3. llms.txt -- AI Context for the Framework

The tina4-js npm package ships an `llms.txt` file. This is a standardized format that AI tools consume to understand a library's API. It includes:

- Every exported function with its signature
- Every interface and type
- Usage examples for each module
- Common patterns

AI agents that support `llms.txt` load this as context when generating tina4-js code, even if they have never encountered the framework before. The file bridges the gap between "I have never seen this library" and "I know every function signature and every convention."

---

## 4. The tina4-js Skill

Beyond `CLAUDE.md` and `llms.txt`, tina4-js ships with an AI skill file at `.claude/skills/tina4-js/SKILL.md`. This is a deep reference that teaches AI agents the three rules that fix 90% of mistakes:

### Rule 1: Static vs Reactive

```typescript
// WRONG -- AI often generates this
html`<p>${count.value}</p>`

// RIGHT -- the skill teaches this
html`<p>${count}</p>`
```

AI agents love to be explicit. They write `count.value` because it shows they are reading the signal's current value. But in tina4-js templates, `.value` makes the binding static -- evaluated once, never updated. Passing the signal itself creates a reactive binding that updates when the signal changes. The skill file drills this distinction until the AI internalizes it.

### Rule 2: New References

```typescript
// WRONG -- AI loves Array.push()
items.value.push(newItem);

// RIGHT
items.value = [...items.value, newItem];
```

AI agents trained on React often generate mutation patterns because React's `useState` works with `setState(prev => [...prev, item])`. In tina4-js, the signal itself must receive a new reference. No setter function wraps the mutation. The signal compares references. The skill teaches the spread pattern for every array and object operation.

### Rule 3: Boolean Attributes

```typescript
// WRONG -- AI writes this because it looks logical
html`<button disabled=${isDisabled}>Click</button>`

// RIGHT
html`<button ?disabled=${isDisabled}>Click</button>`
```

Without the `?` prefix, `disabled` is set as a string attribute. `disabled="false"` still disables the button in HTML -- the attribute's presence is what matters, not its value. The `?` prefix tells tina4-js to add or remove the attribute based on the signal's truthiness. The skill file explains this with examples that prevent the mistake before it happens.

---

## 5. What AI Gets Wrong

Even with the skill file, AI agents make these mistakes. Watch for them in generated code:

### Using .value in Templates

```typescript
// AI generates:
html`<p>Count: ${count.value}</p>`
html`<button ?disabled=${loading.value}>Submit</button>`

// Should be:
html`<p>Count: ${count}</p>`
html`<button ?disabled=${loading}>Submit</button>`
```

When you see `.value` inside a template interpolation, it is almost always wrong. The signal itself should be passed for reactive binding. The `.value` version renders once and freezes.

### The && Pattern

```typescript
// AI generates (React habit):
html`${isLoading.value && html`<p>Loading...</p>`}`

// Should be:
html`${() => isLoading.value ? html`<p>Loading...</p>` : null}`
```

AI agents trained on JSX use `&&` for conditional rendering. In tina4-js, `false` renders as the text "false." The ternary with `null` is the correct pattern. Every conditional in a template should use `() =>` with a ternary.

### Missing @event Syntax

```typescript
// AI generates:
html`<button onclick=${handler}>Click</button>`

// Should be:
html`<button @click=${handler}>Click</button>`
```

The `@` prefix is tina4-js syntax for event binding. Native `onclick` as an attribute does not work with template interpolation. The AI sometimes falls back to vanilla HTML event attributes out of habit.

### Forgetting Reactive Blocks for Conditionals

```typescript
// AI generates:
html`
  <div>
    ${showDetails ? html`<p>Details</p>` : html`<p>Summary</p>`}
  </div>
`

// Should be:
html`
  <div>
    ${() => showDetails.value ? html`<p>Details</p>` : html`<p>Summary</p>`}
  </div>
`
```

The function wrapper `() =>` is required for the template to re-evaluate when `showDetails` changes. Without it, the condition evaluates once at render time and never updates. The page stays frozen on whichever branch was true at creation.

### Using route() with Handler First

```typescript
// AI sometimes generates:
route(() => html`<h1>Home</h1>`, '/');

// Should be:
route('/', () => html`<h1>Home</h1>`);
```

Pattern first. Handler second. Always.

---

## 6. Working with Claude Code on tina4-js Projects

Claude Code reads `CLAUDE.md` on project open. When you work on a tina4-js project in Claude Code, the AI knows the framework. Here is how to get the best results:

### Be Specific About Modules

```
"Add a route at /users/{id} that fetches the user from /api/users/:id and displays their name and email"
```

This tells Claude which modules to use (route, api, html) and what the result should look like. Specific prompts produce specific code.

### Reference Existing Patterns

```
"Add a new page similar to src/pages/users.ts but for products"
```

Claude reads the existing file and replicates the pattern -- same signal structure, same API calls, same template style. Your codebase stays consistent.

### Let It Run the Dev Server

```
"Create a counter component and show me it works"
```

Claude creates the component, adds it to a route, and runs `npm run dev` to verify. The feedback loop is immediate.

### Review Generated Templates

After Claude generates tina4-js code, scan for five things:

1. `.value` inside `${}` in templates -- should it be the signal itself?
2. `&&` patterns -- should it be a ternary with `null`?
3. `disabled=` without `?` prefix -- should it be `?disabled=`?
4. Missing `() =>` wrappers around conditional expressions
5. Array mutations without new references

Five checks. Ten seconds. They catch the mistakes that would cost you ten minutes of debugging.

---

## 7. The AI Advantage

tina4-js was designed with AI-assisted development in mind. The framework's constraints are the AI's strengths:

- **One way to do things** means the AI never picks the wrong approach
- **Small API surface** means the AI does not hallucinate non-existent methods
- **Consistent conventions** mean generated code matches existing code
- **`CLAUDE.md` and skills** mean the AI has perfect context from the first prompt

Tell an AI: "Build a todo app with tina4-js." The AI needs to decide on state management, components, routing, styling, and API communication. With React, each decision has three to five options. The AI picks a combination. It might work. It might not. With tina4-js, there is one answer for each decision. The AI generates working code faster with fewer errors because fewer decisions means fewer wrong decisions.

This is not accidental. When every tina4 project follows the same structure, uses the same conventions, and ships the same instruction files, AI assistance becomes reliable. Not probabilistic. Not "usually right." Reliable.

---

## 8. Setting Up Your Project for AI

To get the best AI experience with tina4-js:

1. **Keep `CLAUDE.md` up to date.** If you add custom conventions -- naming patterns, file organization rules, API endpoint structures -- document them. The AI reads what you write.

2. **Use debug labels on signals.** AI agents read your code to understand patterns. `signal(0, 'cart-count')` communicates intent. `signal(0)` communicates nothing.

3. **Follow the project structure.** `src/routes/`, `src/pages/`, `src/components/`, `src/store.ts`. When the AI sees consistent structure, it generates code that fits. When the structure is chaotic, the AI generates code that adds to the chaos.

4. **Write TypeScript.** Type annotations give AI agents precise context about what functions expect and return. A typed interface is worth a paragraph of explanation.

5. **Use the store pattern.** Export signals from `store.ts`. AI agents recognize this pattern and replicate it. Scattered signals in random files confuse AI agents the same way they confuse human developers.

One framework. One structure. One set of conventions. The AI becomes an extension of your thinking instead of a source of surprises.

---

## Summary

| What | Where |
|---|---|
| Project instructions | `CLAUDE.md` at project root |
| Framework API reference | `llms.txt` in the npm package |
| Deep AI skill | `.claude/skills/tina4-js/SKILL.md` |
| Common AI mistake 1 | `${count.value}` instead of `${count}` |
| Common AI mistake 2 | `&&` pattern instead of ternary with `null` |
| Common AI mistake 3 | `disabled=` instead of `?disabled=` |
| Common AI mistake 4 | Missing `() =>` for reactive conditionals |
| Common AI mistake 5 | Array mutation instead of new reference |
