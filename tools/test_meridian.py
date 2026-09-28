"""Contract tests and real RGBA32F shader probes; no screenshot golden files."""
from __future__ import annotations

import math
import re
import unittest

from render_preview import GLProbe
from validate_glsl import SHADERS
from validate_profiles import PROFILES, apply_profile, parse_profiles, parse_settings

MERIDIAN = 'probeColor = vec4(meridianRadiance(rd, uSunHeight, frameTimeCounter, rainStrength), 1.0);'
TIDE = '''probeColor = vec4(tidalRadiance(vec3(uv.x * 40.0, 0.0, uv.y * 40.0),
    4.0, 1.0, 12.0, uSunHeight, frameTimeCounter), 1.0);'''
SKY = 'vec3 sun = normalize(vec3(1.0, uSunHeight, 0.0)); probeColor = vec4(renderDimensionSky(rd, sun, -sun), 1.0);'


def rgb(pixels):
    return [value for i, value in enumerate(pixels) if i % 4 != 3]


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.settings = (SHADERS / 'lib/settings.glsl').read_text()
        self.properties = (SHADERS / 'shaders.properties').read_text()

    def test_defaults_have_legal_domains(self):
        options = parse_settings(self.settings)
        self.assertEqual(options['VIBE_MODE'], set('01234'))
        self.assertIn('72.0', options['VISION_FOCUS_DISTANCE'])
        self.assertIn('0.78', options['SURVIVAL_EFFECT_STRENGTH'])

    def test_every_profile_drives_new_options(self):
        self.assertEqual(set(PROFILES), {'LOW', 'MEDIUM', 'HIGH', 'CINEMATIC'})
        for profile in PROFILES.values():
            for key in ('CELESTIAL_QUALITY', 'CELESTIAL_STRENGTH', 'TIDAL_GLOW', 'PHENOMENA_SPEED'):
                self.assertIn(key, profile['numbers'])
            self.assertEqual(profile['numbers']['VIBE_MODE'], '4')
        self.assertEqual(PROFILES['LOW']['numbers']['TIDAL_GLOW'], '0.00')
        self.assertIn('TAA_ENABLED', PROFILES['HIGH']['off'])

    def test_unknown_option_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_profiles(self.properties.replace('TIDAL_GLOW=', 'TIDAL_TYPO='), self.settings)

    def test_invalid_numeric_value_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_profiles(self.properties.replace('CELESTIAL_QUALITY=1', 'CELESTIAL_QUALITY=99'), self.settings)

    def test_duplicate_or_wrong_type_is_rejected(self):
        for text in ('profile.X = TIDAL_GLOW=0.65 TIDAL_GLOW=0.00',
                     'profile.X = TIDAL_GLOW', 'profile.X = SSAO_ENABLED=1',
                     'profile.X = !SSAO_ENABLED SSAO_ENABLED',
                     'profile.X = !TIDAL_GLOW=0.65', ''):
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_profiles(text, self.settings)

    def test_profile_replaces_numeric_and_boolean_defines(self):
        pattern = r"(?m)^(?://)?#define[ \t]+(\w+)"
        expected_keys = set(re.findall(pattern, self.settings))
        for profile in PROFILES.values():
            result = apply_profile(self.settings, profile)
            actual_keys = set(re.findall(pattern, result)) - profile.get('feature_defines', set())
            self.assertEqual(actual_keys, expected_keys)
            for key in profile['on']:
                self.assertRegex(result, rf"(?m)^#define {key}$")
            for key in profile['off']:
                self.assertRegex(result, rf"(?m)^//#define {key}$")
            for key, value in profile['numbers'].items():
                self.assertIn(f'#define {key} {value}\n', result)

    def test_fog_does_not_use_object_sky(self):
        source = (SHADERS / 'program/deferred/main.glsl').read_text()
        self.assertNotIn('fogColor = renderDimensionSky', source)
        self.assertEqual(source.count('fogColor = renderDimensionFog'), 2)


class ShaderPixelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Missing EGL is a failure, not a silent skip in the CI validation job.
        cls.probe = GLProbe()

    @classmethod
    def tearDownClass(cls):
        cls.probe.close()

    def values(self, body=MERIDIAN, **kwargs):
        return rgb(self.probe.render(body, **kwargs))

    def assert_zero(self, values):
        self.assertLessEqual(max(map(abs, values)), 1e-7)

    def test_all_skies_are_finite_nonnegative(self):
        for dim in ('OVERWORLD', 'NETHER', 'END'):
            for quality in ('0', '1', '2'):
                for sun in (-1.0, 0.0, 1.0):
                    with self.subTest(dim=dim, quality=quality, sun=sun):
                        values = self.values(SKY, dimension=dim, numbers={'CELESTIAL_QUALITY': quality},
                                             uniforms={'uSunHeight': sun})
                        self.assertTrue(all(math.isfinite(v) and v >= 0 for v in values))

    def test_poles_and_opposite_hemisphere_are_finite(self):
        for direction in ('0.0, 1.0, 0.0', '0.0, -1.0, 0.0', '0.0, 0.0, 1.0'):
            for dim in ('OVERWORLD', 'NETHER', 'END'):
                values = self.values(f'rd = vec3({direction});' + SKY,
                                     dimension=dim, width=1, height=1)
                self.assertTrue(all(math.isfinite(v) for v in values))

    def test_meridian_disable_paths(self):
        for numbers in ({'CELESTIAL_QUALITY': '0'}, {'CELESTIAL_STRENGTH': '0.00'}):
            self.assert_zero(self.values(numbers=numbers))
        self.assert_zero(self.values(uniforms={'rainStrength': 1.0}))
        self.assert_zero(self.values('rd.y = -abs(rd.y);' + MERIDIAN))

    def test_meridian_is_local_not_fullscreen_tint(self):
        values = self.values(uniforms={'uSunHeight': -0.035})
        visible = sum(max(values[i:i+3]) > 0.01 for i in range(0, len(values), 3))
        self.assertGreater(visible, 0)
        self.assertLess(visible, len(values) // 3 * 0.20)

    def test_tide_is_sparse_and_visible_at_night(self):
        values = self.values(TIDE, width=128, height=128)
        visible = sum(max(values[i:i+3]) > 0.002 for i in range(0, len(values), 3))
        self.assertGreater(visible, 8)
        self.assertLess(visible, len(values) // 3 * 0.20)
        self.assertGreater(max(values), 0.02)

    def test_tide_disable_and_dimension_paths(self):
        for numbers in ({'TIDAL_GLOW': '0.00'}, {'WATER_QUALITY': '0'}):
            self.assert_zero(self.values(TIDE, numbers=numbers))
        self.assert_zero(self.values(TIDE, dimension='NETHER'))
        self.assert_zero(self.values(TIDE, uniforms={'uSunHeight': 0.3}))

    def test_tide_respects_thin_water_and_distance(self):
        for original, replacement in (('4.0, 1.0, 12.0', '4.0, 0.0, 12.0'),
                                      ('4.0, 1.0, 12.0', '4.0, 1.0, 76.0'),
                                      ('4.0, 1.0, 12.0', '0.01, 1.0, 12.0')):
            self.assert_zero(self.values(TIDE.replace(original, replacement)))

    def test_zero_speed_freezes_new_surface_and_sky_patterns(self):
        for body in (MERIDIAN, TIDE):
            a = self.values(body, numbers={'PHENOMENA_SPEED': '0.00'}, uniforms={'frameTimeCounter': 1.0})
            b = self.values(body, numbers={'PHENOMENA_SPEED': '0.00'}, uniforms={'frameTimeCounter': 90.0})
            self.assertEqual(a, b)

    def test_motion_changes_the_pattern(self):
        for body in (MERIDIAN, TIDE):
            a = self.values(body, uniforms={'frameTimeCounter': 1.0})
            b = self.values(body, uniforms={'frameTimeCounter': 90.0})
            self.assertGreater(max(abs(x-y) for x, y in zip(a, b)), 0.001)

    def test_end_has_no_mirrored_object_behind_camera(self):
        body = '''rd = -normalize(vec3(0.18, 0.24, -1.0));
        probeColor = vec4(abs(endSky(rd) - endStarBackdrop(rd)), 1.0);'''
        self.assert_zero(self.values(body, dimension='END', width=1, height=1))

    def test_end_dark_center_occludes_stars(self):
        body = '''rd = normalize(vec3(0.18, 0.24, -1.0));
        probeColor = vec4(endSky(rd), 1.0);'''
        self.assertLess(max(self.values(body, dimension='END', width=1, height=1)), 0.002)

    def test_celestial_objects_do_not_enter_fog(self):
        body = 'probeColor = vec4(renderDimensionFog(rd, vec3(0.0, 1.0, 0.0)), 1.0);'
        for dim in ('NETHER', 'END'):
            a = self.values(body, dimension=dim, numbers={'CELESTIAL_STRENGTH': '0.00'})
            b = self.values(body, dimension=dim, numbers={'CELESTIAL_STRENGTH': '1.25'})
            self.assertEqual(a, b)

    def test_exact_wave_normal_matches_height_derivative(self):
        body = '''vec2 p = uv * 20.0;
        float e = 0.01;
        vec2 slope = vec2(waterHeight(p + vec2(e,0), frameTimeCounter) -
                          waterHeight(p - vec2(e,0), frameTimeCounter),
                          waterHeight(p + vec2(0,e), frameTimeCounter) -
                          waterHeight(p - vec2(0,e), frameTimeCounter)) / (2.0 * e);
        vec3 expected = normalize(vec3(-slope.x, 1.0, -slope.y));
        probeColor = vec4(abs(expected - waterNormalFromWorld(p, frameTimeCounter)), 1.0);'''
        self.assertLess(max(self.values(body)), 2e-5)


if __name__ == '__main__':
    unittest.main()
