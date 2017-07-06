class InstitutionSerializer < AvatarObjSerializer
  attributes :id, :title,
             :country, :city, :address,
             :web_page
end


# using active_model_serializer - if we switch to RAILS >= 4
# class InstitutionSerializer < ActiveModel::Serializer
#   attributes :id, :title, :country, :city, :web_page
#   has_many :projects
#   has_many :people
# end