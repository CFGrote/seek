class PCSSerializer < BaseSerializer
  has_many :creators, include_data:true
  has_one :submitter
  has_one :policy, include_data:true
  attribute :tags do
    serialize_annotations(object)
  end

  def submitter
    determine_submitter object
  end

end
