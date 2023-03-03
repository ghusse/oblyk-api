# frozen_string_literal: true

module Statistics
  class GymStatistic
    attr_accessor :gym, :date, :space_ids, :opener_ids, :routes

    def initialize(
      gym,
      date,
      space_ids: [],
      opener_ids: []
    )
      self.gym = gym
      self.date = date || Date.current
      self.space_ids = space_ids || []
      self.opener_ids = opener_ids || []
    end

    def figures
      self.routes ||= gym_routes
      ascents = AscentGymRoute.made.where(gym_route_id: routes.map(&:id))
      youngest_opening_date = routes.maximum(:opened_at)
      oldest_opening_date = routes.minimum(:opened_at)

      age_sum = 0
      routes.each do |route|
        age_sum += (date - route.opened_at).to_i
      end

      {
        route_count: routes.size,
        ascent_count: ascents.count,
        opening: {
          youngest_opening_date: youngest_opening_date,
          oldest_opening_date: oldest_opening_date,
          oldest_route_age: oldest_opening_date ? (date - oldest_opening_date).to_i : nil,
          youngest_route_age: youngest_opening_date ? (date - youngest_opening_date).to_i : nil,
          average_route_age: routes.size.positive? ? (age_sum / routes.size).round.to_i : nil
        },
        grade: {
          max_value: routes.maximum(:max_grade_value),
          min_value: routes.minimum(:min_grade_value),
          average_value: routes.average(:max_grade_value)&.round
        }
      }
    end

    def routes_by_grades
      self.routes ||= gym_routes

      grades = {}
      54.times do |grade_value|
        next unless grade_value.even?

        grades[grade_value + 1] = { count: 0 }
      end

      routes.each do |route|
        next if route.min_grade_value.blank? || route.min_grade_value.zero?

        grade_value = route.min_grade_value
        grade_value -= 1 if grade_value.even?

        grades[grade_value][:count] += 1
      end

      {
        datasets: [
          {
            data: grades.map { |grade| grade[1][:count] },
            backgroundColor: grades.map { |grade| Grade.value_color(grade[0] - 1) },
            label: 'number'
          }
        ],
        labels: grades.map { |grade| grade[0] }
      }
    end

    def routes_by_levels
      self.routes ||= gym_routes

      charts = []
      gym_routes.group_by { |route| route.gym_grade_line&.gym_grade&.id }.each do |_key, routes_in_level|
        next if routes_in_level.first.gym_grade_line.blank?

        gym_grade = routes_in_level.first.gym_grade_line.gym_grade
        background = []
        labels = []
        data = []
        gym_grade.gym_grade_lines.each do |gym_grade_line|
          background << gym_grade_line.colors.first
          labels << gym_grade_line.name
          data << routes_in_level.sum { |route| route.gym_grade_line_id == gym_grade_line.id ? 1 : 0 }
        end

        charts << {
          type: 'level_chart',
          gym_grade: gym_grade.detail_to_json,
          chart: {
            datasets: [
              {
                data: data,
                backgroundColor: background,
                label: 'level'
              }
            ],
            labels: labels
          }
        }
      end
      charts
    end

    def notes
      self.routes ||= gym_routes
      ascents = AscentGymRoute.made
                              .where(gym_route_id: routes.pluck(:id))
                              .where
                              .not(note: nil)
      notes = {}
      7.times do |note|
        notes[note] = 0
      end

      ascents.each do |ascent|
        notes[ascent.note] += 1
      end
      notes
    end

    def opening_frequencies
      self.routes ||= gym_routes

      if routes.size.zero?
        return {
          datasets: [{}],
          labels: []
        }
      end

      oldest_opening_date = routes.minimum(:opened_at)
      dates = {}

      (oldest_opening_date..date).each do |date|
        dates[date.strftime('%Y-%m-%d')] ||= { count: 0 }
      end

      routes.each do |route|
        dates[route.opened_at.strftime('%Y-%m-%d')][:count] += 1
      end

      {
        datasets: [
          {
            data: dates.map { |date| date[1][:count] },
            backgroundColor: '#31994e',
            label: 'number'
          }
        ],
        labels: dates.map { |date| date[0] }
      }
    end

    private

    def gym_routes
      routes = gym.gym_routes
                  .joins(gym_sector: :gym_space)
                  .where('gym_routes.opened_at <= :date AND (gym_routes.dismounted_at IS NULL OR gym_routes.dismounted_at >= :date)', date: date)
      routes = routes.where(gym_spaces: { id: space_ids }) if space_ids.size.positive?
      routes = routes.where('EXISTS(SELECT * FROM gym_route_openers WHERE gym_opener_id IN (:opener_ids) AND gym_route_id = gym_routes.id)', opener_ids: opener_ids) if opener_ids.size.positive?
      routes
    end
  end
end