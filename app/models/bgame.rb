class Bgame < ActiveRecord::Base
  scope :starting_with_a, -> { where('name like \'A%\'') }
  scope :todays, -> { where('created_at BETWEEN ? AND ?', DateTime.now.beginning_of_day, DateTime.now.end_of_day) }
end
