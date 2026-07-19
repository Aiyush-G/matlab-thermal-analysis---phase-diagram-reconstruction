# Thermal Analysis of Cooling Curves: User Guide

**Version 2.0** · Aiyush Gupta, Department of Materials, University of Oxford
Contact: aiyush.gupta@st-annes.ox.ac.uk

## 1. What the app does

When a molten alloy cools and solidifies, latent heat released at phase transformations
briefly slows the cooling. These "thermal arrests" mark the **liquidus** (first solid
appears), the **solidus** (last liquid disappears), and any invariant reactions such as a
eutectic. This app makes the arrests easy to locate: it fits a smooth *no-transformation
background* to the measured cooling curve, using a polynomial and/or a Newton's-law-of-cooling
exponential, T(t) = T_env + (T₀ − T_env)·e^(−at), and subtracts it. What remains is the
transformation signal, and peaks in its smoothed time-derivative pinpoint the arrest
temperatures. Doing this for several alloy compositions and entering the results in the
second tab builds an experimental phase diagram.

## 2. Installation (Assumed MATLAB installed with Curve Fitting Toolbox)

If you *do* have MATLAB (R2021a or newer, with the Curve Fitting Toolbox), simply run `ThermalAnalysisOfCoolingCurves.m`.

## 3. Input file formats

The app reads delimited text and spreadsheet files: **CSV**, tab/space/semicolon-delimited
**.txt/.dat/.tsv**, and **Excel** (.xlsx/.xls).

| Format | Notes |
| --- | --- |
| Optional single header row | Detected automatically and used to label the channel dropdowns. |
| Time column | One column must be time, in any unit and increasing. Every other numeric column is available as a temperature channel, so any number of channels is fine. |
| Legacy numeric matrices | Plain headerless numeric matrices, with time in column 1, load exactly as before. The legacy format from earlier versions remains supported, and `sample_data/sample_cooling_curve_legacy_format.txt` is an example. |
| Non-numeric columns | Ignored. Files that cannot be parsed produce a clear error dialog listing the supported formats. |

## 4. The Analysis tab

**Controls (left panel, top to bottom):**

| Control | Purpose |
| --- | --- |
| Load Data File… | Pick your logged data file. The preview table at the bottom shows the first 500 rows with their row numbers, which are used by the fit range below. |
| Time column / Sample channel / Reference channel | Choose channels by name from dropdowns. The sample channel is the thermocouple in the solidifying material; the reference, which is optional, is typically the furnace. Choose "(none)" if you logged only one channel. Sensible defaults are guessed on load. |
| Sample name / Reference name / Plot title | Free-text labels used in graph titles and legends, for example "Al-12Si ingot" / "Furnace wall". |
| Time unit / Temperature unit | Axis-label units, with defaults of s and °C. The ambient temperature below must be entered in the same temperature unit. |
| Ambient temp | T_env in the Newton-cooling fit, default 20. |
| Smoothing window | Number of points in the moving average applied to derivatives, default 11. Use odd values; larger values are smoother but broaden peaks. |
| Polynomial order | Degree of the polynomial background, default 9 and max 9. |
| Subtract background | Chooses which fitted background graph 5 subtracts: Newton cooling, which is physically motivated, or Polynomial, which follows more complicated furnace programmes. |
| Fit range start/end (row) | Data-row window used for the background fit. Choose a window that starts on the smooth liquid-cooling section and brackets the whole transformation. Hover any control for a tooltip. |
| Update Graphs | Recomputes all five graphs. See §6 for Save/Load Session. |

**The five graphs, and how to read them:**

| Graph | How to read it |
| --- | --- |
| Cooling curves | Raw sample, and reference if present, temperature versus time. Sanity check: arrests appear as changes of slope or plateaus. |
| Sample and difference | Sample temperature with sample minus reference on the right axis. The difference removes the shared furnace trend, so arrests stand out as bumps. |
| Difference and cooling rate | The difference signal alongside the smoothed dT/dt. Arrests appear where the cooling rate suddenly heads toward zero. |
| Background fit | The data in your fit range with the polynomial and Newton-cooling fits overlaid. Check the fits hug the smooth, non-transforming parts of the curve; adjust the fit range if they chase the arrests themselves. |
| Background-subtracted | The residual, data minus background, and its smoothed derivative. Read your transformation temperatures here: the onset of the first peak corresponds to the liquidus; the last arrest, a sharp spike for a eutectic, gives the solidus. Read the temperature off graph 1/2 at the matching time, and jot the values in the Notes box. They are saved with your exports and sessions. |

**Exporting:** choose a folder (**Set Export Path…**), an optional filename prefix, tick
PNG/JPEG/PDF, and press **Export**. All five graphs are written as
`<prefix>_1_cooling_curves.png` through `<prefix>_5_background_subtracted.png`, and your notes
as `<prefix>_Notes.txt`.

## 5. The Phase Diagram Construction tab

Each analysed composition contributes one row: **Composition, Liquidus, Solidus**.

| Action | Purpose |
| --- | --- |
| Import Table Data… | Load rows from CSV/Excel. Columns are matched by header keywords (comp/liq/sol), falling back to column order. You are asked whether to replace or append to existing rows. |
| Add New Row | Appends an empty row. Double-click cells to type values. |
| Delete Selected | Removes the highlighted row or rows. |
| Export Table Data… | Saves the table to CSV or Excel. |
| Composition axis label | X-axis label, for example "Sn content (wt.%)." |
| Plot Phase Diagram | Sorts by composition and draws the liquidus and solidus curves. At least two complete rows are needed. |
| Export Graph… | Saves the diagram as PNG, JPEG, or PDF. |

## 6. Sessions

**Save Session…** writes a single `.mat` file containing the loaded data, every setting,
your notes, and the phase-diagram table. **Load Session…** restores all of it and redraws
the graphs, so there is no need to re-do an analysis or keep the original data file. Session files
are portable between the standalone and MATLAB versions.

## 7. Quick start with the sample data

1. Analysis tab → **Load Data File…** → `sample_cooling_curve_AlloyA_30wtB.csv`
   (a synthetic alloy, 30 wt.% B: liquidus 260 °C, eutectic solidus 183 °C).
2. The dropdowns auto-select Time_s / Sample_degC / Furnace_degC. Set the fit range to
   roughly rows **60–900** and click **Update Graphs**.
3. In graph 5, the derivative shows two peaks at about **259 °C** and **183 °C**, which
   reproduces the liquidus and eutectic arrest.
4. Phase Diagram tab → **Import Table Data…** → `sample_phase_diagram_points.csv`
   → **Plot Phase Diagram** to see a three-composition liquidus/solidus plot.

## 8. Troubleshooting

| Problem | What to do |
| --- | --- |
| "Could not parse … as tabular numeric data" | The file is not a supported delimited format, or it has fewer than two numeric columns. Export your logger data as CSV. |
| Fits fail or look wrong | Widen the fit range onto smooth sections, lower the polynomial order, or check that the ambient temperature matches your temperature unit. |
| Peaks too noisy / too smeared | Decrease or increase the smoothing window. |
| Missing-toolbox warning at startup, MATLAB source version only | Install the Curve Fitting Toolbox; the standalone version bundles everything it needs. |

