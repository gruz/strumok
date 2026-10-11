# Performance notes & decisions log

Notes for anyone (human or AI) investigating CPU load or tempted to
"optimize" this pipeline again. Read this before changing anything —
several tempting changes have already been tried and rejected for
concrete reasons. Only tested/rejected items with solid evidence are
recorded here; untested guesses are listed at the end as open questions.

## Where the CPU actually goes

The pipeline (`launch_gst` in `stream-window`):

```
pipewiresrc → video/x-raw → videorate → videocrop
→ [va: vapostproc (GPU scale+NV12)] | [x264: videoscale → videoconvert]
→ queue(leaky) → textoverlay → caps(fps) → queue → encoder → h264parse
→ flvmux → rtmp2sink
audiotestsrc(silence) → audioconvert → avenc_aac 64k mono → mux
```

Load sources, ordered by typical weight:

1. **Frame delivery (outside our pipeline!).** mutter + PipeWire capture
   the window at its *native* size and *source* rate and copy every frame
   into system memory. For a ~4K window that is ~2 GB/s of traffic,
   visible as CPU in `gnome-shell`/`pipewire`/`xdg-desktop-portal` —
   NOT in `gst-launch`. Output-side settings (scale/fps/bitrate) do not
   reduce this; only a smaller captured window does. Delivery is
   damage-driven: a static window is cheap even at 4K.
2. **CPU path (x264 branch):** `videoscale` 5.2 MP → 720p is
   single-threaded and is the heaviest element; `x264enc veryfast` on
   720p adds ~half a core.
3. **textoverlay:** cheap with the default transparent outline (one
   overlay on a 720p frame, pango render cached). NOT a meaningful load.
   The 9-copy outline emulation (`osd_outline` non-transparent +
   `osd_outline_width > 0`) is the expensive variant — avoid unless
   needed.
4. **Audio:** negligible by design (mono 64k silence).

## Measured results (remote i3-N305, Intel Gen Graphics, GNOME 46)

Worst-case dynamic test: captured a **3840x2160 window showing a
`mandelbrot=size=3840x2160:rate=30` animation** (every pixel changes
every frame — harder than typical high-motion video), portal window capture →
crop → ~996x720@24. %CPU is of a single core (8 logical CPUs):

| Process | Load |
|---|---|
| gst pipeline, **VA** (`vapostproc` + `vah264lpenc` → fakesink) | **~19-25% of one core** |
| gst pipeline, **x264** veryfast, same stream | **~48-51% of one core** |
| `gnome-shell` (compositing + screencast delivery) | ~6-12% |
| `pipewire` | ~0% |
| `screenrec` (systemd service, `--card /dev/dri/card1`) | **0% — confirmed not a load source**; it is never launched by this app, `watch_proc` only polls it |
| `ffplay` mandelbrot generator (test-only) | ~100% |

Conclusions:
- VA encode is ~2.5x cheaper than x264 even in the worst case;
  `encoder: va` appears in the log when the VA path is active.
- The machine can stream even with x264 (~half a core), so report fan
  issues as *which* encoder ran, not just CPU numbers.
- Portal + restore-token can complete without a dialog when the window
  matches the stored token; the dialog only blocks when re-selection is
  needed.
- A static screen is NOT a valid load test: H.264 skips/reuses static
  content and mutter delivers far fewer damaged frames. Any future
  benchmark must animate the captured surface and measure the source
  generator's own CPU separately (our `ffplay` mandelbrot cost ~1 core).

## Tried and rejected — do not re-apply without new data

- **`videoconvert` before crop/scale.** Was the original order and the
  single biggest CPU cost: converted every full-size source frame.
  Moved after `videoscale` deliberately (~12x fewer pixels converted).
- **`ultrafast` x264 preset.** Used initially; produced visibly blurry
  text at the same bitrate. `veryfast` is the chosen floor;
  `superfast` is a known fallback for weak CPUs, `ultrafast` is not.
- **Low-res output (fit 1280x720 → ~996x720 output @ 15fps, 1200 kbps).**
  First "lightweight" attempt — user reported heavy blur because the
  player re-enlarges the small frame. Current 1280x720 box keeps the
  crop region readable.
- **`1920x1440` fit-box @ 2500 kbps.** Tried as "balance ~1080p";
  dropped in v0.1.5 to 1280x720/1800 after the CPU-load reports on the
  work machine. Revisit only if CPU headroom is proven.
- **`lanczos` scaler.** Sharper but pricier; reverted to `bilinear`
  (v0.1.5) for CPU reasons.
