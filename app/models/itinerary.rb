# frozen_string_literal: true

class Itinerary
  include Mongoid::Document
  include Mongoid::MultiParameterAttributes
  include Mongoid::Paranoia
  include Mongoid::Slug
  include Mongoid::Timestamps

  include GeoItinerary

  DAYNAME = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

  belongs_to :user
  delegate :name, to: :user, prefix: true
  delegate :first_name, to: :user, prefix: true

  has_many :conversations, as: :conversable, inverse_of: :conversable, dependent: :destroy

  # Details
  field :description
  field :num_people, type: Integer
  field :smoking_allowed, type: Boolean, default: false
  field :pets_allowed, type: Boolean, default: false
  field :fuel_cost, type: Integer, default: 0
  field :tolls, type: Integer, default: 0
  field :pink, type: Boolean, default: false
  field :round_trip, type: Boolean, default: false
  field :leave_date, type: DateTime
  field :return_date, type: DateTime
  field :daily, type: Boolean, default: false

  # Cached user details (for filtering purposes)
  field :driver_gender
  field :verified

  slug :start_address, :end_address, reserve: %w[new]

  # default_scope -> { any_of({:leave_date.gte => Time.now.utc}, {:return_date.gte => Time.now.utc, round_trip: true}, { daily: true }) }

  validates :description, length: { maximum: 1000 }, presence: true
  validates :num_people, numericality: { only_integer: true, greater_than: 0, less_than: 10 }, allow_blank: true
  validates :fuel_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10_000 }
  validates :tolls, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10_000 }
  validates :leave_date, timeliness: { on_or_after: -> { Time.current } }, on: :create
  validates :return_date, presence: true, if: -> { round_trip }

  validate :driver_is_female, if: -> { pink }
  validate :return_date_validator, if: -> { round_trip }

  def return_date_validator
    return unless return_date && return_date <= leave_date
    errors.add(:return_date,
               I18n.t('mongoid.errors.messages.after',
                      restriction: leave_date.strftime(I18n.t('validates_timeliness.error_value_formats.datetime'))))
  end

  def driver_is_female
    errors.add(:pink, :driver_must_be_female) unless user.female?
  end

  before_create do
    self.driver_gender = user.gender
    self.verified = user.facebook_verified
    true
  end

  def title
    [start_address, end_address].join ' - '
  end

  def to_s
    title || id
  end
end
