fn cosmic_key(game: &mut crate::game::Game<'_>, key: &str, pressed: bool) {
    crate::game::cosmic_glue::key(game, key, pressed);
}
