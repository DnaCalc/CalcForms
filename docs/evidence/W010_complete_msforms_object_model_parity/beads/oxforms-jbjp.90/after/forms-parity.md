# FORMS PARITY

384 pass; 552 fail, including 509 missing measurements.
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
| Clipped | layout / rectangle_edges | pass | [216.0, 100.0, 309.333, 116.0] | [216.0, 100.0, 309.333, 116.0] | 0.0 / 1 px |
| Clipped | layout / twips_to_pixel_rounding | pass | [216, 100, 309, 116] | [216, 100, 309, 116] | 0 / 1 px |
| Clipped | layout / control_kind | pass | "Label" | "Label" | 0 / 0 identity |
| Clipped | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Greet | text / ink_bounds | pass | [293, 60, 346, 68] | [292, 60, 348, 68] | 2 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [293, 60, 346, 68] | [292, 60, 348, 68] | 2 / 2 px |
| Greet | text / alignment_offsets | pass | [29.0, 12.0] | [28.0, 12.0] | 1.0 / 2 px |
| Greet | spacing / insets | pass | [29.0, 12.0, 30.0, 12.0] | [28.0, 12.0, 28.0, 12.0] | 2.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Greet | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Greet | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| Greet | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| InputName | text / ink_bounds | pass | [29, 55, 82, 63] | [28, 55, 84, 63] | 2 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | pass | [29, 55, 82, 63] | [28, 55, 84, 63] | 2 / 2 px |
| InputName | text / alignment_offsets | pass | [13.0, 7.0] | [12.0, 7.0] | 1.0 / 2 px |
| InputName | spacing / insets | pass | [13.0, 7.0, 160.667, 11.667] | [12.0, 7.0, 158.667, 11.667] | 2.0 / 2 px |
| InputName | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| InputName | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| InputName | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| InputName | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| Prompt | text / ink_bounds | pass | [17, 19, 70, 27] | [16, 20, 72, 28] | 2 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [17, 19, 70, 27] | [16, 20, 72, 28] | 2 / 2 px |
| Prompt | text / alignment_offsets | pass | [1.0, 3.0] | [0.0, 4.0] | 1.0 / 2 px |
| Prompt | spacing / insets | pass | [1.0, 3.0, 172.667, 13.0] | [0.0, 4.0, 170.667, 12.0] | 2.0 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Prompt | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| Prompt | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| Clipped | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Greet | text / ink_bounds | pass | [438, 90, 521, 102] | [438, 90, 522, 103] | 1 / 2 px |
| Greet | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Greet | text / caption_0_ink_bounds | pass | [438, 90, 521, 102] | [438, 90, 522, 103] | 1 / 2 px |
| Greet | text / alignment_offsets | pass | [42.0, 18.0] | [42.0, 18.0] | 0.0 / 2 px |
| Greet | spacing / insets | pass | [42.0, 18.0, 43.0, 18.0] | [42.0, 18.0, 42.0, 17.0] | 1.0 / 2 px |
| Greet | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Greet | spacing / focus_rectangle | fail | [396, 91, 564, 98] | [] | 1 / 1 px |
| Greet | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Greet | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Greet | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Greet | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Greet | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Greet | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| Greet | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| InputName | text / ink_bounds | pass | [43, 82, 126, 94] | [42, 82, 126, 95] | 1 / 2 px |
| InputName | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| InputName | text / caption_0_ink_bounds | pass | [43, 82, 126, 94] | [42, 82, 126, 95] | 1 / 2 px |
| InputName | text / alignment_offsets | pass | [19.0, 10.0] | [18.0, 10.0] | 1.0 / 2 px |
| InputName | spacing / insets | pass | [19.0, 10.0, 238.0, 18.0] | [18.0, 10.0, 238.0, 17.0] | 1.0 / 2 px |
| InputName | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| InputName | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| InputName | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| InputName | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| InputName | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| InputName | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| InputName | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| InputName | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| Prompt | text / ink_bounds | pass | [25, 29, 109, 41] | [24, 30, 108, 42] | 1 / 2 px |
| Prompt | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Prompt | text / caption_0_ink_bounds | pass | [25, 29, 109, 41] | [24, 30, 108, 42] | 1 / 2 px |
| Prompt | text / alignment_offsets | pass | [1.0, 5.0] | [0.0, 6.0] | 1.0 / 2 px |
| Prompt | spacing / insets | pass | [1.0, 5.0, 255.0, 19.0] | [0.0, 6.0, 256.0, 18.0] | 1.0 / 2 px |
| Prompt | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Prompt | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Prompt | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Prompt | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Prompt | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| Prompt | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| Checked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Choices | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Choices | text / ink_bounds | fail | [29, 157, 53, 191] | [27, 157, 49, 191] | 4 / 2 px |
| Choices | text / visible_line_count | pass | 4 | 4 | 0 / 0 lines |
| Choices | text / caption_0_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_1_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / caption_2_ink_bounds | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / alignment_offsets | pass | [13.0, 5.0] | [11.0, 5.0] | 2.0 / 2 px |
| Choices | spacing / insets | fail | [13.0, 5.0, 136.333, 56.0] | [11.0, 5.0, 140.333, 57.0] | 4.0 / 2 px |
| Choices | colours / text_class | pass | ["dark-text", "white"] | ["dark-text", "white"] | 0 / 0 class |
| Choices | spacing / list_row_height | pass | [13, 3, 10] | [13, 3, 10] | 0 / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Choices | text / caption_0_literal_source | pass | "A&B" | "A&B" | 0 / 0 literal text |
| Choices | text / caption_0_retained_characters | pass | 3 | 3 | 0 / 0 characters |
| Choices | text / caption_1_literal_source | pass | "A&&B" | "A&&B" | 0 / 0 literal text |
| Choices | text / caption_1_retained_characters | pass | 4 | 4 | 0 / 0 characters |
| Choices | text / caption_2_literal_source | pass | "tail&" | "tail&" | 0 / 0 literal text |
| Choices | text / caption_2_retained_characters | pass | 5 | 5 | 0 / 0 characters |
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
| Dropdown | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Dropdown | text / ink_bounds | pass | [245, 159, 270, 167] | [244, 159, 272, 167] | 2 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | pass | [245, 159, 270, 167] | [244, 159, 272, 167] | 2 / 2 px |
| Dropdown | text / alignment_offsets | pass | [13.0, 7.0] | [12.0, 7.0] | 1.0 / 2 px |
| Dropdown | spacing / insets | pass | [13.0, 7.0, 135.333, 13.0] | [12.0, 7.0, 133.333, 13.0] | 2.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Dropdown | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | text / caption_0_literal_source | pass | "A&&B" | "A&&B" | 0 / 0 literal text |
| Dropdown | text / caption_0_retained_characters | pass | 4 | 4 | 0 / 0 characters |
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
| OptionOne | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionOne | text / ink_bounds | pass | [35, 64, 88, 72] | [34, 64, 90, 72] | 2 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | pass | [35, 64, 88, 72] | [34, 64, 90, 72] | 2 / 2 px |
| OptionOne | text / alignment_offsets | pass | [19.0, 8.0] | [18.0, 8.0] | 1.0 / 2 px |
| OptionOne | spacing / insets | pass | [19.0, 8.0, 101.333, 8.0] | [18.0, 8.0, 99.333, 8.0] | 2.0 / 2 px |
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
| OptionOne | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| OptionOne | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| OptionTwo | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionTwo | text / ink_bounds | pass | [250, 64, 316, 72] | [250, 64, 318, 74] | 2 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | pass | [250, 64, 316, 72] | [250, 64, 318, 74] | 2 / 2 px |
| OptionTwo | text / alignment_offsets | pass | [18.0, 8.0] | [18.0, 8.0] | 0.0 / 2 px |
| OptionTwo | spacing / insets | pass | [18.0, 8.0, 89.333, 8.0] | [18.0, 8.0, 87.333, 6.0] | 2.0 / 2 px |
| OptionTwo | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
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
| ToggleOff | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [76, 108, 129, 116] | [75, 108, 130, 116] | 1 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [76, 108, 129, 116] | [75, 108, 130, 116] | 1 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [60.0, 12.0] | [59.0, 12.0] | 1.0 / 2 px |
| ToggleOff | spacing / insets | pass | [60.0, 12.0, 60.333, 12.0] | [59.0, 12.0, 59.333, 12.0] | 1.0 / 2 px |
| ToggleOff | colours / text_class | fail | ["dark-text"] | ["shadow-or-disabled"] | 1 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOff | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOff | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| ToggleOff | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| ToggleOn | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Unchecked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Unchecked | text / ink_bounds | pass | [35, 24, 88, 32] | [34, 24, 90, 32] | 2 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | pass | [35, 24, 88, 32] | [34, 24, 90, 32] | 2 / 2 px |
| Unchecked | text / alignment_offsets | pass | [19.0, 8.0] | [18.0, 8.0] | 1.0 / 2 px |
| Unchecked | spacing / insets | pass | [19.0, 8.0, 101.333, 8.0] | [18.0, 8.0, 99.333, 8.0] | 2.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | spacing / focus_rectangle | fail | [32, 19, 91, 36] | [] | 1 / 1 px |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Unchecked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| Unchecked | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| Checked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Choices | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Choices | text / ink_bounds | fail | [43, 236, 84, 287] | [41, 235, 81, 287] | 3 / 2 px |
| Choices | text / visible_line_count | pass | 3 | 3 | 0 / 0 lines |
| Choices | text / caption_0_ink_bounds | pass | [43, 236, 73, 248] | [41, 235, 71, 248] | 2 / 2 px |
| Choices | text / caption_1_ink_bounds | fail | [43, 256, 84, 268] | [41, 255, 81, 267] | 3 / 2 px |
| Choices | text / caption_2_ink_bounds | fail | [43, 275, 76, 287] | [41, 274, 73, 287] | 3 / 2 px |
| Choices | text / alignment_offsets | pass | [19.0, 8.0] | [17.0, 7.0] | 2.0 / 2 px |
| Choices | spacing / insets | fail | [19.0, 8.0, 200.0, 83.5] | [17.0, 7.0, 203.0, 85.0] | 3.0 / 2 px |
| Choices | colours / text_class | pass | ["dark-text", "white"] | ["dark-text", "white"] | 0 / 0 class |
| Choices | spacing / list_row_height | pass | [20, 19] | [20, 19] | 0 / 1 px |
| Choices | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Choices | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Choices | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Choices | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Choices | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Choices | text / caption_0_literal_source | pass | "A&B" | "A&B" | 0 / 0 literal text |
| Choices | text / caption_0_retained_characters | pass | 3 | 3 | 0 / 0 characters |
| Choices | text / caption_1_literal_source | pass | "A&&B" | "A&&B" | 0 / 0 literal text |
| Choices | text / caption_1_retained_characters | pass | 4 | 4 | 0 / 0 characters |
| Choices | text / caption_2_literal_source | pass | "tail&" | "tail&" | 0 / 0 literal text |
| Choices | text / caption_2_retained_characters | pass | 5 | 5 | 0 / 0 characters |
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
| Dropdown | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Dropdown | text / ink_bounds | pass | [367, 239, 408, 251] | [366, 238, 407, 251] | 1 / 2 px |
| Dropdown | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Dropdown | text / caption_0_ink_bounds | pass | [367, 239, 408, 251] | [366, 238, 407, 251] | 1 / 2 px |
| Dropdown | text / alignment_offsets | pass | [19.0, 11.0] | [18.0, 10.0] | 1.0 / 2 px |
| Dropdown | spacing / insets | pass | [19.0, 11.0, 200.0, 19.0] | [18.0, 10.0, 201.0, 19.0] | 1.0 / 2 px |
| Dropdown | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Dropdown | colours / fill_class | pass | "white" | "white" | 0 / 0 class |
| Dropdown | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Dropdown | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Dropdown | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Dropdown | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Dropdown | text / caption_0_literal_source | pass | "A&&B" | "A&&B" | 0 / 0 literal text |
| Dropdown | text / caption_0_retained_characters | pass | 4 | 4 | 0 / 0 characters |
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
| OptionOne | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionOne | text / ink_bounds | pass | [49, 96, 133, 108] | [51, 96, 135, 109] | 2 / 2 px |
| OptionOne | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionOne | text / caption_0_ink_bounds | pass | [49, 96, 133, 108] | [51, 96, 135, 109] | 2 / 2 px |
| OptionOne | text / alignment_offsets | pass | [25.0, 12.0] | [27.0, 12.0] | 2.0 / 2 px |
| OptionOne | spacing / insets | pass | [25.0, 12.0, 151.0, 12.0] | [27.0, 12.0, 149.0, 11.0] | 2.0 / 2 px |
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
| OptionOne | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| OptionOne | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| OptionTwo | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| OptionTwo | text / ink_bounds | fail | [373, 95, 475, 108] | [376, 96, 477, 112] | 4 / 2 px |
| OptionTwo | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| OptionTwo | text / caption_0_ink_bounds | fail | [373, 95, 475, 108] | [376, 96, 477, 112] | 4 / 2 px |
| OptionTwo | text / alignment_offsets | fail | [25.0, 11.0] | [28.0, 12.0] | 3.0 / 2 px |
| OptionTwo | spacing / insets | fail | [25.0, 11.0, 133.0, 12.0] | [28.0, 12.0, 131.0, 8.0] | 4.0 / 2 px |
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
| ToggleOff | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| ToggleOff | text / ink_bounds | pass | [112, 162, 195, 174] | [112, 162, 196, 175] | 1 / 2 px |
| ToggleOff | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| ToggleOff | text / caption_0_ink_bounds | pass | [112, 162, 195, 174] | [112, 162, 196, 175] | 1 / 2 px |
| ToggleOff | text / alignment_offsets | pass | [88.0, 18.0] | [88.0, 18.0] | 0.0 / 2 px |
| ToggleOff | spacing / insets | pass | [88.0, 18.0, 89.0, 18.0] | [88.0, 18.0, 88.0, 17.0] | 1.0 / 2 px |
| ToggleOff | colours / text_class | fail | ["chromatic"] | ["dark-text"] | 1 / 0 class |
| ToggleOff | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| ToggleOff | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| ToggleOff | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| ToggleOff | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| ToggleOff | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| ToggleOff | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| ToggleOff | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
| ToggleOn | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
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
| Unchecked | layout / native_capture_qualification | pass | 1 | 1 | 0 / 0 qualified captures |
| Unchecked | text / ink_bounds | fail | [46, 29, 136, 54] | [51, 36, 135, 49] | 7 / 2 px |
| Unchecked | text / visible_line_count | pass | 1 | 1 | 0 / 0 lines |
| Unchecked | text / caption_0_ink_bounds | fail | [46, 29, 136, 54] | [51, 36, 135, 49] | 7 / 2 px |
| Unchecked | text / alignment_offsets | fail | [22.0, 5.0] | [27.0, 12.0] | 7.0 / 2 px |
| Unchecked | spacing / insets | fail | [22.0, 5.0, 148.0, 6.0] | [27.0, 12.0, 149.0, 11.0] | 7.0 / 2 px |
| Unchecked | colours / text_class | pass | ["dark-text"] | ["dark-text"] | 0 / 0 class |
| Unchecked | colours / fill_class | pass | "control-face" | "control-face" | 0 / 0 class |
| Unchecked | text / baseline | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 2 px |
| Unchecked | text / clipping_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / wrap_point | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | text / exact_line_breaks | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 character offsets |
| Unchecked | spacing / glyph_size | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / glyph_caption_gap | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / focus_rectangle | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | spacing / border_thickness | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 1 px |
| Unchecked | colours / border_class | fail | unmeasured (0) | unmeasured (0) | unmeasured (0) / 0 class |
| Unchecked | text / caption_0_literal_source | pass | "A&B && C&" | "A&B && C&" | 0 / 0 literal text |
| Unchecked | text / caption_0_retained_characters | pass | 9 | 9 | 0 / 0 characters |
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
