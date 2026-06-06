<!--
  Venus — full control surface for the split-router / DPI-bypass engine.
  Tabs mirror the LuCI fe-app-venus sections, rebuilt on the OUI design system.
  All data comes from the `venus` CLI via the venus.lua RPC module.
-->
<template>
  <div class="ds-page">
    <oui-section title="Venus" :subtitle="headSub">
      <oui-badge :tone="st.enabled ? (st.vpn_link_up ? 'ok' : 'warn') : 'muted'" dot>
        {{ st.enabled ? (st.vpn_link_up ? 'Активен' : 'Нет линка') : 'Выключен' }}
      </oui-badge>
      <el-button :loading="loading" @click="refreshAll">Обновить</el-button>
      <el-button v-if="!st.enabled" type="primary" :loading="busy" @click="act('enable')">Включить</el-button>
      <el-button v-else type="warning" :loading="busy" @click="act('disable')">Выключить</el-button>
    </oui-section>

    <el-tabs v-model="tab" class="venus-tabs">
      <!-- ─────────────── Обзор ─────────────── -->
      <el-tab-pane label="Обзор" name="overview">
        <div class="ds-stack">
          <div class="ds-grid">
            <oui-stat label="Туннель" :tone="st.enabled ? 'accent' : 'muted'"
              :value="st.enabled ? 'Включён' : 'Выключен'"
              :hint="(st.vpn_iface || '–') + ' · ' + (st.vpn_link_up ? 'линк есть' : 'нет линка')" />
            <oui-stat label="Здоровье" :tone="health.healthy ? 'ok' : 'warn'"
              :value="health.healthy ? 'OK' : 'Проблема'"
              :hint="(health.method || 'ping') + ' · ошибок: ' + (st.fail_count ?? 0)" />
            <oui-stat label="Zapret" :tone="zapret.running ? 'ok' : 'muted'"
              :value="zapret.running ? 'Работает' : 'Стоп'"
              :hint="zapret.enabled ? 'включён' : 'выключен'" />
            <oui-stat label="Система" tone="muted"
              :value="(sys.mem_pct ?? 0) + '% RAM'"
              :hint="'load ' + (sys.load1 ?? '–') + ' · up ' + uptime" />
          </div>

          <div class="ds-grid">
            <oui-stat label="IPsum" :value="sets.ipsum?.count ?? 0" hint="адресов в наборе обхода" />
            <oui-stat label="RU guard" :value="sets.ru?.count ?? 0" hint="доменных диапазонов РФ" />
            <oui-stat label="CPU" :value="(sys.cpu_pct ?? 0) + '%'" :hint="'load ' + (sys.load1 ?? '–')" />
            <oui-stat label="Failover" :tone="failover.enabled ? 'accent' : 'muted'"
              :value="failover.enabled ? 'Включён' : 'Выключен'"
              :hint="(failover.primary || '–') + ' → ' + (failover.backup || '–')" />
          </div>

          <oui-card title="Проверка связи" subtitle="Цели health-проверки через туннель">
            <div class="ds-row">
              <oui-badge v-for="t in (health.targets || [])" :key="t.target"
                :tone="t.ok ? 'ok' : 'err'" dot>{{ t.target }}</oui-badge>
              <span v-if="!(health.targets || []).length" class="ds-muted">нет данных</span>
            </div>
          </oui-card>

          <oui-card title="Действия">
            <div class="ds-row">
              <el-button :loading="busy" @click="act('apply')">Применить</el-button>
              <el-button :loading="busy" @click="act('start')">Старт</el-button>
              <el-button :loading="busy" @click="act('stop')">Стоп</el-button>
              <el-button :loading="busy" @click="act('watchdog')">Watchdog</el-button>
              <el-button :loading="busy" @click="act('failover')">Сменить пир</el-button>
              <el-button :loading="busy" @click="act('zapret-restart')">Перезапуск Zapret</el-button>
            </div>
          </oui-card>
        </div>
      </el-tab-pane>

      <!-- ─────────────── Обход блокировок ─────────────── -->
      <el-tab-pane label="Обход блокировок" name="zapret">
        <div class="ds-stack">
          <oui-card>
            <oui-toggle :model-value="!!cfg.zapret?.enabled" title="Обход DPI (zapret)"
              description="Обходит блокировки на уровне DPI без VPN-туннеля."
              :loading="busy" @change="v => setCfg('zapret','enabled', v ? '1':'0')" />
            <oui-field label="Стратегия" hint="Параметры zapret (задаются Zapret-Manager'ом)">
              <el-input v-model="zapretStrategy" placeholder="по умолчанию" @change="setCfg('zapret','strategy', zapretStrategy)" />
            </oui-field>
            <div class="ds-row" style="margin-top:12px">
              <el-button type="primary" @click="openZapretManager">Открыть Zapret-Manager</el-button>
              <el-button :loading="busy" @click="act('zapret-restart')">Перезапустить</el-button>
            </div>
          </oui-card>

          <oui-card title="Автоподбор стратегии обхода"
            subtitle="Прогоняет набор стратегий и показывает, какие пробивают блокировки">
            <template #actions>
              <el-button v-if="!ztest.running" type="primary" :loading="busy" @click="zapretTest('start')">Запустить тест</el-button>
              <el-button v-else type="danger" @click="zapretTest('stop')">Остановить</el-button>
            </template>
            <div v-if="ztest.running || ztest.done_strategies" class="ztest">
              <el-progress :percentage="ztestPct" :status="ztest.running ? '' : 'success'" />
              <p class="ds-sub">
                {{ ztest.current?.name || 'Готово' }}
                <span v-if="ztest.current?.total"> · {{ ztest.current.checked }}/{{ ztest.current.total }} (ok {{ ztest.current.ok }})</span>
                · стратегий {{ ztest.done_strategies }}/{{ ztest.total_strategies }}
              </p>
              <el-alert v-if="ztest.error" :title="ztest.error" type="error" :closable="false" />
              <el-table v-if="(ztest.results || []).length" :data="ztest.results" size="small" max-height="300">
                <el-table-column prop="name" label="Стратегия" min-width="180" />
                <el-table-column label="Результат" width="120">
                  <template #default="s"><oui-badge :tone="s.row.ok ? 'ok':'err'">{{ s.row.ok ? 'пробивает':'нет' }}</oui-badge></template>
                </el-table-column>
                <el-table-column prop="checked" label="Проверено" width="110" />
              </el-table>
            </div>
            <oui-state v-else type="empty" message="Тест ещё не запускался" />
          </oui-card>
        </div>
      </el-tab-pane>

      <!-- ─────────────── Подключения ─────────────── -->
      <el-tab-pane label="Подключения" name="connections">
        <oui-card title="Туннели" subtitle="WireGuard / AmneziaWG / прокси-выходы">
          <template #actions>
            <el-button type="primary" @click="openTunnel()">Добавить</el-button>
          </template>
          <el-table :data="cfg.tunnels || []" size="small">
            <el-table-column label="" width="40">
              <template #default="s"><oui-badge :tone="s.row.enabled ? 'ok':'muted'" dot /></template>
            </el-table-column>
            <el-table-column prop="name" label="Имя" min-width="100" />
            <el-table-column prop="proto" label="Протокол" width="110" />
            <el-table-column prop="endpoint" label="Endpoint" min-width="180">
              <template #default="s"><span class="ds-mono">{{ s.row.endpoint || '—' }}</span></template>
            </el-table-column>
            <el-table-column label="Активный" width="100">
              <template #default="s">
                <oui-badge v-if="s.row.name === cfg.config?.vpn_iface" tone="accent">основной</oui-badge>
              </template>
            </el-table-column>
            <el-table-column label="" width="180" align="right">
              <template #default="s">
                <el-button size="small" @click="setCfg('config','vpn_iface', s.row.name)" :disabled="s.row.name === cfg.config?.vpn_iface">Сделать основным</el-button>
                <el-button size="small" @click="openTunnel(s.row)"><el-icon><Edit/></el-icon></el-button>
                <el-button size="small" type="danger" @click="delTunnel(s.row.name)"><el-icon><Delete/></el-icon></el-button>
              </template>
            </el-table-column>
          </el-table>
          <oui-state v-if="!(cfg.tunnels || []).length" type="empty" message="Туннелей пока нет" />
        </oui-card>
      </el-tab-pane>

      <!-- ─────────────── Что куда направлять ─────────────── -->
      <el-tab-pane label="Что куда направлять" name="profiles">
        <oui-card title="Профили маршрутизации" subtitle="«Эти адреса/домены — туда»">
          <template #actions>
            <el-button type="primary" @click="openProfile()">Добавить профиль</el-button>
          </template>
          <el-table :data="cfg.profiles || []" size="small">
            <el-table-column label="" width="40">
              <template #default="s"><oui-badge :tone="s.row.enabled ? 'ok':'muted'" dot /></template>
            </el-table-column>
            <el-table-column prop="label" label="Профиль" min-width="140" />
            <el-table-column label="Назначение" width="140">
              <template #default="s">
                <oui-badge :tone="destTone(s.row.dest)">{{ destLabel(s.row.dest) }}{{ s.row.dest==='tunnel' && s.row.tunnel ? ' · '+s.row.tunnel : '' }}</oui-badge>
              </template>
            </el-table-column>
            <el-table-column label="Адресов" width="90">
              <template #default="s">{{ (s.row.ips||[]).length }}</template>
            </el-table-column>
            <el-table-column label="Доменов" width="90">
              <template #default="s">{{ (s.row.domains||[]).length }}</template>
            </el-table-column>
            <el-table-column prop="count" label="В наборе" width="90" />
            <el-table-column label="" width="160" align="right">
              <template #default="s">
                <el-button size="small" @click="setCfg(s.row.id,'enabled', s.row.enabled ? '0':'1')">{{ s.row.enabled ? 'Выкл':'Вкл' }}</el-button>
                <el-button size="small" @click="openProfile(s.row)"><el-icon><Edit/></el-icon></el-button>
                <el-button size="small" type="danger" @click="delProfile(s.row.id)"><el-icon><Delete/></el-icon></el-button>
              </template>
            </el-table-column>
          </el-table>
          <oui-state v-if="!(cfg.profiles || []).length" type="empty" message="Профилей пока нет" />
        </oui-card>
      </el-tab-pane>

      <!-- ─────────────── Частный DNS ─────────────── -->
      <el-tab-pane label="Частный DNS" name="dns">
        <oui-card title="Шифрованный DNS (DoH)"
          subtitle="Запросы DNS уходят по HTTPS — провайдер их не видит и не подменяет">
          <oui-toggle :model-value="!!cfg.doh?.enabled" title="Включить DoH" :loading="busy"
            @change="v => setCfg('doh','enabled', v ? '1':'0')" />
          <oui-field label="Провайдер">
            <el-select :model-value="cfg.doh?.provider || 'cloudflare'" @change="v => setCfg('doh','provider', v)" style="width:240px">
              <el-option label="Cloudflare" value="cloudflare" />
              <el-option label="Google" value="google" />
              <el-option label="Quad9" value="quad9" />
              <el-option label="Свой URL" value="custom" />
            </el-select>
          </oui-field>
          <oui-field v-if="cfg.doh?.provider === 'custom'" label="URL резолвера">
            <el-input v-model="dohCustom" placeholder="https://dns.example/dns-query" @change="setCfg('doh','custom_url', dohCustom)" />
          </oui-field>
        </oui-card>
      </el-tab-pane>

      <!-- ─────────────── Запасной канал ─────────────── -->
      <el-tab-pane label="Запасной канал" name="failover">
        <oui-card title="Резервный пир (failover)"
          subtitle="Автопереключение на запасной туннель при сбоях основного">
          <oui-toggle :model-value="!!cfg.failover?.enabled" title="Включить failover" :loading="busy"
            @change="v => setCfg('failover','enabled', v ? '1':'0')" />
          <oui-field label="Основной интерфейс">
            <el-input :model-value="cfg.failover?.primary_iface" @change="v => setCfg('failover','primary_iface', v)" style="width:200px" />
          </oui-field>
          <oui-field label="Запасной интерфейс">
            <el-input :model-value="cfg.failover?.backup_iface" @change="v => setCfg('failover','backup_iface', v)" style="width:200px" />
          </oui-field>
          <oui-field label="Порог сбоев" hint="Сколько неудачных проверок до переключения">
            <el-input-number :model-value="Number(cfg.failover?.threshold || 3)" :min="1" :max="20" @change="v => setCfg('failover','threshold', String(v))" />
          </oui-field>
          <oui-toggle :model-value="!!cfg.failover?.killswitch" title="Killswitch"
            description="Блокировать трафик туннеля при его падении (иначе уходит через WAN)."
            :loading="busy" @change="v => setCfg('failover','killswitch', v ? '1':'0')" />
        </oui-card>
      </el-tab-pane>

      <!-- ─────────────── Списки сайтов ─────────────── -->
      <el-tab-pane label="Списки сайтов" name="lists">
        <div class="ds-stack">
          <oui-card title="Дома лучше — обход российских ресурсов"
            subtitle="Российские IP/домены идут напрямую через провайдера, мимо VPN">
            <oui-toggle :model-value="ruEnabled" title="Режим «Дома лучше» (RU-guard)" :loading="busy"
              @change="v => setCfg('ru','enabled', v ? '1':'0')" />
            <oui-toggle :model-value="!!cfg.lists?.ru?.force_wan" title="Принудительный WAN для РФ"
              description="Жёсткое правило: домашний трафик никогда не уходит в туннель."
              :loading="busy" @change="v => setCfg('ru','force_wan', v ? '1':'0')" />
          </oui-card>

          <oui-card title="Источники списков" flush>
            <el-table :data="rows" size="small">
              <el-table-column label="Список" min-width="180">
                <template #default="s">
                  <div>{{ niceName(s.row.id) }}</div>
                  <div class="ds-mono ds-faint" style="font-size:11px">{{ s.row.file || '' }}</div>
                </template>
              </el-table-column>
              <el-table-column prop="count" label="Записей" width="100" />
              <el-table-column label="В наборе" width="100">
                <template #default="s">{{ s.row.set_count ?? s.row.count ?? 0 }}</template>
              </el-table-column>
              <el-table-column label="Обновлено" min-width="120">
                <template #default="s">{{ s.row.mtime || '—' }}</template>
              </el-table-column>
              <el-table-column label="Статус" width="90">
                <template #default="s"><oui-badge :tone="s.row.enabled ? 'ok':'muted'">{{ s.row.enabled ? 'вкл':'выкл' }}</oui-badge></template>
              </el-table-column>
              <el-table-column label="" width="110" align="right">
                <template #default="s"><el-button size="small" @click="openViewer(s.row)">Смотреть</el-button></template>
              </el-table-column>
            </el-table>
            <div style="padding:12px 16px">
              <div v-if="cron.length" class="ds-row" style="margin-bottom:12px">
                <span class="ds-label">Автообновление</span>
                <oui-badge v-for="c in cron" :key="c.job">{{ niceJob(c.job) }}: {{ c.schedule || 'выкл' }}</oui-badge>
              </div>
              <div class="ds-row">
                <el-button type="primary" :loading="busy" @click="update('all')">Обновить все</el-button>
                <el-button :loading="busy" @click="update('ipsum')">IPsum</el-button>
                <el-button :loading="busy" @click="update('ru')">RU</el-button>
                <el-button :loading="busy" @click="update('community')">Community</el-button>
              </div>
            </div>
          </oui-card>
        </div>
      </el-tab-pane>

      <!-- ─────────────── Диагностика ─────────────── -->
      <el-tab-pane label="Диагностика" name="diag">
        <div class="ds-stack">
          <oui-card title="Самопроверка">
            <template #actions><el-button :loading="busy" @click="loadDiag">Проверить</el-button></template>
            <div class="ds-stack">
              <div v-for="(f, i) in (diag.findings || [])" :key="i" class="finding">
                <oui-badge :tone="findTone(f.level)" dot>{{ findLabel(f.level) }}</oui-badge>
                <div>
                  <div class="finding-t">{{ f.title }}</div>
                  <div class="ds-sub">{{ f.detail }}</div>
                </div>
              </div>
              <oui-state v-if="!(diag.findings || []).length" type="empty" message="Нет данных" />
            </div>
          </oui-card>

          <oui-card title="Проверка сайта">
            <div class="ds-row">
              <el-input v-model="hostToCheck" placeholder="youtube.com" style="max-width:280px" @keyup.enter="checkHost" />
              <el-button type="primary" :loading="hostBusy" @click="checkHost">Проверить</el-button>
            </div>
            <div v-if="hostResult.host" class="ds-row" style="margin-top:12px">
              <oui-badge :tone="hostResult.ping_ok ? 'ok':'err'" dot>ping {{ hostResult.ping_time }}</oui-badge>
              <oui-badge :tone="hostResult.curl_ok ? 'ok':'err'" dot>https {{ hostResult.curl_time }}</oui-badge>
            </div>
          </oui-card>

          <oui-card title="Компоненты" subtitle="Опциональные пакеты — что включает каждый">
            <div v-for="c in (pkgs.components || [])" :key="c.id" class="comp">
              <div class="comp-i">
                <div class="comp-t">{{ c.title }} <span class="ds-faint">{{ c.size }}</span></div>
                <div class="ds-sub">{{ c.why }}</div>
              </div>
              <oui-badge v-if="c.installed" tone="ok">установлен</oui-badge>
              <el-button v-else size="small" type="primary" :loading="pkgBusy===c.id" @click="pkgInstall(c.id)">Установить</el-button>
            </div>
          </oui-card>

          <oui-card title="Журнал" flush>
            <oui-paginated-list :items="logRows" :columns="logCols" :page-size="40"
              search-placeholder="Фильтр журнала…" empty-message="Журнал пуст" />
          </oui-card>
        </div>
      </el-tab-pane>
    </el-tabs>

    <!-- Tunnel editor -->
    <el-dialog v-model="tunnelDlg" :title="tunnelForm.name ? 'Туннель: '+tunnelForm.name : 'Новый туннель'" width="560">
      <oui-field label="Имя" hint="Имя сетевого интерфейса (wg0, awg0…)">
        <el-input v-model="tunnelForm.name" :disabled="tunnelEditing" />
      </oui-field>
      <oui-field label="Протокол">
        <el-select v-model="tunnelForm.proto" style="width:200px">
          <el-option v-for="p in ['wireguard','amneziawg','vless','trojan','shadowsocks','hysteria2']" :key="p" :label="p" :value="p" />
        </el-select>
      </oui-field>
      <oui-field label="Endpoint"><el-input v-model="tunnelForm.endpoint" placeholder="host:port" /></oui-field>
      <oui-field label="Public key"><el-input v-model="tunnelForm.public_key" /></oui-field>
      <oui-field label="Private key"><el-input v-model="tunnelForm.private_key" show-password /></oui-field>
      <oui-field label="Addresses"><el-input v-model="tunnelForm.addresses" placeholder="10.0.0.2/32" /></oui-field>
      <oui-field label="MTU"><el-input v-model="tunnelForm.mtu" placeholder="1420" /></oui-field>
      <template #footer>
        <el-button @click="tunnelDlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="saveTunnel">Сохранить</el-button>
      </template>
    </el-dialog>

    <!-- Profile editor -->
    <el-dialog v-model="profileDlg" :title="profileForm.id && profileEditing ? 'Профиль: '+profileForm.label : 'Новый профиль'" width="560">
      <oui-field label="Идентификатор" hint="Латиницей, без пробелов"><el-input v-model="profileForm.id" :disabled="profileEditing" /></oui-field>
      <oui-field label="Название"><el-input v-model="profileForm.label" /></oui-field>
      <oui-field label="Назначение">
        <el-select v-model="profileForm.dest" style="width:200px">
          <el-option label="Через туннель" value="tunnel" />
          <el-option label="Напрямую (WAN)" value="direct" />
          <el-option label="Zapret" value="zapret" />
        </el-select>
      </oui-field>
      <oui-field v-if="profileForm.dest==='tunnel'" label="Туннель">
        <el-select v-model="profileForm.tunnel" style="width:200px">
          <el-option v-for="t in (cfg.tunnels||[])" :key="t.name" :label="t.name" :value="t.name" />
        </el-select>
      </oui-field>
      <el-alert v-if="profileEditing" title="Адреса и домены профиля редактируются после создания." type="info" :closable="false" />
      <template #footer>
        <el-button @click="profileDlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="saveProfile">Сохранить</el-button>
      </template>
    </el-dialog>

    <!-- Big-list viewer (paginated, server-windowed) -->
    <el-dialog v-model="viewerDlg" :title="'Список: ' + (viewerRow.id ? niceName(viewerRow.id) : '')" width="720">
      <oui-paginated-list v-if="viewerDlg" :loader="viewerLoader" :columns="viewerCols"
        :page-size="100" search-placeholder="Поиск по списку…" />
    </el-dialog>
  </div>
