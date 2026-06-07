<!-- Status pill. tone: ok | warn | err | accent | muted (default). -->
<template>
  <span class="oui-badge" :class="'is-' + tone">
    <span v-if="dot" class="oui-badge__dot" />
    <slot>{{ label }}</slot>
  </span>
</template>

<script>
export default {
  name: 'OuiBadge',
  props: {
    label: { type: String, default: '' },
    tone: { type: String, default: 'muted' },
    dot: { type: Boolean, default: false }
  }
}
</script>

<style scoped>
.oui-badge {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 2px 10px; border-radius: var(--ds-radius-pill);
  font-size: 12px; font-weight: 600; line-height: 1.6;
  border: 1px solid transparent; white-space: nowrap;
}
.oui-badge__dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; box-shadow: 0 0 6px currentColor; }
.is-muted  { color: var(--ds-text-2); background: var(--ds-surface-2); border-color: var(--ds-border); }
.is-ok     { color: var(--ds-ok);   background: var(--ds-ok-weak); }
.is-warn   { color: var(--ds-warn); background: var(--ds-warn-weak); }
.is-err    { color: var(--ds-err);  background: var(--ds-err-weak); }
.is-accent { color: var(--ds-accent); background: var(--ds-accent-weak); }
</style>
