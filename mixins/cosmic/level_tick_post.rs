fn cosmic_level_tick_post(game: &mut crate::game::Game<'_>, dimension: &str) {
    crate::game::cosmic_glue::level_tick(game, dimension);
}
