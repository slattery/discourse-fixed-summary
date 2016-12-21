
enabled_site_setting :fixed_summary_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "fixed_summary_emails"
DiscoursePluginRegistry.serialized_current_user_fields << "fixed_summary_deliveries"

after_initialize do

  User.register_custom_field_type('fixed_summary_emails', :boolean)
  User.register_custom_field_type('fixed_summary_deliveries', :text)

  if SiteSetting.fixed_summary_enabled then
    add_to_serializer(:post, :fixed_summary_enabled, false) {
        object.user.custom_fields['fixed_summary_emails']
        object.user.custom_fields['fixed_summary_deliveries']
    }

    # I guess this should be the default @ discourse. PR maybe?
    add_to_serializer(:user, :custom_fields, false) {
      if object.custom_fields == nil then
        {}
      else
        object.custom_fields
      end
    }
  end
end
  