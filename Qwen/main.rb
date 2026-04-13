# frozen_string_literal: true

require 'sketchup.rb'

module PolygonalMasonry
  # Путь к директории плагина
  PLUGIN_ROOT = File.dirname(__FILE__) unless defined?(PLUGIN_ROOT)
  
  # Загрузка конфигурации
  require File.join(PLUGIN_ROOT, 'config.rb')
  
  # Загрузка утилит
  require File.join(PLUGIN_ROOT, 'utils', 'geometry_helper.rb')
  require File.join(PLUGIN_ROOT, 'utils', 'polygon_area.rb')
  require File.join(PLUGIN_ROOT, 'utils', 'polygon_containment.rb')
  
  # Загрузка геометрических классов
  require File.join(PLUGIN_ROOT, 'geometry', 'triangle.rb')
  require File.join(PLUGIN_ROOT, 'geometry', 'delaunay_triangulation.rb')
  require File.join(PLUGIN_ROOT, 'geometry', 'voronoi_extractor.rb')
  require File.join(PLUGIN_ROOT, 'geometry', 'poisson_disk_sampler.rb')
  require File.join(PLUGIN_ROOT, 'geometry', 'boundary_clipper.rb')
  
  # Загрузка основных классов
  require File.join(PLUGIN_ROOT, 'core', 'selection_validator.rb')
  require File.join(PLUGIN_ROOT, 'core', 'face_analyzer.rb')
  require File.join(PLUGIN_ROOT, 'core', 'polygon_generator.rb')
  require File.join(PLUGIN_ROOT, 'core', 'face_subdivider.rb')
  
  # Загрузка меню
  require File.join(PLUGIN_ROOT, 'menu.rb')
  
  # Главная функция обработки команды генерации
  def self.handle_generate_command
    model = Sketchup.active_model
    selection = model.selection
    
    # Валидация выбора
    result = SelectionValidator.validate(selection)
    
    unless result[:valid]
      UI.messagebox(result[:error], MB_OK)
      return
    end
    
    face = result[:face]
    
    # Начать операцию с поддержкой undo/redo
    model.start_operation('Полигональная кладка', true)
    
    begin
      # Показать сообщение о начале генерации
      Sketchup.status_text = 'Создание полигональной кладки...'
      
      # Создать генератор
      generator = PolygonGenerator.new(face)
      
      # Сгенерировать полигоны
      polygons = generator.generate
      
      if polygons.empty?
        model.abort_operation
        UI.messagebox(
          'Не удалось сгенерировать полигоны. ' \
          'Попробуйте увеличить размер поверхности.',
          MB_OK
        )
        return
      end
      
      # Создать subdivider
      analyzer = generator.analyzer
      subdivider = FaceSubdivider.new(face, analyzer)
      
      # Разбить грань
      new_faces = subdivider.subdivide(polygons)
      
      if new_faces.empty?
        model.abort_operation
        UI.messagebox(
          'Не удалось создать полигоны кладки. Попробуйте увеличить размер поверхности или упростить её форму.',
          MB_OK
        )
        return
      end
      
      # Завершить операцию
      model.commit_operation
      
      # Показать результат
      Sketchup.status_text = ''
      UI.messagebox(
        "Успешно создано #{new_faces.length} камней полигональной кладки!",
        MB_OK
      )
      
    rescue => e
      model.abort_operation
      Sketchup.status_text = ''
      
      # Показать детальную ошибку
      error_msg = "Ошибка при генерации:\n\n#{e.message}\n\n"
      error_msg += "Трассировка:\n#{e.backtrace.first(5).join("\n")}"
      
      UI.messagebox(error_msg, MB_OK)
      
      # Вывести в консоль для отладки
      puts "=== Polygonal Masonry Error ==="
      puts e.message
      puts e.backtrace.join("\n")
    end
  end
  
  # Показать информацию о плагине
  def self.show_about
    message = "Полигональная кладка v#{Config::VERSION}\n\n" \
              "Автоматическая генерация полигональной кладки на поверхностях.\n\n" \
              "Использование:\n" \
              "1. Выберите плоскую грань\n" \
              "2. Меню: Плагины → Полигональная кладка → Создать кладку\n" \
              "3. Дождитесь завершения генерации\n\n" \
              "Плагин использует диаграмму Вороного для создания\n" \
              "неправильных многоугольников, имитирующих древнюю каменную кладку.\n\n" \
              "Автор: Manasseh\n" \
              "Версия: #{Config::VERSION}"
    
    UI.messagebox(message, MB_OK)
  end
  
  puts "Плагин 'Полигональная кладка' v#{Config::VERSION} загружен успешно!"
end
