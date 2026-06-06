<template>
  <div class="venus-app">
    <div class="venus-head">
      <div class="venus-brand">
        <span class="venus-orb"></span>
        <span class="venus-title">VenusWRT</span>
      </div>
      <el-button :loading="loading" size="small" @click="refresh">Обновить</el-button>
    </div>

    <el-tabs v-model="tab">
      <!-- ───────────────── Обзор ───────────────── -->
      <el-tab-pane label="Обзор" name="overview">
        <el-row :gutter="16">
          <el-col :xs="12" :sm="6">
            <div class="vcard" :class="st.enabled ? 'ok' : 'off'">
              <div class="vcard-k">Туннель</div>
              <div class="vcard-v">{{ st.enabled ? 'Включён' : 'Выключен' }}</div>
              <div class="vcard-s">{{ st.link_up ? 'линк есть' : 'нет линка' }}</div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="vcard" :class="st.healthy ? 'ok' : 'warn'">
              <div class="vcard-k">Здоровье</div>
              <div class="vcard-v">{{ st.healthy ? 'OK' : 'Проблема' }}</div>
              <div class="vcard-s">ошибок: {{ st.fail ?? 0 }}</div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="vcard" :class="st.zap_running ? 'ok' : 'off'">
              <div class="vcard-k">Zapret</div>
              <div class="vcard-v">{{ st.zap_running ? 'Работает' : 'Стоп' }}</div>
              <div class="vcard-s">{{ st.zap_enabled ? 'включён' : 'выключен' }}</div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="vcard">
              <div class="vcard-k">Система</div>
              <div class="vcard-v">{{ sys.mp ?? 0 }}% RAM</div>
              <div class="vcard-s">load {{ sys.load ?? '–' }} · up {{ uptime }}</div>
            </div>
          </el-col>
        </el-row>

        <el-row :gutter="16" style="margin-top:14px">
          <el-col :xs="12" :sm="6">
            <div class="vmini"><span>IPsum</span><b>{{ st.ipsum_c ?? 0 }}</b></div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="vmini"><span>RU guard</span><b>{{ st.ru_c ?? 0 }}</b></div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="vmini"><span>CPU</span><b>{{ sys.cpu ?? 0 }}%</b></div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="vmini"><span>Failover</span><b>{{ st.fo_enabled ? 'вкл' : 'выкл' }}</b></div>
          </el-col>
        </el-row>

        <div class="venus-actions">
          <el-button v-if="!st.enabled" type="primary" :loading="busy" @click="act('enable')">Включить</el-button>
          <el-button v-else type="warning" :loading="busy" @click="act('disable')">Выключить</el-button>
          <el-button :loading="busy" @click="act('apply')">Применить</el-button>
          <el-button :loading="busy" @click="act('start')">Старт</el-button>
          <el-button :loading="busy" @click="act('stop')">Стоп</el-button>
          <el-button :loading="busy" @click="act('watchdog')">Watchdog</el-button>
          <el-button :loading="busy" @click="act('failover')">Сменить пир</el-button>
          <el-button :loading="busy" @click="act('zapret-restart')">Перезапуск Zapret</el-button>
        </div>
      </el-tab-pane>

      <!-- ───────────────── Списки ───────────────── -->
      <el-tab-pane label="Списки" name="lists">
        <el-table :data="rows" size="large" style="width:100%">
          <el-table-column prop="name" label="Источник"/>
          <el-table-column prop="enabled" label="Статус">
            <template #default="s">
              <el-tag :type="s.row.enabled ? 'success' : 'info'" size="small">
                {{ s.row.enabled ? 'вкл' : 'выкл' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="count" label="Записей"/>
          <el-table-column prop="mtime" label="Обновлено"/>
        </el-table>
        <div class="venus-actions">
          <el-button type="primary" :loading="busy" @click="update('all')">Обновить все</el-button>
          <el-button :loading="busy" @click="update('ipsum')">IPsum</el-button>
          <el-button :loading="busy" @click="update('ru')">RU</el-button>
          <el-button :loading="busy" @click="update('community')">Community</el-button>
        </div>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script>
export default {
  data() {
    return {
      tab: 'overview',
      loading: false,
      busy: false,
      st: {},
      lists: {}
    }
  },
  computed: {
    sys() {
      return this.st.system || {}
    },
    uptime() {
      const s = Number(this.sys.up || 0)
      if (!s) return '–'
      const d = Math.floor(s / 86400)
      const h = Math.floor((s % 86400) / 3600)
      return d > 0 ? `${d}д ${h}ч` : `${h}ч`
    },
    rows() {
      const l = this.lists || {}
      return [
        { name: 'IPsum', enabled: l.ipsum_en, count: l.ipsum_count ?? 0, mtime: l.ipsum_mtime || '–' },
        { name: 'RU guard', enabled: l.ru_en, count: l.ru_count ?? 0, mtime: l.ru_mtime || '–' }
      ]
    }
  },
  created() {
    this.refresh()
  },
  methods: {
    async refresh() {
      this.loading = true
      try {
        this.st = await this.$oui.call('venus', 'status') || {}
        this.lists = await this.$oui.call('venus', 'lists') || {}
      } catch (e) {
        this.$message.error('Не удалось получить статус Venus')
      }
      this.loading = false
    },
    async act(cmd) {
      this.busy = true
      try {
        const r = await this.$oui.call('venus', 'action', { cmd })
        if (r && r.ok !== false) this.$message.success('Готово: ' + cmd)
        else this.$message.warning((r && r.msg) || 'Ошибка')
      } catch (e) {
        this.$message.error('Ошибка выполнения')
      }
      this.busy = false
      await this.refresh()
    },
    async update(arg) {
      this.busy = true
      try {
        const r = await this.$oui.call('venus', 'action', { cmd: 'update', arg })
        if (r && r.ok !== false) this.$message.success((r && r.msg) || 'Списки обновлены')
        else this.$message.warning((r && r.msg) || 'Ошибка обновления')
      } catch (e) {
        this.$message.error('Ошибка обновления')
      }
      this.busy = false
      await this.refresh()
    }
  }
}
</script>

<style scoped>
.venus-app { padding: 4px 2px; }
.venus-head { display:flex; align-items:center; justify-content:space-between; margin-bottom:12px; }
.venus-brand { display:flex; align-items:center; gap:10px; }
.venus-orb {
  width:18px; height:18px; border-radius:50%;
  background: radial-gradient(circle at 35% 30%, #38bdf8 0%, #0ea5e9 45%, #b91c1c 110%);
  box-shadow: 0 0 10px rgba(14,165,233,.5);
}
.venus-title { font-weight:700; font-size:18px; letter-spacing:.3px; }
.vcard {
  border-radius:12px; padding:14px 16px; background:var(--el-fill-color-light);
  border-left:4px solid #0ea5e9; min-height:84px;
}
.vcard.ok   { border-left-color:#0ea5e9; }
.vcard.off  { border-left-color:#94a3b8; }
.vcard.warn { border-left-color:#ef4444; }
.vcard-k { font-size:12px; color:var(--el-text-color-secondary); text-transform:uppercase; letter-spacing:.5px; }
.vcard-v { font-size:22px; font-weight:700; margin-top:2px; }
.vcard-s { font-size:12px; color:var(--el-text-color-secondary); margin-top:2px; }
.vmini {
  display:flex; align-items:center; justify-content:space-between;
  padding:10px 14px; border-radius:10px; background:var(--el-fill-color-lighter);
}
.vmini b { font-size:18px; }
.venus-actions { margin-top:18px; display:flex; flex-wrap:wrap; gap:8px; }
</style>
