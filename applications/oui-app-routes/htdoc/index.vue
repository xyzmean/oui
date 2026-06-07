<!--
  Routes — live kernel routing table + static routes (uci network route),
  over routes.lua.
-->
<template>
  <div class="ds-page">
    <oui-section title="Маршруты" subtitle="Таблица маршрутизации и статические маршруты">
      <el-button :loading="loading" @click="load">Обновить</el-button>
      <el-button type="primary" @click="openRoute()">Добавить статический</el-button>
    </oui-section>

    <oui-card title="Статические маршруты" flush>
      <el-table :data="data.static || []" size="small">
        <el-table-column prop="interface" label="Интерфейс" width="120" />
        <el-table-column label="Назначение" min-width="140"><template #default="s"><span class="ds-mono">{{ s.row.target }}{{ s.row.netmask ? '/'+s.row.netmask : '' }}</span></template></el-table-column>
        <el-table-column label="Шлюз" min-width="130"><template #default="s"><span class="ds-mono">{{ s.row.gateway || '—' }}</span></template></el-table-column>
        <el-table-column prop="metric" label="Метрика" width="90" />
        <el-table-column label="" width="110" align="right">
          <template #default="s">
            <el-button size="small" @click="openRoute(s.row)"><el-icon><Edit/></el-icon></el-button>
            <el-button size="small" type="danger" @click="del(s.row.sid)"><el-icon><Delete/></el-icon></el-button>
          </template>
        </el-table-column>
      </el-table>
      <oui-state v-if="!(data.static||[]).length" type="empty" message="Статических маршрутов нет" />
    </oui-card>

    <oui-card title="Активная таблица (IPv4)" flush style="margin-top:20px">
      <el-table :data="data.active || []" size="small" max-height="420">
        <el-table-column label="Назначение" min-width="150"><template #default="s"><span class="ds-mono">{{ s.row.target }}</span></template></el-table-column>
        <el-table-column label="Шлюз" min-width="130"><template #default="s"><span class="ds-mono">{{ s.row.gateway || '—' }}</span></template></el-table-column>
        <el-table-column prop="device" label="Устройство" width="120" />
        <el-table-column prop="metric" label="Метрика" width="90" />
      </el-table>
      <oui-state v-if="!(data.active||[]).length" type="empty" message="Нет данных" />
    </oui-card>

    <el-dialog v-model="dlg" title="Статический маршрут" width="500">
      <oui-field label="Интерфейс"><el-input v-model="form.interface" placeholder="lan / wan" style="width:160px" /></oui-field>
      <oui-field label="Назначение"><el-input v-model="form.target" placeholder="10.0.0.0" /></oui-field>
      <oui-field label="Маска"><el-input v-model="form.netmask" placeholder="255.255.255.0" /></oui-field>
      <oui-field label="Шлюз"><el-input v-model="form.gateway" placeholder="192.168.1.254" /></oui-field>
      <oui-field label="Метрика"><el-input v-model="form.metric" placeholder="0" style="width:120px" /></oui-field>
      <template #footer><el-button @click="dlg=false">Отмена</el-button><el-button type="primary" :loading="busy" @click="save">Сохранить</el-button></template>
    </el-dialog>
  </div>
</template>

<script>
const empty = () => ({ sid: '', interface: '', target: '', netmask: '', gateway: '', metric: '' })
export default {
  data() { return { loading: false, busy: false, data: {}, dlg: false, form: empty() } },
  created() { this.load() },
  methods: {
    async load() { this.loading = true; try { this.data = await this.$oui.call('routes', 'get') || {} } catch (e) { this.$message.error('Ошибка загрузки') } this.loading = false },
    openRoute(r) { this.form = r ? { ...empty(), ...r } : empty(); this.dlg = true },
    async save() { this.busy = true; try { await this.$oui.call('routes', 'set_route', this.form); this.$message.success('Сохранено'); this.dlg = false } catch (e) { this.$message.error('Ошибка') } this.busy = false; await this.load() },
    async del(sid) { try { await this.$confirm('Удалить маршрут?', 'Подтверждение', { type: 'warning' }) } catch (e) { return } await this.$oui.call('routes', 'del_route', { sid }); this.$message.success('Удалено'); await this.load() }
  }
}
</script>
