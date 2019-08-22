# frozen_string_literal: true

require_dependency 'email/sender'
require_relative   '../../mailers/fixed_digest_user_notifications.rb'

module Jobs

  # Asynchronously send an email to a user
  class FixedDigestUserEmail < Jobs::Base
    include Skippable

    sidekiq_options queue: 'low'

    # Can be overridden by subclass, for example critical email
    # should always consider being sent
    def quit_email_early?
      SiteSetting.disable_emails == 'yes'
    end

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      raise Discourse::InvalidParameters.new(:type)    unless args[:type].present?

      # This is for performance. Quit out fast without doing a bunch
      # of extra work when emails are disabled.
      return if quit_email_early?

      post = nil
      notification = nil
      type = args[:type]
      user = User.find_by(id: args[:user_id])
      to_address = args[:to_address].presence || user.try(:email).presence || "no_email_found"

      set_skip_context(type, args[:user_id], to_address, args[:post_id])

      return skip(SkippedEmailLog.reason_types[:user_email_no_user]) unless user

      Rails.logger.warn("[FIXED SUMMARY] entering message builder")

      message, skip_reason_type = message_for_email(
        user,
        post,
        type,
        notification,
        args
      )

      if message
        Rails.logger.warn("[FIXED SUMMARY] output is #{message}")
        Email::Sender.new(message, type, user).send

        if (b = user.user_stat.bounce_score) > SiteSetting.bounce_score_erode_on_send
          # erode bounce score each time we send an email
          # this means that we are punished a lot less for bounces
          # and we can recover more quickly
          user.user_stat.update(bounce_score: b - SiteSetting.bounce_score_erode_on_send)
        end
      else
        skip_reason_type
      end
    end

    def set_skip_context(type, user_id, to_address, post_id)
      @skip_context = { type: type, user_id: user_id, to_address: to_address, post_id: post_id }
    end

    def message_for_email(user, post, type, notification, args = nil)
      args ||= {}

      email_token = args[:email_token]
      to_address = args[:to_address]

      set_skip_context(type, user.id, to_address || user.email, post.try(:id))

      if user.anonymous?
        return skip_message(SkippedEmailLog.reason_types[:user_email_anonymous_user])
      end

      if user.suspended? && !["user_private_message", "account_suspended"].include?(type.to_s)
        return skip_message(SkippedEmailLog.reason_types[:user_email_user_suspended_not_pm])
      end


      interval = SiteSetting.default_email_digest_frequency.to_s
      Rails.logger.warn("[FIXED SUMMARY] interval is #{interval}")

      if type.to_s == "digest"
        return if user.staged
      end

      email_args = {}

      email_args[:post] = post if post
      email_args[:since] = args[:since] if args[:since]

      # Make sure that mailer exists
      raise Discourse::InvalidParameters.new("type=#{type}") unless FixedDigestUserNotifications.respond_to?(type)

      email_args[:email_token] = email_token if email_token.present?
      email_args[:new_email] = user.email if type.to_s == "notify_old_email"

      if args[:client_ip] && args[:user_agent]
        email_args[:client_ip] = args[:client_ip]
        email_args[:user_agent] = args[:user_agent]
      end

      if EmailLog.reached_max_emails?(user, type.to_s)
        return skip_message(SkippedEmailLog.reason_types[:exceeded_emails_limit])
      end

      if !EmailLog::CRITICAL_EMAIL_TYPES.include?(type.to_s) && user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold
        return skip_message(SkippedEmailLog.reason_types[:exceeded_bounces_limit])
      end

      if args[:user_history_id]
        email_args[:user_history] = UserHistory.where(id: args[:user_history_id]).first
      end

      message = EmailLog.unique_email_per_post(post, user) do
        FixedDigestUserNotifications.public_send(type, user, email_args)
      end

      # Update the to address if we have a custom one
      message.to = to_address if message && to_address.present?

      [message, nil]
    end

    sidekiq_retry_in do |count, exception|
      # retry in an hour when SMTP server is busy
      # or use default sidekiq retry formula
      case exception.wrapped
      when Net::SMTPServerBusy
        1.hour + (rand(30) * (count + 1))
      else
        Jobs::FixedDigestUserEmail.seconds_to_delay(count)
      end
    end

    # extracted from sidekiq
    def self.seconds_to_delay(count)
      (count**4) + 15 + (rand(30) * (count + 1))
    end

    private

    def skip_message(reason)
      [nil, skip(reason)]
    end


    def skip(reason_type)
      create_skipped_email_log(
        email_type: @skip_context[:type],
        to_address: @skip_context[:to_address],
        user_id: @skip_context[:user_id],
        post_id: @skip_context[:post_id],
        reason_type: reason_type
      )
    end

    def always_email_private_message?(user, type)
      type == :user_private_message && user.user_option.email_messages_level == UserOption.email_level_types[:always]
    end

    def always_email_regular?(user, type)
      type != :user_private_message && user.user_option.email_level == UserOption.email_level_types[:always]
    end
  end

end