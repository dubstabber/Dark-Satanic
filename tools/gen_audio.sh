#!/usr/bin/env bash
# Generates the procedural Sad Satan sound set into assets/audio/sfx/*.ogg using sox.
# Deterministic (sox -R) so re-running does not churn the LFS objects.
# Usage: tools/gen_audio.sh            Requires: sox (ffmpeg as a fallback ogg encoder).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/assets/audio/sfx"
RATE=44100
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v sox >/dev/null || { echo "error: sox is required" >&2; exit 2; }
if sox --help 2>&1 | grep -A3 "AUDIO FILE FORMATS" | grep -qw ogg; then
  ENCODER=sox
elif command -v ffmpeg >/dev/null; then
  ENCODER=ffmpeg
else
  echo "error: sox lacks ogg support and ffmpeg is missing" >&2; exit 2
fi
mkdir -p "$OUT"

# synth <out.wav> <channels> <sox synth/effect args...>
synth() {
  local out="$1" ch="$2"; shift 2
  sox -R -n -r "$RATE" -c "$ch" -b 16 "$out" "$@"
}
# fx <in.wav> <out.wav> <effects...>
fx() {
  local in="$1" out="$2"; shift 2
  sox -R "$in" "$out" "$@"
}
# finish <in.wav> <out.wav> <effects...>: second pass so `fade ... 0` sees the real length after reverb.
finish() { fx "$@"; }
# mix <out.wav> <in.wav...>
mix() {
  local out="$1"; shift
  sox -R -m "$@" "$out"
}
# encode <name> <in.wav>
encode() {
  local name="$1" in="$2" target="$OUT/$1.ogg"
  if [[ "$ENCODER" == sox ]]; then
    sox -R "$in" -C 5 "$target"
  else
    ffmpeg -y -loglevel error -i "$in" -c:a libvorbis -q:a 5 "$target"
  fi
  local info
  info="$(sox --i -d "$target") s, $(sox --i -c "$target") ch, peak $(sox "$target" -n stat 2>&1 | awk '/Maximum amplitude/ {print $3}')"
  echo "  $name.ogg: $info"
}

echo "==> Generating sfx into $OUT ($ENCODER)"

# dagger_tick: 60 ms noise transient + falling blip, overdriven.
synth "$TMP/tick_noise.wav" 1 synth 0.06 whitenoise fade t 0 0.06 0.05 bandpass 2500 1.2q
synth "$TMP/tick_blip.wav" 1 synth 0.08 sine 1400:420 fade t 0.002 0.08 0.06
mix "$TMP/tick_mix.wav" "$TMP/tick_noise.wav" "$TMP/tick_blip.wav"
fx "$TMP/tick_mix.wav" "$TMP/tick.wav" overdrive 18 norm -3
encode dagger_tick "$TMP/tick.wav"

# shotgun_thump: low sine sweep 130->35 + brown noise, overdrive, lowpass.
synth "$TMP/thump_sine.wav" 1 synth 0.4 sine 130:35 fade t 0 0.4 0.32
synth "$TMP/thump_noise.wav" 1 synth 0.4 brownnoise fade t 0 0.4 0.3
mix "$TMP/thump_mix.wav" "$TMP/thump_sine.wav" "$TMP/thump_noise.wav"
fx "$TMP/thump_mix.wav" "$TMP/thump.wav" overdrive 20 lowpass 650 norm -3
encode shotgun_thump "$TMP/thump.wav"

# hit: short 1400->500 sine click.
synth "$TMP/hit.wav" 1 synth 0.07 sine 1400:500 fade t 0.001 0.07 0.05 norm -4
encode hit "$TMP/hit.wav"

# skull_screech: 0.5 s clashing square/saw sweeps, tremolo, overdrive, bandpass.
synth "$TMP/screech_raw.wav" 1 synth 0.5 square 820:310 saw mix 851:265 fade t 0.01 0.5 0.12
fx "$TMP/screech_raw.wav" "$TMP/screech.wav" tremolo 38 75 overdrive 22 bandpass 1300 1.5q norm -3
encode skull_screech "$TMP/screech.wav"

