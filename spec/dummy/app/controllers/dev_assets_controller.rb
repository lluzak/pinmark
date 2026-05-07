# frozen_string_literal: true

# Serves the engine's Stimulus controller as a JS module so the dummy app can
# load it without an importmap- or webpack-based asset pipeline.
class DevAssetsController < ActionController::Base
  ENGINE_JS_ROOT = Pinmark::Engine.root.join("app/javascript").freeze

  skip_forgery_protection

  def pinmark_controller
    serve(ENGINE_JS_ROOT.join("pinmark/pinmark_controller.js"))
  end

  private

  def serve(path)
    raise ActionController::RoutingError, "asset not found: #{path}" unless path.file?

    expires_in 0, must_revalidate: true
    response.headers["Cache-Control"] = "no-cache"
    send_data path.read,
              type: "application/javascript",
              disposition: "inline"
  end
end
