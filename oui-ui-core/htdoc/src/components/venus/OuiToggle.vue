<!-- Labeled switch row: title + description on the left, el-switch on the right.
     v-model:modelValue (boolean). Emits change for side effects. -->
<template>
  <label class="oui-toggle" :class="{ 'is-disabled': disabled }">
    <span class="oui-toggle__text">
      <span class="oui-toggle__title">{{ title }}</span>
      <span v-if="description" class="oui-toggle__desc">{{ description }}</span>
    </span>
    <el-switch
      :model-value="modelValue"
      :loading="loading"
      :disabled="disabled"
      @update:model-value="v => { $emit('update:modelValue', v); $emit('change', v) }"
    />
  </label>
</template>

<script>
export default {
  name: 'OuiToggle',
  props: {
    modelValue: { type: Boolean, default: false },
    title: { type: String, required: true },
    description: { type: String, default: '' },
    loading: { type: Boolean, default: false },
    disabled: { type: Boolean, default: false }
  },
  emits: ['update:modelValue', 'change']
}
</script>

<style scoped>
.oui-toggle {
  display: flex; align-items: center; gap: var(--ds-4);
  padding: var(--ds-3) 0;
}
.oui-toggle__text { display: flex; flex-direction: column; gap: 2px; flex: 1; min-width: 0; }
.oui-toggle__title { font-size: 14px; font-weight: 560; color: var(--ds-text); }
.oui-toggle__desc { font-size: 12px; color: var(--ds-text-2); }
.is-disabled { opacity: .6; }
</style>
