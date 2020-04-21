module RedmineMessenger
  module Patches
    module IssuePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :send_messenger_create
          after_update :send_messenger_update
        end
      end

      module InstanceMethods
        def send_messenger_create
          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url
          return if is_private? && !Messenger.setting_for_project(project, :post_private_issues)

          set_language_if_valid Setting.default_language

          attachment = {}
          if description.present? && Messenger.setting_for_project(project, :new_include_description)
            attachment[:text] = Messenger.markup_format(description)
          end
          attachment[:fields] = [{ title: I18n.t(:field_status),
                                   value: ERB::Util.html_escape(status.to_s),
                                   short: true },
                                 { title: I18n.t(:field_priority),
                                   value: ERB::Util.html_escape(priority.to_s),
                                   short: true }]
          if assigned_to.present?
            attachment[:fields] << { title: I18n.t(:field_assigned_to),
                                     value: ERB::Util.html_escape(assigned_to.to_s),
                                     short: true }
          end

          if RedmineMessenger.setting?(:display_watchers) && watcher_users.count > 0
            attachment[:fields] << {
              title: I18n.t(:field_watcher),
              value: ERB::Util.html_escape(watcher_users.join(', ')),
              short: true
            }
          end

          Messenger.speak(l(:label_messenger_issue_created,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: send_messenger_mention_url(project, description),
                            user: Messenger.author_to_mention(author)),
                          channels, url, attachment: attachment, project: project)
        end

        def send_messenger_update
          return if current_journal.nil?

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url && Messenger.setting_for_project(project, :post_updates)
          return if is_private? && !Messenger.setting_for_project(project, :post_private_issues)
          return if current_journal.private_notes? && !Messenger.setting_for_project(project, :post_private_notes)

          set_language_if_valid Setting.default_language

          attachment = {}
          if current_journal.notes.present? && Messenger.setting_for_project(project, :updated_include_description)
            attachment[:text] = Messenger.markup_format(current_journal.notes)
          end

          fields = current_journal.details.map { |d| Messenger.detail_to_field d }
          if status_id != status_id_was
            fields << { title: I18n.t(:field_status),
                        value: ERB::Util.html_escape(status.to_s),
                        short: true }
          end
          if priority_id != priority_id_was
            fields << { title: I18n.t(:field_priority),
                        value: ERB::Util.html_escape(priority.to_s),
                        short: true }
          end
          if assigned_to.present?
            fields << { title: I18n.t(:field_assigned_to),
                        value: ERB::Util.html_escape(assigned_to.to_s),
                        short: true }
          end
          attachment[:fields] = fields if fields.any?

          Messenger.speak(l(:label_messenger_issue_updated,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: send_messenger_mention_url(project, current_journal.notes),
                            user: Messenger.author_to_mention(current_journal.user)),
                          channels, url, attachment: attachment, project: project)
        end

        private

        def send_messenger_mention_url(project, text)
          mention_to = ''
          if Messenger.setting_for_project(project, :auto_mentions) ||
             Messenger.textfield_for_project(project, :default_mentions).present?
            mention_to = Messenger.mentions(project, text)
          end
          "<#{Messenger.object_url(self)}|#{ERB::Util.html_escape(self)}>#{mention_to}"
        end
      end
    end
  end
end

Issue.send(:include, RedmineMessenger::Patches::IssuePatch) unless Issue.included_modules.include? RedmineMessenger::Patches::IssuePatch
