# encoding: UTF-8
# Главный модуль плагина «Рядная полигональная кладка» v0.3.0
# Итерация 3: PlanarGraph, CellExtractor, реальные швы, расширенный диалог

require_relative 'utils/geom2d'
require_relative 'utils/polygon_clip'
require_relative 'core/face_local_frame'
require_relative 'core/auto_params'
require_relative 'core/row_generator'
require_relative 'core/node_distributor'
require_relative 'core/seam_matcher'
require_relative 'core/cell_builder'
require_relative 'core/seam_deformer'
require_relative 'core/stone_validator'
require_relative 'core/planar_graph'
require_relative 'core/cell_extractor'
require_relative 'core/sketchup_builder'
require_relative 'ui/params_dialog'

module PolygonalMasonry
  PLUGIN_VERSION = '0.3.0'

  def self.run_on_selected_face
    model = Sketchup.active_model
    sel   = model.selection

    face = sel.find { |e| e.is_a?(Sketchup::Face) }
    unless face
      UI.messagebox('Выберите плоскую грань перед запуском плагина.')
      return
    end

    frame = FaceLocalFrame.new(face)
    bbox  = frame.bbox_2d

    # Автопараметры
    auto_p = AutoParams.new(bbox).compute

    # Диалог параметров
    params = ParamsDialog.new(auto_p, bbox).show
    return unless params

    # RNG
    rng = params[:seed] ? Random.new(params[:seed]) : Random.new

    # --- Pipeline ---

    # 1. Ряды
    rows = RowGenerator.new(bbox, params, rng).build_rows

    # 2. Узлы
    row_nodes = NodeDistributor.new(rows, bbox, params, rng).distribute

    # 3. Камни по полосам
    matcher  = SeamMatcher.new(params, rng)
    builder  = CellBuilder.new(rows, row_nodes, params, rng)
    deformer = SeamDeformer.new(params, rng)

    all_cells = []
    (rows.size - 1).times do |band_idx|
      top_nodes = row_nodes[band_idx]
      bot_nodes = row_nodes[band_idx + 1]
      specs      = matcher.match(top_nodes, bot_nodes)
      band_cells = builder.build_from_specs(band_idx, specs)
      all_cells.concat(band_cells)
    end

    # 4. Обрезка по контуру грани (поддержка невыпуклых контуров)
    boundary = Geom2D.ensure_ccw(frame.face_loop_2d)

    # 5. Попытка использовать PlanarGraph для произвольных контуров
    # (если контур невыпуклый — CellExtractor даст более точный результат)
    clipped = if use_planar_graph?(boundary)
                extract_via_graph(all_cells, boundary, rows, params)
              else
                clip_cells(all_cells, boundary, params)
              end

    # 6. Деформация (зубья на швах) — ПОСЛЕ обрезки, по полосам
    #    Восстанавливаем полосовую структуру для deform_band
    deformed = deform_by_bands(clipped, rows, deformer)

    # 7. Валидация
    validator = StoneValidator.new(params)
    validated = validator.filter_and_repair(deformed)

    # 7. Запись в SketchUp
    SketchupBuilder.new(face, frame, params).build(validated)
  end

  def self.use_planar_graph?(boundary)
    # Используем PlanarGraph если контур невыпуклый (более 4 вершин и невыпуклый)
    boundary.size > 4 && !PolygonClip.convex?(boundary)
  end

  def self.extract_via_graph(cells, boundary, rows, params)
    graph = PlanarGraph.new

    # Добавить контур грани
    graph.add_polyline(boundary + [boundary.first])

    # Добавить все рёбра камней, обрезанные по контуру
    cells.each do |cell|
      pts = cell.points2d
      next unless pts && pts.size >= 3
      loop_pts = pts + [pts.first]
      graph.add_polyline_clipped(loop_pts, boundary)
    end

    # Извлечь ячейки
    face_pts_arr = CellExtractor.new(graph).extract_faces

    # Обернуть в StoneCell
    face_pts_arr.map do |pts|
      # Определить kind: если есть соответствующий камень — взять его kind
      matching = cells.find do |c|
        c_centroid = Geom2D.polygon_centroid(c.points2d)
        Geom2D.point_in_polygon?(c_centroid, pts)
      end
      kind = matching ? matching.kind : :normal
      CellBuilder::StoneCell.new(pts, kind)
    end
  end

  def self.clip_cells(cells, boundary, params)
    cells.map do |cell|
      begin
        pts = cell.points2d
        next nil unless pts && pts.size >= 3

        clipped_pts = PolygonClip.clip_polygon_by_nonconvex(pts, boundary)
        next nil if clipped_pts.nil? || clipped_pts.empty? || clipped_pts.size < 3

        area = Geom2D.polygon_area(clipped_pts).abs
        next nil if area < (params[:min_area] || 0.01) * 0.10

        CellBuilder::StoneCell.new(clipped_pts, cell.kind)
      rescue => _e
        nil
      end
    end.compact
  end

  # Деформация по полосам: группируем уже обрезанные камни по полосе через bbox y
  # и применяем deform_band к каждой полосе отдельно.
  def self.deform_by_bands(cells, rows, deformer)
    return cells if rows.size < 2

    # Для каждой полосы [band_idx] y-диапазон: [rows[band_idx].y_mid .. rows[band_idx+1].y_mid]
    # Группируем камень в полосу по центроиду
    n_bands = rows.size - 1

    # Предвычислить примерные y-границы каждой полосы
    # (используем среднее значение y из крайних точек кривой)
    band_y_mid = (0...n_bands).map do |bi|
      top_curve = rows[bi]
      bot_curve = rows[bi + 1]
      # Примерный y середины полосы
      (top_curve.samples.map { |s| s[1] }.sum / top_curve.samples.size +
       bot_curve.samples.map { |s| s[1] }.sum / bot_curve.samples.size) / 2.0
    end

    # Для каждого камня определяем полосу по centroid.y
    band_cells = Array.new(n_bands) { [] }

    cells.each do |cell|
      cy = cell.points2d.map { |p| p[1] }.sum / cell.points2d.size.to_f
      # Найти ближайшую полосу
      best_band = 0
      best_dist = (cy - band_y_mid[0]).abs
      (1...n_bands).each do |bi|
        d = (cy - band_y_mid[bi]).abs
        if d < best_dist
          best_dist = d
          best_band = bi
        end
      end
      band_cells[best_band] << cell
    end

    # Применить deform_band к каждой полосе, сортируя по x-центроиду
    result = []
    band_cells.each do |band|
      next if band.empty?
      sorted = band.sort_by { |c| c.points2d.map { |p| p[0] }.sum / c.points2d.size.to_f }
      result.concat(deformer.deform_band(sorted))
    end

    result
  end

  unless file_loaded?(__FILE__)
    file_loaded(__FILE__)
  end
end
