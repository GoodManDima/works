class Location < ActiveRecord::Base
  include Filterable
  include Collectable

  has_many :trip_locations, dependent: :destroy
  has_many :trips, through: :trip_locations
  has_many :post_locations, dependent: :destroy
  has_many :posts, through: :post_locations

  extend FriendlyId
  friendly_id :slug_candidates, use: [:slugged, :history]

  scope :dropdown, -> { where(dropdown: true) }
  scope :show, -> { where(show: true) }

  def slug_candidates
    [:name, [:id, :name]]
  end

  def should_generate_new_friendly_id?
    name_changed? || !has_friendly_id_slug?
  end

  def has_friendly_id_slug?
    slugs.where(slug: slug).exists?
  end

  def normalize_friendly_id(text)
    text.to_slug.normalize(transliterations: :russian).to_s
  end

  class << self
    def join_in_one(name, ids)
      # Находим/создаем локацию, в которую будем объединять выбранные локации
      location = Location.find_or_create_by(name: name.strip)

      # Делаем (downcase и strip) для поиска совпадений с локацией в которую объединяем
      similar_main_loc = name.mb_chars.downcase.to_s.strip

      # Делаем (downcase и strip) для поиска совпадений с локациями, которые объединяем
      similar_other_loc = Location.where(id: ids).pluck(:name).map { |e| e.mb_chars.downcase.to_s.strip }

      # Находим все локации, которые совпадают с локациями, выбранными для объединения или с локацией в которую объединяем
      similar = ([similar_main_loc] + similar_other_loc).uniq
      other_locations = Location.where('lower(name) IN (?)', similar).pluck(:id)

      ids = (ids + other_locations).uniq
      Trip.includes(:trip_locations).where(trip_locations: { location: ids }).each do |trip|
        t_locs = trip.trip_locations.order(:position)
        position = t_locs.select { |e| ids.include?(e.location_id) }.first.position

        trip.trip_locations = t_locs.select { |e| !ids.include?(e.location_id) }
        trip.trip_locations.create(location_id: location.id, position: position)
        trip.set_tags_and_locations
      end
      remove_ids = ids - [location.id]
      Location.where(id: remove_ids).destroy_all
      Location.reset_counters location.id, :trips
    end
  end

  def remove
    Location.transaction do
      begin
        trips.each { |t| t.remove_location(self) }
        destroy
      rescue
        return false
      end
      return true
    end
  end

  def set_weight
    if trip_locations.present?
      len = trip_locations.length
      sorted = trip_locations.order(:position).pluck(:position)
      weight = len % 2 == 1 ? sorted[len/2] : (sorted[len/2 - 1] + sorted[len/2]) / 2
    else
      weight = nil
    end
    update_column(:weight, weight)
  end
end

# Идея рефактора состоит в том, чтобы добавить в locations колонку position_average,
# в которую коллбеком, или ночным воркером записывать среднее значение ее позиции по связанным
# location_trips.position. Как правило нам важны только самые первые локации, которые будут часто
# соответствовать типичному положению этой локации.
