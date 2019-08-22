module Jobs
  # A daily job that will enqueue digest emails to be sent to users at fixed times
  # We do this because of time slides with queued jobs.
  # When they run they may start just before the hour and we skip the schedule.
  class EnqueueFixedDigestEmails < Jobs::Scheduled
    daily at: 11.hours

    def execute(args)
      if SiteSetting.fixed_digest_enabled?
        (1..12).each do |n|
          Jobs.enqueue_at(n.hours.from_now, :process_fixed_digest, {})
        end
      end
    end

  end
end