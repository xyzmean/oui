<!--
  Network interfaces — WAN/LAN config (proto static/dhcp/pppoe/none) with live
  status, over interfaces.lua (uci `network` + ubus status).
-->
<template>
  <div class="ds-page">
    <oui-section title="Интерфейсы" subtitle="Сетевые интерфейсы роутера">
      <el-button :loading="loading" @click="load">Обновить</el-button>
    </oui-section>

    <oui-state v-if="loading && !ifaces.length" type="loading" />
    <oui-state v-else-if="!ifaces.length" type="empty" message="Нет интерфейсов" />

    <oui-card v-for="i in ifaces" :key="i.name" :title="i.name.toUpperCase()" :subtitle="i.l3_device || i.device">
      <template #actions>
        <oui-badge :tone="i.up ? 'ok':'muted'" dot>{{ i.up ? 'поднят':'опущен' }}</oui-badge>
        <el-button size="small" @click="restart(i.name)">Перезапустить</el-button>
        <el-button size="small" type="primary" @click="openEdit(i)">Настроить</el-button>
      </template>
      <div class="ds-grid">
        <oui-stat label="Протокол" tone="accent" :value="protoLabel(i.proto)" />
        <oui-stat label="Адрес" :value="i.address || '—'" />
        <oui-stat label="Шлюз" :value="i.gateway || '—'" />
        <oui-stat label="Аптайм" :value="uptime(i.uptime)" :hint="i.up ? 'на связи' : 'нет связи'" />
      </div>
      <div v-if="(i.dns||[]).length" class="ds-row" style="margin-top:12px">
        <span class="ds-label">DNS</span>
        <oui-badge v-for="d in i.dns" :key="d">{{ d }}</oui-badge>
      </div>
    </oui-card>

    <el-dialog v-model="dlg" :title="'Интерфейс ' + (form.name||'').toUpperCase()" width="560">
      <oui-field label="Протокол">
        <el-select v-model="form.proto" style="width:220px">
          <el-option label="DHCP-клиент" value="dhcp" />
          <el-option label="Статический IP" value="static" />
          <el-option label="PPPoE" value="pppoe" />
          <el-option label="Не настроен" value="none" />
        </el-select>
      </oui-field>
      <oui-field label="Устройство" hint="L3-устройство/мост"><el-input v-model="form.device" placeholder="eth0 / br-lan" /></oui-field>

      <template v-if="form.proto === 'static'">
        <oui-field label="IP-адрес"><el-input v-model="form.ipaddr" placeholder="192.168.1.1" /></oui-field>
        <oui-field label="Маска"><el-input v-model="form.netmask" placeholder="255.255.255.0" /></oui-field>
        <oui-field label="Шлюз"><el-input v-model="form.gateway" placeholder="(необязательно)" /></oui-field>
        <oui-field label="DNS" hint="через пробел"><el-input v-model="form.dns" placeholder="1.1.1.1 8.8.8.8" /></oui-field>
      </template>
      <template v-else-if="form.proto === 'pppoe'">
        <oui-field label="Логин"><el-input v-model="form.username" /></oui-field>
        <oui-field label="Пароль"><el-input v-model="form.password" show-password /></oui-field>
      </template>
      <oui-field label="MTU"><el-input v-model="form.mtu" placeholder="1500" /></oui-field>

      <template #footer>
        <el-button @click="dlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="save">Сохранить и применить</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
const emptyForm = () => ({ name: '', proto: 'dhcp', device: '', ipaddr: '', netmask: '', gateway: '', dns: '', username: '', password: '', mtu: '' })
export default {
  data() { return { loading: false, busy: false, ifaces: [], dlg: false, form: emptyForm() } },
  created() { this.load() },
  methods: {
    protoLabel(p) { return ({ dhcp: 'DHCP', static: 'Статический', pppoe: 'PPPoE', none: 'Не настроен', dhcpv6: 'DHCPv6' })[p] || p },
    uptime(s) {
      s = Number(s || 0); if (!s) return '—'
      const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60)
      return d > 0 ? `${d}д ${h}ч` : (h > 0 ? `${h}ч ${m}м` : `${m}м`)
    },
    async load() {
      this.loading = true
      try { this.ifaces = (await this.$oui.call('interfaces', 'list') || {}).interfaces || [] }
      catch (e) { this.$message.error('Не удалось загрузить интерфейсы') }
      this.loading = false
    },
    openEdit(i) {
      this.form = { name: i.name, proto: i.proto, device: i.device, ipaddr: i.ipaddr, netmask: i.netmask, gateway: i.gateway, dns: (i.dns || []).join(' '), username: i.username, password: '', mtu: i.mtu }
      this.dlg = true
    },
    async save() {
      this.busy = true
      try {
        await this.$oui.call('interfaces', 'set', this.form)
        this.$message.success('Сохранено и применено'); this.dlg = false
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false; await this.load()
    },
    async restart(name) {
      try { await this.$oui.call('interfaces', 'restart', { name }); this.$message.success('Перезапущен'); await this.load() }
      catch (e) { this.$message.error('Ошибка') }
    }
  }
}
</script>
