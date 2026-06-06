<!--
  NetShift — sing-box domain/subnet routing engine (de-branded podkop).
  Full control surface on the OUI design system: overview, connection (proxy /
  vpn / block / exclusion + lists), DNS, network/settings, and a paginated log.
  Backed by the netshift.lua RPC over the `netshift` UCI config.
-->
<template>
  <div class="ds-page">
    <oui-section title="NetShift" subtitle="Маршрутизация по доменам/подсетям через sing-box">
      <oui-badge :tone="st.running ? 'ok' : 'muted'" dot>{{ st.running ? 'sing-box работает' : 'остановлен' }}</oui-badge>
      <el-button :loading="loading" @click="loadAll">Обновить</el-button>
      <el-button type="primary" :loading="busy" @click="act('restart')">Перезапустить</el-button>
    </oui-section>

    <el-tabs v-model="tab" class="ns-tabs">
      <!-- Обзор -->
      <el-tab-pane label="Обзор" name="overview">
        <div class="ds-stack">
          <div class="ds-grid">
            <oui-stat label="sing-box" :tone="st.running ? 'ok':'muted'" :value="st.running ? 'работает':'стоп'" :hint="st.singbox_pid ? ('pid ' + st.singbox_pid) : 'не запущен'" />
            <oui-stat label="Автозапуск" :tone="st.enabled ? 'ok':'muted'" :value="st.enabled ? 'вкл':'выкл'" />
            <oui-stat label="Режим" tone="accent" :value="connLabel(st.connection_type)" :hint="st.proxy_config_type" />
            <oui-stat label="Списки" :value="(mainList('community_lists')).length" hint="наборов сообщества" />
          </div>
          <oui-card title="Управление службой">
            <div class="ds-row">
              <el-button type="primary" :loading="busy" @click="act('start')">Старт</el-button>
              <el-button :loading="busy" @click="act('stop')">Стоп</el-button>
              <el-button :loading="busy" @click="act('restart')">Перезапуск</el-button>
              <el-button :loading="busy" @click="act('reload')">Перечитать</el-button>
              <el-divider direction="vertical" />
              <el-button :loading="busy" @click="act(st.enabled ? 'disable':'enable')">{{ st.enabled ? 'Убрать из автозапуска' : 'В автозапуск' }}</el-button>
            </div>
          </oui-card>
        </div>
      </el-tab-pane>

      <!-- Подключение -->
      <el-tab-pane label="Подключение" name="connection">
        <oui-card title="Выходное соединение">
          <oui-field label="Тип" hint="Куда направлять трафик выбранных доменов/подсетей">
            <el-select :model-value="main.connection_type || 'proxy'" @change="v => set('main','connection_type',v)" style="width:240px">
              <el-option label="Прокси (sing-box outbound)" value="proxy" />
              <el-option label="VPN-интерфейс" value="vpn" />
              <el-option label="Блокировать" value="block" />
              <el-option label="Исключение (прямой)" value="exclusion" />
            </el-select>
          </oui-field>

          <template v-if="(main.connection_type||'proxy') === 'proxy'">
            <oui-field label="Формат">
              <el-select :model-value="main.proxy_config_type || 'url'" @change="v => set('main','proxy_config_type',v)" style="width:240px">
                <el-option label="URL (vless:// ss:// …)" value="url" />
                <el-option label="Подписка" value="subscription" />
                <el-option label="Outbound JSON" value="outbound" />
                <el-option label="Selector" value="selector" />
                <el-option label="URLTest" value="urltest" />
              </el-select>
            </oui-field>
            <oui-field :label="(main.proxy_config_type==='subscription') ? 'URL подписки' : 'Строка / JSON'">
              <el-input v-model="proxyString" type="textarea" :rows="3" placeholder="vless://… | ss://… | https://sub.example/api" @change="set('main','proxy_string', proxyString)" />
            </oui-field>
          </template>

          <oui-field label="VPN-интерфейс" v-if="main.connection_type === 'vpn'">
            <el-input :model-value="main.vpn_interface || ''" placeholder="awg0 / wg0" @change="v => set('main','vpn_interface',v)" style="width:240px" />
          </oui-field>
        </oui-card>

        <oui-card title="Что заворачивать" subtitle="Наборы сообщества + ваши домены и подсети">
          <oui-field label="Наборы сообщества">
            <el-select :model-value="mainList('community_lists')" multiple filterable allow-create
              @change="v => setList('main','community_lists',v)" style="width:100%"
              placeholder="russia_inside, …">
              <el-option v-for="o in communitySuggest" :key="o" :label="o" :value="o" />
            </el-select>
          </oui-field>
          <oui-field label="Свои домены" hint="example.com — заворачиваются в выбранный выход">
            <el-select :model-value="mainList('user_domains')" multiple filterable allow-create
              @change="v => setList('main','user_domains',v)" style="width:100%" placeholder="добавьте домены" no-data-text="введите и Enter" />
          </oui-field>
          <oui-field label="Свои подсети" hint="1.2.3.0/24">
            <el-select :model-value="mainList('user_subnets')" multiple filterable allow-create
              @change="v => setList('main','user_subnets',v)" style="width:100%" placeholder="добавьте подсети" no-data-text="введите и Enter" />
          </oui-field>
        </oui-card>
      </el-tab-pane>

      <!-- DNS -->
      <el-tab-pane label="DNS" name="dns">
        <oui-card title="DNS" subtitle="Резолвер для маршрутизируемого трафика">
          <oui-field label="Тип">
            <el-select :model-value="settings.dns_type || 'udp'" @change="v => set('settings','dns_type',v)" style="width:200px">
              <el-option v-for="t in ['udp','tcp','dot','doh','https']" :key="t" :label="t.toUpperCase()" :value="t" />
            </el-select>
          </oui-field>
          <oui-field label="Сервер"><el-input :model-value="settings.dns_server || ''" @change="v => set('settings','dns_server',v)" style="width:280px" placeholder="77.88.8.8" /></oui-field>
          <oui-field label="Bootstrap DNS"><el-input :model-value="settings.bootstrap_dns_server || ''" @change="v => set('settings','bootstrap_dns_server',v)" style="width:280px" /></oui-field>
          <oui-toggle :model-value="settings.disable_quic === '1'" title="Блокировать QUIC (HTTP/3)"
            description="Заставляет браузеры падать на TCP — стабильнее с прокси." @change="v => set('settings','disable_quic', v ? '1':'0')" />
        </oui-card>
      </el-tab-pane>

      <!-- Сеть / Настройки -->
      <el-tab-pane label="Настройки" name="settings">
        <oui-card title="Сеть и поведение">
          <oui-field label="LAN-интерфейсы" hint="Откуда брать клиентов">
            <el-select :model-value="settingsList('source_network_interfaces')" multiple filterable allow-create
              @change="v => setList('settings','source_network_interfaces',v)" style="width:320px" placeholder="br-lan" />
          </oui-field>
          <oui-field label="Интервал обновления списков">
            <el-input :model-value="settings.update_interval || '1d'" @change="v => set('settings','update_interval',v)" style="width:160px" placeholder="1d" />
          </oui-field>
          <oui-field label="Уровень логирования">
            <el-select :model-value="settings.log_level || 'warn'" @change="v => set('settings','log_level',v)" style="width:160px">
              <el-option v-for="l in ['trace','debug','info','warn','error']" :key="l" :label="l" :value="l" />
            </el-select>
          </oui-field>
          <oui-toggle :model-value="settings.enable_yacd === '1'" title="Веб-панель Yacd (Clash dashboard)" @change="v => set('settings','enable_yacd', v ? '1':'0')" />
          <oui-toggle :model-value="settings.dont_touch_dhcp === '1'" title="Не трогать DHCP" @change="v => set('settings','dont_touch_dhcp', v ? '1':'0')" />
        </oui-card>
      </el-tab-pane>

      <!-- Журнал -->
      <el-tab-pane label="Журнал" name="logs">
        <oui-card title="Журнал sing-box" flush>
          <template #actions><el-button size="small" @click="loadLogs">Обновить</el-button></template>
          <oui-paginated-list :items="logRows" :columns="logCols" :page-size="50"
            search-placeholder="Фильтр журнала…" empty-message="Журнал пуст" />
        </oui-card>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script>
