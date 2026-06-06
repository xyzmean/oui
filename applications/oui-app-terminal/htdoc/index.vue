<!--
  Web terminal — embeds ttyd (xterm.js over websocket), like luci-app-ttyd.
  Two ttyd instances run on the router: a general login console (:7681) and the
  Zapret-Manager interactive menu (:7682). We iframe them by the page's own host
  so it works on both the device LAN IP and the dev VM. ttyd has origin-check
  off, so the cross-port websocket from this page connects fine.
-->
<template>
  <div class="ds-page">
    <oui-section title="Терминал" :subtitle="sub">
      <el-radio-group :model-value="mode" @change="switchMode">
        <el-radio-button value="console">Консоль</el-radio-button>
        <el-radio-button value="zapret">Zapret-Manager</el-radio-button>
      </el-radio-group>
      <el-button @click="reload">Перезапустить сессию</el-button>
      <el-button @click="openTab">В новой вкладке</el-button>
    </oui-section>

    <oui-card flush>
      <div class="term-wrap">
        <iframe ref="frame" :key="frameKey" :src="src" class="term-frame" allow="clipboard-read; clipboard-write" />
      </div>
    </oui-card>

    <p class="ds-sub" style="margin-top:8px">
      Терминал работает по {{ host }}:{{ port }}. Если окно пустое — служба ttyd должна быть запущена,
      а порт {{ port }} доступен из вашей сети.
    </p>
  </div>
</template>

<script>
const PORTS = { console: 7681, zapret: 7682 }

export default {
  data() {
    const run = (this.$route?.query?.run || '').toString()
    return {
      mode: run === 'zapret-manager' || run === 'zapret' ? 'zapret' : 'console',
      frameKey: 0
    }
  },
  computed: {
    port() { return PORTS[this.mode] || 7681 },
    host() { return location.hostname },
    src() { return `${location.protocol}//${location.hostname}:${this.port}/` },
    sub() { return this.mode === 'zapret' ? 'Zapret-Manager — подбор стратегий обхода DPI' : 'Полноценная консоль роутера (login)' }
  },
  watch: {
    '$route'(to) {
      const run = (to.query.run || '').toString()
      const m = (run === 'zapret-manager' || run === 'zapret') ? 'zapret' : 'console'
      if (m !== this.mode) { this.mode = m; this.frameKey++ }
    }
  },
  methods: {
    switchMode(m) { this.mode = m; this.frameKey++ },
    reload() { this.frameKey++ },
    openTab() { window.open(this.src, '_blank') }
  }
}
</script>

<style scoped>
.term-wrap { background: #0b0e14; border-radius: var(--ds-radius); overflow: hidden; }
.term-frame { width: 100%; height: 70vh; min-height: 460px; border: 0; display: block; background: #0b0e14; }
</style>
