# frozen_string_literal: true

module PolygonalMasonry
  # Класс представляющий ячейку Вороного
  class VoronoiCell
    attr_reader :site, :vertices
    
    # Создать ячейку Вороного
    # @param site [Array<Float>] Исходная точка (центр ячейки) [x, y]
    # @param vertices [Array<Array<Float>>] Вершины полигона ячейки [[x, y], ...]
    def initialize(site, vertices)
      @site = site
      @vertices = vertices
    end
    
    # Преобразовать ячейку в полигон (массив точек)
    # @return [Array<Array<Float>>] Массив вершин полигона
    def to_polygon
      @vertices
    end
    
    # Получить площадь ячейки
    # @return [Float] Площадь
    def area
      PolygonArea.calculate(@vertices)
    end
  end
  
  # Извлечение диаграммы Вороного из триангуляции Делоне
  class VoronoiExtractor
    attr_reader :triangulation
    
    # Создать экстрактор из триангуляции Делоне
    # @param triangulation [DelaunayTriangulation] Триангуляция Делоне
    def initialize(triangulation)
      @triangulation = triangulation
    end
    
    # Извлечь диаграмму Вороного
    # @return [Hash] Хеш {site => VoronoiCell}
    def extract_voronoi_diagram
      voronoi_cells = {}
      
      # Для каждой исходной точки собрать её ячейку Вороного
      @triangulation.points.each do |point|
        cell = build_voronoi_cell(point)
        voronoi_cells[point] = cell if cell
      end
      
      voronoi_cells
    end
    
    private
    
    # Построить ячейку Вороного для данной точки
    # @param point [Array<Float>] Точка [x, y]
    # @return [VoronoiCell, nil] Ячейка Вороного или nil
    def build_voronoi_cell(point)
      # Найти все треугольники, содержащие эту точку
      containing_triangles = @triangulation.triangles.select do |triangle|
        triangle.has_vertex?(point)
      end
      
      return nil if containing_triangles.empty?
      
      # Центры описанных окружностей этих треугольников образуют
      # вершины ячейки Вороного
      voronoi_vertices = containing_triangles.map do |triangle|
        center, _radius = triangle.circumcircle
        center
      end.compact
      
      # Фильтровать недопустимые точки (infinity)
      voronoi_vertices.reject! do |vertex|
        vertex[0] == Float::INFINITY || vertex[1] == Float::INFINITY
      end
      
      return nil if voronoi_vertices.length < 3
      
      # Сортировать вершины по часовой стрелке вокруг исходной точки
      sorted_vertices = GeometryHelper.sort_clockwise(voronoi_vertices, point)
      
      VoronoiCell.new(point, sorted_vertices)
    end
  end
end
