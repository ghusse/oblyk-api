# frozen_string_literal: true

module Api
  module V1
    class GymSectorsController < ApiController
      include Gymable
      skip_before_action :protected_by_session, only: %i[show index]
      skip_before_action :protected_by_gym_administrator, only: %i[show index]
      before_action :set_gym_space
      before_action :set_gym_sector, only: %i[show update destroy dismount_routes last_routes_with_pictures]
      before_action -> { can? GymRole::MANAGE_SPACE }, except: %i[index show]

      def index
        gym_sectors = @gym_space.gym_sectors
        render json: gym_sectors.map(&:summary_to_json), status: :ok
      end

      def show
        render json: @gym_sector.detail_to_json, status: :ok
      end

      def create
        @gym_sector = GymSector.new(gym_sector_params)
        @gym_sector.gym_space = @gym_space
        if @gym_sector.save
          render json: @gym_sector.detail_to_json, status: :ok
        else
          render json: { error: @gym_sector.errors }, status: :unprocessable_entity
        end
      end

      def update
        if @gym_sector.update(gym_sector_params)
          render json: @gym_sector.detail_to_json, status: :ok
        else
          render json: { error: @gym_sector.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        if @gym_sector.destroy
          head :no_content
        else
          render json: { error: @gym_sector.errors }, status: :unprocessable_entity
        end
      end

      def dismount_routes
        routes = GymRoute.mounted.where(gym_sector: @gym_sector)
        routes.each(&:dismount!)
        render json: @gym_sector.detail_to_json, status: :ok
      end

      def last_routes_with_pictures
        json_data = []
        @gym_sector.gym_routes
                   .joins(:picture_attachment)
                   .where(duplicate_picture: false)
                   .order(created_at: :desc)
                   .limit(params.fetch(:limit, 5))
                   .each do |gym_route|
          summary = gym_route.summary_to_json
          summary[:picture] = gym_route.picture_large_url
          summary[:history] = {
            created_at: gym_route.created_at,
            updated_at: gym_route.updated_at
          }
          json_data << summary
        end
        render json: json_data, status: :ok
      end

      private

      def set_gym_sector
        @gym_sector = GymSector.find params[:id]
      end

      def set_gym_space
        @gym_space = GymSpace.find params[:gym_space_id]
      end

      def gym_sector_params
        params.require(:gym_sector).permit(
          :name,
          :order,
          :description,
          :group_sector_name,
          :climbing_type,
          :height,
          :banner_bg_color,
          :polygon,
          :gym_grade_id,
          :can_be_more_than_one_pitch
        )
      end
    end
  end
end
