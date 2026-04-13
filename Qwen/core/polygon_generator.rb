# frozen_string_literal: true

module PolygonalMasonry
  # Главный генератор полигональной кладки
  class PolygonGenerator
    attr_reader :face, :analyzer
    
    # Создать генератор для грани
    # @param face [Sketchup::Face] Грань SketchUp
    def initialize(face)
      @face = face
      @analyzer = FaceAnalyzer.new(face)
    end
    
    # Сгенерировать полигоны
    # @return [Array<Array<Geom::Point3d>>] Массив полигонов в 3D координатах
    def generate
      # Получить границу в 2D
      boundary_2d = @analyzer.boundary_2d
      
      # Распределить точки Вороного
      sites = generate_sites(boundary_2d)
      
      return [] if sites.empty?
      
      # Добавить точки на границе и в углах для полного покрытия
      boundary_sites = distribute_boundary_points(boundary_2d)
      corner_sites = boundary_2d.dup  # Добавить все углы
      
      # КРИТИЧЕСКИ ВАЖНО: добавить точки ЗА границей для прямых краёв
      external_sites = generate_external_boundary_points(boundary_2d)
      
      all_sites = sites + boundary_sites + corner_sites + external_sites
      
      # Построить диаграмму Вороного
      voronoi_cells = build_voronoi(all_sites)
      
      return [] if voronoi_cells.empty?
      
      # Обрезать по границам
      clipped_polygons = clip_to_boundary(voronoi_cells, boundary_2d)
      
      # Преобразовать в 3D
      polygons_3d = clipped_polygons.map do |polygon_2d|
        polygon_2d.map { |point_2d| @analyzer.from_2d(point_2d) }
      end
      
      polygons_3d
    end
    
    private
    
    # Сгенерировать точки для диаграммы Вороного
    # @param boundary [Array<Array<Float>>] Граница в 2D
    # @return [Array<Array<Float>>] Точки в 2D
    def generate_sites(boundary)
      # Вычислить параметры
      polygon_count = @analyzer.optimal_polygon_count
      area = PolygonArea.calculate(boundary)
      target_size = area / polygon_count
      min_distance = Math.sqrt(target_size) * Config::MIN_POINT_DISTANCE_RATIO
      
      # Получить bounding box
      bbox = GeometryHelper.bounding_box(boundary)
      
      # Создать sampler
      sampler = PoissonDiskSampler.new(
        bbox[:width],
        bbox[:height],
        min_distance
      )
      
      # Генерировать точки
      raw_points = sampler.sample
      
      # Отфильтровать точки внутри границы
      # (переместить координаты относительно bbox)
      raw_points.select do |point|
        adjusted_point = [point[0] + bbox[:min_x], point[1] + bbox[:min_y]]
        PolygonContainment.point_inside?(adjusted_point, boundary)
      end.map do |point|
        [point[0] + bbox[:min_x], point[1] + bbox[:min_y]]
      end
    end
    
    # Распределить точки на границе
    # @param boundary [Array<Array<Float>>] Граница в 2D
    # @return [Array<Array<Float>>] Точки на границе
    def distribute_boundary_points(boundary)
      points = []
      min_spacing = Config::MIN_BOUNDARY_POINT_DISTANCE
      
      boundary.each_with_index do |vertex, i|
        next_vertex = boundary[(i + 1) % boundary.length]
        
        # Вычислить длину ребра
        edge_length = GeometryHelper.distance_2d(vertex, next_vertex)
        
        # Вычислить количество точек на этом ребре (больше точек для лучшего покрытия)
        num_points = [(edge_length / min_spacing).floor, 2].max
        
        # Распределить точки равномерно, НЕ включая концы (они добавляются отдельно)
        (1...num_points).each do |j|
          t = j.to_f / num_points
          point = [
            vertex[0] + t * (next_vertex[0] - vertex[0]),
            vertex[1] + t * (next_vertex[1] - vertex[1])
          ]
          points << point
        end
      end
      
      points
    end
    
    # Генерировать точки ЗА границей для создания прямых краёв
    # @param boundary [Array<Array<Float>>] Граница в 2D
    # @return [Array<Array<Float>>] Точки за границей
    def generate_external_boundary_points(boundary)
      external_points = []
      offset_distance = Config::MIN_BOUNDARY_POINT_DISTANCE * 3.0  # Расстояние за границей
      
      boundary.each_with_index do |vertex, i|
        next_vertex = boundary[(i + 1) % boundary.length]
        prev_vertex = boundary[(i - 1 + boundary.length) % boundary.length]
        
        # Вычислить нормаль к ребру (направление наружу)
        edge_dx = next_vertex[0] - vertex[0]
        edge_dy = next_vertex[1] - vertex[1]
        
        # Перпендикуляр (нормаль наружу) - поворот на 90 градусов
        normal_x = -edge_dy
        normal_y = edge_dx
        length = Math.sqrt(normal_x**2 + normal_y**2)
        
        if length > 0.001
          normal_x /= length
          normal_y /= length
          
          # Точка за границей посередине ребра
          mid_x = (vertex[0] + next_vertex[0]) / 2.0
          mid_y = (vertex[1] + next_vertex[1]) / 2.0
          
          external_point = [
            mid_x + normal_x * offset_distance,
            mid_y + normal_y * offset_distance
          ]
          external_points << external_point
        end
        
        # Добавить точку за углом (биссектриса)
        edge1_dx = vertex[0] - prev_vertex[0]
        edge1_dy = vertex[1] - prev_vertex[1]
        len1 = Math.sqrt(edge1_dx**2 + edge1_dy**2)
        
        edge2_dx = next_vertex[0] - vertex[0]
        edge2_dy = next_vertex[1] - vertex[1]
        len2 = Math.sqrt(edge2_dx**2 + edge2_dy**2)
        
        if len1 > 0.001 && len2 > 0.001
          # Нормализованные направления
          dir1_x = edge1_dx / len1
          dir1_y = edge1_dy / len1
          dir2_x = edge2_dx / len2
          dir2_y = edge2_dy / len2
          
          # Биссектриса (наружу от угла)
          bisect_x = -(dir1_x + dir2_x) / 2.0
          bisect_y = -(dir1_y + dir2_y) / 2.0
          bisect_len = Math.sqrt(bisect_x**2 + bisect_y**2)
          
          if bisect_len > 0.001
            bisect_x /= bisect_len
            bisect_y /= bisect_len
            
            corner_external = [
              vertex[0] + bisect_x * offset_distance * 1.5,
              vertex[1] + bisect_y * offset_distance * 1.5
            ]
            external_points << corner_external
          end
        end
      end
      
      external_points
    end
    
    # Построить диаграмму Вороного
    # @param sites [Array<Array<Float>>] Точки для генерации
    # @return [Hash] Хеш {site => VoronoiCell}
    def build_voronoi(sites)
      return {} if sites.length < 3
      
      # Построить триангуляцию Делоне
      delaunay = DelaunayTriangulation.new(sites)
      delaunay.triangulate
      
      # Извлечь диаграмму Вороного
      extractor = VoronoiExtractor.new(delaunay)
      extractor.extract_voronoi_diagram
    end
    
    # Обрезать полигоны по границе
    # @param voronoi_cells [Hash] Хеш {site => VoronoiCell}
    # @param boundary [Array<Array<Float>>] Граница в 2D
    # @return [Array<Array<Array<Float>>>] Массив обрезанных полигонов
    def clip_to_boundary(voronoi_cells, boundary)
      clipper = BoundaryClipper.new(boundary)
      
      clipped = voronoi_cells.values.map do |cell|
        clipper.clip_polygon(cell.to_polygon)
      end.compact
      
      # Фильтровать вырожденные полигоны
      clipped.select { |polygon| polygon.length >= 3 }
    end
  end
end
