# frozen_string_literal: true

module PolygonalMasonry
  # Клиппинг полигона по выпуклой границе используя алгоритм Сазерленда-Ходжмана
  class SutherlandHodgman
    # Обрезать полигон по границе клиппинга
    # @param subject_polygon [Array<Array<Float>>] Обрезаемый полигон [[x, y], ...]
    # @param clip_polygon [Array<Array<Float>>] Граница клиппинга [[x, y], ...]
    # @return [Array<Array<Float>>] Обрезанный полигон
    def self.clip(subject_polygon, clip_polygon)
      return [] if subject_polygon.nil? || subject_polygon.empty?
      return subject_polygon if clip_polygon.nil? || clip_polygon.empty?
      
      output = subject_polygon.dup
      
      # Для каждого ребра границы клиппинга
      clip_polygon.each_with_index do |clip_vertex, i|
        next_clip_vertex = clip_polygon[(i + 1) % clip_polygon.length]
        
        input = output
        output = []
        
        return [] if input.empty?
        
        # Для каждого ребра обрезаемого полигона
        input.each_with_index do |current_vertex, j|
          next_vertex = input[(j + 1) % input.length]
          
          current_inside = inside_edge?(current_vertex, clip_vertex, next_clip_vertex)
          next_inside = inside_edge?(next_vertex, clip_vertex, next_clip_vertex)
          
          if current_inside && next_inside
            # Оба внутри: добавить следующую вершину
            output << next_vertex
            
          elsif current_inside && !next_inside
            # Выходим: добавить точку пересечения
            intersection = GeometryHelper.line_intersection(
              current_vertex, next_vertex,
              clip_vertex, next_clip_vertex
            )
            output << intersection if intersection
            
          elsif !current_inside && next_inside
            # Входим: добавить пересечение и следующую вершину
            intersection = GeometryHelper.line_intersection(
              current_vertex, next_vertex,
              clip_vertex, next_clip_vertex
            )
            output << intersection if intersection
            output << next_vertex
            
          # else: оба снаружи - ничего не добавляем
          end
        end
      end
      
      output
    end
    
    private
    
    # Проверить, находится ли точка "внутри" (слева от) ребра
    # @param point [Array<Float>] Точка [x, y]
    # @param edge_start [Array<Float>] Начало ребра [x, y]
    # @param edge_end [Array<Float>] Конец ребра [x, y]
    # @return [Boolean] true если точка внутри
    def self.inside_edge?(point, edge_start, edge_end)
      GeometryHelper.point_left_of_edge?(point, edge_start, edge_end)
    end
  end
  
  # Обрезка полигонов по границам с дополнительной обработкой
  class BoundaryClipper
    attr_reader :boundary
    
    # Создать clipper для данной границы
    # @param boundary_polygon [Array<Array<Float>>] Граница [[x, y], ...]
    def initialize(boundary_polygon)
      @boundary = boundary_polygon
    end
    
    # Обрезать полигон по границе
    # @param polygon [Array<Array<Float>>] Полигон для обрезки [[x, y], ...]
    # @return [Array<Array<Float>>, nil] Обрезанный полигон или nil если вырожденный
    def clip_polygon(polygon)
      return nil if polygon.nil? || polygon.empty?
      
      # Выполнить клиппинг
      clipped = SutherlandHodgman.clip(polygon, @boundary)
      
      # Проверить на вырожденность
      return nil if degenerate?(clipped)
      
      # Упростить полигон (удалить коллинеарные точки)
      simplify_polygon(clipped)
    end
    
    # Проверить, является ли полигон вырожденным
    # @param polygon [Array<Array<Float>>] Полигон [[x, y], ...]
    # @return [Boolean] true если вырожденный
    def degenerate?(polygon)
      return true if polygon.nil? || polygon.length < 3
      
      # Более мягкая проверка - сохраняем даже маленькие граничные камни
      area = PolygonArea.calculate(polygon)
      area < (Config::MIN_POLYGON_AREA * 0.5)  # Еще более низкий порог
    end
    
    # Упростить полигон, удаляя коллинеарные точки
    # @param polygon [Array<Array<Float>>] Полигон [[x, y], ...]
    # @return [Array<Array<Float>>] Упрощённый полигон
    def simplify_polygon(polygon)
      return polygon if polygon.length < 3
      
      simplified = []
      n = polygon.length
      
      polygon.each_with_index do |vertex, i|
        prev_vertex = polygon[(i - 1) % n]
        next_vertex = polygon[(i + 1) % n]
        
        # Проверить, не является ли точка коллинеарной с соседями
        cross = GeometryHelper.cross_product_2d(prev_vertex, vertex, next_vertex).abs
        
        # Более мягкая толерантность для сохранения граничных точек
        simplified << vertex if cross > (Config::TOLERANCE * 0.1)
      end
      
      # Если упрощение удалило слишком много точек, вернуть оригинал
      simplified.length >= 3 ? simplified : polygon
    end
  end
end
