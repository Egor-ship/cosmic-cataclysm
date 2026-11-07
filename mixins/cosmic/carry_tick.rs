fn cosmic_carry_tick(
    world: &mut crate::motion::MotionWorld<'_, '_, '_>,
    keys: crate::sprint::Keys,
) -> core::ops::ControlFlow<Result<()>> {
    crate::cosmic_carry::player_tick(world, keys)
}
