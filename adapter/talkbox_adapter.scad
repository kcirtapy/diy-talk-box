// =====================================================================
// Talk box adapter
// Compression driver (1-3/8"-18 screw-on throat) --> talk box tube
// Designed for the Sound Town MHF-014; fits any driver with the
// standard 1-3/8"-18 horn thread.
//
// Part of https://github.com/kcirtapy/diy-talk-box
//
// HOW TO USE
//   1. Open in OpenSCAD (free: openscad.org)
//   2. Set part = "testring" and print that first to check thread fit
//   3. Adjust thread_clear until it screws on smoothly
//   4. Measure your tube, set stub_od / stub_bore
//   5. Set part = "adapter", press F6 (render), then export STL
// =====================================================================


// ---------- WHICH PART TO RENDER ----------
part = "adapter";        // "adapter" = the real thing
                         // "testring" = just the threads, ~2 min print


// ---------- THREAD (driver side) ----------
// These are the standard 1-3/8"-18 values. Don't change unless your
// driver measures differently.
thread_major  = 34.925;  // major diameter, mm  (1.375")
thread_pitch  = 1.4111;  // mm  (25.4 / 18 threads per inch)
thread_len    = 14;      // how deep the driver screws in

// THE NUMBER YOU WILL TUNE. Bigger = looser.
// Start at 0.4. If it won't start threading, try 0.6. If it wobbles, 0.25.
thread_clear  = 0.4;


// ---------- BORE / ACOUSTICS ----------
throat_bore   = 25.4;    // driver throat inside diameter (1")
cone_len      = 30;      // length of the taper. Longer = smoother = better.


// ---------- TUBE SIDE — MEASURE YOUR TUBE ----------
// Default assumes the tube's coupler collar slips OVER this stub.
// Dunlop ECB303 spec: tube ~0.58" diameter, coupler ~0.795".
// Measure the coupler's INSIDE diameter and subtract ~0.2mm for a snug fit.
stub_od       = 14.6;    // outside diameter of the spigot
stub_bore     = 9.0;     // final inside bore at the mouth end
stub_len      = 14;      // how far it goes into the tube

// If instead you want the TUBE to slide over a barb, set stub_od to the
// tube's inside diameter + 0.3mm and turn on the barb ridge:
barb          = false;


// ---------- SHELL ----------
wall          = 3.2;     // min wall thickness of the tapering body
flange_od     = 46;      // outside diameter of the threaded end
grip_flats    = true;    // flat sides so you can grip it while tightening


$fn = 120;


// =====================================================================
// THREAD GENERATION
// =====================================================================

// Standard 60-degree unified thread form, as seen in a 2D slice.
// One full turn of the thread = 360 degrees of this profile:
//   |a| <= 22.5 deg : flat crest   (P/8 wide, at the thread root)
//   22.5 .. 135 deg : 60-degree flanks
//   |a| >= 135 deg  : flat bore    (P/4 wide, the thread's inner crest)
// Extruding it with twist sweeps that shape into a helix.
module thread_profile(root_r, crest_r, steps = 48) {
    pts = [ for (i = [0 : steps - 1])
              let (a = -180 + 360 * i / steps,
                   t = abs(a) <= 22.5 ? 1
                     : abs(a) >= 135  ? 0
                     : (135 - abs(a)) / (135 - 22.5),
                   r = root_r + (crest_r - root_r) * t)
              [r * cos(a), r * sin(a)] ];
    polygon(pts);
}

// The shape of the mating screw (right-hand). Subtracting it from a solid
// leaves a female thread. `clear` grows it so printed parts don't bind.
module male_thread(major_d, pitch, len, clear = 0) {
    crest_r = major_d / 2 + clear / 2;
    root_r  = crest_r - 0.5413 * pitch;      // internal thread depth (5/8 H)
    turns   = len / pitch;
    linear_extrude(height = len,
                   twist  = -360 * turns,
                   slices = ceil(turns * 36),
                   convexity = 12)
        thread_profile(root_r, crest_r);
}


// =====================================================================
// THE ADAPTER
// =====================================================================

shoulder   = 2;                              // flat under the thread
cone_z     = thread_len + shoulder;          // where the taper starts
stub_z     = cone_z + cone_len;              // where the spigot starts
total_h    = stub_z + stub_len;

module outer_shell() {
    union() {
        // threaded end
        intersection() {
            cylinder(d = flange_od, h = cone_z);
            if (grip_flats)
                cube([flange_od, flange_od - 7, 2 * cone_z], center = true);
            else
                cylinder(d = flange_od, h = 2 * cone_z, center = true);
        }
        // tapering body
        translate([0, 0, cone_z - 0.01])
            cylinder(d1 = flange_od, d2 = stub_od + 2 * wall,
                     h = cone_len + 0.02);
        // spigot
        translate([0, 0, stub_z - 0.01])
            cylinder(d = stub_od, h = stub_len + 0.01);
        // optional barb ridge near the tip
        if (barb)
            translate([0, 0, total_h - 4])
                cylinder(d1 = stub_od + 0.9, d2 = stub_od, h = 3);
    }
}

module inner_cavity() {
    // straight bore behind the driver throat
    translate([0, 0, thread_len - 0.01])
        cylinder(d = throat_bore, h = shoulder + 0.02);
    // the taper — this is the acoustically important bit
    translate([0, 0, cone_z - 0.01])
        cylinder(d1 = throat_bore, d2 = stub_bore, h = cone_len + 0.02);
    // through the spigot
    translate([0, 0, stub_z - 0.01])
        cylinder(d = stub_bore, h = stub_len + 1);
}

module adapter() {
    difference() {
        outer_shell();
        inner_cavity();
        // female thread: cut a male thread out of the bottom
        translate([0, 0, -0.5])
            male_thread(thread_major, thread_pitch,
                        thread_len + 0.5, thread_clear);
        // lead-in chamfer so it starts threading easily
        translate([0, 0, -0.01])
            cylinder(d1 = thread_major + 1.6, d2 = thread_major - 1.2, h = 1.4);
    }
}

// Short stub of threads only — print this first to dial in thread_clear.
module testring() {
    difference() {
        cylinder(d = flange_od, h = 9);
        translate([0, 0, -0.5])
            male_thread(thread_major, thread_pitch, 10, thread_clear);
        translate([0, 0, -0.01])
            cylinder(d1 = thread_major + 1.6, d2 = thread_major - 1.2, h = 1.4);
    }
}


// =====================================================================
if (part == "adapter")  adapter();
else                    testring();
