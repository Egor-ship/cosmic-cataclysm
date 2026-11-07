fn cosmic_net_from_server(game: &mut crate::game::Game<'_>, channel: &str, data: &[u8]) {
    crate::game::cosmic_glue::from_server(game, channel, data);
}
