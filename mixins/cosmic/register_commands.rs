fn cosmic_register_commands(
    game: &mut crate::game::Game<'_>,
    commands: &mut Vec<crate::mod_api::NativeCommand>,
) {
    crate::game::cosmic_glue::register_commands(game, commands);
}
