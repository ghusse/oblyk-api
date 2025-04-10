# frozen_string_literal: true

class GymRouteCover < ApplicationRecord
  include AttachmentResizable

  has_one_attached :picture

  has_many :gym_routes

  after_save :delete_caches

  validates :picture, blob: { content_type: :image }, allow_nil: true

  def summary_to_json
    Rails.cache.fetch("#{cache_key_with_version}/summary_gym_route_cover", expires_in: 28.days) do
      {
        id: id,
        original_file_path: original_file_path,
        attachments: {
          picture: attachment_object(picture)
        }
      }
    end
  end

  def original_file_path
    "#{ENV.fetch('IMAGES_STORAGE_DOMAINE', ENV['OBLYK_API_URL'])}/#{picture&.blob&.key}"
  end

  def detail_to_json
    summary_to_json.merge(
      {
        history: {
          created_at: created_at,
          updated_at: updated_at
        }
      }
    )
  end

  def delete_summary_cache
    Rails.cache.delete("#{cache_key_with_version}/summary_gym_route_cover")
  end

  private

  def delete_caches
    gym_routes.each(&:delete_summary_cache)
  end
end