</template>

<script>
// Element Plus icon components (Refresh, Edit, …) are registered globally by
// oui-ui-core, so we use them by tag (<el-icon><Edit/></el-icon>) with no import
// and zero bundle cost.

const emptyTunnel = () => ({ name: '', proto: 'wireguard', endpoint: '', public_key: '', private_key: '', addresses: '', mtu: '' })
const emptyProfile = () => ({ id: '', label: '', dest: 'tunnel', tunnel: '' })

export default {
  data() {
    return {
      tab: 'overview',
      loading: false, busy: false,
      st: {}, lists: {}, cfg: {}, diag: {}, pkgs: {},
      zapretStrategy: '', dohCustom: '',
      // zapret autotest
      ztest: {}, ztestTimer: null,
      // diagnostics
      hostToCheck: 'youtube.com', hostResult: {}, hostBusy: false,
      pkgBusy: '',
      logRows: [], logCols: [{ prop: 'line', label: 'Событие', mono: true }],
      // dialogs
      tunnelDlg: false, tunnelEditing: false, tunnelForm: emptyTunnel(),
      profileDlg: false, profileEditing: false, profileForm: emptyProfile(),
      viewerDlg: false, viewerRow: {},
      viewerCols: [{ prop: 'line', label: 'Запись', mono: true }]
    }
  },
  computed: {
    sys() { return this.st.system || {} },
    health() { return this.st.health || {} },
    zapret() { return this.st.zapret || {} },
    failover() { return this.st.failover || {} },
    sets() { return this.st.sets || {} },
    rows() { return Array.isArray(this.lists.lists) ? this.lists.lists : [] },
    cron() { return Array.isArray(this.lists.cron) ? this.lists.cron : [] },
    ruEnabled() { const r = this.rows.find(l => l.id === 'ru'); return r ? !!r.enabled : !!this.cfg.lists?.ru?.enabled },
    headSub() { return 'fwmark split-routing · обход блокировок · ' + (this.st.vpn_iface || 'нет туннеля') },
    uptime() {
      const s = Number(this.sys.uptime_sec || 0)
      if (!s) return '–'
      const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600)
      return d > 0 ? `${d}д ${h}ч` : `${h}ч`
    },
    ztestPct() {
      const t = Number(this.ztest.total_strategies || 0)
      if (!t) return this.ztest.running ? 5 : 0
      return Math.min(100, Math.round((Number(this.ztest.done_strategies || 0) / t) * 100))
    }
  },
  created() { this.refreshAll() },
  beforeUnmount() { clearInterval(this.ztestTimer) },
  methods: {
    niceName(id) { return ({ ipsum: 'Реестр блокировок (IPsum)', ru: 'Сайты РФ (RU-guard)', community: 'Community' })[id] || id },
    niceJob(j) { return ({ 'update-ipsum': 'IPsum', 'update-ru': 'RU', watchdog: 'Проверка' })[j] || j },
    destTone(d) { return { tunnel: 'accent', zapret: 'warn', direct: 'muted' }[d] || 'muted' },
    destLabel(d) { return { tunnel: 'Туннель', zapret: 'Zapret', direct: 'Напрямую' }[d] || d },
    findTone(l) { return { ok: 'ok', info: 'accent', warn: 'warn', bad: 'err' }[l] || 'muted' },
    findLabel(l) { return { ok: 'OK', info: 'инфо', warn: 'важно', bad: 'проблема' }[l] || l },

    async refreshAll() {
      this.loading = true
      try {
        const [st, lists, cfg] = await Promise.all([
          this.$oui.call('venus', 'status'),
          this.$oui.call('venus', 'lists'),
          this.$oui.call('venus', 'config')
        ])
        this.st = st || {}; this.lists = lists || {}; this.cfg = cfg || {}
        this.zapretStrategy = this.cfg.zapret?.strategy || ''
        this.dohCustom = this.cfg.doh?.custom_url || ''
        this.loadDiag(); this.loadPkgs(); this.loadLogs()
      } catch (e) {
        this.$message.error('Не удалось получить данные Venus')
      }
      this.loading = false
    },
    async loadDiag() { try { this.diag = await this.$oui.call('venus', 'diagnose') || {} } catch (e) {} },
    async loadPkgs() { try { this.pkgs = await this.$oui.call('venus', 'pkg_status') || {} } catch (e) {} },
    async loadLogs() {
      try {
        const arr = await this.$oui.call('venus', 'logs') || []
        this.logRows = (Array.isArray(arr) ? arr : []).map(line => ({ line }))
      } catch (e) { this.logRows = [] }
    },

    async act(cmd) {
      this.busy = true
      try {
        const r = await this.$oui.call('venus', 'action', { cmd })
        if (r && r.ok !== false) this.$message.success('Готово: ' + cmd)
        else this.$message.warning((r && r.msg) || 'Ошибка')
      } catch (e) { this.$message.error('Ошибка выполнения') }
      this.busy = false
      await this.refreshAll()
    },
    async update(arg) {
      this.busy = true
      try {
        const r = await this.$oui.call('venus', 'action', { cmd: 'update', arg })
        this.$message[(r && r.ok !== false) ? 'success' : 'warning']((r && r.msg) || 'Готово')
      } catch (e) { this.$message.error('Ошибка обновления') }
      this.busy = false
      await this.refreshAll()
    },
    async setCfg(section, option, value, { apply = true } = {}) {
      this.busy = true
      try {
        const r = await this.$oui.call('venus', 'config_set', { section, option, value })
        if (r && r.ok === false) { this.$message.warning(r.msg || 'Ошибка'); return }
        if (apply) await this.$oui.call('venus', 'action', { cmd: 'apply' })
        this.$message.success('Сохранено')
      } catch (e) { this.$message.error('Ошибка сохранения') }
      this.busy = false
      await this.refreshAll()
    },

    openZapretManager() { this.$router.push('/terminal?run=zapret-manager') },

    // ── zapret autotest ──
    async zapretTest(sub) {
      try {
        const r = await this.$oui.call('venus', 'zapret_test', { sub })
        if (r && r.ok === false) { this.$message.warning(r.msg || 'Ошибка'); return }
        if (sub === 'start') { this.$message.success('Тест запущен'); this.pollZtest() }
        if (sub === 'stop') this.$message.info('Останавливаю…')
      } catch (e) { this.$message.error('Ошибка теста') }
    },
    pollZtest() {
      clearInterval(this.ztestTimer)
      const tick = async () => {
        try {
          this.ztest = await this.$oui.call('venus', 'zapret_test', { sub: 'progress' }) || {}
          if (!this.ztest.running) { clearInterval(this.ztestTimer); this.refreshAll() }
        } catch (e) { clearInterval(this.ztestTimer) }
      }
      tick(); this.ztestTimer = setInterval(tick, 2000)
    },

    // ── tunnels ──
    openTunnel(row) {
      this.tunnelEditing = !!row
      this.tunnelForm = row ? { ...emptyTunnel(), ...row } : emptyTunnel()
      this.tunnelDlg = true
    },
    async saveTunnel() {
      if (!this.tunnelForm.name) { this.$message.warning('Укажите имя'); return }
      this.busy = true
      try {
        await this.$oui.call('venus', 'config_add_tunnel', this.tunnelForm)
        await this.$oui.call('venus', 'action', { cmd: 'apply' })
        this.$message.success('Туннель сохранён'); this.tunnelDlg = false
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false
      await this.refreshAll()
    },
    async delTunnel(name) {
      try {
        await this.$confirm(`Удалить туннель ${name}?`, 'Подтверждение', { type: 'warning' })
      } catch (e) { return }
      await this.$oui.call('venus', 'config_del_tunnel', { name })
      await this.$oui.call('venus', 'action', { cmd: 'apply' })
      this.$message.success('Удалён'); await this.refreshAll()
    },

    // ── profiles ──
    openProfile(row) {
      this.profileEditing = !!row
      this.profileForm = row ? { ...emptyProfile(), ...row } : emptyProfile()
      this.profileDlg = true
    },
    async saveProfile() {
      if (!this.profileForm.id) { this.$message.warning('Укажите идентификатор'); return }
      this.busy = true
      try {
        if (this.profileEditing) {
          await this.$oui.call('venus', 'config_set', { section: this.profileForm.id, option: 'label', value: this.profileForm.label })
          await this.$oui.call('venus', 'config_set', { section: this.profileForm.id, option: 'dest', value: this.profileForm.dest })
          if (this.profileForm.dest === 'tunnel')
            await this.$oui.call('venus', 'config_set', { section: this.profileForm.id, option: 'tunnel', value: this.profileForm.tunnel })
        } else {
          await this.$oui.call('venus', 'config_add_profile', this.profileForm)
        }
        await this.$oui.call('venus', 'action', { cmd: 'apply' })
        this.$message.success('Профиль сохранён'); this.profileDlg = false
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false
      await this.refreshAll()
    },
    async delProfile(id) {
      try {
        await this.$confirm(`Удалить профиль ${id}?`, 'Подтверждение', { type: 'warning' })
      } catch (e) { return }
      await this.$oui.call('venus', 'config_del_profile', { id })
      await this.$oui.call('venus', 'action', { cmd: 'apply' })
      this.$message.success('Удалён'); await this.refreshAll()
    },

    // ── diagnostics ──
    async checkHost() {
      this.hostBusy = true
      try { this.hostResult = await this.$oui.call('venus', 'check_host', { host: this.hostToCheck }) || {} }
      catch (e) { this.$message.error('Ошибка проверки') }
      this.hostBusy = false
    },
    async pkgInstall(id) {
      this.pkgBusy = id
      try {
        const r = await this.$oui.call('venus', 'pkg_install', { id })
        this.$message[(r && r.ok !== false) ? 'success' : 'warning']((r && r.msg) || 'Готово')
      } catch (e) { this.$message.error('Ошибка установки') }
      this.pkgBusy = ''
      await this.loadPkgs()
    },

    // ── big-list viewer ──
    openViewer(row) { this.viewerRow = row; this.viewerDlg = true },
    async viewerLoader({ offset, limit, query }) {
      const r = await this.$oui.call('venus', 'view_list', { file: this.viewerRow.file, offset, limit }) || {}
      let rows = (r.rows || []).map(line => ({ line }))
      if (query) rows = rows.filter(x => x.line.includes(query))
      return { rows, total: r.total || rows.length }
    }
  }
}
</script>

<style scoped>
.venus-tabs :deep(.el-tabs__item) { font-weight: 540; }
.ztest { display: flex; flex-direction: column; gap: 12px; }
.finding { display: flex; gap: 12px; align-items: flex-start; padding: 10px 0; border-bottom: 1px solid var(--ds-border); }
.finding:last-child { border-bottom: none; }
.finding-t { font-weight: 560; font-size: 14px; }
.comp { display: flex; align-items: center; gap: 16px; padding: 12px 0; border-bottom: 1px solid var(--ds-border); }
.comp:last-child { border-bottom: none; }
.comp-i { flex: 1; min-width: 0; }
.comp-t { font-weight: 560; font-size: 14px; }
</style>
