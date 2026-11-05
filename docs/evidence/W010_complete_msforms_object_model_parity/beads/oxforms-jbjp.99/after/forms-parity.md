# FORMS PARITY

161 pass; 238 fail, including 216 missing measurements.
Layout tolerance: 1 px. Visible ink tolerance: 2 px. Exact line breaks and ordered behaviour require exact matches.
Missing measurements fail coverage. Colour masks measure visible ink; they do not establish glyph identity or a baseline.
Pixels are a coarse regression guard and do not set priorities.

## LayoutCommon — 100%

| Control | Area / measurement | Result | Native | CalcForms | Maximum difference / tolerance |
|---|---|---|---|---|---|
| (form) | layout / client_size | pass | [400, 240] | [400, 240] | 0 / 1 px |
| (form) | layout / missing_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / extra_controls | pass | 0 | 0 | 0 / 0 controls |
| (form) | layout / excel_capture_client_size | pass | [400, 240] | [400, 240] | 0 / 0 px |
| (form) | layout / calcforms_capture_client_size | pass | [400, 240] | [400, 240] | 0 / 0 px |
| Clipped | layout / rectangle_edges | pass | [216.0, 100.0, 309.333, 140.0] | [216.0, 100.0, 309.333, 140.0] | 0.0 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [216, 100, 309, 140] | [216, 100, 309, 140] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Clipped | text / ink_bounds | fail | [216, 105, 297, 126] | [216, 104, 303, 127] | 6 / 2 px |
| Clipped | text / visible_line_count | pass | 2 | 2 | 0 / 0 lines |
| Clipped | text / caption_0_ink_bounds | fail | [216, 105, 297, 126] | [216, 104, 303, 127] | 6 / 2 px |
| Clipped | text / alignment_offsets | pass | [0.0, 5.0] | [0.0, 4.0] | 1.0 / 2 px |
| Clipped | spacing / insets | fail | [0.0, 5.0, 12.333, 14.0] | [0.0, 4.0, 6.333, 13.0] | 6.0 / 2 px |
| Clipped | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Clipped | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Clipped | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Clipped | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | text / wrap_point | pass | [19] | [19] | 0 / 0 character offsets |
| Clipped | text / exact_line_breaks | pass | [19] | [19] | 0 / 0 character offsets |
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
| Disabled | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Fractional | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Greet | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| InputName | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| InputName | text / ink_bounds | fail | [29, 52, 48, 65] | [28, 55, 46, 63] | 3 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | fail | [29, 52, 48, 65] | [28, 55, 46, 63] | 3 / 2 px |
| InputName | text / alignment_offsets | fail | [13.0, 4.0] | [12.0, 7.0] | 3.0 / 2 px |
| InputName | spacing / insets | fail | [13.0, 4.0, 194.667, 9.667] | [12.0, 7.0, 196.667, 11.667] | 3.0 / 2 px |
| InputName | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
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
| LongInput | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| LongInput | text / ink_bounds | pass | [29, 152, 213, 161] | [28, 151, 211, 161] | 2 / 2 px |
| LongInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| LongInput | text / caption_0_ink_bounds | pass | [29, 152, 213, 161] | [28, 151, 211, 161] | 2 / 2 px |
| LongInput | text / alignment_offsets | pass | [13.0, 8.0] | [12.0, 7.0] | 1.0 / 2 px |
| LongInput | spacing / insets | pass | [13.0, 8.0, 3.0, 9.667] | [12.0, 7.0, 5.0, 9.667] | 2.0 / 2 px |
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
| Prompt | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Clipped | layout / rectangle_edges | pass | [324.0, 150.0, 464.0, 210.0] | [324.0, 150.0, 464.0, 210.0] | 0.0 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [324, 150, 464, 210] | [324, 150, 464, 210] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Clipped | text / ink_bounds | fail | [325, 154, 451, 191] | [324, 156, 454, 191] | 3 / 2 px |
| Clipped | text / visible_line_count | pass | 2 | 2 | 0 / 0 lines |
| Clipped | text / caption_0_ink_bounds | fail | [325, 154, 451, 191] | [324, 156, 454, 191] | 3 / 2 px |
| Clipped | text / alignment_offsets | pass | [1.0, 4.0] | [0.0, 6.0] | 2.0 / 2 px |
| Clipped | spacing / insets | fail | [1.0, 4.0, 13.0, 19.0] | [0.0, 6.0, 10.0, 19.0] | 3.0 / 2 px |
| Clipped | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Clipped | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Clipped | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Clipped | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Clipped | text / wrap_point | pass | [19] | [19] | 0 / 0 character offsets |
| Clipped | text / exact_line_breaks | pass | [19] | [19] | 0 / 0 character offsets |
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
| Disabled | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Fractional | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Greet | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| InputName | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| InputName | text / ink_bounds | pass | [43, 81, 69, 94] | [42, 82, 69, 95] | 1 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | pass | [43, 81, 69, 94] | [42, 82, 69, 95] | 1 / 2 px |
| InputName | text / alignment_offsets | pass | [19.0, 9.0] | [18.0, 10.0] | 1.0 / 2 px |
| InputName | spacing / insets | pass | [19.0, 9.0, 295.0, 18.0] | [18.0, 10.0, 295.0, 17.0] | 1.0 / 2 px |
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
| LongInput | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| LongInput | text / ink_bounds | pass | [43, 225, 319, 241] | [42, 226, 317, 242] | 2 / 2 px |
| LongInput | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| LongInput | text / caption_0_ink_bounds | pass | [43, 225, 319, 241] | [42, 226, 317, 242] | 2 / 2 px |
| LongInput | text / alignment_offsets | pass | [19.0, 9.0] | [18.0, 10.0] | 1.0 / 2 px |
| LongInput | spacing / insets | pass | [19.0, 9.0, 5.0, 15.0] | [18.0, 10.0, 7.0, 14.0] | 2.0 / 2 px |
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
| Prompt | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