export default {
  data() {
    return {
      tab: 'overview',
      loading: false, busy: false,
      st: {}, cfg: {},
      proxyString: '',
      communitySuggest: ['russia_inside', 'russia_outside', 'ukraine_inside', 'geoblock', 'block_download', 'porn', 'news', 'anti_porn'],
      logRows: [], logCols: [{ prop: 'line', label: 'Событие', mono: true }]
    }
  },
  computed: {
    settings() { return this.cfg.settings || {} },
    main() { return this.cfg.main || {} }
  },
  created() { this.loadAll() },
  methods: {
    connLabel(t) { return ({ proxy: 'Прокси', vpn: 'VPN', block: 'Блок', exclusion: 'Исключение' })[t] || t || '—' },
    asArr(v) { return Array.isArray(v) ? v : (v ? [v] : []) },
    mainList(opt) { return this.asArr(this.main[opt]) },
    settingsList(opt) { return this.asArr(this.settings[opt]) },
    get proxyPlaceholder() { return '' },
    async loadAll() {
      this.loading = true
      try {
        const [st, cfg] = await Promise.all([
          this.$oui.call('netshift', 'status'),
          this.$oui.call('netshift', 'config')
        ])
        this.st = st || {}; this.cfg = cfg || {}
        this.proxyString = this.main.proxy_string || ''
        this.loadLogs()
      } catch (e) { this.$message.error('Не удалось загрузить NetShift') }
      this.loading = false
    },
    async loadLogs() {
      try {
        const arr = await this.$oui.call('netshift', 'logs') || []
        this.logRows = (Array.isArray(arr) ? arr : []).map(line => ({ line }))
      } catch (e) { this.logRows = [] }
    },
    async act(cmd) {
      this.busy = true
      try {
        const r = await this.$oui.call('netshift', 'action', { cmd })
        this.$message[(r && r.ok !== false) ? 'success' : 'warning']((r && r.msg) || ('Готово: ' + cmd))
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false; await this.loadAll()
    },
    async set(section, option, value) {
      try {
        const r = await this.$oui.call('netshift', 'set', { section, option, value })
        if (r && r.ok === false) { this.$message.warning(r.msg || 'Ошибка'); return }
        this.$message.success('Сохранено')
      } catch (e) { this.$message.error('Ошибка сохранения') }
      await this.loadAll()
    },
    async setList(section, option, items) {
      try {
        await this.$oui.call('netshift', 'set_list', { section, option, items })
        this.$message.success('Сохранено')
      } catch (e) { this.$message.error('Ошибка сохранения') }
      await this.loadAll()
    }
  }
}
</script>

<style scoped>
.ns-tabs :deep(.el-tabs__item) { font-weight: 540; }
</style>
