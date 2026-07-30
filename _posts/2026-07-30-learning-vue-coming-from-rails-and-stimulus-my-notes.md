---
title: "Vue Notes for a Rails and Stimulus Developer"
description: "I've written Rails and Stimulus for years. Here are my notes from learning Vue fast for a real feature, plus three real bugs that cost me real time."
date: 2026-07-30
last_modified_at: 2026-07-30
author: Nanda Suhendra
categories:
  - General
tags:
  - Vue.js
  - Ruby on Rails
  - Stimulus
  - JavaScript
cover_image:
canonical_url:
draft: false
---

I have written Rails and Stimulus for years. Then a project came up where part of the frontend is Vue, and I had to get productive in it fast, while building a real feature: a form where a user searches for a record, picks one, and imports data from it.

I learned by reading the actual codebase instead of tutorials, and I wrote down everything that confused me along the way. This post is those notes, cleaned up. If you already know Rails and Stimulus and want a fast way into Vue, this should help. There are also three real bugs near the end that cost me actual debugging time.

---

## The main difference from Stimulus

Stimulus reacts to the DOM. Vue owns the DOM.

In Stimulus, the server renders the HTML first, and a controller attaches behavior to it after the fact using `data-target` and `data-value`. The HTML is the source of truth. You write code that changes the DOM directly.

```js
// Stimulus: you write the DOM mutation yourself
toggle() {
  this.panelTarget.classList.toggle("hidden")
}
```

Vue works the other way. The component's state is the source of truth, and the DOM is just a rendering of that state. You never write `element.classList.toggle(...)` by hand. You change a variable, and Vue updates whatever part of the template depends on it.

```vue
<!-- Vue: you describe the state, Vue updates the DOM -->
<div v-if="open">panel content</div>
<script setup>
const open = ref(false)
function toggle() { open.value = !open.value }
</script>
```

This is the one thing to internalize before anything else. Stop thinking about DOM mutations, start thinking about state changes.

---

## Not every page is a Vue page

This project mixes classic Rails pages with Vue pages. Some pages are still plain ERB, sometimes with a Stimulus controller. Some pages are Vue, mounted through Vue Router.

You can tell which is which by checking `frontend/src/router/index.ts`:

```ts
{
  path: '/v2/profiles',
  component: () => import('../pages/profiles/Index.vue'),
}
```

If a path is registered there, it is a Vue Router page. If it is not, like the edit page at `/profiles/:id/edit`, it is a regular Rails page. Full HTTP request, full page reload, no Vue Router involved.

I hit this directly. I was wiring up "after creating a profile, open its edit page" inside a Vue component, and my first instinct was `router.push`, since that felt like the normal Vue way to navigate. It did not work, because the edit page is not a Vue route. Vue Router does not know it exists, so you get a blank screen.

The actual fix was a plain navigation:

```ts
import { navigateToUrl } from '@/utils/urlUtils';
navigateToUrl(`/profiles/${profile.id}/edit`);
```

`navigateToUrl` is just `window.location.href = ...`. A real full page navigation, same as clicking a plain anchor tag. Check the router file first, before deciding how to navigate somewhere.

---

## What is inside a .vue file

A `.vue` file has up to three parts:

```vue
<template>
  <!-- markup, with Vue directives -->
</template>

<script setup lang="ts">
  // component logic, this project uses TypeScript everywhere
</script>

<style scoped>
  /* optional, most components here use Tailwind classes instead */
</style>
```

`<script setup>` is compile time sugar. Anything you declare at the top level, a variable, a function, an import, is automatically available in the template. No `return { ... }`, no `this.`. Every component in this project uses `<script setup>`.

---

## ref, computed, and watch

This is the part with no real equivalent in Stimulus.

### ref holds a value

```ts
const open = ref(false)   // open.value is false
open.value = true         // triggers a re-render of anything using `open`
```

In the template you write `open`, no `.value`. Vue unwraps it for you there. In `<script>` you always need `.value`.

A real example from the import form:

```ts
const description = ref('');
const isSubmitting = ref(false);
const selectedRecord = ref<Invoice | null>(null);
```

Each of these is an independent reactive value. Change `isSubmitting.value`, and only the parts of the template that read `isSubmitting` update. Vue tracks the dependency for you automatically.

### computed derives a value automatically

```ts
const canSubmit = computed(() => selectedRecord.value !== null)
```

`canSubmit` is read only and stays in sync with `selectedRecord` on its own. You never manually recompute it. A real example, deciding a status dot's color:

