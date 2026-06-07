<!--
  DHCP & DNS — dnsmasq options, per-interface pools, static leases, over
  dhcp.lua (uci `dhcp`).
-->
<template>
  <div class="ds-page">
    <oui-section title="DHCP и DNS" subtitle="Пулы адресов, статические аренды, dnsmasq">
      <el-button :loading="loading" @click="load">Обновить</el-button>
    </oui-section>

    <el-tabs v-model="tab" class="dh-tabs">
      <el-tab-pane label="Пулы" name="pools">
        <oui-card title="Пулы DHCP" flush>
          <el-table :data="data.pools || []" size="small">
            <el-table-column prop="interface" label="Интерфейс" min-width="120" />
            <el-table-column prop="start" label="Старт" width="100" />
            <el-table-column prop="limit" label="Лимит" width="100" />
            <el-table-column prop="leasetime" label="Аренда" width="100" />
            <el-table-column label="Статус" width="110">
              <template #default="s"><oui-badge :tone="s.row.ignore ? 'muted':'ok'">{{ s.row.ignore ? 'выключен':'активен' }}</oui-badge></template>
            </el-table-column>
            <el-table-column label="" width="100" align="right">
              <template #default="s"><el-button size="small" @click="openPool(s.row)">Настроить</el-button></template>
            </el-table-column>
          </el-table>
          <oui-state v-if="!(data.pools||[]).length" type="empty" message="Пулов нет" />
        </oui-card>
      </el-tab-pane>

      <el-tab-pane label="Статические аренды" name="hosts">
        <oui-card title="Статические аренды" flush>
          <template #actions><el-button type="primary" @click="openHost()">Добавить</el-button></template>
          <el-table :data="data.hosts || []" size="small">
            <el-table-column prop="name" label="Имя" min-width="120" />
            <el-table-column label="MAC" min-width="160"><template #default="s"><span class="ds-mono">{{ s.row.mac }}</span></template></el-table-column>
            <el-table-column label="IP" width="140"><template #default="s"><span class="ds-mono">{{ s.row.ip }}</span></template></el-table-column>
            <el-table-column label="" width="110" align="right">
              <template #default="s">
                <el-button size="small" @click="openHost(s.row)"><el-icon><Edit/></el-icon></el-button>
                <el-button size="small" type="danger" @click="delHost(s.row.sid)"><el-icon><Delete/></el-icon></el-button>
              </template>
            </el-table-column>
          </el-table>
          <oui-state v-if="!(data.hosts||[]).length" type="empty" message="Статических аренд нет" />
        </oui-card>
      </el-tab-pane>

      <el-tab-pane label="DNS" name="dns">
        <oui-card title="dnsmasq">
          <oui-field label="Локальный домен"><el-input :model-value="dnsmasq.domain" @change="v => setDnsmasq('domain', v)" style="width:200px" placeholder="lan" /></oui-field>
          <oui-field label="Local"><el-input :model-value="dnsmasq.local_" @change="v => setDnsmasq('local', v)" style="width:200px" placeholder="/lan/" /></oui-field>
          <oui-toggle :model-value="dnsmasq.rebind_protection" title="Защита от DNS-rebind" @change="v => setDnsmasq('rebind_protection', v)" />
        </oui-card>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="poolDlg" :title="'Пул ' + (poolForm.interface||'')" width="480">
      <oui-field label="Старт"><el-input v-model="poolForm.start" placeholder="100" style="width:140px" /></oui-field>
      <oui-field label="Лимит"><el-input v-model="poolForm.limit" placeholder="150" style="width:140px" /></oui-field>
      <oui-field label="Время аренды"><el-input v-model="poolForm.leasetime" placeholder="12h" style="width:140px" /></oui-field>
      <oui-toggle v-model="poolForm.ignore" title="Отключить DHCP на этом интерфейсе" />
      <template #footer><el-button @click="poolDlg=false">Отмена</el-button><el-button type="primary" :loading="busy" @click="savePool">Сохранить</el-button></template>
    </el-dialog>

    <el-dialog v-model="hostDlg" title="Статическая аренда" width="480">
      <oui-field label="Имя"><el-input v-model="hostForm.name" /></oui-field>
      <oui-field label="MAC"><el-input v-model="hostForm.mac" placeholder="00:11:22:33:44:55" /></oui-field>
      <oui-field label="IP"><el-input v-model="hostForm.ip" placeholder="192.168.1.50" /></oui-field>
      <template #footer><el-button @click="hostDlg=false">Отмена</el-button><el-button type="primary" :loading="busy" @click="saveHost">Сохранить</el-button></template>
    </el-dialog>
  </div>
</template>

<script>
const emptyPool = () => ({ sid: '', interface: '', start: '', limit: '', leasetime: '12h', ignore: false })
const emptyHost = () => ({ sid: '', name: '', mac: '', ip: '' })
export default {
  data() { return { tab: 'pools', loading: false, busy: false, data: {}, poolDlg: false, poolForm: emptyPool(), hostDlg: false, hostForm: emptyHost() } },
  computed: { dnsmasq() { return this.data.dnsmasq || {} } },
  created() { this.load() },
  methods: {
    async load() { this.loading = true; try { this.data = await this.$oui.call('dhcp', 'get') || {} } catch (e) { this.$message.error('Ошибка загрузки') } this.loading = false },
    openPool(r) { this.poolForm = { ...emptyPool(), ...r }; this.poolDlg = true },
    async savePool() { this.busy = true; try { await this.$oui.call('dhcp', 'set_pool', this.poolForm); this.$message.success('Сохранено'); this.poolDlg = false } catch (e) { this.$message.error('Ошибка') } this.busy = false; await this.load() },
    openHost(r) { this.hostForm = r ? { ...emptyHost(), ...r } : emptyHost(); this.hostDlg = true },
    async saveHost() { this.busy = true; try { await this.$oui.call('dhcp', 'set_host', this.hostForm); this.$message.success('Сохранено'); this.hostDlg = false } catch (e) { this.$message.error('Ошибка') } this.busy = false; await this.load() },
    async delHost(sid) { try { await this.$confirm('Удалить аренду?', 'Подтверждение', { type: 'warning' }) } catch (e) { return } await this.$oui.call('dhcp', 'del_host', { sid }); this.$message.success('Удалено'); await this.load() },
    async setDnsmasq(option, value) { await this.$oui.call('dhcp', 'set_dnsmasq', { sid: this.dnsmasq.sid, [option]: value }); this.$message.success('Сохранено'); await this.load() }
  }
}
</script>
<style scoped>.dh-tabs :deep(.el-tabs__item){font-weight:540}</style>
