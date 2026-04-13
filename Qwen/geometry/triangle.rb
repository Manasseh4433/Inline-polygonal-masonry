# frozen_string_literal: true

module PolygonalMasonry
  # Класс представляющий треугольник в 2D пространстве
  class Triangle
    attr_reader :vertices
    
    # Создать треугольник из трёх точек
    # @param p1 [Array<Float>] Первая вершина [x, y]
    # @param p2 [Array<Float>] Вторая вершина [x, y]
    # @param p3 [Array<Float>] Третья вершина [x, y]
    def initialize(p1, p2, p3)
      @vertices = [p1, p2, p3]
    end
    
    # Получить рёбра треугольника
    # @return [Array<Array<Array<Float>>>] Массив рёбер [[[x1, y1], [x2, y2]], ...]
    def edges
      [
        [@vertices[0], @vertices[1]],
        [@vertices[1], @vertices[2]],
        [@vertices[2], @vertices[0]]
      ]
    end
    
    # Вычислить центр и радиус описанной окружности (circumcircle)
    # @return [Array] [center, radius] где center = [x, y], radius = Float
    def circumcircle
      ax, ay = @vertices[0]
      bx, by = @vertices[1]
      cx, cy = @vertices[2]
      
      # Вычислить определитель
      d = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
      
      # Проверка на вырожденность (коллинеарные точки)
      if d.abs < Config::TOLERANCE
        # Вернуть центр в infinity (недопустимый треугольник)
        return [[Float::INFINITY, Float::INFINITY], Float::INFINITY]
      end
      
      # Вычислить координаты центра описанной окружности
      ax2_ay2 = ax * ax + ay * ay
      bx2_by2 = bx * bx + by * by
      cx2_cy2 = cx * cx + cy * cy
      
      ux = (ax2_ay2 * (by - cy) + bx2_by2 * (cy - ay) + cx2_cy2 * (ay - by)) / d
      uy = (ax2_ay2 * (cx - bx) + bx2_by2 * (ax - cx) + cx2_cy2 * (bx - ax)) / d
      
      center = [ux, uy]
      
      # Вычислить радиус
      radius = Math.sqrt((ax - ux)**2 + (ay - uy)**2)
      
      [center, radius]
    end
    
    # Проверить, содержит ли описанная окружность данную точку
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @return [Boolean] true если точка внутри описанной окружности
    def point_in_circumcircle?(point)
      center, radius = circumcircle
      
      # Если треугольник вырожденный, вернуть false
      return false if radius == Float::INFINITY
      
      distance = GeometryHelper.distance_2d(point, center)
      distance < radius - Config::TOLERANCE
    end
    
    # Проверить, содержит ли треугольник данное ребро
    # @param edge [Array<Array<Float>>] Ребро [[x1, y1], [x2, y2]]
    # @return [Boolean] true если ребро принадлежит треугольнику
    def has_edge?(edge)
      edges.any? { |e| GeometryHelper.edges_equal?(e, edge) }
    end
    
    # Проверить, содержит ли треугольник данную вершину
    # @param vertex [Array<Float>] Вершина [x, y]
    # @return [Boolean] true если вершина принадлежит треугольнику
    def has_vertex?(vertex)
      @vertices.any? { |v| GeometryHelper.points_equal?(v, vertex) }
    end
    
    # Получить вершину треугольника по индексу
    # @param index [Integer] Индекс вершины (0, 1, 2)
    # @return [Array<Float>] Вершина [x, y]
    def [](index)
      @vertices[index]
    end
    
    # Строковое представление треугольника
    # @return [String]
    def to_s
      "Triangle[#{@vertices[0]}, #{@vertices[1]}, #{@vertices[2]}]"
    end
    
    # Проверка равенства треугольников
    # @param other [Triangle] Другой треугольник
    # @return [Boolean] true если треугольники равны
    def ==(other)
      return false unless other.is_a?(Triangle)
      
      # Проверить все возможные комбинации вершин
      @vertices.permutation.any? do |perm|
        perm.each_with_index.all? do |v, i|
          GeometryHelper.points_equal?(v, other.vertices[i])
        end
      end
    end
  end
end
