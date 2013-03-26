module Seek
  module Permissions
    module PublishingPermissions

      def self.included klass
        klass.class_eval do
          before_validation :temporary_policy_while_waiting_for_publishing_approval, :publishing_auth, :unless => "Seek::Config.is_virtualliver"
        end
      end

      def can_publish? user=User.current_user
        (Ability.new(user).can? :publish, self) || (can_manage?(user) && state_allows_publish?(user))
      end

      #(manager and projects have no gatekeeper) or (manager and the item was published)
      def state_allows_publish? user=User.current_user
        #FIXME: it should be possible to publish if there are gatekeepers, however the gatekeepers will need to approve the final step
        if self.new_record?
          self.gatekeepers.empty?
        else
          #FIXME:shouldn't be possible to publish something that is already published!
          self.gatekeepers.empty? || self.policy.sharing_scope_was == Policy::EVERYONE
        end
      end

      def publish!
        if can_publish?
          policy.access_type=Policy::ACCESSIBLE
          policy.sharing_scope=Policy::EVERYONE
          policy.save
          touch
        else
          false
        end
      end

      def is_published?
        if self.is_downloadable?
          can_download? nil
        else
          can_view? nil
        end
      end

      def can_send_publishing_request?(user=User.current_user)
        can_manage?(user) && ResourcePublishLog.last_waiting_approval_log(self,user).nil?
      end

      #the asset that can be published together with publishing the whole ISA
      def is_in_isa_publishable?
        #currently based upon the naive assumption that downloadable items are publishable, which is currently the case but may change.
        is_downloadable?
      end


      def publishing_auth
        return true if $authorization_checks_disabled
        #only check if doing publishing
        if self.policy.sharing_scope == Policy::EVERYONE && !self.kind_of?(Publication)
          unless self.can_publish?
            errors.add_to_base("You are not permitted to publish this #{self.class.name.underscore.humanize}")
            return false
          end
        end
      end

      #while item is waiting for publishing approval,set the policy of the item to:
      #new item: sysmo_and_project_policy
      #updated item: keep the policy as before
      def temporary_policy_while_waiting_for_publishing_approval
        return true if $authorization_checks_disabled
        if self.new_record? && self.policy.sharing_scope == Policy::EVERYONE && !self.kind_of?(Publication) && !self.can_publish?
          self.policy = Policy.sysmo_and_projects_policy self.projects
        elsif !self.new_record? && self.policy.sharing_scope == Policy::EVERYONE && !self.kind_of?(Publication) && !self.can_publish?
          self.policy = Policy.find_by_id(self.policy.id)
        end
      end

    end
  end
end
