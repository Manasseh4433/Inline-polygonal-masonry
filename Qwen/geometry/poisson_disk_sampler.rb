# frozen_string_literal: true

module PolygonalMasonry
  # Распределение точек Пуассона используя алгоритм Бриджсона
  # Обеспечивает равномерное распределение с минимальным расстоянием между точками
  class PoissonDiskSampler
    attr_reader :width, :height, :min_distance, :max_attempts
    
    # Создать sampler для прямоугольной области
    # @param width [Float] Ширина области
    # @param height [Float] Высота области
    # @param min_distance [Float] Минимальное расстояние между точками
    # @param max_attempts [Integer] Максимальное количество попыток размещения точки
    def initialize(width, height, min_distance, max_attempts = Config::POISSON_MAX_ATTEMPTS)
      @width = width
      @height = height
      @min_distance = min_distance
      @max_attempts = max_attempts
      
      # Размер ячейки сетки для ускорения поиска соседей
      @cell_size = min_distance / Math.sqrt(2.0)
      @grid_width = (@width / @cell_size).ceil + 1
      @grid_height = (@height / @cell_size).ceil + 1
      @grid = Array.new(@grid_width) { Array.new(@grid_height) }
      
      @active_list = []
      @points = []
    end
    
    # Сгенерировать точки
    # @return [Array<Array<Float>>] Массив точек [[x, y], ...]
    def sample
      # Шаг 1: Выбрать начальную точку
      initial_point = [rand * @width, rand * @height]
      add_point(initial_point)
      
      # Шаг 2: Пока активный список не пуст
      while !@active_list.empty?
        # Выбрать случайную точку из активного списка
        index = rand(@active_list.length)
        point = @active_list[index]
        
        found = false
        
        # Попытаться сгенерировать новую точку вокруг неё
        @max_attempts.times do
          new_point = generate_point_around(point)
          
          if valid_point?(new_point)
            add_point(new_point)
            found = true
            break
          end
        end
        
        # Если не удалось сгенерировать, удалить из активного списка
        @active_list.delete_at(index) unless found
      end
      
      @points
    end
    
    private
    
    # Сгенерировать точку в кольце между r и 2r от исходной точки
    # @param point [Array<Float>] Исходная точка [x, y]
    # @return [Array<Float>] Новая точка [x, y]
    def generate_point_around(point)
      # Генерировать точку в кольце между min_distance и 2*min_distance
      radius = @min_distance * (1.0 + rand)
      angle = rand * 2.0 * Math::PI
      
      x = point[0] + radius * Math.cos(angle)
      y = point[1] + radius * Math.sin(angle)
      
      [x, y]
    end
    
    # Проверить валидность точки
    # @param point [Array<Float>] Проверяемая точка [x, y]
    # @return [Boolean] true если точка валидна
    def valid_point?(point)
      x, y = point
      
      # Проверка границ
      return false if x < 0 || x >= @width || y < 0 || y >= @height
      
      # Получить индексы ячейки сетки
      grid_x = (x / @cell_size).floor
      grid_y = (y / @cell_size).floor
      
      # Проверить соседние ячейки
      search_start_x = [grid_x - 2, 0].max
      search_end_x = [grid_x + 2, @grid_width - 1].min
      search_start_y = [grid_y - 2, 0].max
      search_end_y = [grid_y + 2, @grid_height - 1].min
      
      (search_start_x..search_end_x).each do |i|
        (search_start_y..search_end_y).each do |j|
          neighbor = @grid[i][j]
          next if neighbor.nil?
          
          distance = GeometryHelper.distance_2d(point, neighbor)
          return false if distance < @min_distance
        end
      end
      
      true
    end
    
    # Добавить точку в структуры данных
    # @param point [Array<Float>] Точка [x, y]
    def add_point(point)
      @points << point
      @active_list << point
      
      grid_x = (point[0] / @cell_size).floor
      grid_y = (point[1] / @cell_size).floor
      @grid[grid_x][grid_y] = point
    end
  end
end