# spawner_groan: 1.6 s sawtooth 70->44 + sine, speed 0.6, overdrive, lowpass, tremolo, reverb.
synth "$TMP/groan_raw.wav" 1 synth 1.6 saw 70:44 sine mix 141:88 fade t 0.05 1.6 0.5
fx "$TMP/groan_raw.wav" "$TMP/groan.wav" speed 0.6 rate "$RATE" overdrive 16 gain -6 lowpass 420 \
  gain -8 tremolo 5.5 55 reverb 60 60 90 channels 1
finish "$TMP/groan.wav" "$TMP/groan_out.wav" fade t 0 0 0.1 norm -3
encode spawner_groan "$TMP/groan_out.wav"

# gem_chime: detuned sine pair 1760/1793 + triangle octave, reversed swell, pitch -40, reverb.
synth "$TMP/chime_raw.wav" 1 synth 0.55 sine 1760 sine mix 1793 triangle mix 3520 fade t 0.005 0.55 0.45
fx "$TMP/chime_raw.wav" "$TMP/chime.wav" reverse pitch -40 gain -6 reverb 45 50 80 channels 1
finish "$TMP/chime.wav" "$TMP/chime_out.wav" fade t 0 0 0.03 norm -6
encode gem_chime "$TMP/chime_out.wav"

# tier_up: rising detuned chord with a reversed (swelling) reverb tail.
synth "$TMP/tier_raw.wav" 1 synth 1.1 sine 220:440 sine mix 223:446 sine mix 330:660 triangle mix 441:880 \
  fade t 0.02 1.1 0.4
fx "$TMP/tier_raw.wav" "$TMP/tier.wav" reverse gain -8 reverb 70 60 100 channels 1 reverse
finish "$TMP/tier.wav" "$TMP/tier_out.wav" fade t 0.3 0 0.2 norm -4
encode tier_up "$TMP/tier_out.wav"

# death_stinger: descending sine/square, halved speed (3 s), reversed, overdrive, lowpass 1200, big reverb, fade.
synth "$TMP/death_raw.wav" 1 synth 1.5 sine 440:55 square mix 443:56 fade t 0.02 1.5 0.6
fx "$TMP/death_raw.wav" "$TMP/death.wav" speed 0.5 rate "$RATE" reverse overdrive 14 lowpass 1200 \
  gain -10 reverb 85 70 100 30 channels 1
finish "$TMP/death.wav" "$TMP/death_out.wav" fade t 0.05 0 0.8 norm -3
encode death_stinger "$TMP/death_out.wav"

# ui_click: 30 ms sine 2000.
synth "$TMP/click.wav" 1 synth 0.03 sine 2000 fade t 0.001 0.03 0.02 norm -6
encode ui_click "$TMP/click.wav"

# amb_drone: 30 s loop of detuned low sines with amplitude modulation over a brown noise bed.
synth "$TMP/drone_tone.wav" 2 synth 16 sine 55 sine mix 82.41 sine mix 110.3 sine amod 0.07
synth "$TMP/drone_bed.wav" 2 synth 16 brownnoise vol 0.25
mix "$TMP/drone_mix.wav" "$TMP/drone_tone.wav" "$TMP/drone_bed.wav"
fx "$TMP/drone_mix.wav" "$TMP/drone.wav" speed 0.5 rate "$RATE" reverse pitch -500 overdrive 12 \
  lowpass 900 gain -8 reverb 85 80 100 trim 0 30 fade t 0.05 30 0.05 norm -4
encode amb_drone "$TMP/drone.wav"

# menu_hum: 30 s loop of 50/100.7 Hz sines, slow tremolo, lowpass 300, reverb.
synth "$TMP/hum_raw.wav" 2 synth 30 sine 50 sine mix 100.7
fx "$TMP/hum_raw.wav" "$TMP/hum.wav" tremolo 0.2 40 lowpass 300 gain -6 reverb 50 60 90 trim 0 30 \
  fade t 0.05 30 0.05 norm -10
encode menu_hum "$TMP/hum.wav"

echo "==> Done"
