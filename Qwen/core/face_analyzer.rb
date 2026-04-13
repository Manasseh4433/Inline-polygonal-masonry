# frozen_string_literal: true

module PolygonalMasonry
  # Анализ грани SketchUp и преобразование координат между 3D и 2D
  class FaceAnalyzer
    attr_reader :face, :origin, :x_axis, :y_axis, :normal
    
    # Создать анализатор для грани
    # @param face [Sketchup::Face] Грань SketchUp
    def initialize(face)
      @face = face
      setup_coordinate_system
    end
    
    # Получить площадь грани в см²
    # @return [Float] Площадь в см²
    def area
      # Площадь в SketchUp в квадратных дюймах
      area_sq_inches = @face.area
      area_sq_cm = area_sq_inches * 6.4516  # 1 дюйм² = 6.4516 см²
      area_sq_cm
    end
    
    # Вычислить оптимальное количество полигонов на основе площади
    # @return [Integer] Оптимальное количество полигонов
    def optimal_polygon_count
      total_area = area
      
      # Выбрать целевой размер полигона в зависимости от общей площади
      target_size = if total_area < Config::SMALL_AREA_THRESHOLD
                      Config::TARGET_POLYGON_SIZE_SMALL
                    elsif total_area < Config::LARGE_AREA_THRESHOLD
                      Config::TARGET_POLYGON_SIZE_MEDIUM
                    else
                      Config::TARGET_POLYGON_SIZE_LARGE
                    end
      
      # Вычислить количество полигонов
      count = (total_area / target_size).to_i
      
      # Ограничить диапазон
      count.clamp(Config::MIN_POLYGON_COUNT, Config::MAX_POLYGON_COUNT)
    end
    
    # Преобразовать 3D точку SketchUp в локальные 2D координаты
    # @param point_3d [Geom::Point3d] Точка в 3D
    # @return [Array<Float>] Точка в 2D [x, y] в см
    def to_2d(point_3d)
      # Преобразовать в вектор относительно origin
      local = point_3d - @origin
      
      # Проецировать на локальные оси
      x = local.dot(@x_axis)
      y = local.dot(@y_axis)
      
      # Преобразовать из дюймов в см
      x_cm = x * 2.54
      y_cm = y * 2.54
      
      [x_cm, y_cm]
    end
    
    # Преобразовать 2D точку в 3D координаты SketchUp
    # @param point_2d [Array<Float>] Точка в 2D [x, y] в см
    # @return [Geom::Point3d] Точка в 3D
    def from_2d(point_2d)
      # Преобразовать из см в дюймы
      x_inches = point_2d[0] / 2.54
      y_inches = point_2d[1] / 2.54
      
      # Создать 3D точку
      offset = @x_axis.clone
      offset.length = x_inches
      
      offset_y = @y_axis.clone
      offset_y.length = y_inches
      
      @origin + offset + offset_y
    end
    
    # Получить границу грани в 2D координатах
    # @return [Array<Array<Float>>] Массив точек [[x, y], ...] в см
    def boundary_2d
      vertices = @face.outer_loop.vertices.map(&:position)
      vertices.map { |v| to_2d(v) }
    end
    
    private
    
    # Настроить локальную систему координат для плоской грани
    def setup_coordinate_system
      # Получить нормаль грани
      @normal = @face.normal
      
      # Выбрать origin (первая вершина)
      @origin = @face.vertices[0].position
      
      # Выбрать X ось вдоль первого ребра
      if @face.vertices.length > 1
        edge_vector = @face.vertices[1].position - @origin
        @x_axis = edge_vector.normalize
      else
        # Резервный вариант: использовать произвольную ось
        @x_axis = Geom::Vector3d.new(1, 0, 0)
        # Убедиться что она не параллельна нормали
        if @x_axis.parallel?(@normal)
          @x_axis = Geom::Vector3d.new(0, 1, 0)
        end
      end
      
      # Вычислить Y ось как векторное произведение нормали и X оси
      @y_axis = @normal * @x_axis
      @y_axis.normalize!
      
      # Переортогонализировать X ось для точности
      @x_axis = @y_axis * @normal
      @x_axis.normalize!
    end
  end
end
