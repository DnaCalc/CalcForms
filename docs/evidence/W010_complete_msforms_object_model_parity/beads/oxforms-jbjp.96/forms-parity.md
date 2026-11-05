# FORMS PARITY

442 pass; 1142 fail, including 1018 missing measurements.
Layout tolerance: 1 px. Visible ink tolerance: 2 px. Exact line breaks and ordered behaviour require exact matches.
Missing measurements fail coverage. Colour masks measure visible ink; they do not establish glyph identity or a baseline.
Pixels are a coarse regression guard and do not set priorities.

## greeter — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [384, 174] | [384, 174] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [384, 174] | [384, 174] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [384, 174] | [384, 174] | 0 / 0 px |
| Greet | layout / rectangle_edges | pass | [264.0, 48.0, 360.0, 80.0] | [264.0, 48.0, 360.0, 80.013] | 0.013 / 1 px |
| Greet | layout / twips_to_pixel_rounding | pass | [264, 48, 360, 80] | [264, 48, 360, 80] | 0 / 1 px |
| Greet | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Greet | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Greet | text / ink_bounds | pass | [298, 60, 324, 68] | [299, 60, 325, 68] | 1 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [298, 60, 324, 68] | [299, 60, 325, 68] | 1 / 2 px |
| Greet | text / alignment_offsets | pass | [34.0, 12.0] | [35.0, 12.0] | 1.0 / 2 px |
| Greet | spacing / insets | pass | [34.0, 12.0, 36.0, 12.0] | [35.0, 12.0, 35.0, 12.013] | 1.0 / 2 px |
| Greet | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Greet | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [16.0, 48.0, 242.667, 74.667] | [15.987, 48.0, 242.646, 74.683] | 0.021 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [16, 48, 243, 75] | [16, 48, 243, 75] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| InputName | text / ink_bounds | fail | [29, 56, 45, 63] | [22, 58, 39, 66] | 7 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [29, 56, 45, 63] | [22, 58, 39, 66] | 7 / 2 px |
| InputName | text / alignment_offsets | fail | [13.0, 8.0] | [6.013, 10.0] | 6.987 / 2 px |
| InputName | spacing / insets | fail | [13.0, 8.0, 197.667, 11.667] | [6.013, 10.0, 203.646, 8.683] | 6.987 / 2 px |
| InputName | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| InputName | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| InputName | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | layout / rectangle_edges | pass | [16.0, 88.0, 176.0, 112.0] | [15.987, 87.987, 175.975, 111.987] | 0.025 / 1 px |
| Loud | layout / twips_to_pixel_rounding | pass | [16, 88, 176, 112] | [16, 88, 176, 112] | 0 / 1 px |
| Loud | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Loud | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Loud | text / ink_bounds | fail | [34, 98, 84, 104] | [35, 97, 84, 107] | 3 / 2 px |
| Loud | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Loud | text / caption_0_ink_bounds | fail | [34, 98, 84, 104] | [35, 97, 84, 107] | 3 / 2 px |
| Loud | text / alignment_offsets | pass | [18.0, 10.0] | [19.013, 9.013] | 1.013 / 2 px |
| Loud | spacing / insets | fail | [18.0, 10.0, 92.0, 8.0] | [19.013, 9.013, 91.975, 4.987] | 3.013 / 2 px |
| Loud | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Loud | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Loud | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Loud | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Loud | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Loud | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Loud | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Loud | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | layout / rectangle_edges | pass | [16.0, 128.0, 360.0, 157.333] | [15.987, 128.013, 360.0, 157.342] | 0.013 / 1 px |
| Output | layout / twips_to_pixel_rounding | pass | [16, 128, 360, 157] | [16, 128, 360, 157] | 0 / 1 px |
| Output | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Output | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Output | text / ink_bounds | pass | [17, 130, 49, 141] | [17, 132, 51, 142] | 2 / 2 px |
| Output | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Output | text / caption_0_ink_bounds | pass | [17, 130, 49, 141] | [17, 132, 51, 142] | 2 / 2 px |
| Output | text / alignment_offsets | pass | [1.0, 2.0] | [1.013, 3.987] | 1.987 / 2 px |
| Output | spacing / insets | pass | [1.0, 2.0, 311.0, 16.333] | [1.013, 3.987, 309.0, 15.342] | 2.0 / 2 px |
| Output | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| Output | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Output | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Output | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Output | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Output | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Output | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [16.0, 16.0, 144.0, 40.0] | [15.987, 15.987, 144.0, 39.987] | 0.013 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [16, 16, 144, 40] | [16, 16, 144, 40] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [18, 19, 66, 27] | [16, 20, 68, 28] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [18, 19, 66, 27] | [16, 20, 68, 28] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [2.0, 3.0] | [0.013, 4.013] | 1.987 / 2 px |
| Prompt | spacing / insets | fail | [2.0, 3.0, 78.0, 13.0] | [0.013, 4.013, 76.0, 11.987] | 2.0 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Prompt | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## greeter — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [576, 261] | [576, 261] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [576, 261] | [576, 261] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [576, 261] | [576, 261] | 0 / 0 px |
| Greet | layout / rectangle_edges | pass | [396.0, 72.0, 540.0, 120.0] | [396.0, 72.0, 540.0, 120.019] | 0.019 / 1 px |
| Greet | layout / twips_to_pixel_rounding | pass | [396, 72, 540, 120] | [396, 72, 540, 120] | 0 / 1 px |
| Greet | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Greet | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Greet | text / ink_bounds | pass | [449, 90, 486, 102] | [449, 90, 488, 103] | 2 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [449, 90, 486, 102] | [449, 90, 488, 103] | 2 / 2 px |
| Greet | text / alignment_offsets | pass | [53.0, 18.0] | [53.0, 18.0] | 0.0 / 2 px |
| Greet | spacing / insets | pass | [53.0, 18.0, 54.0, 18.0] | [53.0, 18.0, 52.0, 17.019] | 2.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Greet | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [24.0, 72.0, 364.0, 112.0] | [23.981, 72.0, 363.969, 112.025] | 0.031 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [24, 72, 364, 112] | [24, 72, 364, 112] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| InputName | text / ink_bounds | fail | [43, 81, 69, 94] | [32, 86, 59, 99] | 11 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [43, 81, 69, 94] | [32, 86, 59, 99] | 11 / 2 px |
| InputName | text / alignment_offsets | fail | [19.0, 9.0] | [8.019, 14.0] | 10.981 / 2 px |
| InputName | spacing / insets | fail | [19.0, 9.0, 295.0, 18.0] | [8.019, 14.0, 304.969, 13.025] | 10.981 / 2 px |
| InputName | colours / text_class | fail | ["selection-blue"] | ["dark-text"] | 1 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| InputName | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| InputName | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | layout / rectangle_edges | pass | [24.0, 132.0, 264.0, 168.0] | [23.981, 131.981, 263.962, 167.981] | 0.038 / 1 px |
| Loud | layout / twips_to_pixel_rounding | pass | [24, 132, 264, 168] | [24, 132, 264, 168] | 0 / 1 px |
| Loud | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Loud | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Loud | text / ink_bounds | fail | [50, 144, 125, 156] | [52, 145, 126, 160] | 4 / 2 px |
| Loud | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Loud | text / caption_0_ink_bounds | fail | [50, 144, 125, 156] | [52, 145, 126, 160] | 4 / 2 px |
| Loud | text / alignment_offsets | fail | [26.0, 12.0] | [28.019, 13.019] | 2.019 / 2 px |
| Loud | spacing / insets | fail | [26.0, 12.0, 139.0, 12.0] | [28.019, 13.019, 137.962, 7.981] | 4.019 / 2 px |
| Loud | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Loud | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Loud | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Loud | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Loud | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Loud | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Loud | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Loud | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | layout / rectangle_edges | pass | [24.0, 192.0, 540.0, 236.0] | [23.981, 192.019, 540.0, 236.013] | 0.019 / 1 px |
| Output | layout / twips_to_pixel_rounding | pass | [24, 192, 540, 236] | [24, 192, 540, 236] | 0 / 1 px |
| Output | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Output | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Output | text / ink_bounds | pass | [25, 196, 78, 212] | [25, 198, 76, 213] | 2 / 2 px |
| Output | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Output | text / caption_0_ink_bounds | pass | [25, 196, 78, 212] | [25, 198, 76, 213] | 2 / 2 px |
| Output | text / alignment_offsets | pass | [1.0, 4.0] | [1.019, 5.981] | 1.981 / 2 px |
| Output | spacing / insets | fail | [1.0, 4.0, 462.0, 24.0] | [1.019, 5.981, 464.0, 23.013] | 2.0 / 2 px |
| Output | colours / text_class | fail | ["selection-blue"] | ["dark-text"] | 1 / 0 class |
| Output | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Output | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Output | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Output | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Output | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Output | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [24.0, 24.0, 216.0, 60.0] | [23.981, 23.981, 216.0, 59.981] | 0.019 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [24, 24, 216, 60] | [24, 24, 216, 60] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [25, 29, 103, 41] | [24, 30, 102, 42] | 1 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [25, 29, 103, 41] | [24, 30, 102, 42] | 1 / 2 px |
| Prompt | text / alignment_offsets | pass | [1.0, 5.0] | [0.019, 6.019] | 1.019 / 2 px |
| Prompt | spacing / insets | pass | [1.0, 5.0, 113.0, 19.0] | [0.019, 6.019, 114.0, 17.981] | 1.019 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Prompt | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutCommon — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [400, 240] | [400, 240] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [400, 240] | [400, 240] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [400, 240] | [400, 240] | 0 / 0 px |
| Clipped | layout / rectangle_edges | pass | [216.0, 100.0, 309.333, 116.0] | [216.0, 100.0, 309.333, 116.0] | 0.0 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [216, 100, 309, 116] | [216, 100, 309, 116] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Clipped | text / ink_bounds | fail | [216, 105, 297, 113] | [217, 104, 309, 114] | 12 / 2 px |
| Clipped | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Clipped | text / caption_0_ink_bounds | fail | [216, 105, 297, 113] | [217, 104, 309, 114] | 12 / 2 px |
| Clipped | text / alignment_offsets | pass | [0.0, 5.0] | [1.0, 4.0] | 1.0 / 2 px |
| Clipped | spacing / insets | fail | [0.0, 5.0, 12.333, 3.0] | [1.0, 4.0, 0.333, 2.0] | 12.0 / 2 px |
| Clipped | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Clipped | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Clipped | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Clipped | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| Clipped | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | layout / rectangle_edges | pass | [264.0, 144.0, 376.0, 176.0] | [264.0, 144.0, 376.0, 176.0] | 0.0 / 1 px |
| Disabled | layout / twips_to_pixel_rounding | pass | [264, 144, 376, 176] | [264, 144, 376, 176] | 0 / 1 px |
| Disabled | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Disabled | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Disabled | text / ink_bounds | fail | [299, 156, 337, 164] | [300, 156, 340, 164] | 3 / 2 px |
| Disabled | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Disabled | text / caption_0_ink_bounds | fail | [299, 156, 337, 164] | [300, 156, 340, 164] | 3 / 2 px |
| Disabled | text / alignment_offsets | pass | [35.0, 12.0] | [36.0, 12.0] | 1.0 / 2 px |
| Disabled | spacing / insets | fail | [35.0, 12.0, 39.0, 12.0] | [36.0, 12.0, 36.0, 12.0] | 3.0 / 2 px |
| Disabled | colours / text_class | pass | ["shadow-or-disabled"] | ["shadow-or-disabled"] | 0 / 0 class |
| Disabled | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Disabled | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Disabled | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Disabled | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Disabled | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Disabled | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Disabled | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Disabled | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Disabled | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Disabled | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | layout / rectangle_edges | pass | [16.533, 99.533, 181.0, 123.067] | [16.5, 99.5, 181.0, 123.0] | 0.067 / 1 px |
| Fractional | layout / twips_to_pixel_rounding | pass | [17, 100, 181, 123] | [17, 100, 181, 123] | 0 / 1 px |
| Fractional | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Fractional | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Fractional | text / ink_bounds | pass | [17, 103, 102, 111] | [17, 103, 104, 113] | 2 / 2 px |
| Fractional | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Fractional | text / caption_0_ink_bounds | pass | [17, 103, 102, 111] | [17, 103, 104, 113] | 2 / 2 px |
| Fractional | text / alignment_offsets | pass | [0.467, 3.467] | [0.5, 3.5] | 0.033 / 2 px |
| Fractional | spacing / insets | fail | [0.467, 3.467, 79.0, 12.067] | [0.5, 3.5, 77.0, 10.0] | 2.067 / 2 px |
| Fractional | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| Fractional | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Fractional | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Fractional | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Fractional | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Fractional | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Fractional | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| Fractional | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | layout / rectangle_edges | pass | [264.0, 48.0, 376.0, 80.0] | [264.0, 48.0, 376.0, 80.0] | 0.0 / 1 px |
| Greet | layout / twips_to_pixel_rounding | pass | [264, 48, 376, 80] | [264, 48, 376, 80] | 0 / 1 px |
| Greet | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Greet | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Greet | text / ink_bounds | pass | [306, 60, 332, 68] | [307, 60, 333, 68] | 1 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [306, 60, 332, 68] | [307, 60, 333, 68] | 1 / 2 px |
| Greet | text / alignment_offsets | pass | [42.0, 12.0] | [43.0, 12.0] | 1.0 / 2 px |
| Greet | spacing / insets | pass | [42.0, 12.0, 44.0, 12.0] | [43.0, 12.0, 43.0, 12.0] | 1.0 / 2 px |
| Greet | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Greet | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| Greet | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [16.0, 48.0, 242.667, 74.667] | [16.0, 48.0, 242.667, 74.667] | 0.0 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [16, 48, 243, 75] | [16, 48, 243, 75] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| InputName | text / ink_bounds | fail | [29, 52, 48, 65] | [22, 58, 39, 66] | 9 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [29, 52, 48, 65] | [22, 58, 39, 66] | 9 / 2 px |
| InputName | text / alignment_offsets | fail | [13.0, 4.0] | [6.0, 10.0] | 7.0 / 2 px |
| InputName | spacing / insets | fail | [13.0, 4.0, 194.667, 9.667] | [6.0, 10.0, 203.667, 8.667] | 9.0 / 2 px |
| InputName | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| InputName | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| InputName | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| InputName | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | layout / rectangle_edges | pass | [16.0, 144.0, 216.0, 170.667] | [16.0, 144.0, 216.0, 170.667] | 0.0 / 1 px |
| LongInput | layout / twips_to_pixel_rounding | pass | [16, 144, 216, 171] | [16, 144, 216, 171] | 0 / 1 px |
| LongInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| LongInput | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| LongInput | text / ink_bounds | fail | [29, 152, 213, 161] | [22, 153, 211, 164] | 7 / 2 px |
| LongInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| LongInput | text / caption_0_ink_bounds | fail | [29, 152, 213, 161] | [22, 153, 211, 164] | 7 / 2 px |
| LongInput | text / alignment_offsets | fail | [13.0, 8.0] | [6.0, 9.0] | 7.0 / 2 px |
| LongInput | spacing / insets | fail | [13.0, 8.0, 3.0, 9.667] | [6.0, 9.0, 5.0, 6.667] | 7.0 / 2 px |
| LongInput | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| LongInput | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| LongInput | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| LongInput | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| LongInput | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| LongInput | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| LongInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| LongInput | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| LongInput | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| LongInput | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| LongInput | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [16.0, 16.0, 242.667, 40.0] | [16.0, 16.0, 242.667, 40.0] | 0.0 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [16, 16, 243, 40] | [16, 16, 243, 40] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [18, 19, 109, 29] | [16, 20, 110, 30] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [18, 19, 109, 29] | [16, 20, 110, 30] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [2.0, 3.0] | [0.0, 4.0] | 2.0 / 2 px |
| Prompt | spacing / insets | pass | [2.0, 3.0, 133.667, 11.0] | [0.0, 4.0, 132.667, 10.0] | 2.0 / 2 px |
| Prompt | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Prompt | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Prompt | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutCommon — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [600, 360] | [600, 360] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [600, 360] | [600, 360] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [600, 360] | [600, 360] | 0 / 0 px |
| Clipped | layout / rectangle_edges | pass | [324.0, 150.0, 464.0, 174.0] | [324.0, 150.0, 464.0, 174.0] | 0.0 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [324, 150, 464, 174] | [324, 150, 464, 174] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Clipped | text / ink_bounds | fail | [326, 154, 451, 170] | [325, 156, 464, 171] | 13 / 2 px |
| Clipped | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Clipped | text / caption_0_ink_bounds | fail | [326, 154, 451, 170] | [325, 156, 464, 171] | 13 / 2 px |
| Clipped | text / alignment_offsets | pass | [2.0, 4.0] | [1.0, 6.0] | 2.0 / 2 px |
| Clipped | spacing / insets | fail | [2.0, 4.0, 13.0, 4.0] | [1.0, 6.0, 0.0, 3.0] | 13.0 / 2 px |
| Clipped | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Clipped | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Clipped | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Clipped | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| Clipped | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | layout / rectangle_edges | pass | [396.0, 216.0, 564.0, 264.0] | [396.0, 216.0, 564.0, 264.0] | 0.0 / 1 px |
| Disabled | layout / twips_to_pixel_rounding | pass | [396, 216, 564, 264] | [396, 216, 564, 264] | 0 / 1 px |
| Disabled | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Disabled | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Disabled | text / ink_bounds | pass | [451, 233, 508, 246] | [450, 234, 510, 247] | 2 / 2 px |
| Disabled | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Disabled | text / caption_0_ink_bounds | pass | [451, 233, 508, 246] | [450, 234, 510, 247] | 2 / 2 px |
| Disabled | text / alignment_offsets | pass | [55.0, 17.0] | [54.0, 18.0] | 1.0 / 2 px |
| Disabled | spacing / insets | pass | [55.0, 17.0, 56.0, 18.0] | [54.0, 18.0, 54.0, 17.0] | 2.0 / 2 px |
| Disabled | colours / text_class | pass | ["shadow-or-disabled"] | ["shadow-or-disabled"] | 0 / 0 class |
| Disabled | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Disabled | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Disabled | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Disabled | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Disabled | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Disabled | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Disabled | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Disabled | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Disabled | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Disabled | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | layout / rectangle_edges | pass | [24.8, 149.3, 271.5, 184.6] | [24.75, 149.25, 271.5, 184.5] | 0.1 / 1 px |
| Fractional | layout / twips_to_pixel_rounding | pass | [25, 149, 272, 185] | [25, 149, 272, 185] | 0 / 1 px |
| Fractional | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Fractional | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Fractional | text / ink_bounds | fail | [27, 154, 160, 166] | [26, 155, 156, 170] | 4 / 2 px |
| Fractional | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Fractional | text / caption_0_ink_bounds | fail | [27, 154, 160, 166] | [26, 155, 156, 170] | 4 / 2 px |
| Fractional | text / alignment_offsets | pass | [2.2, 4.7] | [1.25, 5.75] | 1.05 / 2 px |
| Fractional | spacing / insets | fail | [2.2, 4.7, 111.5, 18.6] | [1.25, 5.75, 115.5, 14.5] | 4.1 / 2 px |
| Fractional | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Fractional | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Fractional | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Fractional | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Fractional | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Fractional | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Fractional | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| Fractional | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | layout / rectangle_edges | pass | [396.0, 72.0, 564.0, 120.0] | [396.0, 72.0, 564.0, 120.0] | 0.0 / 1 px |
| Greet | layout / twips_to_pixel_rounding | pass | [396, 72, 564, 120] | [396, 72, 564, 120] | 0 / 1 px |
| Greet | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Greet | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Greet | text / ink_bounds | pass | [461, 90, 498, 102] | [461, 90, 500, 103] | 2 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [461, 90, 498, 102] | [461, 90, 500, 103] | 2 / 2 px |
| Greet | text / alignment_offsets | pass | [65.0, 18.0] | [65.0, 18.0] | 0.0 / 2 px |
| Greet | spacing / insets | pass | [65.0, 18.0, 66.0, 18.0] | [65.0, 18.0, 64.0, 17.0] | 2.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Greet | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| Greet | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [24.0, 72.0, 364.0, 112.0] | [24.0, 72.0, 364.0, 112.0] | 0.0 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [24, 72, 364, 112] | [24, 72, 364, 112] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| InputName | text / ink_bounds | fail | [43, 81, 69, 94] | [32, 86, 59, 99] | 11 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [43, 81, 69, 94] | [32, 86, 59, 99] | 11 / 2 px |
| InputName | text / alignment_offsets | fail | [19.0, 9.0] | [8.0, 14.0] | 11.0 / 2 px |
| InputName | spacing / insets | fail | [19.0, 9.0, 295.0, 18.0] | [8.0, 14.0, 305.0, 13.0] | 11.0 / 2 px |
| InputName | colours / text_class | fail | ["selection-blue"] | ["dark-text"] | 1 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| InputName | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| InputName | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| InputName | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | layout / rectangle_edges | pass | [24.0, 216.0, 324.0, 256.0] | [24.0, 216.0, 324.0, 256.0] | 0.0 / 1 px |
| LongInput | layout / twips_to_pixel_rounding | pass | [24, 216, 324, 256] | [24, 216, 324, 256] | 0 / 1 px |
| LongInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| LongInput | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| LongInput | text / ink_bounds | fail | [43, 225, 319, 241] | [32, 230, 316, 246] | 11 / 2 px |
| LongInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| LongInput | text / caption_0_ink_bounds | fail | [43, 225, 319, 241] | [32, 230, 316, 246] | 11 / 2 px |
| LongInput | text / alignment_offsets | fail | [19.0, 9.0] | [8.0, 14.0] | 11.0 / 2 px |
| LongInput | spacing / insets | fail | [19.0, 9.0, 5.0, 15.0] | [8.0, 14.0, 8.0, 10.0] | 11.0 / 2 px |
| LongInput | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| LongInput | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| LongInput | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| LongInput | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| LongInput | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| LongInput | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| LongInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| LongInput | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| LongInput | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| LongInput | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| LongInput | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [24.0, 24.0, 364.0, 60.0] | [24.0, 24.0, 364.0, 60.0] | 0.0 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [24, 24, 364, 60] | [24, 24, 364, 60] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [25, 29, 168, 44] | [24, 30, 166, 45] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [25, 29, 168, 44] | [24, 30, 166, 45] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [1.0, 5.0] | [0.0, 6.0] | 1.0 / 2 px |
| Prompt | spacing / insets | pass | [1.0, 5.0, 196.0, 16.0] | [0.0, 6.0, 198.0, 15.0] | 2.0 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Prompt | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Prompt | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutSelection — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [440, 280] | [440, 280] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [440, 280] | [440, 280] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [440, 280] | [440, 280] | 0 / 0 px |
| Checked | layout / rectangle_edges | pass | [232.0, 16.0, 405.333, 40.0] | [232.0, 16.0, 405.333, 40.0] | 0.0 / 1 px |
| Checked | layout / twips_to_pixel_rounding | pass | [232, 16, 405, 40] | [232, 16, 405, 40] | 0 / 1 px |
| Checked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Checked | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Checked | text / ink_bounds | pass | [250, 24, 289, 32] | [250, 24, 290, 32] | 1 / 2 px |
| Checked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Checked | text / caption_0_ink_bounds | pass | [250, 24, 289, 32] | [250, 24, 290, 32] | 1 / 2 px |
| Checked | text / alignment_offsets | pass | [18.0, 8.0] | [18.0, 8.0] | 0.0 / 2 px |
| Checked | spacing / insets | pass | [18.0, 8.0, 116.333, 8.0] | [18.0, 8.0, 115.333, 8.0] | 1.0 / 2 px |
| Checked | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| Checked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Checked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Checked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Checked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Checked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | layout / rectangle_edges | pass | [16.0, 152.0, 189.333, 247.0] | [16.0, 152.0, 189.333, 248.0] | 1.0 / 1 px |
| Choices | layout / twips_to_pixel_rounding | pass | [16, 152, 189, 247] | [16, 152, 189, 248] | 1 / 1 px |
| Choices | layout / control_kind | pass | "ListBox" | "ListBox" | 0 / 0 identity |
| Choices | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Choices | text / ink_bounds | fail | [28, 158, 61, 191] | [23, 196, 130, 205] | 69 / 2 px |
| Choices | text / visible_line_count | fail | 4 | 1 | 3 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | fail | [12.0, 6.0] | [7.0, 44.0] | 38.0 / 2 px |
| Choices | spacing / insets | fail | [12.0, 6.0, 128.333, 56.0] | [7.0, 44.0, 59.333, 43.0] | 69.0 / 2 px |
| Choices | colours / text_class | fail | ["dark-text", "white"] | ["shadow-or-disabled"] | 1 / 0 class |
| Choices | spacing / list_row_height | fail | [12, 7, 6] | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Choices | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Choices | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | layout / rectangle_edges | pass | [232.0, 152.0, 405.333, 180.0] | [232.0, 152.0, 405.333, 180.0] | 0.0 / 1 px |
| Dropdown | layout / twips_to_pixel_rounding | pass | [232, 152, 405, 180] | [232, 152, 405, 180] | 0 / 1 px |
| Dropdown | layout / control_kind | pass | "ComboBox" | "ComboBox" | 0 / 0 identity |
| Dropdown | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Dropdown | text / ink_bounds | fail | [244, 159, 264, 167] | [237, 162, 257, 170] | 7 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | fail | [244, 159, 264, 167] | [237, 162, 257, 170] | 7 / 2 px |
| Dropdown | text / alignment_offsets | fail | [12.0, 7.0] | [5.0, 10.0] | 7.0 / 2 px |
| Dropdown | spacing / insets | fail | [12.0, 7.0, 141.333, 13.0] | [5.0, 10.0, 148.333, 10.0] | 7.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Dropdown | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / tab_index | pass | 7 | 7 | 0 / 0 index |
| Dropdown | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | layout / rectangle_edges | pass | [16.0, 56.0, 189.333, 80.0] | [16.0, 56.0, 189.333, 80.0] | 0.0 / 1 px |
| OptionOne | layout / twips_to_pixel_rounding | pass | [16, 56, 189, 80] | [16, 56, 189, 80] | 0 / 1 px |
| OptionOne | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionOne | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| OptionOne | text / ink_bounds | fail | [34, 64, 86, 72] | [38, 64, 91, 74] | 5 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | fail | [34, 64, 86, 72] | [38, 64, 91, 74] | 5 / 2 px |
| OptionOne | text / alignment_offsets | fail | [18.0, 8.0] | [22.0, 8.0] | 4.0 / 2 px |
| OptionOne | spacing / insets | fail | [18.0, 8.0, 103.333, 8.0] | [22.0, 8.0, 98.333, 6.0] | 5.0 / 2 px |
| OptionOne | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionOne | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionOne | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionOne | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionOne | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| OptionOne | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | layout / rectangle_edges | pass | [232.0, 56.0, 405.333, 80.0] | [232.0, 56.0, 405.333, 80.0] | 0.0 / 1 px |
| OptionTwo | layout / twips_to_pixel_rounding | pass | [232, 56, 405, 80] | [232, 56, 405, 80] | 0 / 1 px |
| OptionTwo | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionTwo | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| OptionTwo | text / ink_bounds | fail | [250, 64, 316, 72] | [254, 64, 322, 74] | 6 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | fail | [250, 64, 316, 72] | [254, 64, 322, 74] | 6 / 2 px |
| OptionTwo | text / alignment_offsets | fail | [18.0, 8.0] | [22.0, 8.0] | 4.0 / 2 px |
| OptionTwo | spacing / insets | fail | [18.0, 8.0, 89.333, 8.0] | [22.0, 8.0, 83.333, 6.0] | 6.0 / 2 px |
| OptionTwo | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionTwo | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionTwo | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionTwo | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionTwo | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| OptionTwo | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | layout / rectangle_edges | pass | [16.0, 96.0, 189.333, 128.0] | [16.0, 96.0, 189.333, 128.0] | 0.0 / 1 px |
| ToggleOff | layout / twips_to_pixel_rounding | pass | [16, 96, 189, 128] | [16, 96, 189, 128] | 0 / 1 px |
| ToggleOff | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOff | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [77, 107, 126, 118] | [79, 108, 127, 119] | 2 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [77, 107, 126, 118] | [79, 108, 127, 119] | 2 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [61.0, 11.0] | [63.0, 12.0] | 2.0 / 2 px |
| ToggleOff | spacing / insets | pass | [61.0, 11.0, 63.333, 10.0] | [63.0, 12.0, 62.333, 9.0] | 2.0 / 2 px |
| ToggleOff | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOff | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOff | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| ToggleOff | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | layout / rectangle_edges | pass | [232.0, 96.0, 405.333, 128.0] | [232.0, 96.0, 405.333, 128.0] | 0.0 / 1 px |
| ToggleOn | layout / twips_to_pixel_rounding | pass | [232, 96, 405, 128] | [232, 96, 405, 128] | 0 / 1 px |
| ToggleOn | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOn | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| ToggleOn | text / ink_bounds | pass | [295, 109, 340, 119] | [295, 108, 342, 119] | 2 / 2 px |
| ToggleOn | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOn | text / caption_0_ink_bounds | pass | [295, 109, 340, 119] | [295, 108, 342, 119] | 2 / 2 px |
| ToggleOn | text / alignment_offsets | pass | [63.0, 13.0] | [63.0, 12.0] | 1.0 / 2 px |
| ToggleOn | spacing / insets | pass | [63.0, 13.0, 65.333, 9.0] | [63.0, 12.0, 63.333, 9.0] | 2.0 / 2 px |
| ToggleOn | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| ToggleOn | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| ToggleOn | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOn | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOn | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| ToggleOn | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | layout / rectangle_edges | pass | [16.0, 16.0, 189.333, 40.0] | [16.0, 16.0, 189.333, 40.0] | 0.0 / 1 px |
| Unchecked | layout / twips_to_pixel_rounding | pass | [16, 16, 189, 40] | [16, 16, 189, 40] | 0 / 1 px |
| Unchecked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Unchecked | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Unchecked | text / ink_bounds | pass | [34, 26, 84, 32] | [35, 24, 86, 32] | 2 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | pass | [34, 26, 84, 32] | [35, 24, 86, 32] | 2 / 2 px |
| Unchecked | text / alignment_offsets | pass | [18.0, 10.0] | [19.0, 8.0] | 2.0 / 2 px |
| Unchecked | spacing / insets | pass | [18.0, 10.0, 105.333, 8.0] | [19.0, 8.0, 103.333, 8.0] | 2.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [32, 19, 89, 36] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Unchecked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Unchecked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutSelection — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [660, 420] | [660, 420] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [660, 420] | [660, 420] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [660, 420] | [660, 420] | 0 / 0 px |
| Checked | layout / rectangle_edges | pass | [348.0, 24.0, 608.0, 60.0] | [348.0, 24.0, 608.0, 60.0] | 0.0 / 1 px |
| Checked | layout / twips_to_pixel_rounding | pass | [348, 24, 608, 60] | [348, 24, 608, 60] | 0 / 1 px |
| Checked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Checked | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Checked | text / ink_bounds | fail | [373, 35, 433, 48] | [376, 36, 435, 49] | 3 / 2 px |
| Checked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Checked | text / caption_0_ink_bounds | fail | [373, 35, 433, 48] | [376, 36, 435, 49] | 3 / 2 px |
| Checked | text / alignment_offsets | fail | [25.0, 11.0] | [28.0, 12.0] | 3.0 / 2 px |
| Checked | spacing / insets | fail | [25.0, 11.0, 175.0, 12.0] | [28.0, 12.0, 173.0, 11.0] | 3.0 / 2 px |
| Checked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Checked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Checked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Checked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Checked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Checked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Checked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | layout / rectangle_edges | fail | [24.0, 228.0, 284.0, 370.5] | [24.0, 228.0, 284.0, 372.0] | 1.5 / 1 px |
| Choices | layout / twips_to_pixel_rounding | pass | [24, 228, 284, 371] | [24, 228, 284, 372] | 1 / 1 px |
| Choices | layout / control_kind | pass | "ListBox" | "ListBox" | 0 / 0 identity |
| Choices | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Choices | text / ink_bounds | fail | [43, 235, 98, 287] | [34, 294, 195, 310] | 97 / 2 px |
| Choices | text / visible_line_count | fail | 4 | 1 | 3 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | fail | [19.0, 7.0] | [10.0, 66.0] | 59.0 / 2 px |
| Choices | spacing / insets | fail | [19.0, 7.0, 186.0, 83.5] | [10.0, 66.0, 89.0, 62.0] | 97.0 / 2 px |
| Choices | colours / text_class | fail | ["dark-text", "white"] | ["dark-text"] | 1 / 0 class |
| Choices | spacing / list_row_height | fail | [21, 3, 16] | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Choices | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Choices | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | layout / rectangle_edges | pass | [348.0, 228.0, 608.0, 270.0] | [348.0, 228.0, 608.0, 270.0] | 0.0 / 1 px |
| Dropdown | layout / twips_to_pixel_rounding | pass | [348, 228, 608, 270] | [348, 228, 608, 270] | 0 / 1 px |
| Dropdown | layout / control_kind | pass | "ComboBox" | "ComboBox" | 0 / 0 identity |
| Dropdown | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Dropdown | text / ink_bounds | fail | [368, 239, 399, 251] | [355, 244, 386, 256] | 13 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | fail | [368, 239, 399, 251] | [355, 244, 386, 256] | 13 / 2 px |
| Dropdown | text / alignment_offsets | fail | [20.0, 11.0] | [7.0, 16.0] | 13.0 / 2 px |
| Dropdown | spacing / insets | fail | [20.0, 11.0, 209.0, 19.0] | [7.0, 16.0, 222.0, 14.0] | 13.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Dropdown | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / tab_index | pass | 7 | 7 | 0 / 0 index |
| Dropdown | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | layout / rectangle_edges | pass | [24.0, 84.0, 284.0, 120.0] | [24.0, 84.0, 284.0, 120.0] | 0.0 / 1 px |
| OptionOne | layout / twips_to_pixel_rounding | pass | [24, 84, 284, 120] | [24, 84, 284, 120] | 0 / 1 px |
| OptionOne | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionOne | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| OptionOne | text / ink_bounds | fail | [50, 96, 131, 108] | [57, 97, 137, 112] | 7 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | fail | [50, 96, 131, 108] | [57, 97, 137, 112] | 7 / 2 px |
| OptionOne | text / alignment_offsets | fail | [26.0, 12.0] | [33.0, 13.0] | 7.0 / 2 px |
| OptionOne | spacing / insets | fail | [26.0, 12.0, 153.0, 12.0] | [33.0, 13.0, 147.0, 8.0] | 7.0 / 2 px |
| OptionOne | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionOne | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionOne | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionOne | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionOne | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionOne | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| OptionOne | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | layout / rectangle_edges | pass | [348.0, 84.0, 608.0, 120.0] | [348.0, 84.0, 608.0, 120.0] | 0.0 / 1 px |
| OptionTwo | layout / twips_to_pixel_rounding | pass | [348, 84, 608, 120] | [348, 84, 608, 120] | 0 / 1 px |
| OptionTwo | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionTwo | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| OptionTwo | text / ink_bounds | fail | [373, 95, 475, 108] | [381, 96, 482, 112] | 8 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | fail | [373, 95, 475, 108] | [381, 96, 482, 112] | 8 / 2 px |
| OptionTwo | text / alignment_offsets | fail | [25.0, 11.0] | [33.0, 12.0] | 8.0 / 2 px |
| OptionTwo | spacing / insets | fail | [25.0, 11.0, 133.0, 12.0] | [33.0, 12.0, 126.0, 8.0] | 8.0 / 2 px |
| OptionTwo | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionTwo | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionTwo | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| OptionTwo | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| OptionTwo | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionTwo | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| OptionTwo | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | layout / rectangle_edges | pass | [24.0, 144.0, 284.0, 192.0] | [24.0, 144.0, 284.0, 192.0] | 0.0 / 1 px |
| ToggleOff | layout / twips_to_pixel_rounding | pass | [24, 144, 284, 192] | [24, 144, 284, 192] | 0 / 1 px |
| ToggleOff | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOff | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [117, 161, 190, 177] | [118, 162, 191, 178] | 1 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [117, 161, 190, 177] | [118, 162, 191, 178] | 1 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [93.0, 17.0] | [94.0, 18.0] | 1.0 / 2 px |
| ToggleOff | spacing / insets | pass | [93.0, 17.0, 94.0, 15.0] | [94.0, 18.0, 93.0, 14.0] | 1.0 / 2 px |
| ToggleOff | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOff | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOff | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| ToggleOff | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | layout / rectangle_edges | pass | [348.0, 144.0, 608.0, 192.0] | [348.0, 144.0, 608.0, 192.0] | 0.0 / 1 px |
| ToggleOn | layout / twips_to_pixel_rounding | pass | [348, 144, 608, 192] | [348, 144, 608, 192] | 0 / 1 px |
| ToggleOn | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOn | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| ToggleOn | text / ink_bounds | pass | [442, 162, 512, 178] | [443, 162, 512, 178] | 1 / 2 px |
| ToggleOn | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOn | text / caption_0_ink_bounds | pass | [442, 162, 512, 178] | [443, 162, 512, 178] | 1 / 2 px |
| ToggleOn | text / alignment_offsets | pass | [94.0, 18.0] | [95.0, 18.0] | 1.0 / 2 px |
| ToggleOn | spacing / insets | pass | [94.0, 18.0, 96.0, 14.0] | [95.0, 18.0, 96.0, 14.0] | 1.0 / 2 px |
| ToggleOn | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| ToggleOn | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| ToggleOn | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOn | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOn | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOn | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| ToggleOn | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | layout / rectangle_edges | pass | [24.0, 24.0, 284.0, 60.0] | [24.0, 24.0, 284.0, 60.0] | 0.0 / 1 px |
| Unchecked | layout / twips_to_pixel_rounding | pass | [24, 24, 284, 60] | [24, 24, 284, 60] | 0 / 1 px |
| Unchecked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Unchecked | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Unchecked | text / ink_bounds | fail | [46, 35, 131, 54] | [52, 36, 129, 49] | 6 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | fail | [46, 35, 131, 54] | [52, 36, 129, 49] | 6 / 2 px |
| Unchecked | text / alignment_offsets | fail | [22.0, 11.0] | [28.0, 12.0] | 6.0 / 2 px |
| Unchecked | spacing / insets | fail | [22.0, 11.0, 153.0, 6.0] | [28.0, 12.0, 155.0, 11.0] | 6.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [46, 29, 131, 42] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Unchecked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Unchecked | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutContainers — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [520, 380] | [520, 380] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [520, 380] | [520, 380] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [520, 380] | [520, 380] | 0 / 0 px |
| Group | layout / rectangle_edges | pass | [16.0, 16.0, 248.0, 112.0] | [16.0, 16.0, 248.0, 112.0] | 0.0 / 1 px |
| Group | layout / twips_to_pixel_rounding | pass | [16, 16, 248, 112] | [16, 16, 248, 112] | 0 / 1 px |
| Group | layout / control_kind | pass | "Frame" | "Frame" | 0 / 0 identity |
| Group | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Group | text / ink_bounds | fail | [30, 19, 61, 27] | unmeasured (0) | unmeasured (0) / 2 px |
| Group | text / visible_line_count | fail | 1 | 0 | 1 / 0 lines |
| Group | text / caption_0_ink_bounds | fail | [30, 19, 61, 27] | unmeasured (0) | unmeasured (0) / 2 px |
| Group | colours / text_class | fail | ["dark-text"] | unmeasured (0) | unmeasured (0) / 0 class |
| Group | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Group | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Group | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | spacing / frame_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | layout / rectangle_edges | pass | [16.0, 52.0, 200.0, 76.0] | [16.0, 52.0, 200.0, 76.0] | 0.0 / 1 px |
| Group.NestedInput | layout / twips_to_pixel_rounding | pass | [16, 52, 200, 76] | [16, 52, 200, 76] | 0 / 1 px |
| Group.NestedInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| Group.NestedInput | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Group.NestedInput | text / ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 px |
| Group.NestedInput | colours / fill_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Group.NestedInput | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedInput | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedInput | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedInput | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | colours / text_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Group.NestedInput | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | layout / rectangle_edges | pass | [16.0, 24.0, 200.0, 48.0] | [16.0, 24.0, 200.0, 48.0] | 0.0 / 1 px |
| Group.NestedLabel | layout / twips_to_pixel_rounding | pass | [16, 24, 200, 48] | [16, 24, 200, 48] | 0 / 1 px |
| Group.NestedLabel | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Group.NestedLabel | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Group.NestedLabel | text / ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 px |
| Group.NestedLabel | colours / fill_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedLabel | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Group.NestedLabel | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedLabel | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedLabel | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedLabel | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedLabel | colours / text_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedLabel | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group.NestedLabel | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | layout / rectangle_edges | pass | [280.0, 136.0, 496.0, 328.0] | [280.0, 136.0, 496.0, 328.0] | 0.0 / 1 px |
| PagesControl | layout / twips_to_pixel_rounding | pass | [280, 136, 496, 328] | [280, 136, 496, 328] | 0 / 1 px |
| PagesControl | layout / control_kind | pass | "MultiPage" | "MultiPage" | 0 / 0 identity |
| PagesControl | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| PagesControl | text / ink_bounds | fail | [288, 139, 362, 153] | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | text / visible_line_count | fail | 1 | 0 | 1 / 0 lines |
| PagesControl | text / caption_0_ink_bounds | fail | [288, 141, 308, 149] | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | text / caption_1_ink_bounds | fail | [316, 139, 362, 153] | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | colours / text_class | fail | ["dark-text"] | unmeasured (0) | unmeasured (0) / 0 class |
| PagesControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| PagesControl | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| PagesControl | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| PagesControl | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| PagesControl | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / tab_sizes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| PagesControl | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / tab_index | fail | 4 | 5 | 1 / 0 index |
| PagesControl | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | layout / rectangle_edges | pass | [280.0, 16.0, 368.0, 88.0] | [280.0, 16.0, 368.0, 88.0] | 0.0 / 1 px |
| Picture | layout / twips_to_pixel_rounding | pass | [280, 16, 368, 88] | [280, 16, 368, 88] | 0 / 1 px |
| Picture | layout / control_kind | pass | "Image" | "Image" | 0 / 0 identity |
| Picture | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Picture | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Picture | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Picture | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Picture | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | layout / rectangle_edges | pass | [16.0, 136.0, 248.0, 160.0] | [16.0, 136.0, 248.0, 160.0] | 0.0 / 1 px |
| Slider | layout / twips_to_pixel_rounding | pass | [16, 136, 248, 160] | [16, 136, 248, 160] | 0 / 1 px |
| Slider | layout / control_kind | pass | "ScrollBar" | "ScrollBar" | 0 / 0 identity |
| Slider | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Slider | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Slider | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Slider | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Slider | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | layout / rectangle_edges | pass | [400.0, 16.0, 424.0, 88.0] | [400.0, 16.0, 424.0, 88.0] | 0.0 / 1 px |
| Spinner | layout / twips_to_pixel_rounding | pass | [400, 16, 424, 88] | [400, 16, 424, 88] | 0 / 1 px |
| Spinner | layout / control_kind | pass | "SpinButton" | "SpinButton" | 0 / 0 identity |
| Spinner | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Spinner | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Spinner | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Spinner | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Spinner | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | layout / rectangle_edges | pass | [16.0, 192.0, 248.0, 328.0] | [16.0, 192.0, 248.0, 328.0] | 0.0 / 1 px |
| TabsControl | layout / twips_to_pixel_rounding | pass | [16, 192, 248, 328] | [16, 192, 248, 328] | 0 / 1 px |
| TabsControl | layout / control_kind | pass | "TabStrip" | "TabStrip" | 0 / 0 identity |
| TabsControl | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| TabsControl | text / ink_bounds | fail | [24, 195, 98, 209] | [22, 203, 204, 209] | 106 / 2 px |
| TabsControl | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| TabsControl | text / caption_0_ink_bounds | fail | [24, 197, 44, 205] | [22, 204, 88, 209] | 44 / 2 px |
| TabsControl | text / caption_1_ink_bounds | fail | [52, 195, 98, 209] | [138, 203, 204, 209] | 106 / 2 px |
| TabsControl | text / alignment_offsets | fail | [8.0, 3.0] | [6.0, 11.0] | 8.0 / 2 px |
| TabsControl | spacing / insets | fail | [8.0, 3.0, 150.0, 119.0] | [6.0, 11.0, 44.0, 119.0] | 106.0 / 2 px |
| TabsControl | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| TabsControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| TabsControl | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| TabsControl | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| TabsControl | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| TabsControl | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| TabsControl | spacing / tab_sizes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| TabsControl | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / tab_index | fail | 3 | 4 | 1 / 0 index |
| TabsControl | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutContainers — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [780, 570] | [780, 570] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [780, 570] | [780, 570] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [780, 570] | [780, 570] | 0 / 0 px |
| Group | layout / rectangle_edges | pass | [24.0, 24.0, 372.0, 168.0] | [24.0, 24.0, 372.0, 168.0] | 0.0 / 1 px |
| Group | layout / twips_to_pixel_rounding | pass | [24, 24, 372, 168] | [24, 24, 372, 168] | 0 / 1 px |
| Group | layout / control_kind | pass | "Frame" | "Frame" | 0 / 0 identity |
| Group | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Group | text / ink_bounds | fail | [47, 29, 96, 41] | unmeasured (0) | unmeasured (0) / 2 px |
| Group | text / visible_line_count | fail | 1 | 0 | 1 / 0 lines |
| Group | text / caption_0_ink_bounds | fail | [47, 29, 96, 41] | unmeasured (0) | unmeasured (0) / 2 px |
| Group | colours / text_class | fail | ["dark-text"] | unmeasured (0) | unmeasured (0) / 0 class |
| Group | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Group | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Group | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | spacing / frame_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | layout / rectangle_edges | pass | [24.0, 78.0, 300.0, 114.0] | [24.0, 78.0, 300.0, 114.0] | 0.0 / 1 px |
| Group.NestedInput | layout / twips_to_pixel_rounding | pass | [24, 78, 300, 114] | [24, 78, 300, 114] | 0 / 1 px |
| Group.NestedInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| Group.NestedInput | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Group.NestedInput | text / ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 px |
| Group.NestedInput | colours / fill_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Group.NestedInput | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedInput | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedInput | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedInput | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | colours / text_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Group.NestedInput | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | layout / rectangle_edges | pass | [24.0, 36.0, 300.0, 72.0] | [24.0, 36.0, 300.0, 72.0] | 0.0 / 1 px |
| Group.NestedLabel | layout / twips_to_pixel_rounding | pass | [24, 36, 300, 72] | [24, 36, 300, 72] | 0 / 1 px |
| Group.NestedLabel | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Group.NestedLabel | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Group.NestedLabel | text / ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 px |
| Group.NestedLabel | colours / fill_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedLabel | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Group.NestedLabel | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedLabel | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedLabel | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Group.NestedLabel | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedLabel | colours / text_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedLabel | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group.NestedLabel | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | layout / rectangle_edges | pass | [420.0, 204.0, 744.0, 492.0] | [420.0, 204.0, 744.0, 492.0] | 0.0 / 1 px |
| PagesControl | layout / twips_to_pixel_rounding | pass | [420, 204, 744, 492] | [420, 204, 744, 492] | 0 / 1 px |
| PagesControl | layout / control_kind | pass | "MultiPage" | "MultiPage" | 0 / 0 identity |
| PagesControl | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| PagesControl | text / ink_bounds | fail | [434, 208, 543, 227] | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | text / visible_line_count | fail | 2 | 0 | 2 / 0 lines |
| PagesControl | text / caption_0_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | text / caption_1_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | colours / text_class | fail | ["dark-text", "shadow-or-disabled"] | unmeasured (0) | unmeasured (0) / 0 class |
| PagesControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| PagesControl | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| PagesControl | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| PagesControl | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| PagesControl | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| PagesControl | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / tab_sizes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| PagesControl | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / tab_index | fail | 4 | 5 | 1 / 0 index |
| PagesControl | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | layout / rectangle_edges | pass | [420.0, 24.0, 552.0, 132.0] | [420.0, 24.0, 552.0, 132.0] | 0.0 / 1 px |
| Picture | layout / twips_to_pixel_rounding | pass | [420, 24, 552, 132] | [420, 24, 552, 132] | 0 / 1 px |
| Picture | layout / control_kind | pass | "Image" | "Image" | 0 / 0 identity |
| Picture | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Picture | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Picture | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Picture | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Picture | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | layout / rectangle_edges | pass | [24.0, 204.0, 372.0, 240.0] | [24.0, 204.0, 372.0, 240.0] | 0.0 / 1 px |
| Slider | layout / twips_to_pixel_rounding | pass | [24, 204, 372, 240] | [24, 204, 372, 240] | 0 / 1 px |
| Slider | layout / control_kind | pass | "ScrollBar" | "ScrollBar" | 0 / 0 identity |
| Slider | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Slider | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Slider | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Slider | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Slider | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | layout / rectangle_edges | pass | [600.0, 24.0, 636.0, 132.0] | [600.0, 24.0, 636.0, 132.0] | 0.0 / 1 px |
| Spinner | layout / twips_to_pixel_rounding | pass | [600, 24, 636, 132] | [600, 24, 636, 132] | 0 / 1 px |
| Spinner | layout / control_kind | pass | "SpinButton" | "SpinButton" | 0 / 0 identity |
| Spinner | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| Spinner | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Spinner | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Spinner | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Spinner | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | layout / rectangle_edges | pass | [24.0, 288.0, 372.0, 492.0] | [24.0, 288.0, 372.0, 492.0] | 0.0 / 1 px |
| TabsControl | layout / twips_to_pixel_rounding | pass | [24, 288, 372, 492] | [24, 288, 372, 492] | 0 / 1 px |
| TabsControl | layout / control_kind | pass | "TabStrip" | "TabStrip" | 0 / 0 identity |
| TabsControl | layout / native_capture_qualification | fail | 1 | unmeasured (0) | unmeasured (0) / 0 qualified captures |
| TabsControl | text / ink_bounds | fail | [38, 292, 147, 311] | [33, 304, 305, 314] | 158 / 2 px |
| TabsControl | text / visible_line_count | fail | 2 | 1 | 1 / 0 lines |
| TabsControl | text / caption_0_ink_bounds | fail | unmeasured (0) | [33, 306, 131, 314] | unmeasured (0) / 2 px |
| TabsControl | text / caption_1_ink_bounds | fail | unmeasured (0) | [207, 304, 305, 314] | unmeasured (0) / 2 px |
| TabsControl | text / alignment_offsets | fail | [14.0, 4.0] | [9.0, 16.0] | 12.0 / 2 px |
| TabsControl | spacing / insets | fail | [14.0, 4.0, 225.0, 181.0] | [9.0, 16.0, 67.0, 178.0] | 158.0 / 2 px |
| TabsControl | colours / text_class | fail | ["dark-text", "shadow-or-disabled"] | ["dark-text"] | 1 / 0 class |
| TabsControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| TabsControl | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| TabsControl | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| TabsControl | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| TabsControl | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| TabsControl | spacing / tab_sizes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| TabsControl | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / tab_index | fail | 3 | 4 | 1 / 0 index |
| TabsControl | behaviour / tab_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / enter_default | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / escape_cancel | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / hit_testing | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
