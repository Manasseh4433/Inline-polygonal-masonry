# frozen_string_literal: true

module PolygonalMasonry
  unless file_loaded?(__FILE__)
    # Создать меню плагина (название меню должно быть на английском для совместимости)
    menu = UI.menu('Plugins')
    submenu = menu.add_submenu('Полигональная кладка')
    
    # Команда генерации
    submenu.add_item('Создать кладку') do
      PolygonalMasonry.handle_generate_command
    end
    
    # Разделитель
    submenu.add_separator
    
    # Информация о плагине
    submenu.add_item('О плагине...') do
      PolygonalMasonry.show_about
    end
    
    file_loaded(__FILE__)
  end
end
