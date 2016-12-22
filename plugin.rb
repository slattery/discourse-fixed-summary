
enabled_site_setting :fixed_digest_enabled

after_initialize do
  require_dependency 'user_serializer'

  public_user_custom_fields_setting = SiteSetting.public_user_custom_fields

  if public_user_custom_fields_setting.empty?
    SiteSetting.set("public_user_custom_fields", "fixed_digest_emails|fixed_digest_deliveries")
  else
    if public_user_custom_fields_setting !~ /fixed_digest_emails/
      SiteSetting.set(
        "public_user_custom_fields",
        [SiteSetting.public_user_custom_fields, "fixed_digest_emails"].join("|")
      )
    end
    if public_user_custom_fields_setting !~ /fixed_digest_deliveries/
      SiteSetting.set(
        "public_user_custom_fields",
        [SiteSetting.public_user_custom_fields, "fixed_digest_deliveries"].join("|")
      )
    end
  end

  class ::UserSerializer
    alias_method :_custom_fields, :custom_fields
    def custom_fields
      if !object.custom_fields["fixed_digest_emails"]
        object.custom_fields["fixed_digest_emails"] = ""
        object.save
      end
      if !object.custom_fields["fixed_digest_deliveries"]
        object.custom_fields["fixed_digest_deliveries"] = "0900|1600"
        object.save
      end
      _custom_fields
    end
  end
end
