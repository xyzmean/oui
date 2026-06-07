<!--
  Wireless — radios (band/channel/htmode/country) and their SSIDs (mode,
  encryption, key, hidden), over wireless.lua (uci wireless + ubus status).
-->
<template>
  <div class="ds-page">
    <oui-section title="Wi-Fi" subtitle="Радиомодули и беспроводные сети">
      <el-button :loading="loading" @click="load">Обновить</el-button>
    </oui-section>

    <oui-state v-if="loading && !radios.length" type="loading" />
    <oui-state v-else-if="!radios.length" type="empty" message="Радиомодулей не найдено (нет Wi-Fi на этом устройстве)" />

    <oui-card v-for="r in radios" :key="r.name" :title="r.name.toUpperCase()" :subtitle="bandLabel(r.band) + ' · ' + (r.htmode || '')">
      <template #actions>
        <oui-badge :tone="r.disabled ? 'muted' : (r.up ? 'ok':'warn')" dot>{{ r.disabled ? 'выключено' : (r.up ? 'работает':'не поднято') }}</oui-badge>
        <el-button size="small" @click="openRadio(r)">Радио</el-button>
        <el-button size="small" type="primary" @click="openIface(r.name)">+ Сеть</el-button>
      </template>

      <div class="ds-grid" style="margin-bottom:12px">
        <oui-stat label="Диапазон" tone="accent" :value="bandLabel(r.band)" />
        <oui-stat label="Канал" :value="r.live_channel || r.channel || 'auto'" />
        <oui-stat label="Ширина" :value="r.htmode || '—'" />
        <oui-stat label="Страна" :value="r.country || '—'" />
      </div>

      <el-table :data="r.ifaces" size="small">
        <el-table-column label="" width="36">
          <template #default="s"><oui-badge :tone="s.row.disabled ? 'muted':'ok'" dot /></template>
        </el-table-column>
        <el-table-column label="SSID" min-width="160">
          <template #default="s">{{ s.row.ssid || '(без имени)' }}<span v-if="s.row.hidden" class="ds-faint"> · скрытая</span></template>
        </el-table-column>
        <el-table-column label="Режим" width="90">
          <template #default="s">{{ modeLabel(s.row.mode) }}</template>
        </el-table-column>
        <el-table-column label="Шифрование" width="130">
          <template #default="s"><oui-badge :tone="s.row.encryption==='none' ? 'warn':'ok'">{{ encLabel(s.row.encryption) }}</oui-badge></template>
        </el-table-column>
        <el-table-column prop="network" label="Сеть" width="90" />
        <el-table-column label="" width="110" align="right">
          <template #default="s">
            <el-button size="small" @click="openIface(r.name, s.row)"><el-icon><Edit/></el-icon></el-button>
            <el-button size="small" type="danger" @click="delIface(s.row.sid)"><el-icon><Delete/></el-icon></el-button>
          </template>
        </el-table-column>
      </el-table>
      <oui-state v-if="!r.ifaces.length" type="empty" message="Сетей нет" />
    </oui-card>

    <!-- Radio editor -->
    <el-dialog v-model="radioDlg" :title="'Радио ' + (radioForm.name||'').toUpperCase()" width="520">
      <oui-field label="Диапазон">
        <el-select v-model="radioForm.band" style="width:160px">
          <el-option label="2.4 ГГц" value="2g" /><el-option label="5 ГГц" value="5g" /><el-option label="6 ГГц" value="6g" />
        </el-select>
      </oui-field>
      <oui-field label="Канал"><el-input v-model="radioForm.channel" placeholder="auto / 1 / 36 …" style="width:160px" /></oui-field>
      <oui-field label="Ширина канала">
        <el-select v-model="radioForm.htmode" style="width:160px">
          <el-option v-for="h in ['HT20','HT40','VHT80','VHT160','HE20','HE40','HE80','HE160']" :key="h" :label="h" :value="h" />
        </el-select>
      </oui-field>
      <oui-field label="Страна"><el-input v-model="radioForm.country" placeholder="RU" style="width:100px" /></oui-field>
      <oui-toggle v-model="radioForm.disabled" title="Выключить радио" />
      <template #footer>
        <el-button @click="radioDlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="saveRadio">Сохранить</el-button>
      </template>
    </el-dialog>

    <!-- SSID editor -->
    <el-dialog v-model="ifaceDlg" title="Беспроводная сеть" width="520">
      <oui-field label="Имя сети (SSID)"><el-input v-model="ifaceForm.ssid" /></oui-field>
      <oui-field label="Режим">
        <el-select v-model="ifaceForm.mode" style="width:200px">
          <el-option label="Точка доступа (AP)" value="ap" />
          <el-option label="Клиент (STA)" value="sta" />
        </el-select>
      </oui-field>
      <oui-field label="Шифрование">
        <el-select v-model="ifaceForm.encryption" style="width:200px">
          <el-option label="Открытая" value="none" />
          <el-option label="WPA2 (PSK)" value="psk2" />
          <el-option label="WPA2/WPA3 mixed" value="sae-mixed" />
          <el-option label="WPA3 (SAE)" value="sae" />
        </el-select>
      </oui-field>
      <oui-field v-if="ifaceForm.encryption !== 'none'" label="Пароль"><el-input v-model="ifaceForm.key" show-password placeholder="≥ 8 символов" /></oui-field>
      <oui-field label="Сеть"><el-input v-model="ifaceForm.network" placeholder="lan" style="width:140px" /></oui-field>
      <oui-toggle v-model="ifaceForm.hidden" title="Скрытая сеть" />
      <oui-toggle v-model="ifaceForm.disabled" title="Выключить" />
      <template #footer>
        <el-button @click="ifaceDlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="saveIface">Сохранить</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
