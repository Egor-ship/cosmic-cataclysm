//! Deterministic, SDK-independent geometry for the six impact scars.
//! A column is cleared above `floor`, lined there, then its optional solid feature is built.
//! `fit_surface` anchors columns to surveyed terrain and includes hills in the clearing.
//! Keep pre-existing bedrock out of replacement operations: this module has no block reads.

use std::f64::consts::{PI, TAU};

/// Vanilla Overworld bedrock occupies y=-64..=-60. Never touch those levels.
pub const LOWEST_FLOOR: i32 = -59;
pub const HIGHEST_BLOCK: i32 = 319;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Column {
    pub x: i32,
    pub z: i32,
    pub floor: i32,
    pub top: i32,
    pub lining: &'static str,
    /// Inclusive y range and block ID, filled after the air and lining.
    pub feature: Option<(i32, i32, &'static str)>,
}

impl Column {
    /// Height must be the actual top solid block, not heightmap's first air block.
    pub fn fit_surface(&mut self, surface: i32) {
        let surface = surface.clamp(LOWEST_FLOOR, HIGHEST_BLOCK);
        self.floor = self.floor.min(surface);
        self.top = self.top.max(surface.saturating_add(8)).min(HIGHEST_BLOCK);
        if let Some((_, end, block)) = self.feature {
            // A raised rim/spire is filled from its anchored floor, never left hanging.
            self.feature = (end > self.floor).then_some((self.floor + 1, end, block));
        }
    }
}

pub fn footprint(planet: usize) -> i32 {
    [46, 60, 64, 44, 68, 54].get(planet).copied().unwrap_or(0)
}

fn noise(x: i32, z: i32, salt: u32) -> f64 {
    let mut h = (x as u32).wrapping_mul(0x9e37_79b9)
        ^ (z as u32).wrapping_mul(0x85eb_ca6b) ^ salt;
    h ^= h >> 16;
    h = h.wrapping_mul(0x7feb_352d);
    h ^= h >> 15;
    f64::from(h) / f64::from(u32::MAX)
}

/// The footprint is capped at 68 blocks: fewer than 18,769 candidate columns.
/// Absolute vertical levels are clipped to the Overworld build range.
pub fn plan(planet: usize, center: [i32; 3]) -> Vec<Column> {
    let radius = footprint(planet);
    if radius == 0 || !(LOWEST_FLOOR + 1..=HIGHEST_BLOCK).contains(&center[1]) {
        return Vec::new();
    }
    if center[0].checked_add(radius).is_none() || center[0].checked_sub(radius).is_none()
        || center[2].checked_add(radius).is_none() || center[2].checked_sub(radius).is_none() {
        return Vec::new();
    }
    let [cx, cy, cz] = center;
    let mut columns = Vec::new();
    for dx in -radius..=radius {
        for dz in -radius..=radius {
            let r = f64::from(dx * dx + dz * dz).sqrt();
            let u = r / f64::from(radius);
            let a = f64::from(dz).atan2(f64::from(dx));
            let grain = noise(dx, dz, planet as u32 + 47);
            let mut edge = 1.0;
            if planet == 1 { edge = 0.94 + 0.035 * (a * 3.0 + 0.8).sin(); }
            if planet == 2 { edge = 0.82 + 0.18 * (a * 5.0).cos(); }
            if u > edge { continue; }

            let (depth, lining, raised): (f64, &str, Option<(f64, &str)>) = match planet {
                0 => {
                    let terrace = ((32.0 * (1.0 - u * u)).max(0.0) / 4.0).ceil() * 4.0;
                    let crack = (a * 9.0 + r * 0.085).sin().abs() < 0.09 && u > 0.34;
                    (terrace + if crack { 7.0 } else { 0.0 },
                     if crack || (u < 0.3 && grain > 0.55) { "minecraft:magma_block" }
                     else if grain > 0.22 { "minecraft:obsidian" } else { "minecraft:polished_basalt" }, None)
                }
                1 => {
                    let spiral = (a * 3.0 + r * 0.20).cos();
                    let channel = if spiral > 0.84 && u > 0.2 { 5.0 } else { 0.0 };
                    (18.0 * (1.0 - (u / edge).powi(2)) + channel,
                     if channel > 0.0 { "minecraft:green_stained_glass" }
                     else if grain > 0.72 { "minecraft:yellow_terracotta" }
                     else { "minecraft:packed_mud" }, None)
                }
                2 => {
                    let spoke = (a * 5.0).cos().max(0.0).powi(10);
                    let bowl = 28.0 * (1.0 - (u / edge).powi(2)).max(0.0);
                    let raised = if u / edge > 0.87 {
                        Some((3.0 + grain * 6.0, "minecraft:red_sandstone"))
                    } else { None };
                    (bowl + spoke * 9.0 * u,
                     if spoke > 0.5 { "minecraft:terracotta" }
                     else if grain > 0.8 { "minecraft:granite" }
                     else { "minecraft:red_sandstone" }, raised)
                }
                3 => {
                    let trunk = (a * 7.0 + (r * 0.23).sin() * 1.7).sin().abs() < 0.13;
                    let well = 38.0 * (-((r / 12.0).powi(2))).exp();
                    let raised = if trunk && u > 0.60 && grain > 0.45 {
                        Some((2.0 + grain * 9.0, "minecraft:cyan_stained_glass"))
                    } else { None };
                    (well + 13.0 * (1.0 - u * u) + if trunk { 4.0 } else { 0.0 },
                     if trunk { "minecraft:cyan_stained_glass" }
                     else if grain > 0.8 { "minecraft:polished_blackstone" }
                     else { "minecraft:blackstone" }, raised)
                }
                4 => {
                    let nearest = [0.32_f64, 0.61, 0.88].into_iter()
                        .map(|ring| (u - ring).abs()).fold(1.0_f64, f64::min);
                    let trough = (1.0 - nearest / 0.075).max(0.0);
                    let raised = if r < 3.5 {
                        Some((22.0 - r * 2.0, "minecraft:calcite"))
                    } else if nearest > 0.095 && grain > 0.94 {
                        Some((3.0 + grain * 4.0, "minecraft:packed_ice"))
                    } else { None };
                    (3.0 + trough * 24.0,
                     if trough > 0.55 { "minecraft:blue_ice" }
                     else if grain > 0.78 { "minecraft:calcite" }
                     else { "minecraft:packed_ice" }, raised)
                }
                5 => {
                    let terrace = (40.0 * (1.0 - u * u).max(0.0) / 5.0).ceil() * 5.0;
                    let mut spire = 0.0_f64;
                    for i in 0..6 {
                        let angle = f64::from(i) * TAU / 6.0 + PI / 12.0;
                        let sx = angle.cos() * f64::from(radius) * 0.72;
                        let sz = angle.sin() * f64::from(radius) * 0.72;
                        let d = ((f64::from(dx) - sx).powi(2) + (f64::from(dz) - sz).powi(2)).sqrt();
                        spire = spire.max(43.0 * (1.0 - d / 4.6).max(0.0));
                    }
                    let raised = (spire > 1.0).then_some((spire, "minecraft:blue_ice"));
                    (terrace, if grain > 0.7 { "minecraft:polished_deepslate" }
                     else { "minecraft:blue_ice" }, raised)
                }
                _ => unreachable!(),
            };
            let floor = (cy - depth.round().max(1.0) as i32).clamp(LOWEST_FLOOR, HIGHEST_BLOCK - 1);
            let feature = raised.and_then(|(height, block)| {
                let end = (cy + height.round() as i32).clamp(LOWEST_FLOOR, HIGHEST_BLOCK);
                (end > floor).then_some((floor + 1, end, block))
            });
            let top = (cy.saturating_add(12)).min(HIGHEST_BLOCK).max(floor + 1);
            columns.push(Column { x: cx + dx, z: cz + dz, floor, top, lining, feature });
        }
    }
    columns
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_six_scars_are_bounded_deterministic_and_distinct() {
        let mut signatures = Vec::new();
        for planet in 0..6 {
            let p = plan(planet, [100, 72, -200]);
            assert!(!p.is_empty() && p.len() < 25_000);
            assert_eq!(p, plan(planet, [100, 72, -200]));
            assert!(p.iter().all(|c| (c.x - 100).abs() <= footprint(planet) && (c.z + 200).abs() <= footprint(planet)));
            signatures.push((p.len(), p.iter().map(|c| c.floor).min().unwrap(), p.iter().filter(|c| c.feature.is_some()).count()));
        }
        for i in 0..6 { for j in i+1..6 { assert_ne!(signatures[i], signatures[j]); } }
        assert!(plan(2, [0, 72, 0]).len() < plan(4, [0, 72, 0]).len());
    }

    #[test]
    fn bottom_and_roof_never_escape_world_or_cut_vanilla_bedrock() {
        for y in [-58, 0, 72, 318, 319] { for planet in 0..6 {
            for c in plan(planet, [0, y, 0]) {
                assert!((LOWEST_FLOOR..HIGHEST_BLOCK).contains(&c.floor));
                assert!(c.top > c.floor && c.top <= HIGHEST_BLOCK);
                if let Some((start, end, _)) = c.feature { assert!(start > c.floor && end >= start && end <= HIGHEST_BLOCK); }
            }
        }}
        assert!(plan(0, [0, -60, 0]).is_empty());
        assert!(plan(6, [0, 72, 0]).is_empty());
        assert!(plan(0, [i32::MAX, 72, 0]).is_empty());
    }

    #[test]
    fn surveying_anchors_features_and_clears_hills() {
        let mut c = Column { x: 0, z: 0, floor: 55, top: 84, lining: "minecraft:blue_ice", feature: Some((56, 100, "minecraft:blue_ice")) };
        c.fit_surface(30);
        assert_eq!(c.floor, 30);
        assert_eq!(c.feature.unwrap().0, 31);
        c.fit_surface(300);
        assert_eq!(c.top, 308);
        c.fit_surface(319);
        assert_eq!(c.top, 319);
    }

    #[test]
    fn rings_pit_and_spires_have_actual_vertical_geometry() {
        let saturn = plan(4, [0, 80, 0]);
        let center = saturn.iter().find(|c| c.x == 0 && c.z == 0).unwrap();
        assert!(center.feature.unwrap().1 > 95);
        let ring = saturn.iter().find(|c| c.x == 22 && c.z == 0).unwrap();
        let between = saturn.iter().find(|c| c.x == 31 && c.z == 0).unwrap();
        assert!(ring.floor + 10 < between.floor);
        let neptune = plan(5, [0, 80, 0]);
        assert!(neptune.iter().any(|c| c.feature.is_some_and(|(_, high, _)| high > 110)));
        assert!(neptune.iter().find(|c| c.x == 0 && c.z == 0).unwrap().floor <= 40);
    }
}
