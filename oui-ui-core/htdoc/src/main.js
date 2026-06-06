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

/* VenusWRT sky/ember brand — overrides Element Plus palette (load last). */
import './assets/venus-brand.css'

const app = createApp(App)

app.use(VueAxios, axios)
app.use(router)
app.use(i18n)
app.use(oui)
app.use(timers)
app.use(ElementPlus)

app.mount('#app')
