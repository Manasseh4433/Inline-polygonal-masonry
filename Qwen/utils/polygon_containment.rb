# frozen_string_literal: true

module PolygonalMasonry
  # Проверка вхождения точки в полигон
  class PolygonContainment
    # Проверить, находится ли точка внутри полигона
    # Использует алгоритм Ray Casting
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @param polygon [Array<Array<Float>>] Массив точек полигона [[x, y], ...]
    # @return [Boolean] true если точка внутри полигона
    def self.point_inside?(point, polygon)
      return false if polygon.nil? || polygon.length < 3
      
      x, y = point
      inside = false
      n = polygon.length
      
      polygon.each_with_index do |vertex, i|
        next_vertex = polygon[(i + 1) % n]
        
        xi, yi = vertex
        xj, yj = next_vertex
        
        # Проверка пересечения луча с ребром полигона
        if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
          inside = !inside
        end
      end
      
      inside
    end
    
    # Проверить, находится ли точка на границе полигона
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @param polygon [Array<Array<Float>>] Массив точек полигона [[x, y], ...]
    # @param tolerance [Float] Допустимое отклонение
    # @return [Boolean] true если точка на границе
    def self.point_on_boundary?(point, polygon, tolerance = Config::TOLERANCE)
      return false if polygon.nil? || polygon.length < 3
      
      n = polygon.length
      
      polygon.each_with_index do |vertex, i|
        next_vertex = polygon[(i + 1) % n]
        
        if GeometryHelper.point_on_line?(point, vertex, next_vertex, tolerance)
          return true
        end
      end
      
      false
    end
    
    # Проверить, находится ли точка внутри или на границе полигона
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @param polygon [Array<Array<Float>>] Массив точек полигона [[x, y], ...]
    # @param tolerance [Float] Допустимое отклонение
    # @return [Boolean] true если точка внутри или на границе
    def self.point_inside_or_on_boundary?(point, polygon, tolerance = Config::TOLERANCE)
      point_inside?(point, polygon) || point_on_boundary?(point, polygon, tolerance)
    end
  end
end
