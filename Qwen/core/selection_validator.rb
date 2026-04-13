# frozen_string_literal: true

module PolygonalMasonry
  # Валидация выбранных пользователем сущностей
  class SelectionValidator
    # Валидировать выбор пользователя
    # @param selection [Sketchup::Selection] Выбранные сущности
    # @return [Hash] Результат валидации {:valid => Boolean, :face/:error => ...}
    def self.validate(selection)
      return error_result('Ничего не выбрано. Выберите одну плоскую грань.') if selection.empty?
      
      return error_result('Выберите только одну грань.') if selection.length != 1
      
      entity = selection[0]
      
      unless entity.is_a?(Sketchup::Face)
        return error_result('Выбранный объект не является гранью. Выберите плоскую грань.')
      end
      
      unless sufficient_area?(entity)
        min_area_m2 = (Config::MIN_FACE_AREA / 10000.0).round(2)
        return error_result("Грань слишком маленькая. Минимальная площадь: #{min_area_m2} м².")
      end
      
      { valid: true, face: entity }
    end
    
    private
    
    # Создать результат с ошибкой
    # @param message [String] Сообщение об ошибке
    # @return [Hash]
    def self.error_result(message)
      { valid: false, error: message }
    end
    
    # Проверить достаточность площади грани
    # @param face [Sketchup::Face] Грань
    # @return [Boolean] true если площадь достаточная
    def self.sufficient_area?(face)
      # Площадь в SketchUp в квадратных дюймах, конвертируем в см²
      area_sq_inches = face.area
      area_sq_cm = area_sq_inches * 6.4516  # 1 дюйм² = 6.4516 см²
      
      area_sq_cm >= Config::MIN_FACE_AREA
    end
  end
end
