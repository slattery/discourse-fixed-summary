# frozen_string_literal: true

require_dependency 'markdown_linker'
require_dependency 'email/message_builder'
require_dependency 'age_words'
require_dependency 'rtl'
require_dependency 'discourse_ip_info'
require_dependency 'browser_detection'
require_relative   '../helpers/fixed_digest_user_notifications_helper.rb'


class FixedDigestUserNotifications < ActionMailer::Base
  include FixedDigestUserNotificationsHelper
  include ApplicationHelper
  helper :application, :email
  default charset: 'UTF-8'
  prepend_view_path(Rails.root.join('plugins', 'discourse-fixed-summary', 'app', 'views'))
  layout 'email_template'

  include Email::BuildEmailHelper

  def short_date(dt)
    if dt.year == Time.now.year
      I18n.l(dt, format: :short_no_year)
    else
      I18n.l(dt, format: :date_only)
    end
  end

  def digest(user, opts = {})
    build_summary_for(user)
    min_date = opts[:since] || user.last_emailed_at || user.last_seen_at || 1.month.ago
    Rails.logger.warn("fixed summary - entering digest func")
    # Fetch some topics and posts to show
    digest_opts = { limit: SiteSetting.digest_topics + SiteSetting.digest_other_topics, top_order: true }
    topics_for_digest = Topic.for_digest(user, min_date, digest_opts).to_a
    if topics_for_digest.empty? && !user.user_option.try(:include_tl0_in_digests)
      # Find some topics from new users that are at least 24 hours old
      topics_for_digest = Topic.for_digest(user, min_date, digest_opts.merge(include_tl0: true)).where('topics.created_at < ?', 24.hours.ago).to_a
    end

    @recent_topics = topics_for_digest[0, SiteSetting.digest_topics]

    if @recent_topics.present?
      @other_new_for_you = topics_for_digest.size > SiteSetting.digest_topics ? topics_for_digest[SiteSetting.digest_topics..-1] : []

      @recent_posts = if SiteSetting.digest_posts > 0
        Post.order("posts.updated_at DESC")
          .for_mailing_list(user, min_date)
          .where('posts.post_type = ?', Post.types[:regular])
          .where('posts.deleted_at IS NULL AND posts.hidden = false AND posts.user_deleted = false')
          .where("posts.post_number > ?", 1)
          .where('posts.created_at < ?', (SiteSetting.editing_grace_period || 0).seconds.ago)
          .limit(SiteSetting.digest_posts)
      else
        []
      end

      @excerpts = {}

      @recent_topics.map do |t|
        @excerpts[t.first_post.id] = FixedDigestUserNotificationsHelper.email_excerpt(t.first_post.cooked, t.first_post) if t.first_post.present?
      end

      # Try to find 3 interesting stats for the top of the digest
      new_topics_count = Topic.for_digest(user, min_date).count

      if new_topics_count == 0
        # We used topics from new users instead, so count should match
        new_topics_count = topics_for_digest.size
      end
      @counts = [{ label_key: 'fixed_digest_user_notifications.digest.new_topics',
                   value: new_topics_count,
                   href: "#{Discourse.base_url}/new" }]

      value = user.unread_notifications
      @counts << { label_key: 'fixed_digest_user_notifications.digest.unread_notifications', value: value, href: "#{Discourse.base_url}/my/notifications" } if value > 0

      value = user.unread_private_messages
      @counts << { label_key: 'fixed_digest_user_notifications.digest.unread_messages', value: value, href: "#{Discourse.base_url}/my/messages" } if value > 0

      if @counts.size < 3
        value = user.unread_notifications_of_type(Notification.types[:liked])
        @counts << { label_key: 'fixed_digest_user_notifications.digest.liked_received', value: value, href: "#{Discourse.base_url}/my/notifications" } if value > 0
      end

      if @counts.size < 3
        value = User.real.where(active: true, staged: false).not_suspended.where("created_at > ?", min_date).count
        @counts << { label_key: 'fixed_digest_user_notifications.digest.new_users', value: value, href: "#{Discourse.base_url}/about" } if value > 0
      end

      @last_seen_at = short_date(user.last_seen_at || user.created_at)

      @preheader_text = I18n.t('fixed_digest_user_notifications.digest.preheader', last_seen_at: @last_seen_at)

      opts = {
        from_alias: I18n.t('fixed_digest_user_notifications.digest.from', site_name: Email.site_title),
        subject: I18n.t('fixed_digest_user_notifications.digest.subject_template', email_prefix: @email_prefix, date: short_date(Time.now)),
        add_unsubscribe_link: false,
        unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}",
      }

      build_email(user.email, opts)
    end
  end

  private

  def build_summary_for(user)
    @site_name       = SiteSetting.email_prefix.presence || SiteSetting.title # used by I18n
    @user            = user
    @date            = short_date(Time.now)
    @base_url        = Discourse.base_url
    @email_prefix    = SiteSetting.email_prefix.presence || SiteSetting.title
    @header_color    = ColorScheme.hex_for_name('header_primary')
    @header_bgcolor  = ColorScheme.hex_for_name('header_background')
    @anchor_color    = ColorScheme.hex_for_name('tertiary')
    @markdown_linker = MarkdownLinker.new(@base_url)
    @unsubscribe_key = UnsubscribeKey.create_key_for(@user, "digest")
    @disable_email_custom_styles = !SiteSetting.apply_custom_styles_to_digest
  end
end