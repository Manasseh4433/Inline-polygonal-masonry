# frozen_string_literal: true

module PolygonalMasonry
  # Разбиение грани SketchUp на полигоны
  class FaceSubdivider
    attr_reader :face, :analyzer, :model
    
    # Создать subdivider для грани
    # @param face [Sketchup::Face] Грань SketchUp
    # @param analyzer [FaceAnalyzer] Анализатор грани
    def initialize(face, analyzer)
      @face = face
      @analyzer = analyzer
      @model = face.model
    end
    
    # Разбить грань на полигоны
    # @param polygons_3d [Array<Array<Geom::Point3d>>] Массив полигонов в 3D
    # @return [Array<Sketchup::Face>] Массив созданных граней
    def subdivide(polygons_3d)
      return [] if polygons_3d.empty?
      
      entities = @face.parent.entities
      new_faces = []
      
      # Создать все новые грани
      polygons_3d.each do |polygon|
        begin
          face = create_face(entities, polygon)
          new_faces << face if face
        rescue => e
          puts "Ошибка создания грани: #{e.message}"
        end
      end
      
      # Удалить исходную грань
      begin
        entities.erase_entities(@face) unless new_faces.empty?
      rescue => e
        puts "Ошибка удаления исходной грани: #{e.message}"
      end
      
      new_faces
    end
    
    private
    
    # Создать грань из точек
    # @param entities [Sketchup::Entities] Коллекция сущностей
    # @param points_3d [Array<Geom::Point3d>] Точки полигона
    # @return [Sketchup::Face, nil] Созданная грань или nil
    def create_face(entities, points_3d)
      return nil if points_3d.length < 3
      
      # Убедиться что точки уникальные
      unique_points = []
      points_3d.each do |point|
        unless unique_points.any? { |p| p.distance(point) < 0.001 }
          unique_points << point
        end
      end
      
      return nil if unique_points.length < 3
      
      # Создать грань
      face = entities.add_face(unique_points)
      
      # Проверить ориентацию нормали
      if face && !face.normal.parallel?(@face.normal)
        face.reverse! unless face.normal.samedirection?(@face.normal)
      end
      
      face
    end
  end
end
