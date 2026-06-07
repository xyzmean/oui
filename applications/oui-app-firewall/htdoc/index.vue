<!--
  Firewall — zones overview, port forwards (DNAT), and traffic rules, over
  firewall.lua (uci `firewall`).
-->
<template>
  <div class="ds-page">
    <oui-section title="Брандмауэр" subtitle="Зоны, проброс портов и правила трафика">
      <el-button :loading="loading" @click="load">Обновить</el-button>
    </oui-section>

    <el-tabs v-model="tab" class="fw-tabs">
      <el-tab-pane label="Проброс портов" name="forwards">
        <oui-card title="Проброс портов (DNAT)" flush>
          <template #actions><el-button type="primary" @click="openFwd()">Добавить</el-button></template>
          <el-table :data="fw.forwards || []" size="small">
            <el-table-column label="" width="46">
              <template #default="s"><el-switch :model-value="s.row.enabled" @change="v => toggle(s.row.sid, v)" size="small" /></template>
            </el-table-column>
            <el-table-column prop="name" label="Имя" min-width="120" />
            <el-table-column label="Извне" min-width="120">
              <template #default="s"><span class="ds-mono">{{ s.row.src }}:{{ s.row.src_dport || '*' }}</span></template>
            </el-table-column>
            <el-table-column label="На" min-width="140">
              <template #default="s"><span class="ds-mono">{{ s.row.dest_ip }}:{{ s.row.dest_port || s.row.src_dport }}</span></template>
            </el-table-column>
            <el-table-column prop="proto" label="Proto" width="90" />
            <el-table-column label="" width="110" align="right">
              <template #default="s">
                <el-button size="small" @click="openFwd(s.row)"><el-icon><Edit/></el-icon></el-button>
                <el-button size="small" type="danger" @click="del(s.row.sid)"><el-icon><Delete/></el-icon></el-button>
              </template>
            </el-table-column>
          </el-table>
          <oui-state v-if="!(fw.forwards||[]).length" type="empty" message="Пробросов нет" />
        </oui-card>
      </el-tab-pane>

      <el-tab-pane label="Правила" name="rules">
        <oui-card title="Правила трафика" flush>
          <template #actions><el-button type="primary" @click="openRule()">Добавить</el-button></template>
          <el-table :data="fw.rules || []" size="small">
            <el-table-column label="" width="46">
              <template #default="s"><el-switch :model-value="s.row.enabled" @change="v => toggle(s.row.sid, v)" size="small" /></template>
            </el-table-column>
            <el-table-column prop="name" label="Имя" min-width="140" />
            <el-table-column prop="src" label="Из" width="90" />
            <el-table-column prop="dest" label="В" width="90" />
            <el-table-column prop="dest_port" label="Порт" width="90" />
            <el-table-column label="Действие" width="100">
              <template #default="s"><oui-badge :tone="s.row.target==='ACCEPT' ? 'ok' : (s.row.target==='DROP'||s.row.target==='REJECT' ? 'err':'muted')">{{ s.row.target }}</oui-badge></template>
            </el-table-column>
            <el-table-column label="" width="110" align="right">
              <template #default="s">
                <el-button size="small" @click="openRule(s.row)"><el-icon><Edit/></el-icon></el-button>
                <el-button size="small" type="danger" @click="del(s.row.sid)"><el-icon><Delete/></el-icon></el-button>
              </template>
            </el-table-column>
          </el-table>
          <oui-state v-if="!(fw.rules||[]).length" type="empty" message="Правил нет" />
        </oui-card>
      </el-tab-pane>

      <el-tab-pane label="Зоны" name="zones">
        <oui-card title="Зоны" flush>
          <el-table :data="fw.zones || []" size="small">
            <el-table-column prop="name" label="Зона" min-width="110" />
            <el-table-column label="Сети" min-width="160">
              <template #default="s"><oui-badge v-for="n in s.row.network" :key="n" style="margin-right:4px">{{ n }}</oui-badge></template>
            </el-table-column>
            <el-table-column label="Input" width="100"><template #default="s"><oui-badge :tone="pTone(s.row.input)">{{ s.row.input }}</oui-badge></template></el-table-column>
            <el-table-column label="Forward" width="100"><template #default="s"><oui-badge :tone="pTone(s.row.forward)">{{ s.row.forward }}</oui-badge></template></el-table-column>
            <el-table-column label="Output" width="100"><template #default="s"><oui-badge :tone="pTone(s.row.output)">{{ s.row.output }}</oui-badge></template></el-table-column>
            <el-table-column label="NAT" width="70"><template #default="s"><oui-badge :tone="s.row.masq ? 'accent':'muted'">{{ s.row.masq ? 'да':'—' }}</oui-badge></template></el-table-column>
          </el-table>
          <oui-state v-if="!(fw.zones||[]).length" type="empty" message="Зон нет" />
        </oui-card>
      </el-tab-pane>
    </el-tabs>

    <!-- Forward editor -->
    <el-dialog v-model="fwdDlg" title="Проброс порта" width="560">
      <oui-field label="Имя"><el-input v-model="fwdForm.name" /></oui-field>
      <oui-field label="Внешняя зона"><el-input v-model="fwdForm.src" placeholder="wan" style="width:160px" /></oui-field>
      <oui-field label="Внешний порт"><el-input v-model="fwdForm.src_dport" placeholder="8080" style="width:160px" /></oui-field>
      <oui-field label="Внутренний IP"><el-input v-model="fwdForm.dest_ip" placeholder="192.168.1.10" /></oui-field>
      <oui-field label="Внутренний порт"><el-input v-model="fwdForm.dest_port" placeholder="80" style="width:160px" /></oui-field>
      <oui-field label="Протокол">
        <el-select v-model="fwdForm.proto" style="width:160px">
          <el-option label="TCP+UDP" value="tcp udp" /><el-option label="TCP" value="tcp" /><el-option label="UDP" value="udp" />
        </el-select>
      </oui-field>
      <template #footer><el-button @click="fwdDlg=false">Отмена</el-button><el-button type="primary" :loading="busy" @click="saveFwd">Сохранить</el-button></template>
    </el-dialog>

    <!-- Rule editor -->
    <el-dialog v-model="ruleDlg" title="Правило трафика" width="560">
      <oui-field label="Имя"><el-input v-model="ruleForm.name" /></oui-field>
      <oui-field label="Из зоны"><el-input v-model="ruleForm.src" placeholder="wan" style="width:160px" /></oui-field>
      <oui-field label="В зону"><el-input v-model="ruleForm.dest" placeholder="lan (пусто=сам роутер)" style="width:220px" /></oui-field>
      <oui-field label="Протокол">
        <el-select v-model="ruleForm.proto" style="width:160px">
          <el-option label="TCP+UDP" value="tcp udp" /><el-option label="TCP" value="tcp" /><el-option label="UDP" value="udp" /><el-option label="Любой" value="" />
        </el-select>
      </oui-field>
      <oui-field label="Порт назначения"><el-input v-model="ruleForm.dest_port" placeholder="22" style="width:160px" /></oui-field>
      <oui-field label="Действие">
        <el-select v-model="ruleForm.target" style="width:160px">
          <el-option label="Разрешить" value="ACCEPT" /><el-option label="Отклонить" value="REJECT" /><el-option label="Отбросить" value="DROP" />
        </el-select>
      </oui-field>
      <template #footer><el-button @click="ruleDlg=false">Отмена</el-button><el-button type="primary" :loading="busy" @click="saveRule">Сохранить</el-button></template>
    </el-dialog>
  </div>
