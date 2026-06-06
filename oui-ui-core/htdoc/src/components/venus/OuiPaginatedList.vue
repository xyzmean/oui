<!--
  Paginated / windowed list — renders only the current page, never the whole
  dataset. This is the fix for the browser hang where dumping a full IP/log list
  (thousands of rows) into the DOM froze the tab.

  Two modes:
    • client : pass :items (array); filtered + sliced in the browser.
    • server : pass :loader  (async ({offset, limit, query}) => {rows, total});
               called on page/search change — the backend returns only a window.

  Rendering: pass :columns to get an el-table, or use the #row slot per item.
-->
<template>
  <div class="oui-plist">
    <div v-if="searchable || $slots.toolbar" class="oui-plist__bar">
      <el-input
        v-if="searchable"
        v-model="query"
        :placeholder="searchPlaceholder"
        clearable
        class="oui-plist__search"
      >
        <template #prefix><el-icon><Search /></el-icon></template>
      </el-input>
      <span class="oui-plist__count ds-mono ds-faint">{{ total }}</span>
      <div class="ds-spacer" />
      <slot name="toolbar" />
    </div>

    <oui-state v-if="loading" type="loading" />
    <oui-state v-else-if="total === 0" type="empty" :message="emptyMessage" />

    <template v-else>
      <el-table
        v-if="columns.length"
        :data="pageRows"
        :row-key="rowKey"
        :max-height="height"
        size="small"
        class="oui-plist__table"
      >
        <el-table-column
          v-for="c in columns"
          :key="c.prop"
          :prop="c.prop"
          :label="c.label"
          :width="c.width"
          :min-width="c.minWidth"
          :align="c.align || 'left'"
        >
          <template #default="scope">
            <span :class="{ 'ds-mono': c.mono }">
              <slot :name="'col-' + c.prop" :row="scope.row" :value="scope.row[c.prop]">
                {{ format(c, scope.row[c.prop], scope.row) }}
              </slot>
            </span>
          </template>
        </el-table-column>
      </el-table>

      <div v-else class="oui-plist__rows">
        <slot name="row" v-for="(row, i) in pageRows" :row="row" :index="i" :key="rowKey ? row[rowKey] : i" />
      </div>
    </template>

    <div v-if="total > pageSize" class="oui-plist__pager">
      <el-pagination
        layout="prev, pager, next, jumper"
        :total="total"
        :page-size="pageSize"
        :current-page="page"
        @current-change="onPage"
        background
        small
      />
    </div>
  </div>
</template>

<script>
export default {
  name: 'OuiPaginatedList',
  props: {
    items: { type: Array, default: null },
    loader: { type: Function, default: null },
    columns: { type: Array, default: () => [] },
    pageSize: { type: Number, default: 50 },
    rowKey: { type: String, default: '' },
    searchable: { type: Boolean, default: true },
    searchPlaceholder: { type: String, default: 'Поиск…' },
    searchKeys: { type: Array, default: null }, // client mode; null = stringify whole row
    height: { type: [String, Number], default: 440 },
    emptyMessage: { type: String, default: 'Ничего не найдено' }
  },
  data() {
    return { page: 1, query: '', loading: false, serverRows: [], serverTotal: 0, _t: null }
  },
  computed: {
    server() { return typeof this.loader === 'function' },
    filtered() {
      if (this.server) return this.serverRows
      const all = this.items || []
      const q = this.query.trim().toLowerCase()
      if (!q) return all
      return all.filter(row => this.matches(row, q))
    },
    total() { return this.server ? this.serverTotal : this.filtered.length },
    pageRows() {
      if (this.server) return this.serverRows
      const start = (this.page - 1) * this.pageSize
      return this.filtered.slice(start, start + this.pageSize)
    }
  },
  watch: {
    query() {
      this.page = 1
      if (this.server) this.debouncedFetch()
    },
    items() { if (this.page > this.maxPage()) this.page = 1 }
  },
  mounted() { if (this.server) this.fetch() },
  methods: {
    maxPage() { return Math.max(1, Math.ceil(this.total / this.pageSize)) },
    matches(row, q) {
      if (this.searchKeys) return this.searchKeys.some(k => String(row[k] ?? '').toLowerCase().includes(q))
      return JSON.stringify(row).toLowerCase().includes(q)
    },
    format(c, v, row) { return c.format ? c.format(v, row) : (v ?? '') },
    onPage(p) { this.page = p; if (this.server) this.fetch() },
    debouncedFetch() { clearTimeout(this._t); this._t = setTimeout(() => this.fetch(), 250) },
    async fetch() {
      if (!this.server) return
      this.loading = true
      try {
        const r = await this.loader({
          offset: (this.page - 1) * this.pageSize,
          limit: this.pageSize,
          query: this.query.trim()
        }) || {}
        this.serverRows = r.rows || []
        this.serverTotal = r.total ?? this.serverRows.length
      } catch (e) {
        this.serverRows = []; this.serverTotal = 0
      } finally {
        this.loading = false
      }
    },
    reload() { if (this.server) this.fetch() }
  }
}
</script>

<style scoped>
.oui-plist { display: flex; flex-direction: column; gap: var(--ds-3); }
.oui-plist__bar { display: flex; align-items: center; gap: var(--ds-3); }
.oui-plist__search { max-width: 320px; }
.oui-plist__count { font-size: 12px; }
.oui-plist__rows { display: flex; flex-direction: column; gap: var(--ds-2); }
.oui-plist__pager { display: flex; justify-content: flex-end; }
</style>