const emptyRadio = () => ({ name: '', band: '2g', channel: 'auto', htmode: '', country: '', disabled: false })
const emptyIface = () => ({ sid: '', device: '', ssid: '', mode: 'ap', encryption: 'psk2', key: '', network: 'lan', hidden: false, disabled: false })
export default {
  data() {
    return { loading: false, busy: false, radios: [], radioDlg: false, radioForm: emptyRadio(), ifaceDlg: false, ifaceForm: emptyIface() }
  },
  created() { this.load() },
  methods: {
    bandLabel(b) { return ({ '2g': '2.4 ГГц', '5g': '5 ГГц', '6g': '6 ГГц' })[b] || b || '—' },
    modeLabel(m) { return ({ ap: 'AP', sta: 'Клиент' })[m] || m },
    encLabel(e) { return e === 'none' ? 'Открытая' : (e || '').toUpperCase() },
    async load() {
      this.loading = true
      try { this.radios = (await this.$oui.call('wireless', 'list') || {}).radios || [] }
      catch (e) { this.$message.error('Не удалось загрузить Wi-Fi') }
      this.loading = false
    },
    openRadio(r) { this.radioForm = { name: r.name, band: r.band || '2g', channel: r.channel || 'auto', htmode: r.htmode, country: r.country, disabled: r.disabled }; this.radioDlg = true },
    async saveRadio() {
      this.busy = true
      try { await this.$oui.call('wireless', 'set_device', this.radioForm); this.$message.success('Сохранено'); this.radioDlg = false }
      catch (e) { this.$message.error('Ошибка') }
      this.busy = false; await this.load()
    },
    openIface(device, s) {
      this.ifaceForm = s ? { sid: s.sid, device, ssid: s.ssid, mode: s.mode, encryption: s.encryption, key: s.key, network: s.network, hidden: s.hidden, disabled: s.disabled } : { ...emptyIface(), device }
      this.ifaceDlg = true
    },
    async saveIface() {
      this.busy = true
      try { await this.$oui.call('wireless', 'set_iface', this.ifaceForm); this.$message.success('Сохранено'); this.ifaceDlg = false }
      catch (e) { this.$message.error('Ошибка') }
      this.busy = false; await this.load()
    },
    async delIface(sid) {
      try { await this.$confirm('Удалить сеть?', 'Подтверждение', { type: 'warning' }) } catch (e) { return }
      await this.$oui.call('wireless', 'del_iface', { sid }); this.$message.success('Удалена'); await this.load()
    }
  }
}
</script>
