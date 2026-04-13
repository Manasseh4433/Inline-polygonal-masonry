# frozen_string_literal: true

module PolygonalMasonry
  # Триангуляция Делоне используя алгоритм Боуера-Уотсона
  class DelaunayTriangulation
    attr_reader :points, :triangles
    
    # Создать триангуляцию для набора точек
    # @param points [Array<Array<Float>>] Массив точек [[x, y], ...]
    def initialize(points)
      @points = points
      @triangles = []
    end
    
    # Построить триангуляцию Делоне
    # @return [Array<Triangle>] Массив треугольников
    def triangulate
      return [] if @points.length < 3
      
      # Шаг 1: Создать супертриугольник, содержащий все точки
      super_triangle = create_super_triangle
      @triangles = [super_triangle]
      
      # Шаг 2: Добавить каждую точку по одной
      @points.each do |point|
        add_point(point)
      end
      
      # Шаг 3: Удалить треугольники, связанные с супертриугольником
      remove_super_triangle_vertices(super_triangle)
      
      @triangles
    end
    
    private
    
    # Создать супертриугольник, содержащий все точки
    # @return [Triangle] Супертриугольник
    def create_super_triangle
      # Найти bounding box всех точек
      bbox = GeometryHelper.bounding_box(@points)
      
      min_x = bbox[:min_x]
      max_x = bbox[:max_x]
      min_y = bbox[:min_y]
      max_y = bbox[:max_y]
      
      # Создать треугольник с большим запасом
      dx = (max_x - min_x) * 10.0
      dy = (max_y - min_y) * 10.0
      
      p1 = [min_x - dx, min_y - dy * 3.0]
      p2 = [min_x - dx, max_y + dy]
      p3 = [max_x + dx * 3.0, max_y + dy]
      
      Triangle.new(p1, p2, p3)
    end
    
    # Добавить точку в триангуляцию
    # @param point [Array<Float>] Точка [x, y]
    def add_point(point)
      bad_triangles = []
      
      # Найти все треугольники, чья описанная окружность содержит точку
      @triangles.each do |triangle|
        if triangle.point_in_circumcircle?(point)
          bad_triangles << triangle
        end
      end
      
      # Если нет "плохих" треугольников, точка уже внутри существующей триангуляции
      return if bad_triangles.empty?
      
      # Найти границу полигональной дыры
      polygon_edges = []
      
      bad_triangles.each do |triangle|
        triangle.edges.each do |edge|
          # Если ребро не разделяется другим "плохим" треугольником,
          # оно часть границы дыры
          unless is_shared_edge?(edge, bad_triangles - [triangle])
            polygon_edges << edge
          end
        end
      end
      
      # Удалить плохие треугольники
      @triangles -= bad_triangles
      
      # Создать новые треугольники из точки к границе дыры
      polygon_edges.each do |edge|
        new_triangle = Triangle.new(edge[0], edge[1], point)
        @triangles << new_triangle
      end
    end
    
    # Проверить, разделяется ли ребро с другими треугольниками
    # @param edge [Array<Array<Float>>] Ребро [[x1, y1], [x2, y2]]
    # @param triangles [Array<Triangle>] Массив треугольников для проверки
    # @return [Boolean] true если ребро разделяется
    def is_shared_edge?(edge, triangles)
      triangles.any? { |triangle| triangle.has_edge?(edge) }
    end
    
    # Удалить треугольники, содержащие вершины супертриугольника
    # @param super_triangle [Triangle] Супертриугольник
    def remove_super_triangle_vertices(super_triangle)
      @triangles.reject! do |triangle|
        super_triangle.vertices.any? do |super_vertex|
          triangle.has_vertex?(super_vertex)
        end
      end
    end
  end
end
