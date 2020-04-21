module RedmineMessenger
  module Patches
    module PasswordPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :send_messenger_create
          after_update :send_messenger_update
        end
      end

      module InstanceMethods
        def send_messenger_create
          return unless Messenger.setting_for_project(project, :post_password)
          return if is_private?
          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          Messenger.speak(l(:label_messenger_password_created,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{name}>",
                            user: Messenger.author_to_mention(User.current)),
                          channels, url, project: project)
        end

        def send_messenger_update
          return unless Messenger.setting_for_project(project, :post_password_updates)
          return if is_private?
          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url
          Messenger.speak(l(:label_messenger_password_updated,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{name}>",
                            user: Messenger.author_to_mention(User.current)),
                          channels, url, project: project)
        end
      end
    end
  end
end

unless Password.included_modules.include? RedmineMessenger::Patches::PasswordPatch
  Password.send(:include, RedmineMessenger::Patches::PasswordPatch)
end
