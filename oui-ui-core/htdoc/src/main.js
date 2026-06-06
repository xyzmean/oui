/* SPDX-License-Identifier: MIT */
/*
 * Author: Jianhui Zhao <zhaojh329@gmail.com>
 */

import { createApp } from 'vue'
import VueAxios from 'vue-axios'
import axios from 'axios'
import App from './App.vue'
import router from './router'
import timers from './timers'
import i18n from './i18n'
import oui from './oui'
import ElementPlus from './element-plus'
import venusComponents from './components/venus'

/* VenusWRT design system — clean minimalism, overrides Element Plus tokens.
 * Loaded last so its variables win. */
import './assets/venus-ds.css'

const app = createApp(App)

app.use(VueAxios, axios)
app.use(router)
app.use(i18n)
app.use(oui)
app.use(timers)
app.use(ElementPlus)
app.use(venusComponents)

app.mount('#app')