```ts
const statusDotClass = computed(() => {
  if (props.record.status === 'running') return 'tw-bg-yellow-500';
  if (props.record.status === 'ready') return 'tw-bg-green-500';
  return 'tw-bg-red-500';
});
```

When `record.status` changes, this recalculates, and the element bound to `:class="statusDotClass"` updates. No manual wiring.

### watch runs a side effect when something changes

Use `watch` when a change should trigger an action, like an API call or resetting another field, not just when you need to derive a value to display. Example from a searchable select component:

```ts
watch(() => props.modelValue, value => {
  if (value === null) selectedOption.value = null
})
```

This means: when the parent clears `modelValue`, also clear the internally tracked `selectedOption`. That is a side effect, changing a different ref, which `computed` cannot do, since `computed` must stay pure and only return a value.

Simple rule: deriving a value to display, use `computed`. Reacting to a change to do something else, use `watch`.

---

## Props down, events up

A Vue component talks to its parent in two directions only. It reads props the parent passed in, and it emits events the parent can listen to. It never reaches up and changes the parent's state directly. One way data flow, stricter than a Stimulus outlet.

A searchable select component declaring what it accepts and what it emits:

```ts
interface Props {
  modelValue?: T | null
  fetchOptions: SearchSelectFetcher<T>
  label?: string
  // ...
}
const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: T | null): void
}>()
```

The parent uses it like this:

```vue
<SearchSelect
  v-model="selectedRecord"
  :fetch-options="fetchRecordOptions"
  label="Record"
/>
```

The searchable select does not know the import form exists. It just calls `emit('update:modelValue', someValue)` when a user picks something, and whoever is listening reacts. That is why the same component gets reused for different lookups across the app.

---

## v-model is just sugar

`v-model="selectedRecord"` above is shorthand for:

```vue
<SearchSelect
  :model-value="selectedRecord"
  @update:model-value="selectedRecord = $event"
/>
```

Prop down, event up, the same pattern as above, just with a naming convention, `modelValue` and `update:modelValue`, that lets Vue offer the shorthand.

You can put more than one `v-model` on one component. This project does that on a search and sort bar, bound directly to a Pinia store:

```vue
<SearchSortBar
  v-model:search="store.searchQuery"
  v-model:sort="store.sortBy"
  v-model:status="store.statusBy"
  @change="handleSearchChange"
/>
```

Three independent two way bindings on one component instance.

---

## Composables

A composable is a plain function whose name starts with `use`, that uses `ref`, `computed`, or lifecycle hooks internally, and returns whatever the caller needs. It is how you share stateful logic across components without inheritance or mixins.

The full `useDebounce` composable:

```ts
export function useDebounce<T extends (...args: any[]) => void>(fn: T, delay = 300) {
  let timeout: ReturnType<typeof setTimeout>
  return (...args: Parameters<T>) => {
    clearTimeout(timeout)
    timeout = setTimeout(() => fn(...args), delay)
  }
}
```

Used inside the searchable select component:

```ts
const debouncedSearch = useDebounce((query: string) => runSearch(query), props.debounceMs)
```

`useClickOutside` also hooks into the component's lifecycle:

```ts
export function useClickOutside(elementRef, callback) {
  const handler = (event: MouseEvent) => {
    const el = elementRef.value
    if (!el) return
    if (!el.contains(event.target as Node)) callback()
  }

  onMounted(() => document.addEventListener('click', handler, true))
  onBeforeUnmount(() => document.removeEventListener('click', handler, true))
}
```

`onMounted` and `onBeforeUnmount` only work from inside a component's setup, meaning the top level of `<script setup>`, because Vue needs to know which component instance they belong to. You cannot call `onMounted` from a random function outside a component.

---

## Pinia for global state

Stimulus controllers are local to the DOM node they are attached to. Vue apps often need state shared across many components, no matter where they sit in the tree. That is what Pinia is for.

A trimmed down version of the profiles store:

```ts
export const useProfilesStore = defineStore('profiles', {
  state: () => ({
    searchQuery: '',
    sortBy: 'created_at_desc',
    statusBy: '',
    profiles: [] as ProfileRecord[],
  }),
  getters: {
    hasProfiles: (state) => state.profiles.length > 0,
  },
  actions: {
    async fetchAndSetProfiles(page?: number) {
      const response = await apiFetchProfiles({ /* ... */ })
      this.profiles = response.data.profiles
    },
  },
})
```

Any component can call `useProfilesStore()` and get the same shared instance back. It is a client side singleton, similar to how a Rails model or service can be the single source of truth for a piece of data, except it lives in the browser tab's memory, not the database.

- `state` is the reactive data, like a group of refs, shared globally
- `getters` work like `computed`, scoped to the store
- `actions` are functions that change state and run async work, this is where API calls live, not directly in components

