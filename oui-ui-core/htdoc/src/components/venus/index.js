/*
 * VenusWRT design-system components, registered globally on the host Vue app.
 * App views (loaded as UMD) resolve these by tag at runtime — exactly like the
 * built-in el-* components — so they cost nothing in each app's bundle.
 */
import OuiCard from './OuiCard.vue'
import OuiSection from './OuiSection.vue'
import OuiStat from './OuiStat.vue'
import OuiBadge from './OuiBadge.vue'
import OuiToggle from './OuiToggle.vue'
import OuiField from './OuiField.vue'
import OuiState from './OuiState.vue'
import OuiPaginatedList from './OuiPaginatedList.vue'

const components = {
  OuiCard, OuiSection, OuiStat, OuiBadge,
  OuiToggle, OuiField, OuiState, OuiPaginatedList
}

export default {
  install(app) {
    for (const name in components)
      app.component(name, components[name])
  }
}
