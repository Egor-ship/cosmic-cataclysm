fn cosmic_render_frame(frame: &crate::gfx::Frame<'_>) {
    crate::cosmic_post::capture(frame);
}