</template>

<script>
const emptyFwd = () => ({ sid: '', name: '', src: 'wan', src_dport: '', dest_ip: '', dest_port: '', proto: 'tcp udp', target: 'DNAT', enabled: true })
const emptyRule = () => ({ sid: '', name: '', src: 'wan', dest: '', proto: 'tcp', dest_port: '', target: 'ACCEPT', enabled: true })
export default {
  data() { return { tab: 'forwards', loading: false, busy: false, fw: {}, fwdDlg: false, fwdForm: emptyFwd(), ruleDlg: false, ruleForm: emptyRule() } },
  created() { this.load() },
  methods: {
    pTone(p) { return p === 'ACCEPT' ? 'ok' : (p === 'DROP' || p === 'REJECT' ? 'err' : 'muted') },
    async load() {
      this.loading = true
      try { this.fw = await this.$oui.call('firewall', 'get') || {} }
      catch (e) { this.$message.error('Не удалось загрузить firewall') }
      this.loading = false
    },
    openFwd(r) { this.fwdForm = r ? { ...emptyFwd(), ...r } : emptyFwd(); this.fwdDlg = true },
    openRule(r) { this.ruleForm = r ? { ...emptyRule(), ...r } : emptyRule(); this.ruleDlg = true },
    async saveFwd() { this.busy = true; try { await this.$oui.call('firewall', 'set_forward', this.fwdForm); this.$message.success('Сохранено'); this.fwdDlg = false } catch (e) { this.$message.error('Ошибка') } this.busy = false; await this.load() },
    async saveRule() { this.busy = true; try { await this.$oui.call('firewall', 'set_rule', this.ruleForm); this.$message.success('Сохранено'); this.ruleDlg = false } catch (e) { this.$message.error('Ошибка') } this.busy = false; await this.load() },
    async toggle(sid, enabled) { await this.$oui.call('firewall', 'toggle', { sid, enabled }); await this.load() },
    async del(sid) { try { await this.$confirm('Удалить запись?', 'Подтверждение', { type: 'warning' }) } catch (e) { return } await this.$oui.call('firewall', 'del', { sid }); this.$message.success('Удалено'); await this.load() }
  }
}
</script>

<style scoped>.fw-tabs :deep(.el-tabs__item){font-weight:540}</style>
