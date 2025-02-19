module Seek
  module ProjectAssociation
    def self.included(klass)
      klass.class_eval do
        include Seek::ProjectHierarchies::ItemsProjectsExtension if Seek::Config.project_hierarchy_enabled

        join_table_name = [table_name, 'projects'].sort.join('_')
        has_and_belongs_to_many :projects, join_table: "#{join_table_name}",
                                           before_add: :react_to_project_addition,
                                           before_remove: :react_to_project_removal
        has_many :programmes, through: :projects

        after_save -> { @project_additions = [] }

        validates :projects, presence: true, unless: proc { |object|
          Seek::Config.is_virtualliver ||
            object.is_a?(Strain)
        }

        def project_additions
          @project_additions ||= []
          @project_additions
        end

        def react_to_project_addition(project)
          project_additions << project
          SetSubscriptionsForItemJob.new(self, [project]).queue_job if !self.new_record? && self.subscribable?
          update_rdf_on_associated_change(project) if self.respond_to?(:update_rdf_on_associated_change)
        end

        def react_to_project_removal(project)
          RemoveSubscriptionsForItemJob.new(self, [project]).queue_job if self.subscribable?
          create_rdf_generation_job(true) if self.respond_to?(:create_rdf_generation_job)
        end
      end
    end
  end
end
