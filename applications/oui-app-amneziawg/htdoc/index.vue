<!--
  AmneziaWG — obfuscated WireGuard tunnels. Manages uci `network` interfaces of
  proto `amneziawg` and their peers via the amneziawg.lua RPC: interface keys
  (with awg key generation), obfuscation params, peers, and live handshake.
-->
<template>
  <div class="ds-page">
    <oui-section title="AmneziaWG" subtitle="Обфусцированный WireGuard — туннели и пиры">
      <el-button :loading="loading" @click="load">Обновить</el-button>
      <el-button type="primary" @click="openIface()">Добавить интерфейс</el-button>
    </oui-section>

    <oui-state v-if="loading && !ifaces.length" type="loading" />
    <oui-state v-else-if="!ifaces.length" type="empty" message="Нет интерфейсов AmneziaWG" />

    <oui-card v-for="i in ifaces" :key="i.name" :title="i.name" :subtitle="i.public_key ? ('pubkey ' + short(i.public_key)) : 'ключ не задан'">
      <template #actions>
        <oui-badge :tone="i.up ? 'ok' : 'muted'" dot>{{ i.up ? 'поднят' : 'опущен' }}</oui-badge>
        <el-button size="small" @click="openIface(i)"><el-icon><Edit/></el-icon></el-button>
        <el-button size="small" type="danger" @click="delIface(i.name)"><el-icon><Delete/></el-icon></el-button>
      </template>

      <div class="ds-grid" style="margin-bottom:16px">
        <oui-stat label="Порт" :value="i.listen_port || '—'" />
        <oui-stat label="MTU" :value="i.mtu || '1420'" />
        <oui-stat label="Адреса" :value="(i.addresses||[]).length" :hint="(i.addresses||[]).join(', ')" />
        <oui-stat label="Обфускация" :tone="obfOn(i) ? 'accent':'muted'" :value="obfOn(i) ? 'вкл' : 'выкл'"
          :hint="'Jc ' + (i.obf?.awg_jc||'—') + ' · S1 ' + (i.obf?.awg_s1||'—')" />
      </div>

      <div class="ds-row" style="justify-content:space-between;margin-bottom:8px">
        <span class="ds-label">Пиры</span>
        <el-button size="small" type="primary" @click="openPeer(i.name)">Добавить пир</el-button>
      </div>
      <el-table :data="i.peers" size="small">
        <el-table-column label="" width="36">
          <template #default="s"><oui-badge :tone="peerTone(s.row)" dot /></template>
        </el-table-column>
        <el-table-column label="Public key" min-width="160">
          <template #default="s"><span class="ds-mono">{{ short(s.row.public_key) }}</span></template>
        </el-table-column>
        <el-table-column label="Endpoint" min-width="160">
          <template #default="s"><span class="ds-mono">{{ s.row.endpoint_host ? (s.row.endpoint_host + ':' + (s.row.endpoint_port||'51820')) : '—' }}</span></template>
        </el-table-column>
        <el-table-column label="Хендшейк" width="130">
          <template #default="s">{{ hs(s.row.handshake) }}</template>
        </el-table-column>
        <el-table-column label="Трафик" min-width="130">
          <template #default="s"><span class="ds-mono">↓{{ bytes(s.row.rx) }} ↑{{ bytes(s.row.tx) }}</span></template>
        </el-table-column>
        <el-table-column label="" width="110" align="right">
          <template #default="s">
            <el-button size="small" @click="openPeer(i.name, s.row)"><el-icon><Edit/></el-icon></el-button>
            <el-button size="small" type="danger" @click="delPeer(s.row.sid)"><el-icon><Delete/></el-icon></el-button>
          </template>
        </el-table-column>
      </el-table>
      <oui-state v-if="!i.peers.length" type="empty" message="Пиров нет" />
    </oui-card>

    <!-- Interface editor -->
    <el-dialog v-model="ifaceDlg" :title="ifaceForm.name ? ('Интерфейс ' + ifaceForm.name) : 'Новый интерфейс'" width="600">
      <oui-field label="Имя" hint="Имя сетевого интерфейса, напр. awg0"><el-input v-model="ifaceForm.name" :disabled="ifaceEditing" /></oui-field>
      <oui-field label="Приватный ключ">
        <div class="ds-row" style="width:100%">
          <el-input v-model="ifaceForm.private_key" show-password style="flex:1" />
          <el-button @click="genKey">Сгенерировать</el-button>
        </div>
      </oui-field>
      <oui-field v-if="ifaceForm.public_key" label="Публичный ключ"><span class="ds-mono">{{ ifaceForm.public_key }}</span></oui-field>
      <oui-field label="Порт прослушивания"><el-input v-model="ifaceForm.listen_port" placeholder="51820" /></oui-field>
      <oui-field label="MTU"><el-input v-model="ifaceForm.mtu" placeholder="1420" /></oui-field>
      <oui-field label="Адреса" hint="IP интерфейса через пробел"><el-input v-model="ifaceForm.addresses" placeholder="10.0.0.2/32" /></oui-field>

      <el-collapse>
        <el-collapse-item title="Параметры обфускации (AmneziaWG)">
          <div class="ds-grid">
            <oui-field v-for="k in obfKeys" :key="k" :label="k.replace('awg_','').toUpperCase()">
              <el-input v-model="ifaceForm.obf[k]" />
            </oui-field>
          </div>
        </el-collapse-item>
      </el-collapse>
      <template #footer>
        <el-button @click="ifaceDlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="saveIface">Сохранить</el-button>
      </template>
    </el-dialog>

    <!-- Peer editor -->
    <el-dialog v-model="peerDlg" title="Пир" width="560">
      <oui-field label="Public key"><el-input v-model="peerForm.public_key" /></oui-field>
      <oui-field label="Endpoint host"><el-input v-model="peerForm.endpoint_host" placeholder="vpn.example.com" /></oui-field>
      <oui-field label="Endpoint port"><el-input v-model="peerForm.endpoint_port" placeholder="51820" /></oui-field>
      <oui-field label="Allowed IPs" hint="через пробел"><el-input v-model="peerForm.allowed_ips" placeholder="0.0.0.0/0 ::/0" /></oui-field>
      <oui-field label="Keepalive"><el-input v-model="peerForm.persistent_keepalive" placeholder="25" /></oui-field>
      <oui-toggle v-model="peerForm.disabled" title="Отключён" />
      <template #footer>
        <el-button @click="peerDlg=false">Отмена</el-button>
        <el-button type="primary" :loading="busy" @click="savePeer">Сохранить</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