Convention on this project: components never call the API layer directly for shared domain data. They go through a store action. The API files are the only files that know real URLs and HTTP methods. Stores call those and expose plain async methods. Components call store actions and read store state.

---

## Generic components

Used exactly once in this project, in the searchable select component:

```vue
<script setup lang="ts" generic="T">
interface Props {
  modelValue?: T | null
  fetchOptions: SearchSelectFetcher<T>
}
</script>
```

This lets one component stay type safe for different payload types depending on where it is used. In the import form it is used as `SearchSelect<Invoice>`, inferred from `fetchOptions` returning `SearchSelectOption<Invoice>[]`, so `selectedRecord` is typed as `Invoice | null`, not `unknown`. Without generics, you would either duplicate the component per type, or cast everything with `as` and lose type safety. At compile time this erases to a normal component, `T` does not exist at runtime.

---

## Directive cheat sheet

- `v-if`, `v-else-if`, `v-else`: creates or destroys the element. Closest to `<% if %>` in ERB, but re-evaluated live.
- `v-show`: toggles CSS display, element stays in the DOM. Closest to a `.hidden` class toggle in Stimulus.
- `v-for="item in list"`: renders a list, always pair it with `:key`. Closest to `<% list.each do |item| %>`.
- `v-bind:x` or `:x`: binds an attribute or prop to a JS expression. Closest to ERB interpolation, but live updating.
- `v-on:click` or `@click`: attaches an event listener. Closest to `data-action="click->controller#method"`.
- `v-model`: two way binding, covered above.
- `v-slot` or `#name`: named content passed into a child component. Closest to a Rails `content_for` or a partial yield.

Use `v-if` when the condition is rarely true, it skips the rendering cost. Use `v-show` when it toggles often and you want to avoid recreating the DOM node or losing its state. Almost everything in this codebase uses `v-if`.

---

## Lifecycle hooks

Roughly, per component:

1. `setup()` runs, the `<script setup>` body, top to bottom
2. `onMounted` fires, the DOM exists now, safe to measure things or attach listeners
3. Reactive updates happen, any number of times, as long as the component is alive
4. `onBeforeUnmount` fires right before the component is destroyed, time to clean up

Every `document.addEventListener` added in `onMounted` needs a matching removal in `onBeforeUnmount`, or it leaks. The listener keeps the component's closures alive even after the component itself is gone. This project always pairs them, see the searchable select component and `useClickOutside`.

---

## Three real bugs I hit building this feature

These are the parts worth reading slowly. Not general Vue concepts, but real bugs that cost me time, and are the kind of thing a getting started guide will not mention.

### Bug one: a dropdown getting cut off

The modal component's content wrapper uses this CSS:

```css
.tw-modal-container { @apply tw-overflow-hidden ...; }
.tw-modal-body { @apply tw-overflow-y-auto ...; }
```

The searchable select's dropdown panel is `position: absolute`, positioned relative to its own wrapper. When that wrapper lives inside the modal body, and the dropdown would extend past the modal's visible area, it gets cut off. `overflow` clips every descendant regardless of `position`, as long as they are still DOM descendants of the clipping ancestor.

The standard fix is `Teleport to="body"`, moving the dropdown's DOM node to be a direct child of `body`, combined with `position: fixed` computed from the trigger's `getBoundingClientRect()`. I tried this twice and could not get it to render reliably, mostly because this environment has no working headless browser, so debugging was indirect, through console logs someone else pasted back to me. I reverted it rather than ship something I could not verify myself.

What I shipped instead was smaller. While the dropdown is open, walk up with `closest()` to find the modal's clipping ancestors, and temporarily set their overflow to visible, then restore it on close:

```ts
function getOverflowEscapeTargets(): HTMLElement[] {
  if (!root.value) return []
  return [
    root.value.closest<HTMLElement>('.tw-modal-body'),
    root.value.closest<HTMLElement>('.tw-modal-container'),
  ].filter((el): el is HTMLElement => el !== null)
}

function setOverflowEscaped(escaped: boolean) {
  getOverflowEscapeTargets().forEach(el => {
    el.style.overflow = escaped ? 'visible' : ''
  })
}
```

Teleport is the correct answer on paper, but it moves your element to a new spot in the DOM, and that can break assumptions elsewhere, see the next bug. When you cannot test something interactively, prefer the smaller reversible fix over the "correct" one.

### Bug two: click outside stopped working, but only inside the modal

The modal's content wrapper does this:

```vue
<div ref="modalContent" :class="modalClasses" @click.stop>
```

