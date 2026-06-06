<template>
  <div class="ns-app">
    <div class="ns-head">
      <div class="ns-brand">
        <span class="ns-dot" :class="{ live: st.running }"></span>
        <span class="ns-title">NetShift</span>
        <el-tag :type="st.running ? 'success' : 'info'" size="small" effect="dark">
          {{ st.running ? 'sing-box работает' : 'остановлен' }}
        </el-tag>
      </div>
      <el-button :loading="loading" size="small" @click="refresh">Обновить</el-button>
    </div>

    <el-row :gutter="16">
      <el-col :xs="12" :sm="8">
        <div class="ns-card"><div class="ns-k">Автозапуск</div><div class="ns-v">{{ st.enabled ? 'вкл' : 'выкл' }}</div></div>
      </el-col>
      <el-col :xs="12" :sm="8">
        <div class="ns-card"><div class="ns-k">Тип</div><div class="ns-v">{{ st.connection_type || '–' }}/{{ st.proxy_config_type || '–' }}</div></div>
      </el-col>
      <el-col :xs="24" :sm="8">
        <div class="ns-card"><div class="ns-k">Списки</div><div class="ns-v ns-sm">{{ (st.community_lists || []).join(', ') || '—' }}</div></div>
      </el-col>
    </el-row>

    <el-form label-position="top" style="margin-top:16px">
      <el-form-item label="Прокси (vless:// · ss:// · подписка URL)">
        <el-input v-model="proxy" type="textarea" :rows="2" placeholder="vless://… или ссылка на подписку"/>
      </el-form-item>
      <el-button type="primary" :loading="busy" @click="saveProxy">Сохранить и применить</el-button>
    </el-form>

    <div class="ns-actions">
      <el-button v-if="!st.enabled" type="primary" :loading="busy" @click="act('enable')">Включить автозапуск</el-button>
      <el-button v-else :loading="busy" @click="act('disable')">Выключить автозапуск</el-button>
      <el-button :loading="busy" @click="act('start')">Старт</el-button>
      <el-button :loading="busy" @click="act('stop')">Стоп</el-button>
      <el-button :loading="busy" @click="act('restart')">Рестарт</el-button>
      <el-button :loading="busy" @click="act('reload')">Reload</el-button>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return { loading: false, busy: false, st: {}, proxy: '' }
  },
  created() {
    this.refresh()
  },
  methods: {
    async refresh() {
      this.loading = true
      try {
        this.st = await this.$oui.call('netshift', 'status') || {}
        this.proxy = this.st.proxy_string || ''
      } catch (e) {
        this.$message.error('Не удалось получить статус NetShift')
      }
      this.loading = false
    },
    async act(cmd) {
      this.busy = true
      try {
        const r = await this.$oui.call('netshift', 'action', { cmd })
        if (r && r.ok !== false) this.$message.success('Готово: ' + cmd)
        else this.$message.warning((r && r.msg) || 'Ошибка')
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false
      await this.refresh()
    },
    async saveProxy() {
      this.busy = true
      try {
        const r = await this.$oui.call('netshift', 'set_proxy', { proxy_string: this.proxy })
        if (r && r.ok) this.$message.success('Прокси сохранён и применён')
        else this.$message.warning((r && r.msg) || 'Ошибка')
      } catch (e) { this.$message.error('Ошибка сохранения') }
      this.busy = false
      await this.refresh()
    }
  }
}
</script>

<style scoped>
.ns-app { padding: 4px 2px; }
.ns-head { display:flex; align-items:center; justify-content:space-between; margin-bottom:14px; }
.ns-brand { display:flex; align-items:center; gap:10px; }
.ns-dot { width:12px; height:12px; border-radius:50%; background:#94a3b8; }
.ns-dot.live { background:#0ea5e9; box-shadow:0 0 8px #0ea5e9; }
.ns-title { font-weight:700; font-size:18px; }
.ns-card { border-radius:12px; padding:14px 16px; background:var(--el-fill-color-light); border-left:4px solid #0ea5e9; min-height:64px; }
.ns-k { font-size:12px; color:var(--el-text-color-secondary); text-transform:uppercase; letter-spacing:.5px; }
.ns-v { font-size:20px; font-weight:700; margin-top:2px; }
.ns-v.ns-sm { font-size:14px; font-weight:500; }
.ns-actions { margin-top:8px; display:flex; flex-wrap:wrap; gap:8px; }
</style>
