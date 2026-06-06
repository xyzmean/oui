<!-- Surface card with optional title / subtitle / header actions. -->
<template>
  <section class="oui-card" :class="{ 'is-flush': flush }">
    <header v-if="title || $slots.actions || $slots.header" class="oui-card__head">
      <slot name="header">
        <div class="oui-card__titles">
          <h2 class="ds-h2">{{ title }}</h2>
          <p v-if="subtitle" class="ds-sub">{{ subtitle }}</p>
        </div>
      </slot>
      <div v-if="$slots.actions" class="ds-row-end"><slot name="actions" /></div>
    </header>
    <div class="oui-card__body"><slot /></div>
  </section>
</template>

<script>
export default {
  name: 'OuiCard',
  props: {
    title: { type: String, default: '' },
    subtitle: { type: String, default: '' },
    flush: { type: Boolean, default: false }
  }
}
</script>

<style scoped>
.oui-card {
  background: var(--ds-surface);
  border: 1px solid var(--ds-border);
  border-radius: var(--ds-radius);
  box-shadow: var(--ds-shadow);
}
.oui-card__head {
  display: flex; align-items: flex-start; gap: var(--ds-3);
  padding: var(--ds-4) var(--ds-5);
  border-bottom: 1px solid var(--ds-border);
}
.oui-card__titles { display: flex; flex-direction: column; gap: 2px; }
.oui-card__body { padding: var(--ds-5); }
.is-flush .oui-card__body { padding: 0; }
</style>