const OBF_KEYS = ['awg_jc','awg_jmin','awg_jmax','awg_s1','awg_s2','awg_s3','awg_s4','awg_h1','awg_h2','awg_h3','awg_h4']
const emptyIface = () => ({ name: '', private_key: '', public_key: '', listen_port: '', mtu: '', addresses: '', obf: {} })
const emptyPeer = () => ({ sid: '', iface: '', public_key: '', endpoint_host: '', endpoint_port: '', allowed_ips: '', persistent_keepalive: '', disabled: false })

export default {
  data() {
    return {
      loading: false, busy: false,
      ifaces: [],
      obfKeys: OBF_KEYS,
      ifaceDlg: false, ifaceEditing: false, ifaceForm: emptyIface(),
      peerDlg: false, peerForm: emptyPeer()
    }
  },
  created() { this.load() },
  methods: {
    short(k) { return k ? (k.slice(0, 10) + '…' + k.slice(-6)) : '—' },
    obfOn(i) { return !!(i.obf && (i.obf.awg_jc || i.obf.awg_s1)) },
    peerTone(p) { return p.disabled ? 'muted' : (p.handshake ? 'ok' : 'warn') },
    hs(t) {
      if (!t) return 'нет'
      const d = Math.floor(Date.now() / 1000) - t
      if (d < 0) return 'только что'
      if (d < 60) return d + 'с назад'
      if (d < 3600) return Math.floor(d / 60) + 'м назад'
      return Math.floor(d / 3600) + 'ч назад'
    },
    bytes(n) {
      n = Number(n || 0)
      if (n < 1024) return n + 'B'
      if (n < 1048576) return (n / 1024).toFixed(1) + 'K'
      if (n < 1073741824) return (n / 1048576).toFixed(1) + 'M'
      return (n / 1073741824).toFixed(2) + 'G'
    },
    async load() {
      this.loading = true
      try {
        const r = await this.$oui.call('amneziawg', 'list') || {}
        this.ifaces = r.interfaces || []
      } catch (e) { this.$message.error('Не удалось загрузить AmneziaWG') }
      this.loading = false
    },
    openIface(i) {
      this.ifaceEditing = !!i
      this.ifaceForm = i
        ? { name: i.name, private_key: i.private_key, public_key: i.public_key, listen_port: i.listen_port, mtu: i.mtu, addresses: (i.addresses || []).join(' '), obf: { ...(i.obf || {}) } }
        : emptyIface()
      this.ifaceDlg = true
    },
    async genKey() {
      try {
        const r = await this.$oui.call('amneziawg', 'genkey') || {}
        if (r.ok === false) { this.$message.warning(r.msg || 'awg недоступен'); return }
        this.ifaceForm.private_key = r.private_key
        this.ifaceForm.public_key = r.public_key
      } catch (e) { this.$message.error('Ошибка генерации') }
    },
    async saveIface() {
      if (!this.ifaceForm.name) { this.$message.warning('Укажите имя'); return }
      this.busy = true
      try {
        await this.$oui.call('amneziawg', 'set_iface', this.ifaceForm)
        this.$message.success('Сохранено'); this.ifaceDlg = false
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false; await this.load()
    },
    async delIface(name) {
      try { await this.$confirm(`Удалить интерфейс ${name}?`, 'Подтверждение', { type: 'warning' }) } catch (e) { return }
      await this.$oui.call('amneziawg', 'del_iface', { name })
      this.$message.success('Удалён'); await this.load()
    },
    openPeer(iface, p) {
      this.peerForm = p
        ? { sid: p.sid, iface, public_key: p.public_key, endpoint_host: p.endpoint_host, endpoint_port: p.endpoint_port, allowed_ips: (p.allowed_ips || []).join(' '), persistent_keepalive: p.persistent_keepalive, disabled: p.disabled }
        : { ...emptyPeer(), iface }
      this.peerDlg = true
    },
    async savePeer() {
      this.busy = true
      try {
        await this.$oui.call('amneziawg', 'set_peer', this.peerForm)
        this.$message.success('Пир сохранён'); this.peerDlg = false
      } catch (e) { this.$message.error('Ошибка') }
      this.busy = false; await this.load()
    },
    async delPeer(sid) {
      try { await this.$confirm('Удалить пир?', 'Подтверждение', { type: 'warning' }) } catch (e) { return }
      await this.$oui.call('amneziawg', 'del_peer', { sid })
      this.$message.success('Удалён'); await this.load()
    }
  }
}
</script>
