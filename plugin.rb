# name: discourse-fixed-summary
# about: Discourse Fixed Summary
# version: 0.2
# authors: Mike Slattery
# url: https://github.com/slattery/discourse-fixed-summary

enabled_site_setting :fixed_digest_enabled

after_initialize do


  register_editable_user_custom_field :fixed_digest_emails
  register_editable_user_custom_field :fixed_digest_deliveries

  User.register_custom_field_type 'fixed_digest_emails', :boolean

  DiscoursePluginRegistry.serialized_current_user_fields << 'fixed_digest_emails'
  DiscoursePluginRegistry.serialized_current_user_fields << 'fixed_digest_deliveries'

  [
    '../app/jobs/scheduled/fixed_daily_digest.rb',
    '../app/jobs/regular/process_fixed_digest.rb',
    '../app/jobs/regular/fixed_digest_user_email.rb',
    '../app/mailers/fixed_digest_user_notifications.rb',
    '../app/helpers/fixed_digest_user_notifications_helper.rb'
   ].each { |path| load File.expand_path(path, __FILE__) }

end