`@click.stop` calls `event.stopPropagation()` during the bubble phase. It stops a click inside the modal from also reaching the modal's overlay, which is what closes the modal on an outside click.

But `useClickOutside` also listens on `document`, on the bubble phase:

```ts
document.addEventListener('click', handler)   // bubble phase, this was the bug
```

A click bubbles from the target up through its ancestors to `document`. Since the modal content sits between the click target and `document`, and it calls `stopPropagation()`, the event never reached `document`. The click outside handler never fired for clicks inside the modal that were not on the dropdown itself. The dropdown would only close if you clicked fully outside the modal.

The fix is to register on the capture phase instead:

```ts
document.addEventListener('click', handler, true)   // capture phase, this was the fix
```

A click actually fires twice. Capture happens first, top down from the window to the target. Bubble happens second, bottom up, from the target back to the window. A capture phase listener on `document` fires before the click even reaches the modal content, so the modal's later `stopPropagation()`, which only affects the bubble phase from that point on, cannot block it.

If a click outside to close pattern stops working only inside one specific container, look for a `.stop` or `stopPropagation()` between your listener and the click. Switching to capture phase is the standard fix.

### Bug three: a teleported element rendering somewhere invisible

While debugging the Teleport attempt, I wrapped an already `position: absolute` element in `Teleport to="body"` without giving it explicit coordinates. It rendered far down the page, wherever it landed in `body`'s normal document flow, since Teleport appends at the end of `body` by default. Effectively invisible without scrolling all the way down. If you teleport an absolutely positioned element, give it explicit `top` and `left`, or switch to `position: fixed` with computed coordinates. Otherwise it silently works while rendering somewhere you will never see it.

---

## How the code is organized

- `api/`, one file per Rails resource, the only place that knows URLs and HTTP verbs
- `stores/`, Pinia stores, components talk to these, not to the API layer directly
- `types/`, shared TypeScript interfaces, mirroring the backend serializer shapes
- `composables/`, reusable reactive logic, `useDebounce`, `useClickOutside`, `useToast`
- `components/ui/`, generic reusable primitives, buttons, inputs, selects, the searchable select, no knowledge of any specific page or feature
- `components/shared/`, less generic shared pieces, modal, dropdown, page loader
- `pages/<feature>/`, one Vue Router page per feature
- `pages/<feature>/components/`, components specific to that one feature

Rule of thumb: if it could plausibly be reused by an unrelated feature, it belongs in `components/ui/` or `components/shared/`. If it only makes sense in the context of one feature, it belongs under `pages/<feature>/components/`.

---

## Checking my work without a browser

This environment has no reliable browser automation, so I relied on static checks, and they caught most of my mistakes anyway:

```bash
cd frontend
npx vue-tsc --noEmit -p tsconfig.json   # type checks every .vue file's script
npx eslint src                          # lint, unused vars, style, hook misuse
```

`vue-tsc` catches wrong prop types, a typo in an emitted event name, a `ref` used without `.value` in `<script>`, mismatched generic type arguments. It will not catch CSS layout or clipping bugs, event bubbling issues, or anything about visual correctness. Those need a browser, or a careful trace through the DOM structure, the same way I worked through the three bugs above.

---

## Quick glossary, Rails and Stimulus to Vue

- A Stimulus controller becomes a `.vue` single file component
- `data-target` becomes a template ref, `ref="foo"` plus `const foo = ref(null)`
- `data-value` becomes a prop
- `this.dispatch(...)` becomes `emit('eventName', payload)`
- A Stimulus mixin or shared behavior becomes a composable, a `useSomething.ts` function
- Turbo Frame or session data becomes a Pinia store
- ERB `<% if %>` becomes `v-if`
- ERB `<% collection.each %>` becomes `v-for`
- A partial with `yield` becomes a slot
- A plain anchor tag full page link becomes `navigateToUrl(...)`
- Vue Router's `router.push` only works for paths registered in `router/index.ts`, everything else is still a real Rails page

---

## Wrapping up

The biggest adjustment was not any single API, it was the direction of control. Stimulus reacts to the DOM. Vue owns the state and treats the DOM as a result of it. Once that clicked, `ref`, `computed`, and `v-model` stopped feeling like new syntax to memorize.

The three bugs above were the more useful lessons. Overflow clipping, click event phases, and Teleport's positioning quirks are not things a getting started guide covers, and they cost real debugging time if you do not already know to check for them.

If you are a Rails or Stimulus developer picking up Vue, my advice: read real components in your codebase instead of only tutorial examples, and when something breaks in a way that feels impossible, check whether a click handler or an overflow rule somewhere up the tree is getting in the way.
