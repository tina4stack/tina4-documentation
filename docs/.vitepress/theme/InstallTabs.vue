<script setup lang="ts">
import { computed, ref } from 'vue'

const tabs = [
  { id: 'macos', label: 'macOS', cmd: 'curl -fsSL https://tina4.com/install.sh | sh' },
  { id: 'linux', label: 'Linux', cmd: 'curl -fsSL https://tina4.com/install.sh | sh' },
  { id: 'windows', label: 'Windows', cmd: 'irm https://tina4.com/install.ps1 | iex' },
]

const active = ref(tabs[0].id)
const copied = ref(false)
const activeCmd = computed(() => (tabs.find((t) => t.id === active.value) ?? tabs[0]).cmd)

function copy() {
  navigator.clipboard?.writeText(activeCmd.value).then(() => {
    copied.value = true
    setTimeout(() => { copied.value = false }, 1500)
  })
}
</script>

<template>
  <section class="install">
    <div class="install-inner">
      <h2 class="install-title">Install</h2>
      <p class="install-sub">
        Install the <code>tina4</code> CLI with one command, then run
        <code>tina4 setup</code> to scaffold your first project.
      </p>

      <div class="install-card">
        <div class="install-tabs" role="tablist">
          <button
            v-for="t in tabs"
            :key="t.id"
            class="install-tab"
            :class="{ active: active === t.id }"
            role="tab"
            :aria-selected="active === t.id"
            @click="active = t.id"
          >{{ t.label }}</button>
        </div>
        <div class="install-cmd">
          <code>{{ activeCmd }}</code>
          <button class="install-copy" type="button" aria-label="Copy command" @click="copy">
            {{ copied ? 'Copied' : 'Copy' }}
          </button>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.install {
  padding: 0 24px;
  margin: -24px 0 8px;
}
.install-inner {
  max-width: 1152px;
  margin: 0 auto;
}
.install-title {
  font-size: 24px;
  font-weight: 600;
  letter-spacing: -0.02em;
  line-height: 1.2;
}
.install-sub {
  margin: 8px 0 16px;
  color: var(--vp-c-text-2);
  font-size: 15px;
  line-height: 1.6;
}
.install-sub code {
  font-family: var(--vp-font-family-mono);
  font-size: 0.92em;
  color: var(--vp-c-brand-1);
}
.install-card {
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  overflow: hidden;
  background: var(--vp-c-bg-alt);
}
.install-tabs {
  display: flex;
  gap: 4px;
  padding: 8px 12px 0;
  border-bottom: 1px solid var(--vp-c-divider);
}
.install-tab {
  padding: 8px 14px;
  border: 0;
  border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--vp-c-text-2);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: color 0.2s, border-color 0.2s;
}
.install-tab:hover {
  color: var(--vp-c-text-1);
}
.install-tab.active {
  color: var(--vp-c-brand-1);
  border-bottom-color: var(--vp-c-brand-1);
}
.install-cmd {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 20px;
  background: var(--vp-code-block-bg);
}
.install-cmd code {
  overflow-x: auto;
  color: var(--vp-c-text-1);
  background: transparent;
  font-family: var(--vp-font-family-mono);
  font-size: 14px;
  white-space: pre;
}
.install-copy {
  flex: none;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  padding: 6px 14px;
  background: var(--vp-c-bg);
  color: var(--vp-c-text-2);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: color 0.2s, border-color 0.2s;
}
.install-copy:hover {
  border-color: var(--vp-c-brand-1);
  color: var(--vp-c-brand-1);
}
@media (min-width: 640px) {
  .install { padding: 0 48px; }
}
@media (min-width: 960px) {
  .install { padding: 0 64px; margin-top: -16px; }
}
</style>
