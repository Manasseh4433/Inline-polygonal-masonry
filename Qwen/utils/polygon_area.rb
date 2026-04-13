# frozen_string_literal: true

module PolygonalMasonry
  # Вычисление площади полигона
  class PolygonArea
    # Вычислить площадь полигона используя формулу Гаусса (Shoelace formula)
    # @param polygon [Array<Array<Float>>] Массив точек [[x, y], ...] в порядке обхода
    # @return [Float] Площадь полигона (всегда положительная)
    def self.calculate(polygon)
      return 0.0 if polygon.nil? || polygon.length < 3
      
      area = 0.0
      n = polygon.length
      
      polygon.each_with_index do |vertex, i|
        next_vertex = polygon[(i + 1) % n]
        area += vertex[0] * next_vertex[1]
        area -= next_vertex[0] * vertex[1]
      end
      
      (area.abs / 2.0)
    end
    
    # Проверить, является ли полигон вырожденным (слишком маленькая площадь)
    # @param polygon [Array<Array<Float>>] Массив точек [[x, y], ...]
    # @param min_area [Float] Минимальная допустимая площадь
    # @return [Boolean] true если полигон вырожденный
    def self.degenerate?(polygon, min_area = Config::MIN_POLYGON_AREA)
      calculate(polygon) < min_area
    end
  end
end
