
enabled_site_setting :fixed_summary_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "fixed_digest_emails"
DiscoursePluginRegistry.serialized_current_user_fields << "fixed_digest_deliveries"

after_initialize do

  User.register_custom_field_type('fixed_digest_emails', :bool)
  User.register_custom_field_type('fixed_digest_deliveries', :text)

  if SiteSetting.fixed_digest_enabled then
    add_to_serializer(:post, :user_fixed_digest_emails, false) {
        object.user.custom_fields['fixed_digest_emails']
        object.user.custom_fields['fixed_digest_deliveries']
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
