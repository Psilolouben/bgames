class Bgame < ActiveRecord::Base
  scope :starting_with_a, -> { where('name like \'A%\'') }
end
