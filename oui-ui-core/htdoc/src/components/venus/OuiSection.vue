<!-- Page/section header: title + subtitle on the left, actions on the right. -->
<template>
  <div class="oui-section">
    <div class="oui-section__titles">
      <h1 class="ds-h1">{{ title }}</h1>
      <p v-if="subtitle" class="ds-sub">{{ subtitle }}</p>
    </div>
    <div v-if="$slots.default" class="ds-row-end"><slot /></div>
  </div>
</template>

<script>
export default {
  name: 'OuiSection',
  props: {
    title: { type: String, required: true },
    subtitle: { type: String, default: '' }
  }
}
</script>

<style scoped>
.oui-section { display: flex; align-items: flex-start; gap: var(--ds-3); }
.oui-section__titles { display: flex; flex-direction: column; gap: 3px; }
</style>
