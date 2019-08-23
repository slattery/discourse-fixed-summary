import { withPluginApi } from 'discourse/lib/plugin-api'

export default {
  name: 'fixed-summary',
  initialize() {
    withPluginApi('0.8.22', api => {
      api.modifyClass('controller:preferences/emails', {
        actions: {
          save () {
            this.get('saveAttrNames').push('custom_fields')
            this._super()
          }
        }
      })
      if (!Discourse.SiteSettings.fixed_digest_enabled) { return }
    })
  }
}