<!-- Form row: label (+optional hint) above/left of an input slot. Aligns in a
     grid for a tidy settings form. -->
<template>
  <div class="oui-field">
    <div class="oui-field__label">
      <span>{{ label }}</span>
      <el-tooltip v-if="hint" :content="hint" placement="top">
        <span class="oui-field__q">?</span>
      </el-tooltip>
    </div>
    <div class="oui-field__control"><slot /></div>
  </div>
</template>

<script>
export default {
  name: 'OuiField',
  props: {
    label: { type: String, required: true },
    hint: { type: String, default: '' }
  }
}
</script>

<style scoped>
.oui-field {
  display: grid; grid-template-columns: 200px 1fr; gap: var(--ds-4);
  align-items: center; padding: var(--ds-3) 0;
  border-bottom: 1px solid var(--ds-border);
}
.oui-field:last-child { border-bottom: none; }
.oui-field__label { display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 540; color: var(--ds-text); }
.oui-field__q {
  display: inline-flex; align-items: center; justify-content: center;
  width: 15px; height: 15px; border-radius: 50%; font-size: 10px; cursor: help;
  color: var(--ds-text-3); border: 1px solid var(--ds-border-strong);
}
.oui-field__control { min-width: 0; }
@media (max-width: 720px) {
  .oui-field { grid-template-columns: 1fr; gap: var(--ds-2); align-items: stretch; }
}
</style>
