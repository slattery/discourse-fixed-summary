module Jobs
  # A daily job that will enqueue digest emails to be sent to users at fixed times
  class ProcessFixedDigest < Jobs::Base
  #  was Jobs::Scheduled every 1.hour

    def execute(args)
      match_hrs = Time.now.in_time_zone('America/New_York').hour
      match_arr = %w[0000 0100 0200 0300 0400 0500 0600 0700 0800 0900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 2100 2200 2300];
      @match_str = match_arr.at(match_hrs) || '0000'

      if SiteSetting.fixed_digest_enabled?
        #if match_hrs >= 7 && match_hrs <= 20
          Rails.logger.warn("[FIXED SUMMARY] trying to match users for #{@match_str}")
          target_user_ids.each do |user_id|
            Rails.logger.warn("[FIXED SUMMARY] trying to send digest to #{user_id} for #{@match_str} delivery")
            Jobs.enqueue(:fixed_digest_user_email, type: :digest, since: 1.day.ago, user_id: user_id)
          end
        #end
      end
    end

    def target_user_ids
      # Users who want to receive digest email within their chosen digest email frequency
      query = User.real
                  .where(active: true, staged: false)
                  .joins("INNER JOIN user_custom_fields ok ON ok.user_id = users.id")
                  .where("ok.name = 'fixed_digest_emails' AND ( ok.value = 'true' OR ok.value = 't' )")
                  .joins("INNER JOIN user_custom_fields deliveries ON deliveries.user_id = users.id")
                  .where("deliveries.name = 'fixed_digest_deliveries' AND deliveries.value ~* ?", "#{@match_str}")

      # If the site requires approval, make sure the user is approved
      if SiteSetting.must_approve_users?
        query = query.where("approved OR moderator OR admin")
      end
      query.pluck('deliveries.user_id')
    end

  end
end
