# FORMS PARITY

1169 pass; 449 fail, including 378 missing measurements.
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
| Greet | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Greet | text / ink_bounds | pass | [298, 60, 324, 68] | [298, 61, 325, 69] | 1 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [298, 60, 324, 68] | [298, 61, 325, 69] | 1 / 2 px |
| Greet | text / alignment_offsets | pass | [34.0, 12.0] | [34.0, 13.0] | 1.0 / 2 px |
| Greet | spacing / insets | pass | [34.0, 12.0, 36.0, 12.0] | [34.0, 13.0, 35.0, 11.013] | 1.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | pass | [20.0] | [20.506] | 0.506 / 2 px |
| Greet | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Greet | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| Greet | colours / border_class | pass | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | 0 / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_order | pass | [{"position": 1, "next": "Loud"}] | [{"position": 1, "next": "Loud"}] | 0 / 0 ordered observations |
| Greet | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | 0 / 0 ordered observations |
| Greet | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | pass | ["Greet"] | ["Greet"] | 0 / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [16.0, 48.0, 242.667, 74.667] | [15.987, 48.0, 242.646, 74.683] | 0.021 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [16, 48, 243, 75] | [16, 48, 243, 75] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| InputName | text / ink_bounds | fail | [29, 52, 48, 65] | [28, 55, 45, 63] | 3 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [29, 52, 48, 65] | [28, 55, 45, 63] | 3 / 2 px |
| InputName | text / alignment_offsets | fail | [13.0, 4.0] | [12.013, 7.0] | 3.0 / 2 px |
| InputName | spacing / insets | fail | [13.0, 4.0, 194.667, 9.667] | [12.013, 7.0, 197.646, 11.683] | 3.0 / 2 px |
| InputName | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | pass | [15.0] | [15.0] | 0.0 / 2 px |
| InputName | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| InputName | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | pass | [2, 2, 2, 2] | [2, 2, 2, 2] | 0 / 1 px |
| InputName | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| InputName | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / tab_order | pass | [{"position": 0, "next": "Greet"}] | [{"position": 0, "next": "Greet"}] | 0 / 0 ordered observations |
| InputName | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | 0 / 0 ordered observations |
| InputName | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | pass | ["InputName"] | ["InputName"] | 0 / 0 ordered observations |
| InputName | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | layout / rectangle_edges | pass | [16.0, 88.0, 176.0, 112.0] | [15.987, 87.987, 175.975, 111.987] | 0.025 / 1 px |
| Loud | layout / twips_to_pixel_rounding | pass | [16, 88, 176, 112] | [16, 88, 176, 112] | 0 / 1 px |
| Loud | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Loud | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Loud | text / ink_bounds | pass | [34, 98, 84, 104] | [34, 96, 84, 106] | 2 / 2 px |
| Loud | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Loud | text / caption_0_ink_bounds | pass | [34, 98, 84, 104] | [34, 96, 84, 106] | 2 / 2 px |
| Loud | text / alignment_offsets | pass | [18.0, 10.0] | [18.013, 8.013] | 1.987 / 2 px |
| Loud | spacing / insets | fail | [18.0, 10.0, 92.0, 8.0] | [18.013, 8.013, 91.975, 5.987] | 2.013 / 2 px |
| Loud | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Loud | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Loud | text / baseline | pass | [16.0] | [16.5] | 0.5 / 2 px |
| Loud | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Loud | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Loud | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Loud | spacing / glyph_size | pass | [13.0, 13.0] | [12.667, 12.667] | 0.333 / 1 px |
| Loud | spacing / glyph_caption_gap | pass | 4.0 | 4.667 | 0.667 / 1 px |
| Loud | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Loud | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / tab_order | pass | [{"position": 2, "next": "InputName"}] | [{"position": 2, "next": "InputName"}] | 0 / 0 ordered observations |
| Loud | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | 0 / 0 ordered observations |
| Loud | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Loud | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / hit_testing | pass | ["Loud"] | ["Loud"] | 0 / 0 ordered observations |
| Loud | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | layout / rectangle_edges | pass | [16.0, 128.0, 360.0, 157.333] | [15.987, 128.013, 360.0, 157.342] | 0.013 / 1 px |
| Output | layout / twips_to_pixel_rounding | pass | [16, 128, 360, 157] | [16, 128, 360, 157] | 0 / 1 px |
| Output | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Output | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Output | text / ink_bounds | pass | [17, 130, 49, 141] | [16, 131, 51, 142] | 2 / 2 px |
| Output | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Output | text / caption_0_ink_bounds | pass | [17, 130, 49, 141] | [16, 131, 51, 142] | 2 / 2 px |
| Output | text / alignment_offsets | pass | [1.0, 2.0] | [0.013, 2.987] | 0.987 / 2 px |
| Output | spacing / insets | pass | [1.0, 2.0, 311.0, 16.333] | [0.013, 2.987, 309.0, 15.342] | 2.0 / 2 px |
| Output | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Output | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Output | text / baseline | pass | [11.0] | [12.0] | 1.0 / 2 px |
| Output | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Output | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Output | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Output | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Output | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | 0 / 0 ordered observations |
| Output | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Output | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / hit_testing | pass | ["Output"] | ["Output"] | 0 / 0 ordered observations |
| Output | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [16.0, 16.0, 144.0, 40.0] | [15.987, 15.987, 144.0, 39.987] | 0.013 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [16, 16, 144, 40] | [16, 16, 144, 40] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [18, 19, 66, 27] | [16, 20, 66, 28] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [18, 19, 66, 27] | [16, 20, 66, 28] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [2.0, 3.0] | [0.013, 4.013] | 1.987 / 2 px |
| Prompt | spacing / insets | pass | [2.0, 3.0, 78.0, 13.0] | [0.013, 4.013, 78.0, 11.987] | 1.987 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | pass | [11.0] | [12.0] | 1.0 / 2 px |
| Prompt | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Prompt | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Prompt | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | 0 / 0 ordered observations |
| Prompt | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | pass | ["Prompt"] | ["Prompt"] | 0 / 0 ordered observations |
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
| Greet | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Greet | text / ink_bounds | fail | [449, 90, 486, 102] | [448, 91, 489, 103] | 3 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | fail | [449, 90, 486, 102] | [448, 91, 489, 103] | 3 / 2 px |
| Greet | text / alignment_offsets | pass | [53.0, 18.0] | [52.0, 19.0] | 1.0 / 2 px |
| Greet | spacing / insets | fail | [53.0, 18.0, 54.0, 18.0] | [52.0, 19.0, 51.0, 17.019] | 3.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | pass | [30.0] | [30.509] | 0.509 / 2 px |
| Greet | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Greet | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | pass | [4, 4, 4, 4] | [5, 5, 4, 4] | 1 / 1 px |
| Greet | colours / border_class | pass | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | 0 / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_order | pass | [{"position": 1, "next": "Loud"}] | [{"position": 1, "next": "Loud"}] | 0 / 0 ordered observations |
| Greet | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | 0 / 0 ordered observations |
| Greet | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | pass | ["Greet"] | ["Greet"] | 0 / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [24.0, 72.0, 364.0, 112.0] | [23.981, 72.0, 363.969, 112.025] | 0.031 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [24, 72, 364, 112] | [24, 72, 364, 112] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| InputName | text / ink_bounds | pass | [43, 81, 69, 94] | [43, 81, 69, 94] | 0 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | pass | [43, 81, 69, 94] | [43, 81, 69, 94] | 0 / 2 px |
| InputName | text / alignment_offsets | pass | [19.0, 9.0] | [19.019, 9.0] | 0.019 / 2 px |
| InputName | spacing / insets | pass | [19.0, 9.0, 295.0, 18.0] | [19.019, 9.0, 294.969, 18.025] | 0.031 / 2 px |
| InputName | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | pass | [22.0] | [22.0] | 0.0 / 2 px |
| InputName | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| InputName | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| InputName | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| InputName | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / tab_order | pass | [{"position": 0, "next": "Greet"}] | [{"position": 0, "next": "Greet"}] | 0 / 0 ordered observations |
| InputName | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | [{"step": "enter", "events": ["Click:Hello, Ada"]}] | 0 / 0 ordered observations |
| InputName | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | pass | ["InputName"] | ["InputName"] | 0 / 0 ordered observations |
| InputName | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | layout / rectangle_edges | pass | [24.0, 132.0, 264.0, 168.0] | [23.981, 131.981, 263.962, 167.981] | 0.038 / 1 px |
| Loud | layout / twips_to_pixel_rounding | pass | [24, 132, 264, 168] | [24, 132, 264, 168] | 0 / 1 px |
| Loud | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Loud | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Loud | text / ink_bounds | fail | [50, 144, 125, 156] | [52, 144, 128, 159] | 3 / 2 px |
| Loud | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Loud | text / caption_0_ink_bounds | fail | [50, 144, 125, 156] | [52, 144, 128, 159] | 3 / 2 px |
| Loud | text / alignment_offsets | fail | [26.0, 12.0] | [28.019, 12.019] | 2.019 / 2 px |
| Loud | spacing / insets | fail | [26.0, 12.0, 139.0, 12.0] | [28.019, 12.019, 135.962, 8.981] | 3.038 / 2 px |
| Loud | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Loud | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Loud | text / baseline | pass | [24.0] | [24.5] | 0.5 / 2 px |
| Loud | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Loud | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Loud | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Loud | spacing / glyph_size | pass | [19.0, 19.0] | [19.0, 19.0] | 0.0 / 1 px |
| Loud | spacing / glyph_caption_gap | fail | 4.0 | 7.0 | 3.0 / 1 px |
| Loud | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Loud | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Loud | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / tab_order | pass | [{"position": 2, "next": "InputName"}] | [{"position": 2, "next": "InputName"}] | 0 / 0 ordered observations |
| Loud | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | 0 / 0 ordered observations |
| Loud | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Loud | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / hit_testing | pass | ["Loud"] | ["Loud"] | 0 / 0 ordered observations |
| Loud | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Loud | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | layout / rectangle_edges | pass | [24.0, 192.0, 540.0, 236.0] | [23.981, 192.019, 540.0, 236.013] | 0.019 / 1 px |
| Output | layout / twips_to_pixel_rounding | pass | [24, 192, 540, 236] | [24, 192, 540, 236] | 0 / 1 px |
| Output | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Output | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Output | text / ink_bounds | pass | [25, 196, 78, 212] | [25, 198, 78, 214] | 2 / 2 px |
| Output | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Output | text / caption_0_ink_bounds | pass | [25, 196, 78, 212] | [25, 198, 78, 214] | 2 / 2 px |
| Output | text / alignment_offsets | pass | [1.0, 4.0] | [1.019, 5.981] | 1.981 / 2 px |
| Output | spacing / insets | pass | [1.0, 4.0, 462.0, 24.0] | [1.019, 5.981, 462.0, 22.013] | 1.987 / 2 px |
| Output | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Output | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Output | text / baseline | pass | [17.0] | [18.5] | 1.5 / 2 px |
| Output | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Output | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Output | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Output | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Output | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | 0 / 0 ordered observations |
| Output | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Output | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / hit_testing | pass | ["Output"] | ["Output"] | 0 / 0 ordered observations |
| Output | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Output | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [24.0, 24.0, 216.0, 60.0] | [23.981, 23.981, 216.0, 59.981] | 0.019 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [24, 24, 216, 60] | [24, 24, 216, 60] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [25, 29, 103, 41] | [24, 30, 103, 42] | 1 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [25, 29, 103, 41] | [24, 30, 103, 42] | 1 / 2 px |
| Prompt | text / alignment_offsets | pass | [1.0, 5.0] | [0.019, 6.019] | 1.019 / 2 px |
| Prompt | spacing / insets | pass | [1.0, 5.0, 113.0, 19.0] | [0.019, 6.019, 113.0, 17.981] | 1.019 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | pass | [17.0] | [18.5] | 1.5 / 2 px |
| Prompt | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Prompt | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Prompt | behaviour / enter_default | pass | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | [{"step": "enter", "events": ["Click:HELLO, ADA"]}] | 0 / 0 ordered observations |
| Prompt | behaviour / escape_cancel | pass | [{"step": "escape", "events": []}] | [{"step": "escape", "events": []}] | 0 / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | pass | ["Prompt"] | ["Prompt"] | 0 / 0 ordered observations |
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
| Clipped | layout / rectangle_edges | pass | [216, 100, 309, 116] | [216.0, 100.0, 309.333, 116.0] | 0.333 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [216, 100, 309, 116] | [216, 100, 309, 116] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Clipped | text / ink_bounds | pass | [216, 105, 297, 113] | [216, 103, 299, 114] | 2 / 2 px |
| Clipped | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Clipped | text / caption_0_ink_bounds | pass | [216, 105, 297, 113] | [216, 103, 299, 114] | 2 / 2 px |
| Clipped | text / alignment_offsets | pass | [0, 5] | [0.0, 3.0] | 2.0 / 2 px |
| Clipped | spacing / insets | pass | [0, 5, 12, 3] | [0.0, 3.0, 10.333, 2.0] | 2.0 / 2 px |
| Clipped | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Clipped | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Clipped | text / baseline | pass | [11.0, 24.0] | [12.0, 25.0] | 1.0 / 2 px |
| Clipped | text / clipping_point | pass | [[null, null]] | [[null, null]] | 0 / 0 character offsets |
| Clipped | text / wrap_point | pass | [[19]] | [[19]] | 0 / 0 character offsets |
| Clipped | text / exact_line_breaks | pass | [[19]] | [[19]] | 0 / 0 character offsets |
| Clipped | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| Clipped | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Clipped | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Clipped | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Clipped | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / hit_testing | pass | ["Clipped"] | ["Clipped"] | 0 / 0 ordered observations |
| Clipped | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | layout / rectangle_edges | pass | [264, 144, 376, 176] | [264.0, 144.0, 376.0, 176.0] | 0.0 / 1 px |
| Disabled | layout / twips_to_pixel_rounding | pass | [264, 144, 376, 176] | [264, 144, 376, 176] | 0 / 1 px |
| Disabled | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Disabled | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Disabled | text / ink_bounds | pass | [299, 156, 337, 164] | [299, 156, 339, 165] | 2 / 2 px |
| Disabled | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Disabled | text / caption_0_ink_bounds | pass | [299, 156, 337, 164] | [299, 156, 339, 165] | 2 / 2 px |
| Disabled | text / alignment_offsets | pass | [35, 12] | [35.0, 12.0] | 0.0 / 2 px |
| Disabled | spacing / insets | pass | [35, 12, 39, 12] | [35.0, 12.0, 37.0, 11.0] | 2.0 / 2 px |
| Disabled | colours / text_class | pass | ["shadow-or-disabled"] | ["shadow-or-disabled"] | 0 / 0 class |
| Disabled | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Disabled | text / baseline | pass | [20.0] | [20.5] | 0.5 / 2 px |
| Disabled | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Disabled | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Disabled | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Disabled | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Disabled | spacing / border_thickness | pass | [2, 2, 2, 2] | [2, 2, 2, 2] | 0 / 1 px |
| Disabled | colours / border_class | pass | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | 0 / 0 class |
| Disabled | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Disabled | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Disabled | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Disabled | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Disabled | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / hit_testing | fail | ["(form)"] | [] | 1 / 0 ordered observations |
| Disabled | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | layout / rectangle_edges | pass | [17, 100, 181, 123] | [16.5, 99.5, 181.0, 123.0] | 0.5 / 1 px |
| Fractional | layout / twips_to_pixel_rounding | pass | [17, 100, 181, 123] | [17, 100, 181, 123] | 0 / 1 px |
| Fractional | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Fractional | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Fractional | text / ink_bounds | fail | [17, 103, 102, 111] | [17, 103, 103, 114] | 3 / 2 px |
| Fractional | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Fractional | text / caption_0_ink_bounds | fail | [17, 103, 102, 111] | [17, 103, 103, 114] | 3 / 2 px |
| Fractional | text / alignment_offsets | pass | [0, 3] | [0.5, 3.5] | 0.5 / 2 px |
| Fractional | spacing / insets | fail | [0, 3, 79, 12] | [0.5, 3.5, 78.0, 9.0] | 3.0 / 2 px |
| Fractional | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Fractional | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Fractional | text / baseline | pass | [11.0] | [12.0] | 1.0 / 2 px |
| Fractional | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Fractional | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Fractional | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Fractional | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| Fractional | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Fractional | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Fractional | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Fractional | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / hit_testing | pass | ["Fractional"] | ["Fractional"] | 0 / 0 ordered observations |
| Fractional | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | layout / rectangle_edges | pass | [264, 48, 376, 80] | [264.0, 48.0, 376.0, 80.0] | 0.0 / 1 px |
| Greet | layout / twips_to_pixel_rounding | pass | [264, 48, 376, 80] | [264, 48, 376, 80] | 0 / 1 px |
| Greet | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Greet | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Greet | text / ink_bounds | pass | [306, 60, 332, 68] | [306, 61, 333, 69] | 1 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [306, 60, 332, 68] | [306, 61, 333, 69] | 1 / 2 px |
| Greet | text / alignment_offsets | pass | [42, 12] | [42.0, 13.0] | 1.0 / 2 px |
| Greet | spacing / insets | pass | [42, 12, 44, 12] | [42.0, 13.0, 43.0, 11.0] | 1.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | pass | [20.0] | [20.5] | 0.5 / 2 px |
| Greet | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Greet | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| Greet | colours / border_class | pass | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | 0 / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| Greet | behaviour / tab_order | pass | [{"position": 1, "next": "LongInput"}] | [{"position": 1, "next": "LongInput"}] | 0 / 0 ordered observations |
| Greet | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Greet | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | pass | ["Greet"] | ["Greet"] | 0 / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [16, 48, 243, 75] | [16.0, 48.0, 242.667, 74.667] | 0.333 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [16, 48, 243, 75] | [16, 48, 243, 75] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| InputName | text / ink_bounds | fail | [29, 52, 48, 65] | [28, 55, 45, 63] | 3 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [29, 52, 48, 65] | [28, 55, 45, 63] | 3 / 2 px |
| InputName | text / alignment_offsets | fail | [13, 4] | [12.0, 7.0] | 3.0 / 2 px |
| InputName | spacing / insets | fail | [13, 4, 195, 10] | [12.0, 7.0, 197.667, 11.667] | 3.0 / 2 px |
| InputName | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | pass | [15.0] | [15.0] | 0.0 / 2 px |
| InputName | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| InputName | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | pass | [2, 2, 2, 2] | [2, 2, 2, 2] | 0 / 1 px |
| InputName | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| InputName | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "InputName.Change\|"}, {"step": "repeat", "value": "InputName.Change\|"}, {"step": "restore", "value": "InputName.Change\|InputName.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "InputName.Change\|"}, {"step": "repeat", "value": "InputName.Change\|"}, {"step": "restore", "value": "InputName.Change\|InputName.Change\|"}] | 0 / 0 ordered observations |
| InputName | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| InputName | behaviour / tab_order | pass | [{"position": 0, "next": "Greet"}] | [{"position": 0, "next": "Greet"}] | 0 / 0 ordered observations |
| InputName | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| InputName | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | pass | ["InputName"] | ["InputName"] | 0 / 0 ordered observations |
| InputName | behaviour / selection | pass | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | 0 / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | pass | [{"step": "initial", "value": "Ada"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Ada"}] | [{"step": "initial", "value": "Ada"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Ada"}] | 0 / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | layout / rectangle_edges | pass | [16, 144, 216, 171] | [16.0, 144.0, 216.0, 170.667] | 0.333 / 1 px |
| LongInput | layout / twips_to_pixel_rounding | pass | [16, 144, 216, 171] | [16, 144, 216, 171] | 0 / 1 px |
| LongInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| LongInput | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| LongInput | text / ink_bounds | pass | [29, 152, 213, 161] | [28, 151, 212, 161] | 1 / 2 px |
| LongInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| LongInput | text / caption_0_ink_bounds | pass | [29, 152, 213, 161] | [28, 151, 212, 161] | 1 / 2 px |
| LongInput | text / alignment_offsets | pass | [13, 8] | [12.0, 7.0] | 1.0 / 2 px |
| LongInput | spacing / insets | pass | [13, 8, 3, 10] | [12.0, 7.0, 4.0, 9.667] | 1.0 / 2 px |
| LongInput | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| LongInput | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| LongInput | text / baseline | pass | [15.0] | [15.0] | 0.0 / 2 px |
| LongInput | text / clipping_point | pass | [[40]] | [[40]] | 0 / 0 character offsets |
| LongInput | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| LongInput | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| LongInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| LongInput | spacing / border_thickness | pass | [2, 2, 2, 2] | [2, 2, 2, 2] | 0 / 1 px |
| LongInput | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| LongInput | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "LongInput.Change\|"}, {"step": "repeat", "value": "LongInput.Change\|"}, {"step": "restore", "value": "LongInput.Change\|LongInput.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "LongInput.Change\|"}, {"step": "repeat", "value": "LongInput.Change\|"}, {"step": "restore", "value": "LongInput.Change\|LongInput.Change\|"}] | 0 / 0 ordered observations |
| LongInput | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| LongInput | behaviour / tab_order | pass | [{"position": 2, "next": "InputName"}] | [{"position": 2, "next": "InputName"}] | 0 / 0 ordered observations |
| LongInput | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| LongInput | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| LongInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / hit_testing | pass | ["LongInput"] | ["LongInput"] | 0 / 0 ordered observations |
| LongInput | behaviour / selection | pass | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | 0 / 0 ordered observations |
| LongInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / value_changes | pass | [{"step": "initial", "value": "A long input with a clipped trailing word"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "A long input with a clipped trailing word"}] | [{"step": "initial", "value": "A long input with a clipped trailing word"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "A long input with a clipped trailing word"}] | 0 / 0 ordered observations |
| LongInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [16, 16, 243, 40] | [16.0, 16.0, 242.667, 40.0] | 0.333 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [16, 16, 243, 40] | [16, 16, 243, 40] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [18, 19, 109, 29] | [16, 20, 109, 30] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [18, 19, 109, 29] | [16, 20, 109, 30] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [2, 3] | [0.0, 4.0] | 2.0 / 2 px |
| Prompt | spacing / insets | pass | [2, 3, 134, 11] | [0.0, 4.0, 133.667, 10.0] | 2.0 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | pass | [11.0] | [12.0] | 1.0 / 2 px |
| Prompt | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Prompt | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Prompt | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Prompt | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Prompt | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | pass | ["Prompt"] | ["Prompt"] | 0 / 0 ordered observations |
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
| Clipped | layout / rectangle_edges | pass | [324, 150, 464, 174] | [324.0, 150.0, 464.0, 174.0] | 0.0 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [324, 150, 464, 174] | [324, 150, 464, 174] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Clipped | text / ink_bounds | fail | [326, 154, 451, 170] | [325, 156, 455, 172] | 4 / 2 px |
| Clipped | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Clipped | text / caption_0_ink_bounds | fail | [326, 154, 451, 170] | [325, 156, 455, 172] | 4 / 2 px |
| Clipped | text / alignment_offsets | pass | [2, 4] | [1.0, 6.0] | 2.0 / 2 px |
| Clipped | spacing / insets | fail | [2, 4, 13, 4] | [1.0, 6.0, 9.0, 2.0] | 4.0 / 2 px |
| Clipped | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Clipped | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Clipped | text / baseline | pass | [17.0, 38.0] | [18.5, 39.5] | 1.5 / 2 px |
| Clipped | text / clipping_point | pass | [[null, null]] | [[null, null]] | 0 / 0 character offsets |
| Clipped | text / wrap_point | pass | [[19]] | [[19]] | 0 / 0 character offsets |
| Clipped | text / exact_line_breaks | pass | [[19]] | [[19]] | 0 / 0 character offsets |
| Clipped | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| Clipped | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Clipped | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Clipped | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Clipped | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / hit_testing | pass | ["Clipped"] | ["Clipped"] | 0 / 0 ordered observations |
| Clipped | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Clipped | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | layout / rectangle_edges | pass | [396, 216, 564, 264] | [396.0, 216.0, 564.0, 264.0] | 0.0 / 1 px |
| Disabled | layout / twips_to_pixel_rounding | pass | [396, 216, 564, 264] | [396, 216, 564, 264] | 0 / 1 px |
| Disabled | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Disabled | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Disabled | text / ink_bounds | fail | [451, 233, 508, 246] | [449, 234, 511, 247] | 3 / 2 px |
| Disabled | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Disabled | text / caption_0_ink_bounds | fail | [451, 233, 508, 246] | [449, 234, 511, 247] | 3 / 2 px |
| Disabled | text / alignment_offsets | pass | [55, 17] | [53.0, 18.0] | 2.0 / 2 px |
| Disabled | spacing / insets | fail | [55, 17, 56, 18] | [53.0, 18.0, 53.0, 17.0] | 3.0 / 2 px |
| Disabled | colours / text_class | pass | ["shadow-or-disabled"] | ["shadow-or-disabled"] | 0 / 0 class |
| Disabled | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Disabled | text / baseline | pass | [30.0] | [30.5] | 0.5 / 2 px |
| Disabled | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Disabled | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Disabled | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Disabled | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Disabled | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| Disabled | colours / border_class | pass | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | 0 / 0 class |
| Disabled | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Disabled | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Disabled | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Disabled | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Disabled | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / hit_testing | fail | ["(form)"] | [] | 1 / 0 ordered observations |
| Disabled | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Disabled | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | layout / rectangle_edges | pass | [25, 149, 272, 185] | [24.75, 149.25, 271.5, 184.5] | 0.5 / 1 px |
| Fractional | layout / twips_to_pixel_rounding | pass | [25, 149, 272, 185] | [25, 149, 272, 185] | 0 / 1 px |
| Fractional | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Fractional | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Fractional | text / ink_bounds | fail | [27, 154, 160, 166] | [26, 155, 160, 171] | 5 / 2 px |
| Fractional | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Fractional | text / caption_0_ink_bounds | fail | [27, 154, 160, 166] | [26, 155, 160, 171] | 5 / 2 px |
| Fractional | text / alignment_offsets | pass | [2, 5] | [1.25, 5.75] | 0.75 / 2 px |
| Fractional | spacing / insets | fail | [2, 5, 112, 19] | [1.25, 5.75, 111.5, 13.5] | 5.5 / 2 px |
| Fractional | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Fractional | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Fractional | text / baseline | fail | [16.0] | [18.5] | 2.5 / 2 px |
| Fractional | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Fractional | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Fractional | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Fractional | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| Fractional | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Fractional | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Fractional | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Fractional | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / hit_testing | pass | ["Fractional"] | ["Fractional"] | 0 / 0 ordered observations |
| Fractional | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Fractional | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | layout / rectangle_edges | pass | [396, 72, 564, 120] | [396.0, 72.0, 564.0, 120.0] | 0.0 / 1 px |
| Greet | layout / twips_to_pixel_rounding | pass | [396, 72, 564, 120] | [396, 72, 564, 120] | 0 / 1 px |
| Greet | layout / control_kind | pass | "CommandButton" | "CommandButton" | 0 / 0 identity |
| Greet | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Greet | text / ink_bounds | fail | [461, 90, 498, 102] | [460, 91, 501, 103] | 3 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | fail | [461, 90, 498, 102] | [460, 91, 501, 103] | 3 / 2 px |
| Greet | text / alignment_offsets | pass | [65, 18] | [64.0, 19.0] | 1.0 / 2 px |
| Greet | spacing / insets | fail | [65, 18, 66, 18] | [64.0, 19.0, 63.0, 17.0] | 3.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | pass | [30.0] | [30.5] | 0.5 / 2 px |
| Greet | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Greet | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | pass | [4, 4, 4, 4] | [5, 5, 4, 4] | 1 / 1 px |
| Greet | colours / border_class | pass | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | [["dark-text", "white", "mid-light"], ["dark-text", "white", "mid-light"], ["dark-text", "shadow-or-disabled"], ["dark-text", "shadow-or-disabled"]] | 0 / 0 class |
| Greet | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| Greet | behaviour / tab_order | pass | [{"position": 1, "next": "LongInput"}] | [{"position": 1, "next": "LongInput"}] | 0 / 0 ordered observations |
| Greet | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Greet | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Greet | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / hit_testing | pass | ["Greet"] | ["Greet"] | 0 / 0 ordered observations |
| Greet | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Greet | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | layout / rectangle_edges | pass | [24, 72, 364, 112] | [24.0, 72.0, 364.0, 112.0] | 0.0 / 1 px |
| InputName | layout / twips_to_pixel_rounding | pass | [24, 72, 364, 112] | [24, 72, 364, 112] | 0 / 1 px |
| InputName | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| InputName | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| InputName | text / ink_bounds | pass | [43, 81, 69, 94] | [43, 81, 69, 94] | 0 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | pass | [43, 81, 69, 94] | [43, 81, 69, 94] | 0 / 2 px |
| InputName | text / alignment_offsets | pass | [19, 9] | [19.0, 9.0] | 0.0 / 2 px |
| InputName | spacing / insets | pass | [19, 9, 295, 18] | [19.0, 9.0, 295.0, 18.0] | 0.0 / 2 px |
| InputName | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | pass | [22.0] | [22.0] | 0.0 / 2 px |
| InputName | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| InputName | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| InputName | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| InputName | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "InputName.Change\|"}, {"step": "repeat", "value": "InputName.Change\|"}, {"step": "restore", "value": "InputName.Change\|InputName.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "InputName.Change\|"}, {"step": "repeat", "value": "InputName.Change\|"}, {"step": "restore", "value": "InputName.Change\|InputName.Change\|"}] | 0 / 0 ordered observations |
| InputName | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| InputName | behaviour / tab_order | pass | [{"position": 0, "next": "Greet"}] | [{"position": 0, "next": "Greet"}] | 0 / 0 ordered observations |
| InputName | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| InputName | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| InputName | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / hit_testing | pass | ["InputName"] | ["InputName"] | 0 / 0 ordered observations |
| InputName | behaviour / selection | pass | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | 0 / 0 ordered observations |
| InputName | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| InputName | behaviour / value_changes | pass | [{"step": "initial", "value": "Ada"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Ada"}] | [{"step": "initial", "value": "Ada"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Ada"}] | 0 / 0 ordered observations |
| InputName | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | layout / rectangle_edges | pass | [24, 216, 324, 256] | [24.0, 216.0, 324.0, 256.0] | 0.0 / 1 px |
| LongInput | layout / twips_to_pixel_rounding | pass | [24, 216, 324, 256] | [24, 216, 324, 256] | 0 / 1 px |
| LongInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| LongInput | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| LongInput | text / ink_bounds | pass | [43, 225, 319, 241] | [43, 225, 318, 241] | 1 / 2 px |
| LongInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| LongInput | text / caption_0_ink_bounds | pass | [43, 225, 319, 241] | [43, 225, 318, 241] | 1 / 2 px |
| LongInput | text / alignment_offsets | pass | [19, 9] | [19.0, 9.0] | 0.0 / 2 px |
| LongInput | spacing / insets | pass | [19, 9, 5, 15] | [19.0, 9.0, 6.0, 15.0] | 1.0 / 2 px |
| LongInput | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| LongInput | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| LongInput | text / baseline | pass | [22.0] | [22.0] | 0.0 / 2 px |
| LongInput | text / clipping_point | fail | [[40]] | [[39]] | 1 / 0 character offsets |
| LongInput | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| LongInput | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| LongInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| LongInput | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| LongInput | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| LongInput | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "LongInput.Change\|"}, {"step": "repeat", "value": "LongInput.Change\|"}, {"step": "restore", "value": "LongInput.Change\|LongInput.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "LongInput.Change\|"}, {"step": "repeat", "value": "LongInput.Change\|"}, {"step": "restore", "value": "LongInput.Change\|LongInput.Change\|"}] | 0 / 0 ordered observations |
| LongInput | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| LongInput | behaviour / tab_order | pass | [{"position": 2, "next": "InputName"}] | [{"position": 2, "next": "InputName"}] | 0 / 0 ordered observations |
| LongInput | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| LongInput | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| LongInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / hit_testing | pass | ["LongInput"] | ["LongInput"] | 0 / 0 ordered observations |
| LongInput | behaviour / selection | pass | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | 0 / 0 ordered observations |
| LongInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| LongInput | behaviour / value_changes | pass | [{"step": "initial", "value": "A long input with a clipped trailing word"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "A long input with a clipped trailing word"}] | [{"step": "initial", "value": "A long input with a clipped trailing word"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "A long input with a clipped trailing word"}] | 0 / 0 ordered observations |
| LongInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | layout / rectangle_edges | pass | [24, 24, 364, 60] | [24.0, 24.0, 364.0, 60.0] | 0.0 / 1 px |
| Prompt | layout / twips_to_pixel_rounding | pass | [24, 24, 364, 60] | [24, 24, 364, 60] | 0 / 1 px |
| Prompt | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Prompt | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Prompt | text / ink_bounds | pass | [25, 29, 168, 44] | [24, 31, 169, 46] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [25, 29, 168, 44] | [24, 31, 169, 46] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [1, 5] | [0.0, 7.0] | 2.0 / 2 px |
| Prompt | spacing / insets | pass | [1, 5, 196, 16] | [0.0, 7.0, 195.0, 14.0] | 2.0 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | pass | [17.0] | [18.5] | 1.5 / 2 px |
| Prompt | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Prompt | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Prompt | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Prompt | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Prompt | behaviour / enter_default | pass | [{"step": "enter", "value": "Greet.Click\|"}] | [{"step": "enter", "value": "Greet.Click\|"}] | 0 / 0 ordered observations |
| Prompt | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Prompt | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Prompt | behaviour / hit_testing | pass | ["Prompt"] | ["Prompt"] | 0 / 0 ordered observations |
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
| Checked | layout / rectangle_edges | pass | [232, 16, 405, 40] | [232.0, 16.0, 405.333, 40.0] | 0.333 / 1 px |
| Checked | layout / twips_to_pixel_rounding | pass | [232, 16, 405, 40] | [232, 16, 405, 40] | 0 / 1 px |
| Checked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Checked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Checked | text / ink_bounds | pass | [250, 24, 289, 32] | [250, 24, 290, 33] | 1 / 2 px |
| Checked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Checked | text / caption_0_ink_bounds | pass | [250, 24, 289, 32] | [250, 24, 290, 33] | 1 / 2 px |
| Checked | text / alignment_offsets | pass | [18, 8] | [18.0, 8.0] | 0.0 / 2 px |
| Checked | spacing / insets | pass | [18, 8, 116, 8] | [18.0, 8.0, 115.333, 7.0] | 1.0 / 2 px |
| Checked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Checked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Checked | text / baseline | pass | [16.0] | [16.5] | 0.5 / 2 px |
| Checked | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Checked | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Checked | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Checked | spacing / glyph_size | pass | [13.0, 13.0] | [12.667, 12.667] | 0.333 / 1 px |
| Checked | spacing / glyph_caption_gap | pass | 4.0 | 4.667 | 0.667 / 1 px |
| Checked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Checked | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Checked.Change\|Checked.Click\|"}, {"step": "repeat", "value": "Checked.Change\|Checked.Click\|"}, {"step": "restore", "value": "Checked.Change\|Checked.Click\|Checked.Change\|Checked.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Checked.Change\|Checked.Click\|"}, {"step": "repeat", "value": "Checked.Change\|Checked.Click\|"}, {"step": "restore", "value": "Checked.Change\|Checked.Click\|Checked.Change\|Checked.Click\|"}] | 0 / 0 ordered observations |
| Checked | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Checked | behaviour / tab_order | pass | [{"position": 1, "next": "OptionOne"}] | [{"position": 1, "next": "OptionOne"}] | 0 / 0 ordered observations |
| Checked | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Checked | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Checked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / hit_testing | pass | ["Checked"] | ["Checked"] | 0 / 0 ordered observations |
| Checked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / value_changes | pass | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | 0 / 0 ordered observations |
| Checked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | layout / rectangle_edges | pass | [16, 152, 189, 247] | [16.0, 152.0, 189.333, 248.0] | 1.0 / 1 px |
| Choices | layout / twips_to_pixel_rounding | pass | [16, 152, 189, 247] | [16, 152, 189, 248] | 1 / 1 px |
| Choices | layout / control_kind | pass | "ListBox" | "ListBox" | 0 / 0 identity |
| Choices | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Choices | text / ink_bounds | pass | [28, 158, 61, 191] | [27, 157, 60, 191] | 1 / 2 px |
| Choices | text / visible_line_count | fail | 4 | 3 | 1 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | [27, 157, 52, 165] | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | [27, 170, 47, 178] | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | [27, 183, 60, 191] | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | pass | [12, 6] | [11.0, 5.0] | 1.0 / 2 px |
| Choices | spacing / insets | pass | [12, 6, 128, 56] | [11.0, 5.0, 129.333, 57.0] | 1.333 / 2 px |
| Choices | colours / text_class | pass | ["dark-text", "white"] | ["dark-text", "white"] | 0 / 0 class |
| Choices | spacing / list_row_height | fail | [12, 7, 6] | [13, 13] | 1 / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | pass | [2, 2, 2, 2] | [2, 2, 2, 2] | 0 / 1 px |
| Choices | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| Choices | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Choices.Change\|Choices.Click\|"}, {"step": "repeat", "value": "Choices.Change\|Choices.Click\|"}, {"step": "restore", "value": "Choices.Change\|Choices.Click\|Choices.Change\|Choices.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Choices.Change\|Choices.Click\|"}, {"step": "repeat", "value": "Choices.Change\|Choices.Click\|"}, {"step": "restore", "value": "Choices.Change\|Choices.Click\|Choices.Change\|Choices.Click\|"}] | 0 / 0 ordered observations |
| Choices | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Choices | behaviour / tab_order | pass | [{"position": 6, "next": "Dropdown"}] | [{"position": 6, "next": "Dropdown"}] | 0 / 0 ordered observations |
| Choices | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Choices | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Choices | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / hit_testing | pass | ["Choices"] | ["Choices"] | 0 / 0 ordered observations |
| Choices | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| Choices | behaviour / scrolling | pass | [{"step": "initial", "value": "index=1;count=23;top=0"}, {"step": "page_down_1", "value": "index=7;count=23;top=1"}, {"step": "page_down_2", "value": "index=13;count=23;top=7"}, {"step": "home", "value": "index=0;count=23;top=0"}] | [{"step": "initial", "value": "index=1;count=23;top=0"}, {"step": "page_down_1", "value": "index=7;count=23;top=1"}, {"step": "page_down_2", "value": "index=13;count=23;top=7"}, {"step": "home", "value": "index=0;count=23;top=0"}] | 0 / 0 ordered observations |
| Choices | behaviour / value_changes | pass | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | 0 / 0 ordered observations |
| Choices | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | layout / rectangle_edges | pass | [232, 152, 405, 180] | [232.0, 152.0, 405.333, 180.0] | 0.333 / 1 px |
| Dropdown | layout / twips_to_pixel_rounding | pass | [232, 152, 405, 180] | [232, 152, 405, 180] | 0 / 1 px |
| Dropdown | layout / control_kind | pass | "ComboBox" | "ComboBox" | 0 / 0 identity |
| Dropdown | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Dropdown | text / ink_bounds | pass | [244, 159, 264, 167] | [244, 159, 264, 167] | 0 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | pass | [244, 159, 264, 167] | [244, 159, 264, 167] | 0 / 2 px |
| Dropdown | text / alignment_offsets | pass | [12, 7] | [12.0, 7.0] | 0.0 / 2 px |
| Dropdown | spacing / insets | pass | [12, 7, 141, 13] | [12.0, 7.0, 141.333, 13.0] | 0.333 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | pass | [15.0] | [15.0] | 0.0 / 2 px |
| Dropdown | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Dropdown | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Dropdown | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | spacing / drop_arrow_bounds | pass | [391, 164, 398, 168] | [391, 164, 398, 168] | 0 / 1 px |
| Dropdown | spacing / drop_button_border_thickness | pass | [2, 2, 3, 3] | [2, 2, 3, 3] | 0 / 1 px |
| Dropdown | spacing / drop_button_fill_bounds | pass | [388, 156, 401, 176] | [388, 156, 401, 176] | 0 / 1 px |
| Dropdown | spacing / drop_button_rectangle | pass | [386, 154, 404, 179] | [386.0, 154.0, 404.0, 178.667] | 0.333 / 1 px |
| Dropdown | colours / drop_button_border_class | pass | [["mid-light", "white"], ["mid-light", "white"], ["mid-light", "shadow-or-disabled"], ["mid-light", "shadow-or-disabled"]] | [["mid-light", "white"], ["mid-light", "white"], ["mid-light", "shadow-or-disabled"], ["mid-light", "shadow-or-disabled"]] | 0 / 0 class |
| Dropdown | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "repeat", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "restore", "value": "Dropdown.Change\|Dropdown.Click\|Dropdown.Change\|Dropdown.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "repeat", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "restore", "value": "Dropdown.Change\|Dropdown.Click\|Dropdown.Change\|Dropdown.Click\|"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / tab_index | pass | 7 | 7 | 0 / 0 index |
| Dropdown | behaviour / tab_order | pass | [{"position": 7, "next": "Unchecked"}] | [{"position": 7, "next": "Unchecked"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Dropdown | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Dropdown | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / hit_testing | pass | ["Dropdown"] | ["Dropdown"] | 0 / 0 ordered observations |
| Dropdown | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / value_changes | pass | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | layout / rectangle_edges | pass | [16, 56, 189, 80] | [16.0, 56.0, 189.333, 80.0] | 0.333 / 1 px |
| OptionOne | layout / twips_to_pixel_rounding | pass | [16, 56, 189, 80] | [16, 56, 189, 80] | 0 / 1 px |
| OptionOne | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionOne | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionOne | text / ink_bounds | fail | [34, 64, 86, 72] | [34, 65, 87, 75] | 3 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | fail | [34, 64, 86, 72] | [34, 65, 87, 75] | 3 / 2 px |
| OptionOne | text / alignment_offsets | pass | [18, 8] | [18.0, 9.0] | 1.0 / 2 px |
| OptionOne | spacing / insets | fail | [18, 8, 103, 8] | [18.0, 9.0, 102.333, 5.0] | 3.0 / 2 px |
| OptionOne | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionOne | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionOne | text / baseline | pass | [16.0] | [16.5] | 0.5 / 2 px |
| OptionOne | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| OptionOne | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionOne | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionOne | spacing / glyph_size | pass | [13.0, 13.0] | [13.0, 13.0] | 0.0 / 1 px |
| OptionOne | spacing / glyph_caption_gap | pass | 4.0 | 3.0 | 1.0 / 1 px |
| OptionOne | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionOne | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|"}, {"step": "repeat", "value": "OptionOne.Change\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionOne.Change\|OptionOne.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|"}, {"step": "repeat", "value": "OptionOne.Change\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionOne.Change\|OptionOne.Click\|"}] | 0 / 0 ordered observations |
| OptionOne | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| OptionOne | behaviour / tab_order | pass | [{"position": 2, "next": "OptionTwo"}] | [{"position": 2, "next": "OptionTwo"}] | 0 / 0 ordered observations |
| OptionOne | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| OptionOne | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| OptionOne | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / hit_testing | pass | ["OptionOne"] | ["OptionOne"] | 0 / 0 ordered observations |
| OptionOne | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / value_changes | pass | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | 0 / 0 ordered observations |
| OptionOne | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | layout / rectangle_edges | pass | [232, 56, 405, 80] | [232.0, 56.0, 405.333, 80.0] | 0.333 / 1 px |
| OptionTwo | layout / twips_to_pixel_rounding | pass | [232, 56, 405, 80] | [232, 56, 405, 80] | 0 / 1 px |
| OptionTwo | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionTwo | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionTwo | text / ink_bounds | fail | [250, 64, 316, 72] | [250, 64, 317, 75] | 3 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | fail | [250, 64, 316, 72] | [250, 64, 317, 75] | 3 / 2 px |
| OptionTwo | text / alignment_offsets | pass | [18, 8] | [18.0, 8.0] | 0.0 / 2 px |
| OptionTwo | spacing / insets | fail | [18, 8, 89, 8] | [18.0, 8.0, 88.333, 5.0] | 3.0 / 2 px |
| OptionTwo | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionTwo | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionTwo | text / baseline | pass | [16.0] | [16.5] | 0.5 / 2 px |
| OptionTwo | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| OptionTwo | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionTwo | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionTwo | spacing / glyph_size | pass | [13.0, 13.0] | [13.0, 13.0] | 0.0 / 1 px |
| OptionTwo | spacing / glyph_caption_gap | pass | 4.0 | 3.0 | 1.0 / 1 px |
| OptionTwo | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionTwo | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "repeat", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|OptionTwo.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "repeat", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|OptionTwo.Change\|"}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| OptionTwo | behaviour / tab_order | pass | [{"position": 3, "next": "ToggleOff"}] | [{"position": 3, "next": "ToggleOff"}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / hit_testing | pass | ["OptionTwo"] | ["OptionTwo"] | 0 / 0 ordered observations |
| OptionTwo | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / value_changes | pass | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | layout / rectangle_edges | pass | [16, 96, 189, 128] | [16.0, 96.0, 189.333, 128.0] | 0.333 / 1 px |
| ToggleOff | layout / twips_to_pixel_rounding | pass | [16, 96, 189, 128] | [16, 96, 189, 128] | 0 / 1 px |
| ToggleOff | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOff | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [77, 107, 126, 118] | [77, 108, 127, 119] | 1 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [77, 107, 126, 118] | [77, 108, 127, 119] | 1 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [61, 11] | [61.0, 12.0] | 1.0 / 2 px |
| ToggleOff | spacing / insets | pass | [61, 11, 63, 10] | [61.0, 12.0, 62.333, 9.0] | 1.0 / 2 px |
| ToggleOff | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | pass | [20.0] | [20.5] | 0.5 / 2 px |
| ToggleOff | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| ToggleOff | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOff | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | pass | [2, 2, 2, 2] | [2, 2, 2, 2] | 0 / 1 px |
| ToggleOff | colours / border_class | pass | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | 0 / 0 class |
| ToggleOff | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "repeat", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "restore", "value": "ToggleOff.Change\|ToggleOff.Click\|ToggleOff.Change\|ToggleOff.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "repeat", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "restore", "value": "ToggleOff.Change\|ToggleOff.Click\|ToggleOff.Change\|ToggleOff.Click\|"}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| ToggleOff | behaviour / tab_order | pass | [{"position": 4, "next": "ToggleOn"}] | [{"position": 4, "next": "ToggleOn"}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / hit_testing | pass | ["ToggleOff"] | ["ToggleOff"] | 0 / 0 ordered observations |
| ToggleOff | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / value_changes | pass | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | layout / rectangle_edges | pass | [232, 96, 405, 128] | [232.0, 96.0, 405.333, 128.0] | 0.333 / 1 px |
| ToggleOn | layout / twips_to_pixel_rounding | pass | [232, 96, 405, 128] | [232, 96, 405, 128] | 0 / 1 px |
| ToggleOn | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOn | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOn | text / ink_bounds | pass | [295, 109, 340, 119] | [294, 108, 341, 119] | 1 / 2 px |
| ToggleOn | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOn | text / caption_0_ink_bounds | pass | [295, 109, 340, 119] | [294, 108, 341, 119] | 1 / 2 px |
| ToggleOn | text / alignment_offsets | pass | [63, 13] | [62.0, 12.0] | 1.0 / 2 px |
| ToggleOn | spacing / insets | pass | [63, 13, 65, 9] | [62.0, 12.0, 64.333, 9.0] | 1.0 / 2 px |
| ToggleOn | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| ToggleOn | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOn | text / baseline | pass | [21.0] | [20.5] | 0.5 / 2 px |
| ToggleOn | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| ToggleOn | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOn | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOn | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOn | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "repeat", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "restore", "value": "ToggleOn.Change\|ToggleOn.Click\|ToggleOn.Change\|ToggleOn.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "repeat", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "restore", "value": "ToggleOn.Change\|ToggleOn.Click\|ToggleOn.Change\|ToggleOn.Click\|"}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| ToggleOn | behaviour / tab_order | pass | [{"position": 5, "next": "Choices"}] | [{"position": 5, "next": "Choices"}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / hit_testing | pass | ["ToggleOn"] | ["ToggleOn"] | 0 / 0 ordered observations |
| ToggleOn | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / value_changes | pass | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | layout / rectangle_edges | pass | [16, 16, 189, 40] | [16.0, 16.0, 189.333, 40.0] | 0.333 / 1 px |
| Unchecked | layout / twips_to_pixel_rounding | pass | [16, 16, 189, 40] | [16, 16, 189, 40] | 0 / 1 px |
| Unchecked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Unchecked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Unchecked | text / ink_bounds | pass | [34, 26, 84, 32] | [34, 24, 85, 33] | 2 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | pass | [34, 26, 84, 32] | [34, 24, 85, 33] | 2 / 2 px |
| Unchecked | text / alignment_offsets | pass | [18, 10] | [18.0, 8.0] | 2.0 / 2 px |
| Unchecked | spacing / insets | pass | [18, 10, 105, 8] | [18.0, 8.0, 104.333, 7.0] | 2.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [32, 19, 89, 36] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | pass | [16.0] | [16.5] | 0.5 / 2 px |
| Unchecked | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Unchecked | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Unchecked | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Unchecked | spacing / glyph_size | pass | [13.0, 13.0] | [12.667, 12.667] | 0.333 / 1 px |
| Unchecked | spacing / glyph_caption_gap | pass | 4.0 | 4.667 | 0.667 / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "repeat", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "restore", "value": "Unchecked.Change\|Unchecked.Click\|Unchecked.Change\|Unchecked.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "repeat", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "restore", "value": "Unchecked.Change\|Unchecked.Click\|Unchecked.Change\|Unchecked.Click\|"}] | 0 / 0 ordered observations |
| Unchecked | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Unchecked | behaviour / tab_order | pass | [{"position": 0, "next": "Checked"}] | [{"position": 0, "next": "Checked"}] | 0 / 0 ordered observations |
| Unchecked | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Unchecked | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Unchecked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / hit_testing | pass | ["Unchecked"] | ["Unchecked"] | 0 / 0 ordered observations |
| Unchecked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / value_changes | pass | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | 0 / 0 ordered observations |
| Unchecked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutSelection — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [660, 420] | [660, 420] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [660, 420] | [660, 420] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [660, 420] | [660, 420] | 0 / 0 px |
| Checked | layout / rectangle_edges | pass | [348, 24, 608, 60] | [348.0, 24.0, 608.0, 60.0] | 0.0 / 1 px |
| Checked | layout / twips_to_pixel_rounding | pass | [348, 24, 608, 60] | [348, 24, 608, 60] | 0 / 1 px |
| Checked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Checked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Checked | text / ink_bounds | fail | [373, 35, 433, 48] | [375, 36, 436, 49] | 3 / 2 px |
| Checked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Checked | text / caption_0_ink_bounds | fail | [373, 35, 433, 48] | [375, 36, 436, 49] | 3 / 2 px |
| Checked | text / alignment_offsets | pass | [25, 11] | [27.0, 12.0] | 2.0 / 2 px |
| Checked | spacing / insets | fail | [25, 11, 175, 12] | [27.0, 12.0, 172.0, 11.0] | 3.0 / 2 px |
| Checked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Checked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Checked | text / baseline | pass | [24.0] | [24.5] | 0.5 / 2 px |
| Checked | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Checked | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Checked | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Checked | spacing / glyph_size | pass | [19.0, 19.0] | [19.0, 19.0] | 0.0 / 1 px |
| Checked | spacing / glyph_caption_gap | fail | 4.0 | 7.0 | 3.0 / 1 px |
| Checked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Checked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Checked | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Checked.Change\|Checked.Click\|"}, {"step": "repeat", "value": "Checked.Change\|Checked.Click\|"}, {"step": "restore", "value": "Checked.Change\|Checked.Click\|Checked.Change\|Checked.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Checked.Change\|Checked.Click\|"}, {"step": "repeat", "value": "Checked.Change\|Checked.Click\|"}, {"step": "restore", "value": "Checked.Change\|Checked.Click\|Checked.Change\|Checked.Click\|"}] | 0 / 0 ordered observations |
| Checked | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Checked | behaviour / tab_order | pass | [{"position": 1, "next": "OptionOne"}] | [{"position": 1, "next": "OptionOne"}] | 0 / 0 ordered observations |
| Checked | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Checked | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Checked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / hit_testing | pass | ["Checked"] | ["Checked"] | 0 / 0 ordered observations |
| Checked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Checked | behaviour / value_changes | pass | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | 0 / 0 ordered observations |
| Checked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | layout / rectangle_edges | pass | [24, 228, 284, 371] | [24.0, 228.0, 284.0, 372.0] | 1.0 / 1 px |
| Choices | layout / twips_to_pixel_rounding | pass | [24, 228, 284, 371] | [24, 228, 284, 372] | 1 / 1 px |
| Choices | layout / control_kind | pass | "ListBox" | "ListBox" | 0 / 0 identity |
| Choices | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Choices | text / ink_bounds | pass | [43, 235, 98, 287] | [41, 234, 97, 286] | 2 / 2 px |
| Choices | text / visible_line_count | fail | 4 | 3 | 1 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | [41, 234, 82, 250] | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | [42, 255, 73, 267] | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | [41, 274, 97, 286] | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | pass | [19, 7] | [17.0, 6.0] | 2.0 / 2 px |
| Choices | spacing / insets | pass | [19, 7, 186, 84] | [17.0, 6.0, 187.0, 86.0] | 2.0 / 2 px |
| Choices | colours / text_class | pass | ["dark-text", "white"] | ["dark-text", "white"] | 0 / 0 class |
| Choices | spacing / list_row_height | fail | [21, 3, 16] | [21, 19] | 1 / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| Choices | colours / border_class | pass | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | [["shadow-or-disabled"], ["shadow-or-disabled"], ["white", "mid-light"], ["white", "mid-light"]] | 0 / 0 class |
| Choices | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Choices.Change\|Choices.Click\|"}, {"step": "repeat", "value": "Choices.Change\|Choices.Click\|"}, {"step": "restore", "value": "Choices.Change\|Choices.Click\|Choices.Change\|Choices.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Choices.Change\|Choices.Click\|"}, {"step": "repeat", "value": "Choices.Change\|Choices.Click\|"}, {"step": "restore", "value": "Choices.Change\|Choices.Click\|Choices.Change\|Choices.Click\|"}] | 0 / 0 ordered observations |
| Choices | behaviour / tab_index | pass | 6 | 6 | 0 / 0 index |
| Choices | behaviour / tab_order | pass | [{"position": 6, "next": "Dropdown"}] | [{"position": 6, "next": "Dropdown"}] | 0 / 0 ordered observations |
| Choices | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Choices | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Choices | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Choices | behaviour / hit_testing | pass | ["Choices"] | ["Choices"] | 0 / 0 ordered observations |
| Choices | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| Choices | behaviour / scrolling | pass | [{"step": "initial", "value": "index=1;count=23;top=0"}, {"step": "page_down_1", "value": "index=7;count=23;top=1"}, {"step": "page_down_2", "value": "index=13;count=23;top=7"}, {"step": "home", "value": "index=0;count=23;top=0"}] | [{"step": "initial", "value": "index=1;count=23;top=0"}, {"step": "page_down_1", "value": "index=7;count=23;top=1"}, {"step": "page_down_2", "value": "index=13;count=23;top=7"}, {"step": "home", "value": "index=0;count=23;top=0"}] | 0 / 0 ordered observations |
| Choices | behaviour / value_changes | pass | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | 0 / 0 ordered observations |
| Choices | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | layout / rectangle_edges | pass | [348, 228, 608, 270] | [348.0, 228.0, 608.0, 270.0] | 0.0 / 1 px |
| Dropdown | layout / twips_to_pixel_rounding | pass | [348, 228, 608, 270] | [348, 228, 608, 270] | 0 / 1 px |
| Dropdown | layout / control_kind | pass | "ComboBox" | "ComboBox" | 0 / 0 identity |
| Dropdown | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Dropdown | text / ink_bounds | pass | [368, 239, 399, 251] | [367, 239, 399, 251] | 1 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | pass | [368, 239, 399, 251] | [367, 239, 399, 251] | 1 / 2 px |
| Dropdown | text / alignment_offsets | pass | [20, 11] | [19.0, 11.0] | 1.0 / 2 px |
| Dropdown | spacing / insets | pass | [20, 11, 209, 19] | [19.0, 11.0, 209.0, 19.0] | 1.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | pass | [23.0] | [23.0] | 0.0 / 2 px |
| Dropdown | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Dropdown | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Dropdown | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | spacing / drop_arrow_bounds | pass | [586, 246, 597, 252] | [586, 246, 597, 252] | 0 / 1 px |
| Dropdown | spacing / drop_button_border_thickness | pass | [3, 3, 4, 4] | [3, 3, 4, 4] | 0 / 1 px |
| Dropdown | spacing / drop_button_fill_bounds | pass | [582, 234, 602, 264] | [582, 234, 602, 264] | 0 / 1 px |
| Dropdown | spacing / drop_button_rectangle | pass | [579, 231, 606, 268] | [579.0, 231.0, 606.0, 268.0] | 0.0 / 1 px |
| Dropdown | colours / drop_button_border_class | pass | [["mid-light", "white"], ["mid-light", "white"], ["mid-light", "shadow-or-disabled"], ["mid-light", "shadow-or-disabled"]] | [["mid-light", "white"], ["mid-light", "white"], ["mid-light", "shadow-or-disabled"], ["mid-light", "shadow-or-disabled"]] | 0 / 0 class |
| Dropdown | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "repeat", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "restore", "value": "Dropdown.Change\|Dropdown.Click\|Dropdown.Change\|Dropdown.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "repeat", "value": "Dropdown.Change\|Dropdown.Click\|"}, {"step": "restore", "value": "Dropdown.Change\|Dropdown.Click\|Dropdown.Change\|Dropdown.Click\|"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / tab_index | pass | 7 | 7 | 0 / 0 index |
| Dropdown | behaviour / tab_order | pass | [{"position": 7, "next": "Unchecked"}] | [{"position": 7, "next": "Unchecked"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Dropdown | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Dropdown | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / hit_testing | pass | ["Dropdown"] | ["Dropdown"] | 0 / 0 ordered observations |
| Dropdown | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Dropdown | behaviour / value_changes | pass | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | [{"step": "initial", "value": "1;value=Beta"}, {"step": "set", "value": "2;value=Gamma"}, {"step": "repeat", "value": "2;value=Gamma"}, {"step": "restore", "value": "1;value=Beta"}] | 0 / 0 ordered observations |
| Dropdown | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | layout / rectangle_edges | pass | [24, 84, 284, 120] | [24.0, 84.0, 284.0, 120.0] | 0.0 / 1 px |
| OptionOne | layout / twips_to_pixel_rounding | pass | [24, 84, 284, 120] | [24, 84, 284, 120] | 0 / 1 px |
| OptionOne | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionOne | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionOne | text / ink_bounds | fail | [50, 96, 131, 108] | [52, 97, 134, 112] | 4 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | fail | [50, 96, 131, 108] | [52, 97, 134, 112] | 4 / 2 px |
| OptionOne | text / alignment_offsets | pass | [26, 12] | [28.0, 13.0] | 2.0 / 2 px |
| OptionOne | spacing / insets | fail | [26, 12, 153, 12] | [28.0, 13.0, 150.0, 8.0] | 4.0 / 2 px |
| OptionOne | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionOne | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionOne | text / baseline | pass | [24.0] | [24.5] | 0.5 / 2 px |
| OptionOne | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| OptionOne | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionOne | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionOne | spacing / glyph_size | pass | [19.0, 19.0] | [19.5, 19.5] | 0.5 / 1 px |
| OptionOne | spacing / glyph_caption_gap | pass | 4.0 | 4.5 | 0.5 / 1 px |
| OptionOne | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionOne | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionOne | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|"}, {"step": "repeat", "value": "OptionOne.Change\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionOne.Change\|OptionOne.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|"}, {"step": "repeat", "value": "OptionOne.Change\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionOne.Change\|OptionOne.Click\|"}] | 0 / 0 ordered observations |
| OptionOne | behaviour / tab_index | pass | 2 | 2 | 0 / 0 index |
| OptionOne | behaviour / tab_order | pass | [{"position": 2, "next": "OptionTwo"}] | [{"position": 2, "next": "OptionTwo"}] | 0 / 0 ordered observations |
| OptionOne | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| OptionOne | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| OptionOne | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / hit_testing | pass | ["OptionOne"] | ["OptionOne"] | 0 / 0 ordered observations |
| OptionOne | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionOne | behaviour / value_changes | pass | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | 0 / 0 ordered observations |
| OptionOne | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | layout / rectangle_edges | pass | [348, 84, 608, 120] | [348.0, 84.0, 608.0, 120.0] | 0.0 / 1 px |
| OptionTwo | layout / twips_to_pixel_rounding | pass | [348, 84, 608, 120] | [348, 84, 608, 120] | 0 / 1 px |
| OptionTwo | layout / control_kind | pass | "OptionButton" | "OptionButton" | 0 / 0 identity |
| OptionTwo | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionTwo | text / ink_bounds | fail | [373, 95, 475, 108] | [375, 96, 478, 112] | 4 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | fail | [373, 95, 475, 108] | [375, 96, 478, 112] | 4 / 2 px |
| OptionTwo | text / alignment_offsets | pass | [25, 11] | [27.0, 12.0] | 2.0 / 2 px |
| OptionTwo | spacing / insets | fail | [25, 11, 133, 12] | [27.0, 12.0, 130.0, 8.0] | 4.0 / 2 px |
| OptionTwo | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| OptionTwo | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| OptionTwo | text / baseline | pass | [24.0] | [24.5] | 0.5 / 2 px |
| OptionTwo | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| OptionTwo | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionTwo | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| OptionTwo | spacing / glyph_size | pass | [19.0, 19.0] | [19.5, 19.5] | 0.5 / 1 px |
| OptionTwo | spacing / glyph_caption_gap | pass | 4.0 | 4.5 | 0.5 / 1 px |
| OptionTwo | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| OptionTwo | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| OptionTwo | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "repeat", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|OptionTwo.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "repeat", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|"}, {"step": "restore", "value": "OptionOne.Change\|OptionTwo.Change\|OptionTwo.Click\|OptionTwo.Change\|"}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / tab_index | pass | 3 | 3 | 0 / 0 index |
| OptionTwo | behaviour / tab_order | pass | [{"position": 3, "next": "ToggleOff"}] | [{"position": 3, "next": "ToggleOff"}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / hit_testing | pass | ["OptionTwo"] | ["OptionTwo"] | 0 / 0 ordered observations |
| OptionTwo | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| OptionTwo | behaviour / value_changes | pass | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | 0 / 0 ordered observations |
| OptionTwo | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | layout / rectangle_edges | pass | [24, 144, 284, 192] | [24.0, 144.0, 284.0, 192.0] | 0.0 / 1 px |
| ToggleOff | layout / twips_to_pixel_rounding | pass | [24, 144, 284, 192] | [24, 144, 284, 192] | 0 / 1 px |
| ToggleOff | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOff | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [117, 161, 190, 177] | [117, 162, 191, 178] | 1 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [117, 161, 190, 177] | [117, 162, 191, 178] | 1 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [93, 17] | [93.0, 18.0] | 1.0 / 2 px |
| ToggleOff | spacing / insets | pass | [93, 17, 94, 15] | [93.0, 18.0, 93.0, 14.0] | 1.0 / 2 px |
| ToggleOff | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | pass | [30.0] | [30.5] | 0.5 / 2 px |
| ToggleOff | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| ToggleOff | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOff | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | pass | [3, 3, 3, 3] | [3, 3, 3, 3] | 0 / 1 px |
| ToggleOff | colours / border_class | pass | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | [["white", "mid-light"], ["white", "mid-light"], ["shadow-or-disabled"], ["shadow-or-disabled"]] | 0 / 0 class |
| ToggleOff | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "repeat", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "restore", "value": "ToggleOff.Change\|ToggleOff.Click\|ToggleOff.Change\|ToggleOff.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "repeat", "value": "ToggleOff.Change\|ToggleOff.Click\|"}, {"step": "restore", "value": "ToggleOff.Change\|ToggleOff.Click\|ToggleOff.Change\|ToggleOff.Click\|"}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / tab_index | pass | 4 | 4 | 0 / 0 index |
| ToggleOff | behaviour / tab_order | pass | [{"position": 4, "next": "ToggleOn"}] | [{"position": 4, "next": "ToggleOn"}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / hit_testing | pass | ["ToggleOff"] | ["ToggleOff"] | 0 / 0 ordered observations |
| ToggleOff | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOff | behaviour / value_changes | pass | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | 0 / 0 ordered observations |
| ToggleOff | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | layout / rectangle_edges | pass | [348, 144, 608, 192] | [348.0, 144.0, 608.0, 192.0] | 0.0 / 1 px |
| ToggleOn | layout / twips_to_pixel_rounding | pass | [348, 144, 608, 192] | [348, 144, 608, 192] | 0 / 1 px |
| ToggleOn | layout / control_kind | pass | "ToggleButton" | "ToggleButton" | 0 / 0 identity |
| ToggleOn | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOn | text / ink_bounds | pass | [442, 162, 512, 178] | [442, 162, 514, 178] | 2 / 2 px |
| ToggleOn | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOn | text / caption_0_ink_bounds | pass | [442, 162, 512, 178] | [442, 162, 514, 178] | 2 / 2 px |
| ToggleOn | text / alignment_offsets | pass | [94, 18] | [94.0, 18.0] | 0.0 / 2 px |
| ToggleOn | spacing / insets | pass | [94, 18, 96, 14] | [94.0, 18.0, 94.0, 14.0] | 2.0 / 2 px |
| ToggleOn | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| ToggleOn | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOn | text / baseline | pass | [31.0] | [30.5] | 0.5 / 2 px |
| ToggleOn | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| ToggleOn | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOn | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| ToggleOn | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOn | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOn | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "repeat", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "restore", "value": "ToggleOn.Change\|ToggleOn.Click\|ToggleOn.Change\|ToggleOn.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "repeat", "value": "ToggleOn.Change\|ToggleOn.Click\|"}, {"step": "restore", "value": "ToggleOn.Change\|ToggleOn.Click\|ToggleOn.Change\|ToggleOn.Click\|"}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / tab_index | pass | 5 | 5 | 0 / 0 index |
| ToggleOn | behaviour / tab_order | pass | [{"position": 5, "next": "Choices"}] | [{"position": 5, "next": "Choices"}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / hit_testing | pass | ["ToggleOn"] | ["ToggleOn"] | 0 / 0 ordered observations |
| ToggleOn | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| ToggleOn | behaviour / value_changes | pass | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | [{"step": "initial", "value": "True"}, {"step": "set", "value": "False"}, {"step": "repeat", "value": "False"}, {"step": "restore", "value": "True"}] | 0 / 0 ordered observations |
| ToggleOn | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | layout / rectangle_edges | pass | [24, 24, 284, 60] | [24.0, 24.0, 284.0, 60.0] | 0.0 / 1 px |
| Unchecked | layout / twips_to_pixel_rounding | pass | [24, 24, 284, 60] | [24, 24, 284, 60] | 0 / 1 px |
| Unchecked | layout / control_kind | pass | "CheckBox" | "CheckBox" | 0 / 0 identity |
| Unchecked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Unchecked | text / ink_bounds | fail | [46, 35, 131, 54] | [52, 36, 130, 49] | 6 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | fail | [46, 35, 131, 54] | [52, 36, 130, 49] | 6 / 2 px |
| Unchecked | text / alignment_offsets | fail | [22, 11] | [28.0, 12.0] | 6.0 / 2 px |
| Unchecked | spacing / insets | fail | [22, 11, 153, 6] | [28.0, 12.0, 154.0, 11.0] | 6.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [46, 29, 131, 42] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | pass | [24.0] | [24.5] | 0.5 / 2 px |
| Unchecked | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Unchecked | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Unchecked | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Unchecked | spacing / glyph_size | pass | [19.0, 19.0] | [19.0, 19.0] | 0.0 / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | 4.0 | 7.0 | 3.0 / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "repeat", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "restore", "value": "Unchecked.Change\|Unchecked.Click\|Unchecked.Change\|Unchecked.Click\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "repeat", "value": "Unchecked.Change\|Unchecked.Click\|"}, {"step": "restore", "value": "Unchecked.Change\|Unchecked.Click\|Unchecked.Change\|Unchecked.Click\|"}] | 0 / 0 ordered observations |
| Unchecked | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Unchecked | behaviour / tab_order | pass | [{"position": 0, "next": "Checked"}] | [{"position": 0, "next": "Checked"}] | 0 / 0 ordered observations |
| Unchecked | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Unchecked | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Unchecked | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / hit_testing | pass | ["Unchecked"] | ["Unchecked"] | 0 / 0 ordered observations |
| Unchecked | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Unchecked | behaviour / value_changes | pass | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | [{"step": "initial", "value": "False"}, {"step": "set", "value": "True"}, {"step": "repeat", "value": "True"}, {"step": "restore", "value": "False"}] | 0 / 0 ordered observations |
| Unchecked | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutContainers — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [520, 380] | [520, 380] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [520, 380] | [520, 380] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [520, 380] | [520, 380] | 0 / 0 px |
| Group | layout / rectangle_edges | pass | [16, 16, 248, 112] | [16.0, 16.0, 248.0, 112.0] | 0.0 / 1 px |
| Group | layout / twips_to_pixel_rounding | pass | [16, 16, 248, 112] | [16, 16, 248, 112] | 0 / 1 px |
| Group | layout / control_kind | pass | "Frame" | "Frame" | 0 / 0 identity |
| Group | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Group | text / ink_bounds | pass | [30, 19, 61, 27] | [30, 19, 61, 28] | 1 / 2 px |
| Group | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Group | text / caption_0_ink_bounds | pass | [30, 19, 61, 27] | [30, 19, 61, 28] | 1 / 2 px |
| Group | text / alignment_offsets | pass | [14, 3] | [14.0, 3.0] | 0.0 / 2 px |
| Group | spacing / insets | pass | [14, 3, 187, 85] | [14.0, 3.0, 187.0, 84.0] | 1.0 / 2 px |
| Group | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Group | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Group | text / baseline | pass | [11.0] | [12.0] | 1.0 / 2 px |
| Group | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Group | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group | spacing / frame_caption_gap | pass | [10, 40] | [10.0, 40.0] | 0.0 / 1 px |
| Group | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Group | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Group | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Group | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / hit_testing | fail | ["Group"] | [] | 1 / 0 ordered observations |
| Group | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | layout / rectangle_edges | pass | [34, 76, 218, 100] | [34.0, 75.5, 218.0, 99.5] | 0.5 / 1 px |
| Group.NestedInput | layout / twips_to_pixel_rounding | pass | [34, 76, 218, 100] | [34, 76, 218, 100] | 0 / 1 px |
| Group.NestedInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| Group.NestedInput | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Group.NestedInput | text / ink_bounds | pass | [46, 83, 78, 91] | [46, 83, 78, 91] | 0 / 2 px |
| Group.NestedInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Group.NestedInput | text / caption_0_ink_bounds | pass | [46, 83, 78, 91] | [46, 83, 78, 91] | 0 / 2 px |
| Group.NestedInput | text / alignment_offsets | pass | [12, 7] | [12.0, 7.5] | 0.5 / 2 px |
| Group.NestedInput | spacing / insets | pass | [12, 7, 140, 9] | [12.0, 7.5, 140.0, 8.5] | 0.5 / 2 px |
| Group.NestedInput | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Group.NestedInput | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Group.NestedInput | text / baseline | pass | [15.0] | [15.0] | 0.0 / 2 px |
| Group.NestedInput | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Group.NestedInput | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedInput | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Group.NestedInput.Change\|"}, {"step": "repeat", "value": "Group.NestedInput.Change\|"}, {"step": "restore", "value": "Group.NestedInput.Change\|Group.NestedInput.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Group.NestedInput.Change\|"}, {"step": "repeat", "value": "Group.NestedInput.Change\|"}, {"step": "restore", "value": "Group.NestedInput.Change\|Group.NestedInput.Change\|"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Group.NestedInput | behaviour / tab_order | pass | [{"position": 0, "next": "Spinner"}] | [{"position": 0, "next": "Spinner"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / hit_testing | pass | ["Group.NestedInput"] | ["Group.NestedInput"] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / selection | pass | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / value_changes | pass | [{"step": "initial", "value": "Nested"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Nested"}] | [{"step": "initial", "value": "Nested"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Nested"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | layout / rectangle_edges | pass | [34, 48, 218, 72] | [34.0, 47.5, 218.0, 71.5] | 0.5 / 1 px |
| Group.NestedLabel | layout / twips_to_pixel_rounding | pass | [34, 48, 218, 72] | [34, 48, 218, 72] | 0 / 1 px |
| Group.NestedLabel | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Group.NestedLabel | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Group.NestedLabel | text / ink_bounds | pass | [34, 50, 93, 59] | [34, 51, 93, 60] | 1 / 2 px |
| Group.NestedLabel | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Group.NestedLabel | text / caption_0_ink_bounds | pass | [34, 50, 93, 59] | [34, 51, 93, 60] | 1 / 2 px |
| Group.NestedLabel | text / alignment_offsets | pass | [0, 2] | [0.0, 3.5] | 1.5 / 2 px |
| Group.NestedLabel | spacing / insets | pass | [0, 2, 125, 13] | [0.0, 3.5, 125.0, 11.5] | 1.5 / 2 px |
| Group.NestedLabel | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Group.NestedLabel | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Group.NestedLabel | text / baseline | pass | [11.0] | [12.0] | 1.0 / 2 px |
| Group.NestedLabel | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Group.NestedLabel | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedLabel | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedLabel | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group.NestedLabel | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / hit_testing | pass | ["Group.NestedLabel"] | ["Group.NestedLabel"] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | layout / rectangle_edges | pass | [280, 136, 496, 328] | [280.0, 136.0, 496.0, 328.0] | 0.0 / 1 px |
| PagesControl | layout / twips_to_pixel_rounding | pass | [280, 136, 496, 328] | [280, 136, 496, 328] | 0 / 1 px |
| PagesControl | layout / control_kind | pass | "MultiPage" | "MultiPage" | 0 / 0 identity |
| PagesControl | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| PagesControl | text / ink_bounds | pass | [288, 141, 354, 151] | [288, 141, 355, 151] | 1 / 2 px |
| PagesControl | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| PagesControl | text / caption_0_ink_bounds | pass | [288, 141, 308, 149] | [288, 141, 308, 149] | 0 / 2 px |
| PagesControl | text / caption_0_character_advances | pass | [6.0, 2.0, 4.0, 5.0, 4.0] | [6.0, 2.0, 4.0, 5.0, 4.0] | 0.0 / 1 px |
| PagesControl | text / caption_1_ink_bounds | pass | [321, 143, 354, 151] | [321, 142, 355, 151] | 1 / 2 px |
| PagesControl | text / caption_1_character_advances | pass | [6.0, 6.0, 5.0, 6.0, 6.0, 6.0] | [6.0, 6.0, 5.0, 6.0, 6.0, 6.0] | 0.0 / 1 px |
| PagesControl | text / alignment_offsets | pass | [8, 5] | [8.0, 5.0] | 0.0 / 2 px |
| PagesControl | spacing / insets | pass | [8, 5, 142, 177] | [8.0, 5.0, 141.0, 177.0] | 1.0 / 2 px |
| PagesControl | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| PagesControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| PagesControl | text / baseline | pass | [13.0, 15.0] | [13.0, 15.0] | 0.0 / 2 px |
| PagesControl | text / clipping_point | pass | [[null], [null]] | [[null], [null]] | 0 / 0 character offsets |
| PagesControl | text / wrap_point | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| PagesControl | text / exact_line_breaks | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| PagesControl | spacing / tab_sizes | pass | [37, 21, 47, 17] | [37.0, 21.0, 47.0, 17.0] | 0.0 / 1 px |
| PagesControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| PagesControl | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "PagesControl.Change\|"}, {"step": "repeat", "value": "PagesControl.Change\|"}, {"step": "restore", "value": "PagesControl.Change\|PagesControl.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "PagesControl.Change\|"}, {"step": "repeat", "value": "PagesControl.Change\|"}, {"step": "restore", "value": "PagesControl.Change\|PagesControl.Change\|"}] | 0 / 0 ordered observations |
| PagesControl | behaviour / tab_index | fail | 4 | 5 | 1 / 0 index |
| PagesControl | behaviour / tab_order | fail | [{"position": 4, "next": "PagesControl"}, {"position": 5, "next": "NestedInput"}] | [{"position": 4, "next": "NestedInput"}] | 1 / 0 ordered observations |
| PagesControl | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| PagesControl | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| PagesControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / hit_testing | pass | ["PagesControl"] | ["PagesControl"] | 0 / 0 ordered observations |
| PagesControl | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| PagesControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| PagesControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | layout / rectangle_edges | pass | [280, 16, 368, 88] | [280.0, 16.0, 368.0, 88.0] | 0.0 / 1 px |
| Picture | layout / twips_to_pixel_rounding | pass | [280, 16, 368, 88] | [280, 16, 368, 88] | 0 / 1 px |
| Picture | layout / control_kind | pass | "Image" | "Image" | 0 / 0 identity |
| Picture | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Picture | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Picture | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Picture | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Picture | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Picture | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Picture | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Picture | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / hit_testing | pass | ["Picture"] | ["Picture"] | 0 / 0 ordered observations |
| Picture | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | layout / rectangle_edges | pass | [16, 136, 248, 160] | [16.0, 136.0, 248.0, 160.0] | 0.0 / 1 px |
| Slider | layout / twips_to_pixel_rounding | pass | [16, 136, 248, 160] | [16, 136, 248, 160] | 0 / 1 px |
| Slider | layout / control_kind | pass | "ScrollBar" | "ScrollBar" | 0 / 0 identity |
| Slider | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Slider | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Slider | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Slider | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Slider | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Slider.Change\|"}, {"step": "repeat", "value": "Slider.Change\|"}, {"step": "restore", "value": "Slider.Change\|Slider.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Slider.Change\|"}, {"step": "repeat", "value": "Slider.Change\|"}, {"step": "restore", "value": "Slider.Change\|Slider.Change\|"}] | 0 / 0 ordered observations |
| Slider | behaviour / tab_order | pass | [{"position": 2, "next": "TabsControl"}] | [{"position": 2, "next": "TabsControl"}] | 0 / 0 ordered observations |
| Slider | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Slider | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Slider | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / hit_testing | fail | unmeasured (0) | ["Slider"] | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| Slider | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | layout / rectangle_edges | pass | [400, 16, 424, 88] | [400.0, 16.0, 424.0, 88.0] | 0.0 / 1 px |
| Spinner | layout / twips_to_pixel_rounding | pass | [400, 16, 424, 88] | [400, 16, 424, 88] | 0 / 1 px |
| Spinner | layout / control_kind | pass | "SpinButton" | "SpinButton" | 0 / 0 identity |
| Spinner | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Spinner | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Spinner | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Spinner | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Spinner | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Spinner.Change\|"}, {"step": "repeat", "value": "Spinner.Change\|"}, {"step": "restore", "value": "Spinner.Change\|Spinner.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Spinner.Change\|"}, {"step": "repeat", "value": "Spinner.Change\|"}, {"step": "restore", "value": "Spinner.Change\|Spinner.Change\|"}] | 0 / 0 ordered observations |
| Spinner | behaviour / tab_order | pass | [{"position": 1, "next": "Slider"}] | [{"position": 1, "next": "Slider"}] | 0 / 0 ordered observations |
| Spinner | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Spinner | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Spinner | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / hit_testing | fail | unmeasured (0) | ["Spinner"] | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| Spinner | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | layout / rectangle_edges | pass | [16, 192, 248, 328] | [16.0, 192.0, 248.0, 328.0] | 0.0 / 1 px |
| TabsControl | layout / twips_to_pixel_rounding | pass | [16, 192, 248, 328] | [16, 192, 248, 328] | 0 / 1 px |
| TabsControl | layout / control_kind | pass | "TabStrip" | "TabStrip" | 0 / 0 identity |
| TabsControl | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| TabsControl | text / ink_bounds | pass | [24, 197, 90, 207] | [24, 197, 91, 207] | 1 / 2 px |
| TabsControl | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| TabsControl | text / caption_0_ink_bounds | pass | [24, 197, 44, 205] | [24, 197, 44, 205] | 0 / 2 px |
| TabsControl | text / caption_0_character_advances | pass | [6.0, 2.0, 4.0, 5.0, 4.0] | [6.0, 2.0, 4.0, 5.0, 4.0] | 0.0 / 1 px |
| TabsControl | text / caption_1_ink_bounds | pass | [57, 199, 90, 207] | [57, 198, 91, 207] | 1 / 2 px |
| TabsControl | text / caption_1_character_advances | pass | [6.0, 6.0, 5.0, 6.0, 6.0, 6.0] | [6.0, 6.0, 5.0, 6.0, 6.0, 6.0] | 0.0 / 1 px |
| TabsControl | text / alignment_offsets | pass | [8, 5] | [8.0, 5.0] | 0.0 / 2 px |
| TabsControl | spacing / insets | pass | [8, 5, 158, 121] | [8.0, 5.0, 157.0, 121.0] | 1.0 / 2 px |
| TabsControl | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| TabsControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| TabsControl | text / baseline | pass | [13.0, 15.0] | [13.0, 15.0] | 0.0 / 2 px |
| TabsControl | text / clipping_point | pass | [[null], [null]] | [[null], [null]] | 0 / 0 character offsets |
| TabsControl | text / wrap_point | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| TabsControl | text / exact_line_breaks | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| TabsControl | spacing / tab_sizes | pass | [37, 21, 47, 17] | [37.0, 21.0, 47.0, 17.0] | 0.0 / 1 px |
| TabsControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| TabsControl | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "TabsControl.Change\|"}, {"step": "repeat", "value": "TabsControl.Change\|"}, {"step": "restore", "value": "TabsControl.Change\|TabsControl.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "TabsControl.Change\|"}, {"step": "repeat", "value": "TabsControl.Change\|"}, {"step": "restore", "value": "TabsControl.Change\|TabsControl.Change\|"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / tab_index | fail | 3 | 4 | 1 / 0 index |
| TabsControl | behaviour / tab_order | pass | [{"position": 3, "next": "PagesControl"}] | [{"position": 3, "next": "PagesControl"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| TabsControl | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| TabsControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / hit_testing | pass | ["TabsControl"] | ["TabsControl"] | 0 / 0 ordered observations |
| TabsControl | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |

## LayoutContainers — 150%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [780, 570] | [780, 570] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [780, 570] | [780, 570] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [780, 570] | [780, 570] | 0 / 0 px |
| Group | layout / rectangle_edges | pass | [24, 24, 372, 168] | [24.0, 24.0, 372.0, 168.0] | 0.0 / 1 px |
| Group | layout / twips_to_pixel_rounding | pass | [24, 24, 372, 168] | [24, 24, 372, 168] | 0 / 1 px |
| Group | layout / control_kind | pass | "Frame" | "Frame" | 0 / 0 identity |
| Group | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Group | text / ink_bounds | pass | [47, 29, 96, 41] | [46, 30, 96, 43] | 2 / 2 px |
| Group | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Group | text / caption_0_ink_bounds | pass | [47, 29, 96, 41] | [46, 30, 96, 43] | 2 / 2 px |
| Group | text / alignment_offsets | pass | [23, 5] | [22.0, 6.0] | 1.0 / 2 px |
| Group | spacing / insets | pass | [23, 5, 276, 127] | [22.0, 6.0, 276.0, 125.0] | 2.0 / 2 px |
| Group | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Group | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Group | text / baseline | pass | [17.0] | [18.5] | 1.5 / 2 px |
| Group | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Group | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group | spacing / frame_caption_gap | pass | [15, 64] | [15.0, 64.0] | 0.0 / 1 px |
| Group | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Group | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Group | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Group | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / hit_testing | fail | ["Group"] | [] | 1 / 0 ordered observations |
| Group | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | layout / rectangle_edges | pass | [51, 113, 327, 149] | [51.0, 113.25, 327.0, 149.25] | 0.25 / 1 px |
| Group.NestedInput | layout / twips_to_pixel_rounding | pass | [51, 113, 327, 149] | [51, 113, 327, 149] | 0 / 1 px |
| Group.NestedInput | layout / control_kind | pass | "TextBox" | "TextBox" | 0 / 0 identity |
| Group.NestedInput | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Group.NestedInput | text / ink_bounds | pass | [71, 123, 120, 136] | [70, 123, 120, 136] | 1 / 2 px |
| Group.NestedInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Group.NestedInput | text / caption_0_ink_bounds | pass | [71, 123, 120, 136] | [70, 123, 120, 136] | 1 / 2 px |
| Group.NestedInput | text / alignment_offsets | pass | [20, 10] | [19.0, 9.75] | 1.0 / 2 px |
| Group.NestedInput | spacing / insets | pass | [20, 10, 207, 13] | [19.0, 9.75, 207.0, 13.25] | 1.0 / 2 px |
| Group.NestedInput | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Group.NestedInput | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Group.NestedInput | text / baseline | pass | [23.0] | [23.0] | 0.0 / 2 px |
| Group.NestedInput | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Group.NestedInput | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedInput | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedInput | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Group.NestedInput | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Group.NestedInput | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Group.NestedInput.Change\|"}, {"step": "repeat", "value": "Group.NestedInput.Change\|"}, {"step": "restore", "value": "Group.NestedInput.Change\|Group.NestedInput.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Group.NestedInput.Change\|"}, {"step": "repeat", "value": "Group.NestedInput.Change\|"}, {"step": "restore", "value": "Group.NestedInput.Change\|Group.NestedInput.Change\|"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / tab_index | pass | 1 | 1 | 0 / 0 index |
| Group.NestedInput | behaviour / tab_order | pass | [{"position": 0, "next": "Spinner"}] | [{"position": 0, "next": "Spinner"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / hit_testing | pass | ["Group.NestedInput"] | ["Group.NestedInput"] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / selection | pass | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | [{"step": "range", "value": "2;4;pha "}, {"step": "replace", "value": "AlXBeta;3;0"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedInput | behaviour / value_changes | pass | [{"step": "initial", "value": "Nested"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Nested"}] | [{"step": "initial", "value": "Nested"}, {"step": "set", "value": "Parity probe"}, {"step": "repeat", "value": "Parity probe"}, {"step": "restore", "value": "Nested"}] | 0 / 0 ordered observations |
| Group.NestedInput | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | layout / rectangle_edges | pass | [51, 71, 327, 107] | [51.0, 71.25, 327.0, 107.25] | 0.25 / 1 px |
| Group.NestedLabel | layout / twips_to_pixel_rounding | pass | [51, 71, 327, 107] | [51, 71, 327, 107] | 0 / 1 px |
| Group.NestedLabel | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Group.NestedLabel | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Group.NestedLabel | text / ink_bounds | pass | [52, 75, 143, 88] | [51, 77, 143, 90] | 2 / 2 px |
| Group.NestedLabel | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Group.NestedLabel | text / caption_0_ink_bounds | pass | [52, 75, 143, 88] | [51, 77, 143, 90] | 2 / 2 px |
| Group.NestedLabel | text / alignment_offsets | pass | [1, 4] | [0.0, 5.75] | 1.75 / 2 px |
| Group.NestedLabel | spacing / insets | pass | [1, 4, 184, 19] | [0.0, 5.75, 184.0, 17.25] | 1.75 / 2 px |
| Group.NestedLabel | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Group.NestedLabel | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Group.NestedLabel | text / baseline | pass | [17.0] | [18.5] | 1.5 / 2 px |
| Group.NestedLabel | text / clipping_point | pass | [[null]] | [[null]] | 0 / 0 character offsets |
| Group.NestedLabel | text / wrap_point | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedLabel | text / exact_line_breaks | pass | [[]] | [[]] | 0 / 0 character offsets |
| Group.NestedLabel | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / tab_index | pass | 0 | 0 | 0 / 0 index |
| Group.NestedLabel | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / hit_testing | pass | ["Group.NestedLabel"] | ["Group.NestedLabel"] | 0 / 0 ordered observations |
| Group.NestedLabel | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Group.NestedLabel | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | layout / rectangle_edges | pass | [420, 204, 744, 492] | [420.0, 204.0, 744.0, 492.0] | 0.0 / 1 px |
| PagesControl | layout / twips_to_pixel_rounding | pass | [420, 204, 744, 492] | [420, 204, 744, 492] | 0 / 1 px |
| PagesControl | layout / control_kind | pass | "MultiPage" | "MultiPage" | 0 / 0 identity |
| PagesControl | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| PagesControl | text / ink_bounds | pass | [434, 212, 535, 227] | [433, 212, 535, 227] | 1 / 2 px |
| PagesControl | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| PagesControl | text / caption_0_ink_bounds | pass | [434, 212, 465, 224] | [433, 212, 465, 224] | 1 / 2 px |
| PagesControl | text / caption_0_character_advances | pass | [9.0, 4.0, 6.0, 8.0, 6.0] | [9.0, 4.0, 6.0, 8.0, 6.0] | 0.0 / 1 px |
| PagesControl | text / caption_1_ink_bounds | pass | [484, 214, 535, 227] | [483, 214, 535, 227] | 1 / 2 px |
| PagesControl | text / caption_1_character_advances | pass | [9.0, 9.0, 8.0, 9.0, 9.0, 9.0] | [9.0, 9.0, 8.0, 9.0, 9.0, 9.0] | 0.0 / 1 px |
| PagesControl | text / alignment_offsets | pass | [14, 8] | [13.0, 8.0] | 1.0 / 2 px |
| PagesControl | spacing / insets | pass | [14, 8, 209, 265] | [13.0, 8.0, 209.0, 265.0] | 1.0 / 2 px |
| PagesControl | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| PagesControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| PagesControl | text / baseline | pass | [20.0, 23.0] | [20.0, 23.0] | 0.0 / 2 px |
| PagesControl | text / clipping_point | pass | [[null], [null]] | [[null], [null]] | 0 / 0 character offsets |
| PagesControl | text / wrap_point | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| PagesControl | text / exact_line_breaks | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| PagesControl | spacing / tab_sizes | pass | [57, 33, 71, 27] | [57.0, 33.0, 71.0, 27.0] | 0.0 / 1 px |
| PagesControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| PagesControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| PagesControl | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "PagesControl.Change\|"}, {"step": "repeat", "value": "PagesControl.Change\|"}, {"step": "restore", "value": "PagesControl.Change\|PagesControl.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "PagesControl.Change\|"}, {"step": "repeat", "value": "PagesControl.Change\|"}, {"step": "restore", "value": "PagesControl.Change\|PagesControl.Change\|"}] | 0 / 0 ordered observations |
| PagesControl | behaviour / tab_index | fail | 4 | 5 | 1 / 0 index |
| PagesControl | behaviour / tab_order | fail | [{"position": 4, "next": "PagesControl"}, {"position": 5, "next": "NestedInput"}] | [{"position": 4, "next": "NestedInput"}] | 1 / 0 ordered observations |
| PagesControl | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| PagesControl | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| PagesControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / hit_testing | pass | ["PagesControl"] | ["PagesControl"] | 0 / 0 ordered observations |
| PagesControl | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| PagesControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| PagesControl | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| PagesControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | layout / rectangle_edges | pass | [420, 24, 552, 132] | [420.0, 24.0, 552.0, 132.0] | 0.0 / 1 px |
| Picture | layout / twips_to_pixel_rounding | pass | [420, 24, 552, 132] | [420, 24, 552, 132] | 0 / 1 px |
| Picture | layout / control_kind | pass | "Image" | "Image" | 0 / 0 identity |
| Picture | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Picture | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Picture | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Picture | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Picture | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Picture | behaviour / event_order | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / tab_order | pass | [] | [] | 0 / 0 ordered observations |
| Picture | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Picture | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Picture | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / hit_testing | pass | ["Picture"] | ["Picture"] | 0 / 0 ordered observations |
| Picture | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / value_changes | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Picture | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | layout / rectangle_edges | pass | [24, 204, 372, 240] | [24.0, 204.0, 372.0, 240.0] | 0.0 / 1 px |
| Slider | layout / twips_to_pixel_rounding | pass | [24, 204, 372, 240] | [24, 204, 372, 240] | 0 / 1 px |
| Slider | layout / control_kind | pass | "ScrollBar" | "ScrollBar" | 0 / 0 identity |
| Slider | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Slider | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Slider | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Slider | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Slider | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Slider | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Slider.Change\|"}, {"step": "repeat", "value": "Slider.Change\|"}, {"step": "restore", "value": "Slider.Change\|Slider.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Slider.Change\|"}, {"step": "repeat", "value": "Slider.Change\|"}, {"step": "restore", "value": "Slider.Change\|Slider.Change\|"}] | 0 / 0 ordered observations |
| Slider | behaviour / tab_order | pass | [{"position": 2, "next": "TabsControl"}] | [{"position": 2, "next": "TabsControl"}] | 0 / 0 ordered observations |
| Slider | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Slider | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Slider | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / hit_testing | fail | unmeasured (0) | ["Slider"] | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Slider | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| Slider | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | layout / rectangle_edges | pass | [600, 24, 636, 132] | [600.0, 24.0, 636.0, 132.0] | 0.0 / 1 px |
| Spinner | layout / twips_to_pixel_rounding | pass | [600, 24, 636, 132] | [600, 24, 636, 132] | 0 / 1 px |
| Spinner | layout / control_kind | pass | "SpinButton" | "SpinButton" | 0 / 0 identity |
| Spinner | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Spinner | text / caption_count | pass | 0 | 0 | 0 / 0 captions |
| Spinner | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Spinner | spacing / insets | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Spinner | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Spinner | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "Spinner.Change\|"}, {"step": "repeat", "value": "Spinner.Change\|"}, {"step": "restore", "value": "Spinner.Change\|Spinner.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "Spinner.Change\|"}, {"step": "repeat", "value": "Spinner.Change\|"}, {"step": "restore", "value": "Spinner.Change\|Spinner.Change\|"}] | 0 / 0 ordered observations |
| Spinner | behaviour / tab_order | pass | [{"position": 1, "next": "Slider"}] | [{"position": 1, "next": "Slider"}] | 0 / 0 ordered observations |
| Spinner | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| Spinner | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| Spinner | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / hit_testing | fail | unmeasured (0) | ["Spinner"] | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / selection | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| Spinner | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| Spinner | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | layout / rectangle_edges | pass | [24, 288, 372, 492] | [24.0, 288.0, 372.0, 492.0] | 0.0 / 1 px |
| TabsControl | layout / twips_to_pixel_rounding | pass | [24, 288, 372, 492] | [24, 288, 372, 492] | 0 / 1 px |
| TabsControl | layout / control_kind | pass | "TabStrip" | "TabStrip" | 0 / 0 identity |
| TabsControl | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| TabsControl | text / ink_bounds | pass | [38, 296, 139, 311] | [37, 296, 139, 311] | 1 / 2 px |
| TabsControl | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| TabsControl | text / caption_0_ink_bounds | pass | [38, 296, 69, 308] | [37, 296, 69, 308] | 1 / 2 px |
| TabsControl | text / caption_0_character_advances | pass | [9.0, 4.0, 6.0, 8.0, 6.0] | [9.0, 4.0, 6.0, 8.0, 6.0] | 0.0 / 1 px |
| TabsControl | text / caption_1_ink_bounds | pass | [88, 298, 139, 311] | [87, 298, 139, 311] | 1 / 2 px |
| TabsControl | text / caption_1_character_advances | pass | [9.0, 9.0, 8.0, 9.0, 9.0, 9.0] | [9.0, 9.0, 8.0, 9.0, 9.0, 9.0] | 0.0 / 1 px |
| TabsControl | text / alignment_offsets | pass | [14, 8] | [13.0, 8.0] | 1.0 / 2 px |
| TabsControl | spacing / insets | pass | [14, 8, 233, 181] | [13.0, 8.0, 233.0, 181.0] | 1.0 / 2 px |
| TabsControl | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| TabsControl | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| TabsControl | text / baseline | pass | [20.0, 23.0] | [20.0, 23.0] | 0.0 / 2 px |
| TabsControl | text / clipping_point | pass | [[null], [null]] | [[null], [null]] | 0 / 0 character offsets |
| TabsControl | text / wrap_point | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| TabsControl | text / exact_line_breaks | pass | [[], []] | [[], []] | 0 / 0 character offsets |
| TabsControl | spacing / tab_sizes | pass | [57, 33, 71, 27] | [57.0, 33.0, 71.0, 27.0] | 0.0 / 1 px |
| TabsControl | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| TabsControl | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| TabsControl | behaviour / event_order | pass | [{"step": "initial", "value": ""}, {"step": "set", "value": "TabsControl.Change\|"}, {"step": "repeat", "value": "TabsControl.Change\|"}, {"step": "restore", "value": "TabsControl.Change\|TabsControl.Change\|"}] | [{"step": "initial", "value": ""}, {"step": "set", "value": "TabsControl.Change\|"}, {"step": "repeat", "value": "TabsControl.Change\|"}, {"step": "restore", "value": "TabsControl.Change\|TabsControl.Change\|"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / tab_index | fail | 3 | 4 | 1 / 0 index |
| TabsControl | behaviour / tab_order | pass | [{"position": 3, "next": "PagesControl"}] | [{"position": 3, "next": "PagesControl"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / enter_default | pass | [{"step": "enter", "value": ""}] | [{"step": "enter", "value": ""}] | 0 / 0 ordered observations |
| TabsControl | behaviour / escape_cancel | pass | [{"step": "escape", "value": ""}] | [{"step": "escape", "value": ""}] | 0 / 0 ordered observations |
| TabsControl | behaviour / accelerators | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / hit_testing | pass | ["TabsControl"] | ["TabsControl"] | 0 / 0 ordered observations |
| TabsControl | behaviour / selection | pass | [{"step": "select", "value": "1"}] | [{"step": "select", "value": "1"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / scrolling | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
| TabsControl | behaviour / value_changes | pass | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | [{"step": "initial", "value": "0"}, {"step": "set", "value": "1"}, {"step": "repeat", "value": "1"}, {"step": "restore", "value": "0"}] | 0 / 0 ordered observations |
| TabsControl | behaviour / show_hide_unload | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 ordered observations |
