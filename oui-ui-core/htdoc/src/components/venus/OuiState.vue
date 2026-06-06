<!-- Empty / loading / error placeholder. type: loading | empty | error. -->
<template>
  <div class="oui-state" :class="'is-' + type">
    <el-icon v-if="type === 'loading'" class="is-spin"><Loading /></el-icon>
    <el-icon v-else-if="type === 'error'"><WarningFilled /></el-icon>
    <el-icon v-else><Box /></el-icon>
    <p class="oui-state__msg">{{ message || defaultMsg }}</p>
    <div v-if="$slots.default" class="oui-state__actions"><slot /></div>
  </div>
</template>

<script>
export default {
  name: 'OuiState',
  props: {
    type: { type: String, default: 'empty' }, // loading | empty | error
    message: { type: String, default: '' }
  },
  computed: {
    defaultMsg() {
      return { loading: 'Загрузка…', empty: 'Пусто', error: 'Ошибка загрузки' }[this.type] || ''
    }
  }
}
</script>

<style scoped>
.oui-state {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: var(--ds-3); padding: var(--ds-7) var(--ds-4); text-align: center;
  color: var(--ds-text-3);
}
.oui-state .el-icon { font-size: 28px; }
.is-error .el-icon { color: var(--ds-err); }
.oui-state__msg { margin: 0; font-size: 13px; color: var(--ds-text-2); }
.is-spin { animation: oui-spin 1s linear infinite; }
@keyframes oui-spin { to { transform: rotate(360deg); } }
</style>
