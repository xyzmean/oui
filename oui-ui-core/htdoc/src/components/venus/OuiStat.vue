<!-- Compact metric tile: label, big value, optional hint + state accent bar. -->
<template>
  <div class="oui-stat" :class="'is-' + tone">
    <div class="oui-stat__label ds-label">{{ label }}</div>
    <div class="oui-stat__value ds-num">
      <slot>{{ value }}</slot>
    </div>
    <div v-if="hint || $slots.hint" class="oui-stat__hint">
      <slot name="hint">{{ hint }}</slot>
    </div>
  </div>
</template>

<script>
export default {
  name: 'OuiStat',
  props: {
    label: { type: String, default: '' },
    value: { type: [String, Number], default: '' },
    hint: { type: String, default: '' },
    tone: { type: String, default: 'muted' } // muted | ok | warn | err | accent
  }
}
</script>

<style scoped>
.oui-stat {
  position: relative;
  background: var(--ds-surface);
  border: 1px solid var(--ds-border);
  border-radius: var(--ds-radius);
  padding: var(--ds-4) var(--ds-4) var(--ds-4) calc(var(--ds-4) + 3px);
  box-shadow: var(--ds-shadow);
  min-width: 0;
}
.oui-stat::before {
  content: ''; position: absolute; left: 0; top: 10px; bottom: 10px; width: 3px;
  border-radius: 3px; background: var(--ds-border-strong);
}
.is-ok::before     { background: var(--ds-ok); }
.is-warn::before   { background: var(--ds-warn); }
.is-err::before    { background: var(--ds-err); }
.is-accent::before { background: var(--ds-accent); }
.oui-stat__label { margin-bottom: 6px; }
.oui-stat__value { font-size: 22px; font-weight: 680; letter-spacing: -.01em; line-height: 1.1; overflow-wrap: anywhere; }
.oui-stat__hint { margin-top: 4px; font-size: 12px; color: var(--ds-text-2); }
</style>
