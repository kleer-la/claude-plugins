# Capturas para video desde un system test de Rails (Capybara + Selenium).
#
# Mismo contrato que la receta Playwright: PNGs `NN_nombre.png` en un directorio,
# que después consume el motor. La paridad con `capture.ts` es a propósito —
# `highlight:` y `scroll:` se comportan igual; `focus:` tiene una limitación,
# documentada abajo.
#
# Uso:
#   class AltaVideoTest < ApplicationSystemTestCase
#     include VideoRecording
#     driven_by :selenium, using: :headless_chrome, screen_size: [1280, 800]
#     def scenario_name = "alta"
#
#     test "alta de un pedido" do
#       setup_video_recording
#       visit root_path
#       capture "inicio"
#       capture "total", highlight: "#total", scroll: "css:#total"
#     end
#   end
module VideoRecording
  HIGHLIGHT_ATTR  = "data-e2e-highlight".freeze
  HIGHLIGHT_STYLE_ID = "e2e-highlight-style".freeze
  HIGHLIGHT_CSS = <<~CSS.freeze
    [#{HIGHLIGHT_ATTR}] {
      outline: 3px solid #d9534f !important;
      outline-offset: 2px !important;
      box-shadow: 0 0 0 6px rgba(217, 83, 79, .18) !important;
      border-radius: 3px;
    }
  CSS

  # Nombre del escenario — las capturas van a tmp/video_screenshots/<escenario>/
  def scenario_name
    raise NotImplementedError, "definí scenario_name en la clase del test"
  end

  def screenshot_dir
    @screenshot_dir ||= Rails.root.join("tmp", "video_screenshots", scenario_name)
  end

  def setup_video_recording
    FileUtils.rm_rf(screenshot_dir)
    FileUtils.mkdir_p(screenshot_dir)
    @step = 0
  end

  # scroll:    :bottom | :top | Integer (píxeles) | "css:<selector>"
  # highlight: selector o array de selectores — recuadro rojo durante el disparo.
  # focus:     selector — fotografía sólo ese elemento.
  #            Ojo: Selenium recorta a la caja exacta, sin el aire que da
  #            `focusPad` en Playwright. Si necesitás contexto alrededor,
  #            enmarcá con highlight: en vez de recortar con focus:.
  def capture(name, pause: 0.4, scroll: nil, highlight: nil, focus: nil)
    aplicar_scroll(scroll) if scroll
    marcas = Array(highlight)
    marcar(marcas) if marcas.any?

    sleep pause
    @step += 1
    filename = format("%02d_%s.png", @step, name)
    destino = screenshot_dir.join(filename)

    if focus
      el = find(focus)
      el.native.save_screenshot(destino.to_s)
    else
      page.save_screenshot(destino)
    end

    desmarcar if marcas.any?
    filename
  end

  private

  def aplicar_scroll(scroll)
    case scroll
    when :bottom then page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    when :top    then page.execute_script("window.scrollTo(0, 0)")
    when Integer then page.execute_script("window.scrollBy(0, arguments[0])", scroll)
    when /\Acss:(.+)\z/ then find(Regexp.last_match(1)).execute_script("arguments[0].scrollIntoView({block: 'center'})")
    else raise ArgumentError, "scroll no reconocido: #{scroll.inspect}"
    end
  end

  def marcar(selectores)
    page.execute_script(<<~JS, HIGHLIGHT_STYLE_ID, HIGHLIGHT_CSS)
      if (!document.getElementById(arguments[0])) {
        const s = document.createElement("style");
        s.id = arguments[0];
        s.textContent = arguments[1];
        document.head.appendChild(s);
      }
    JS
    selectores.each do |sel|
      # Falla ruidosa: un highlight que no matchea es narración que apunta a algo
      # que ya no está en la pantalla — justo el cambio que el video debe delatar.
      el = find(sel)
      el.execute_script("arguments[0].setAttribute(arguments[1], '1')", HIGHLIGHT_ATTR)
    end
  end

  def desmarcar
    page.execute_script(<<~JS, HIGHLIGHT_ATTR)
      document.querySelectorAll("[" + arguments[0] + "]")
        .forEach((el) => el.removeAttribute(arguments[0]));
    JS
  end
end
