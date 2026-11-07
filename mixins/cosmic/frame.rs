fn cosmic_frame(game: &mut crate::game::Game<'_>, elapsed: std::time::Duration) {
    crate::game::cosmic_glue::frame(game, elapsed);
}