- **Hardcoded `LIBVA_DRIVER_NAME=iHD`.** Breaks VA-API on AMD
  (needs `radeonsi`). Only `LIBVA_DRIVERS_PATH` is set, and only on
  NixOS (`/run/opengl-driver` is a NixOS-ism; other distros find the
  driver themselves).

## Deliberate design choices (not bugs)

- **`video/x-raw` caps right after `pipewiresrc`:** pins system memory —
  `videorate`/`videocrop` cannot handle DMABuf, and `vapostproc`
  downstream would otherwise negotiate DMABuf unexpectedly.
- **`queue max-size-buffers=8 leaky=downstream`** (v0.1.5): under
  backpressure, drop frames instead of accumulating latency.
- **`encoder=auto` probes `vah264lpenc` + `vapostproc`.** The `va`
  plugin ships inside `gst-plugins-bad` (verified on the work machine:
  elements exist in both the system GStreamer and the script's
  nix-shell env), so `gst_all_1.gst-vaapi` in the shebang is a
  belt-and-suspenders extra, not the real source. If the element exists
  but the driver fails at runtime, the supervisor gives up after 2
  failed starts and notifies; force `encoder = x264` to revert.
- **`vapostproc` crashes with non-VA downstream sinks** (gst-plugins-bad
  1.24.3): `vapostproc ! fakesink` tries to allocate ~140 TB and dies.
  With a VA-aware consumer downstream (`vah264lpenc`, also through
  `queue`/`textoverlay` in the real chain) it works fine — verified
  end-to-end including `videocrop`. Don't judge it by the fakesink
  test.
- **Hardware measured on the work machine (v0.1.6 tests):** Intel
  i3-N305 + iHD (`/run/opengl-driver/lib/dri` has both i965 and iHD).
  Synthetic 2686x1938 → 1280x720 @ 24fps full chain (incl.
  videotestsrc generation overhead): x264 path ≈ 80% of one core,
  va path ≈ 45%. The i3-N305 is a low-power E-core-only chip — the
  remaining cost is mostly unavoidable frame delivery.
- **`vah264lpenc` is the low-power Intel path.** If its quality at
  1800 kbps is insufficient, `vah264enc` (full-power encode) is the
  next knob — slightly more GPU work, better quality per bit.
- **`screenrec` on the work machine is a systemd service**
  (`screenrec --card /dev/dri/card1`), 0% CPU when idle — it is NOT
  started by us and not the load source. `watch_proc` only observes it.
  It does share the GPU, though.
- **`require_proc` is pinned to the pids seen at stream start.** The
  captured window dies with that instance; a pattern re-match would keep
  the stream alive after an app restart even though the window is gone.
  `watch_proc` keeps pattern semantics (any match keeps it alive).
- **`pgrep_filtered` excludes our own processes:** the orchestrator argv
  carries the profile name and gst children carry the OSD text, so an
  unfiltered `pgrep -f` can self-match and never detect app death.
- **Silent audio at all:** some RTMP servers reject video-only FLV.
  64k mono AAC of silence compresses to ~nothing.

## Diagnosing CPU load on a machine

```sh
# which encoder is actually running (the profile line prints it)
grep 'encoder:' ~/stream-window.log | tail -5    # va vs x264

# who is burning CPU during a stream — check screenrec separately!
top -b -n1 | head -25

# is a VA-API driver present (NixOS)
ls /run/opengl-driver/lib/dri 2>/dev/null   # iHD/i965/radeonsi => VA possible

# what GPU
lspci | grep -i vga
```

Reading the GPU result: Intel iGPU (`iHD`/`i965` driver) and AMD
(`radeonsi`) both support VA-API H.264 encode. NVIDIA does not — its
VA-API driver is decode-only, so `x264` is the only option there. If
`/run/opengl-driver` does not exist at all, `hardware.graphics` is off
in the NixOS config and VA-API cannot work regardless of the GPU.

Caveat: `gst-inspect-1.0 vah264lpenc` in a plain shell shows nothing —
the plugin lives only inside the script's nix-shell environment. The
`encoder:` line in `~/stream-window.log` is the reliable check.

## Open questions / not yet tried

- Whether `vapostproc` + `textoverlay` NV12 compositing works across
  drivers — verify on the work machine (`encoder: va` in the log).
- `glupload`/`gldownload` GPU-resident pipeline for the x264 path.
- Whether PipeWire can negotiate a lower source framerate instead of
  dropping in `videorate` (would cut delivery cost).
