<!--
  Network diagnostics — ping / traceroute / nslookup / arp, output shown in a
  terminal-like panel. Backed by diagnostics.lua.
-->
<template>
  <div class="ds-page">
    <oui-section title="Диагностика" subtitle="Сетевые инструменты" />

    <oui-card>
      <div class="ds-row">
        <el-select v-model="tool" style="width:180px">
          <el-option label="Ping" value="ping" />
          <el-option label="Traceroute" value="traceroute" />
          <el-option label="Nslookup" value="nslookup" />
          <el-option label="ARP-таблица" value="arp" />
        </el-select>
        <el-input v-model="host" placeholder="хост или IP" style="max-width:320px" :disabled="tool==='arp'" @keyup.enter="run" />
        <el-button type="primary" :loading="busy" @click="run">Запустить</el-button>
      </div>
      <pre v-if="output" class="diag-out">{{ output }}</pre>
      <oui-state v-else-if="!busy" type="empty" message="Выберите инструмент и запустите" />
      <oui-state v-else type="loading" message="Выполняется…" />
    </oui-card>
  </div>
</template>

<script>
export default {
  data() { return { tool: 'ping', host: '', output: '', busy: false } },
  methods: {
    async run() {
      this.busy = true; this.output = ''
      try {
        const r = await this.$oui.call('diagnostics', 'run', { tool: this.tool, host: this.host }) || {}
        if (r.ok === false) { this.$message.warning(r.msg || 'Ошибка'); }
        this.output = r.output || '(нет вывода)'
      } catch (e) { this.$message.error('Ошибка выполнения') }
      this.busy = false
    }
  }
}
</script>

<style scoped>
.diag-out {
  margin-top: 16px; padding: 16px; border-radius: var(--ds-radius);
  background: #0b0e14; color: #cdd6e4; font-family: var(--ds-mono);
  font-size: 12.5px; line-height: 1.55; white-space: pre-wrap; word-break: break-all;
  max-height: 520px; overflow: auto; border: 1px solid var(--ds-border);
}
</style>
