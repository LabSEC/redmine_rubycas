module AccountControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :login, :cas
      alias_method_chain :logout, :cas
    end
  end

  module InstanceMethods
    def login_with_cas
      if params[:username].blank? && params[:password].blank? && RedmineRubyCas.enabled?
        if session[:user_id].blank? && CASClient::Frameworks::Rails::Filter.filter(self)
          attributes = RedmineRubyCas.user_extra_attributes_from_session session
          login_name = attributes['login']
          user = User.find_by_login login_name
          if user.nil?
            user = User.new do |u|
              u.login = login_name
              u.mail = login_name+RedmineRubyCas.setting("user_email_host")
              u.firstname = t('first_name')
              u.lastname = t('last_name')
              u.admin = false
              u.language = Setting.default_language
              u.random_password
            end
          end
          if user.new_record?
            if RedmineRubyCas.setting("auto_create_users") == "true"
              user.attributes = RedmineRubyCas.user_extra_attributes_from_session(session)
              user.status = User::STATUS_REGISTERED
              register_automatically(user) do
                onthefly_creation_failed(user)
              end
            else
              render_error(
                  :message => l(:cas_user_not_found, :user => session[:"#{RedmineRubyCas.setting("username_session_key")}"]),
                  :status => 401
              )
            end
          else
            if user.active?
              if RedmineRubyCas.setting("auto_update_users") == "true"
                user.update_attributes(RedmineRubyCas.user_extra_attributes_from_session(session))
              end
              successful_authentication(user)
            else
              render_error(
                  :message => l(:cas_user_not_found, :user => session[:"#{RedmineRubyCas.setting("username_session_key")}"]),
                  :status => 401
              )
            end
          end
        end
      else
        login_without_cas
      end
    end

    def logout_with_cas
      if RedmineRubyCas.enabled? && RedmineRubyCas.setting("logout_of_cas_on_logout") == "true"
        CASClient::Frameworks::Rails::Filter.logout(self, home_url)
        logout_user
      else
        logout_without_cas
      end
    end
  end
end
