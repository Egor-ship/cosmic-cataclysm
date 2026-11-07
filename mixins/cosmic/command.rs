fn cosmic_command(game: &mut crate::game::Game<'_>, command: &str, ran: &mut bool) {
    if crate::game::cosmic_glue::command(game, command) {
        *ran = true;
    }
}
