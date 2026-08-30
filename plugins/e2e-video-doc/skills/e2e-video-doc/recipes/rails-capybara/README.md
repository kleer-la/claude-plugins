# Receta Rails (Capybara + Selenium)

Copiá `video_recording.rb` a `test/support/`.

```ruby
class AltaVideoTest < ApplicationSystemTestCase
  include VideoRecording
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 800]

  def scenario_name = "alta"

  test "alta de un pedido" do
    setup_video_recording
    visit root_path
    capture "inicio"
    capture "total", highlight: "#total", scroll: "css:#total"
  end
end
```

Capturas en `tmp/video_screenshots/<scenario_name>/`. **El MP4 no puede quedar
ahí** — `setup_video_recording` hace `rm -rf` del directorio.

| Opción | Qué hace |
|---|---|
| `highlight:` | Recuadro rojo, uno o varios selectores. Falla si no matchea. |
| `focus:` | Fotografía sólo ese elemento. **Sin padding** — ver abajo. |
| `scroll:` | `:top` \| `:bottom` \| Integer \| `"css:<selector>"`. |
| `pause:` | Espera antes del disparo (default 0.4). |

## Diferencia con la receta Playwright

`focus:` recorta a la caja exacta del elemento: Selenium saca la captura del
elemento, no un recorte del viewport, así que no hay equivalente a `focusPad`. Si
necesitás contexto alrededor, **enmarcá con `highlight:` en vez de recortar con
`focus:`**.

Todo lo demás se comporta igual, a propósito.

## Correrlo

Los tests de video suelen ir detrás de un flag para que no corran en CI:

```ruby
test "alta de un pedido" do
  skip "sólo con RUN_VIDEO_TESTS=1" unless ENV["RUN_VIDEO_TESTS"]
```

```bash
docker exec -e RUN_VIDEO_TESTS=1 <container> bin/rails test test/system/alta_video_test.rb
```

Si el entorno de test necesita el meta de CSRF presente (Rails lo deshabilita y
`csrf_meta_tags` no renderiza nada), inyectá uno dummy después de navegar.
