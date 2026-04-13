# frozen_string_literal: true

module PolygonalMasonry
  # Вспомогательные геометрические функции
  module GeometryHelper
    # Вычисление евклидова расстояния между двумя точками в 2D
    # @param p1 [Array<Float>] Первая точка [x, y]
    # @param p2 [Array<Float>] Вторая точка [x, y]
    # @return [Float] Расстояние между точками
    def self.distance_2d(p1, p2)
      dx = p2[0] - p1[0]
      dy = p2[1] - p1[1]
      Math.sqrt(dx * dx + dy * dy)
    end
    
    # Векторное произведение для трёх точек (2D)
    # Положительное значение означает поворот против часовой стрелки
    # @param p1 [Array<Float>] Первая точка [x, y]
    # @param p2 [Array<Float>] Вторая точка [x, y]
    # @param p3 [Array<Float>] Третья точка [x, y]
    # @return [Float] Значение векторного произведения
    def self.cross_product_2d(p1, p2, p3)
      (p2[0] - p1[0]) * (p3[1] - p1[1]) - (p2[1] - p1[1]) * (p3[0] - p1[0])
    end
    
    # Вычисление угла между двумя точками относительно центра
    # @param p [Array<Float>] Точка [x, y]
    # @param center [Array<Float>] Центр [x, y]
    # @return [Float] Угол в радианах
    def self.angle_from_center(p, center)
      Math.atan2(p[1] - center[1], p[0] - center[0])
    end
    
    # Проверка, лежит ли точка на отрезке
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @param line_start [Array<Float>] Начало отрезка [x, y]
    # @param line_end [Array<Float>] Конец отрезка [x, y]
    # @param tolerance [Float] Допустимое отклонение
    # @return [Boolean] true если точка на отрезке
    def self.point_on_line?(point, line_start, line_end, tolerance = Config::TOLERANCE)
      # Проверить коллинеарность
      cross = cross_product_2d(line_start, line_end, point).abs
      return false if cross > tolerance
      
      # Проверить, что точка между началом и концом
      dot = (point[0] - line_start[0]) * (line_end[0] - line_start[0]) +
            (point[1] - line_start[1]) * (line_end[1] - line_start[1])
      
      len_sq = (line_end[0] - line_start[0])**2 + (line_end[1] - line_start[1])**2
      
      dot >= -tolerance && dot <= len_sq + tolerance
    end
    
    # Найти пересечение двух отрезков в 2D
    # @param p1 [Array<Float>] Начало первого отрезка [x, y]
    # @param p2 [Array<Float>] Конец первого отрезка [x, y]
    # @param p3 [Array<Float>] Начало второго отрезка [x, y]
    # @param p4 [Array<Float>] Конец второго отрезка [x, y]
    # @return [Array<Float>, nil] Точка пересечения [x, y] или nil
    def self.line_intersection(p1, p2, p3, p4)
      x1, y1 = p1
      x2, y2 = p2
      x3, y3 = p3
      x4, y4 = p4
      
      denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
      return nil if denom.abs < Config::TOLERANCE  # Параллельные линии
      
      t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
      u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
      
      # Проверить, что пересечение внутри отрезков
      return nil if t < 0 || t > 1 || u < 0 || u > 1
      
      # Вычислить точку пересечения
      x = x1 + t * (x2 - x1)
      y = y1 + t * (y2 - y1)
      
      [x, y]
    end
    
    # Проверка, находится ли точка слева от направленного ребра
    # (используется для определения "внутри" в алгоритмах клиппинга)
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @param edge_start [Array<Float>] Начало ребра [x, y]
    # @param edge_end [Array<Float>] Конец ребра [x, y]
    # @return [Boolean] true если точка слева (внутри)
    def self.point_left_of_edge?(point, edge_start, edge_end)
      cross_product_2d(edge_start, edge_end, point) >= 0
    end
    
    # Вычисление центроида (центра масс) полигона
    # @param polygon [Array<Array<Float>>] Массив точек [[x, y], ...]
    # @return [Array<Float>] Центроид [x, y]
    def self.centroid(polygon)
      return nil if polygon.empty?
      
      sum_x = polygon.reduce(0.0) { |sum, p| sum + p[0] }
      sum_y = polygon.reduce(0.0) { |sum, p| sum + p[1] }
      
      [sum_x / polygon.length, sum_y / polygon.length]
    end
    
    # Сортировка точек по часовой стрелке вокруг центра
    # @param points [Array<Array<Float>>] Массив точек [[x, y], ...]
    # @param center [Array<Float>, nil] Центр вращения (если nil, используется центроид)
    # @return [Array<Array<Float>>] Отсортированный массив точек
    def self.sort_clockwise(points, center = nil)
      center ||= centroid(points)
      
      points.sort_by do |point|
        angle_from_center(point, center)
      end
    end
    
    # Проверка, являются ли два ребра одинаковыми (независимо от направления)
    # @param edge1 [Array<Array<Float>>] Первое ребро [[x1, y1], [x2, y2]]
    # @param edge2 [Array<Array<Float>>] Второе ребро [[x1, y1], [x2, y2]]
    # @param tolerance [Float] Допустимое отклонение
    # @return [Boolean] true если рёбра одинаковые
    def self.edges_equal?(edge1, edge2, tolerance = Config::TOLERANCE)
      e1_p1, e1_p2 = edge1
      e2_p1, e2_p2 = edge2
      
      # Прямое совпадение
      if points_equal?(e1_p1, e2_p1, tolerance) && points_equal?(e1_p2, e2_p2, tolerance)
        return true
      end
      
      # Обратное совпадение
      if points_equal?(e1_p1, e2_p2, tolerance) && points_equal?(e1_p2, e2_p1, tolerance)
        return true
      end
      
      false
    end
    
    # Проверка равенства двух точек с учётом толерантности
    # @param p1 [Array<Float>] Первая точка [x, y]
    # @param p2 [Array<Float>] Вторая точка [x, y]
    # @param tolerance [Float] Допустимое отклонение
    # @return [Boolean] true если точки равны
    def self.points_equal?(p1, p2, tolerance = Config::TOLERANCE)
      (p1[0] - p2[0]).abs < tolerance && (p1[1] - p2[1]).abs < tolerance
    end
    
    # Вычислить bounding box для набора точек
    # @param points [Array<Array<Float>>] Массив точек [[x, y], ...]
    # @return [Hash] Хеш с ключами :min_x, :max_x, :min_y, :max_y, :width, :height
    def self.bounding_box(points)
      return nil if points.empty?
      
      xs = points.map { |p| p[0] }
      ys = points.map { |p| p[1] }
      
      min_x = xs.min
      max_x = xs.max
      min_y = ys.min
      max_y = ys.max
      
      {
        min_x: min_x,
        max_x: max_x,
        min_y: min_y,
        max_y: max_y,
        width: max_x - min_x,
        height: max_y - min_y
      }
    end
  end
end
